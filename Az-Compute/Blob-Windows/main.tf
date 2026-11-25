locals {
  location     = "canadacentral"
  storage_name = "adlswin${random_id.storage.hex}"
}

resource "random_id" "storage" {
  byte_length = 6
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = local.location
}

data "azurerm_client_config" "current" {}

resource "random_password" "vm_admin" {
  length           = 32
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!@#$%^&*-_=+"
}

resource "azurerm_key_vault" "lab" {
  name                       = "kv-adls-${random_id.storage.hex}"
  location                   = local.location
  resource_group_name        = azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7

  network_acls {
    bypass         = "None"
    default_action = "Deny"
    ip_rules       = [coalesce(var.key_vault_source_cidr, var.rdp_source_cidr)]
  }
}

resource "azurerm_role_assignment" "vault_operator" {
  scope                = azurerm_key_vault.lab.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "vm_admin" {
  name         = "windows-admin-password"
  value        = random_password.vm_admin.result
  key_vault_id = azurerm_key_vault.lab.id

  depends_on = [azurerm_role_assignment.vault_operator]
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-adls-lab"
  location            = local.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.40.0.0/16"]
}

resource "azurerm_public_ip" "identifier" {
  name                = "pip-storage-network-identifier"
  location            = local.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
}

resource "azurerm_network_security_group" "lab" {
  name                = "nsg-adls-lab"
  location            = local.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "AllowRdpFromOperator"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.rdp_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyOtherInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# AzureRM does not yet expose the service endpoint network identifier.
resource "azapi_resource" "subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2025-07-01"
  name      = "snet-windows"
  parent_id = azurerm_virtual_network.lab.id

  body = {
    properties = {
      addressPrefix = "10.40.1.0/24"
      networkSecurityGroup = {
        id = azurerm_network_security_group.lab.id
      }
      serviceEndpoints = [{
        service = "Microsoft.Storage"
        networkIdentifier = {
          id = azurerm_public_ip.identifier.id
        }
      }]
    }
  }
}

resource "azurerm_public_ip" "vm" {
  name                = "pip-windows-vm"
  location            = local.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "vm" {
  name                = "nic-windows-vm"
  location            = local.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azapi_resource.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "vm-adls-lab"
  computer_name         = "adls-lab"
  resource_group_name   = azurerm_resource_group.lab.name
  location              = local.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = azurerm_key_vault_secret.vm_admin.value
  network_interface_ids = [azurerm_network_interface.vm.id]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

# Create the account locked down before it is associated with the perimeter.
resource "azapi_resource" "storage" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = local.storage_name
  parent_id = azurerm_resource_group.lab.id
  location  = local.location

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "StorageV2"
    sku  = { name = "Standard_LRS" }
    properties = {
      isHnsEnabled             = true
      supportsHttpsTrafficOnly = true
      minimumTlsVersion        = "TLS1_2"
      allowBlobPublicAccess    = false
      allowSharedKeyAccess     = false
      publicNetworkAccess      = "SecuredByPerimeter"
      networkAcls              = { defaultAction = "Deny", bypass = "None" }
    }
  }
}

data "azapi_resource" "blob_service" {
  type      = "Microsoft.Storage/storageAccounts/blobServices@2023-05-01"
  name      = "default"
  parent_id = azapi_resource.storage.id
}

resource "azapi_resource" "container" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01"
  name      = "container1"
  parent_id = data.azapi_resource.blob_service.id
  body      = { properties = { publicAccess = "None" } }
}

resource "azurerm_role_assignment" "vm_blob_contributor" {
  scope                = azapi_resource.container.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_windows_virtual_machine.vm.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_network_security_perimeter" "lab" {
  name                = "nsp-adls-lab"
  location            = local.location
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_network_security_perimeter_profile" "lab" {
  name                          = "profile-adls"
  network_security_perimeter_id = azurerm_network_security_perimeter.lab.id
}

resource "azurerm_network_security_perimeter_access_rule" "subnet" {
  name                                  = "allow-windows-subnet"
  network_security_perimeter_profile_id = azurerm_network_security_perimeter_profile.lab.id
  direction                             = "Inbound"
  address_prefixes                      = ["${azurerm_public_ip.identifier.ip_address}/32"]
}

resource "azurerm_network_security_perimeter_association" "storage" {
  name                                  = "storage-association"
  network_security_perimeter_profile_id = azurerm_network_security_perimeter_profile.lab.id
  resource_id                           = azapi_resource.storage.id
  access_mode                           = "Enforced"

  depends_on = [azurerm_network_security_perimeter_access_rule.subnet]
}

resource "azurerm_virtual_machine_extension" "bootstrap" {
  name                       = "install-azcopy-and-job"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \"$b=[Convert]::FromBase64String('${base64gzip(templatefile("${path.module}/bootstrap.ps1.tftpl", {
      copy_script = base64encode(templatefile("${path.module}/copy.ps1.tftpl", { storage_name = local.storage_name }))
    }))}'); $m=New-Object IO.MemoryStream(,$b); $g=New-Object IO.Compression.GZipStream($m,[IO.Compression.CompressionMode]::Decompress); $r=New-Object IO.StreamReader($g); Invoke-Expression $r.ReadToEnd(); if (-not $?) { exit 1 }\""
  })

  depends_on = [
    azurerm_network_security_perimeter_association.storage,
    azurerm_role_assignment.vm_blob_contributor
  ]
}
