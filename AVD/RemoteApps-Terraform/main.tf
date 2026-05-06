data "azurerm_client_config" "current" {}

# Random suffix for globally-unique names (Key Vault).
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
  numeric = true
}

resource "random_password" "local_admin" {
  length           = 24
  special          = true
  override_special = "!@#$%^&*()-_=+[]{}"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------
resource "azurerm_virtual_network" "this" {
  name                = "vnet-avd"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "hosts" {
  name                 = "snet-avd-hosts"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_address_prefixes
}

resource "azurerm_network_security_group" "hosts" {
  name                = "nsg-avd-hosts"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "hosts" {
  subnet_id                 = azurerm_subnet.hosts.id
  network_security_group_id = azurerm_network_security_group.hosts.id
}

# -----------------------------------------------------------------------------
# Key Vault (stores local admin credentials + host pool registration token)
# -----------------------------------------------------------------------------
resource "azurerm_key_vault" "this" {
  name                       = "kv-avd-${random_string.suffix.result}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  tags                       = var.tags
}

# Grant the deploying principal rights to write secrets.
resource "azurerm_role_assignment" "kv_admin_deployer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Allow KV RBAC to propagate before writing secrets.
resource "time_sleep" "kv_rbac_wait" {
  depends_on      = [azurerm_role_assignment.kv_admin_deployer]
  create_duration = "60s"
}

resource "azurerm_key_vault_secret" "local_admin_username" {
  name         = "avd-local-admin-username"
  value        = var.local_admin_username
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [time_sleep.kv_rbac_wait]
}

resource "azurerm_key_vault_secret" "local_admin_password" {
  name         = "avd-local-admin-password"
  value        = random_password.local_admin.result
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [time_sleep.kv_rbac_wait]
}

resource "azurerm_key_vault_secret" "hostpool_token" {
  name         = "avd-hostpool-registration-token"
  value        = azurerm_virtual_desktop_host_pool_registration_info.this.token
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [time_sleep.kv_rbac_wait]
}

# -----------------------------------------------------------------------------
# AVD: Host Pool, Registration Info, Workspace, Application Group
# -----------------------------------------------------------------------------
resource "azurerm_virtual_desktop_host_pool" "this" {
  name                     = var.host_pool_name
  location                 = azurerm_resource_group.this.location
  resource_group_name      = azurerm_resource_group.this.name
  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  maximum_sessions_allowed = var.max_sessions_per_host
  preferred_app_group_type = "RailApplications"
  start_vm_on_connect      = true
  validate_environment     = false

  # Single Sign-On (SSO) for Entra ID joined session hosts.
  # enablerdsaadauth:i:1   -> use Entra ID as the auth provider (enables SSO)
  # targetisaadjoined:i:1  -> tells the client the host is AAD-joined
  custom_rdp_properties = "enablerdsaadauth:i:1;targetisaadjoined:i:1;audiocapturemode:i:1;audiomode:i:0;camerastoredirect:s:*;redirectclipboard:i:1;redirectprinters:i:1;drivestoredirect:s:*;usbdevicestoredirect:s:*"

  tags = var.tags
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "this" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.this.id
  expiration_date = timeadd(timestamp(), "24h")

  lifecycle {
    ignore_changes = [expiration_date]
  }
}

resource "azurerm_virtual_desktop_workspace" "this" {
  name                = var.workspace_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  friendly_name       = "AVD Workspace"
  tags                = var.tags
}

resource "azurerm_virtual_desktop_application_group" "remoteapp" {
  name                = var.app_group_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  type                = "RemoteApp"
  host_pool_id        = azurerm_virtual_desktop_host_pool.this.id
  friendly_name       = "RemoteApps"
  tags                = var.tags
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "this" {
  workspace_id         = azurerm_virtual_desktop_workspace.this.id
  application_group_id = azurerm_virtual_desktop_application_group.remoteapp.id
}

# -----------------------------------------------------------------------------
# RemoteApps: Notepad, Edge, Remote Desktop
# -----------------------------------------------------------------------------
resource "azurerm_virtual_desktop_application" "notepad" {
  name                         = "notepad"
  application_group_id         = azurerm_virtual_desktop_application_group.remoteapp.id
  friendly_name                = "Notepad"
  description                  = "Windows Notepad"
  path                         = "C:\\Windows\\System32\\notepad.exe"
  command_line_argument_policy = "DoNotAllow"
  show_in_portal               = true
  icon_path                    = "C:\\Windows\\System32\\notepad.exe"
  icon_index                   = 0
}

resource "azurerm_virtual_desktop_application" "edge" {
  name                         = "msedge"
  application_group_id         = azurerm_virtual_desktop_application_group.remoteapp.id
  friendly_name                = "Microsoft Edge"
  description                  = "Microsoft Edge browser"
  path                         = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
  command_line_argument_policy = "DoNotAllow"
  show_in_portal               = true
  icon_path                    = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
  icon_index                   = 0
}

resource "azurerm_virtual_desktop_application" "mstsc" {
  name                         = "mstsc"
  application_group_id         = azurerm_virtual_desktop_application_group.remoteapp.id
  friendly_name                = "Remote Desktop"
  description                  = "Remote Desktop Connection"
  path                         = "C:\\Windows\\System32\\mstsc.exe"
  command_line_argument_policy = "DoNotAllow"
  show_in_portal               = true
  icon_path                    = "C:\\Windows\\System32\\mstsc.exe"
  icon_index                   = 0
}

# -----------------------------------------------------------------------------
# RBAC: Application Group + VM User Login (Entra ID join requires this)
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "app_group_user" {
  for_each             = toset(var.avd_user_object_ids)
  scope                = azurerm_virtual_desktop_application_group.remoteapp.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "vm_user_login" {
  for_each             = toset(var.avd_user_object_ids)
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = each.value
}

# -----------------------------------------------------------------------------
# Session Hosts (NIC + VM + AADLogin extension + AVD DSC extension)
# -----------------------------------------------------------------------------
resource "azurerm_network_interface" "sh" {
  count               = var.session_host_count
  name                = format("nic-%s-%02d", var.vm_name_prefix, count.index + 1)
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.hosts.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "sh" {
  count               = var.session_host_count
  name                = format("%s-%02d", var.vm_name_prefix, count.index + 1)
  computer_name       = format("%s-%02d", var.vm_name_prefix, count.index + 1)
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = var.vm_size
  admin_username      = var.local_admin_username
  admin_password      = random_password.local_admin.result
  license_type        = "Windows_Client"
  provision_vm_agent  = true

  network_interface_ids = [azurerm_network_interface.sh[count.index].id]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    name                 = format("osdisk-%s-%02d", var.vm_name_prefix, count.index + 1)
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = "latest"
  }

  tags = var.tags
}

# Entra ID join (AAD Login for Windows)
resource "azurerm_virtual_machine_extension" "aad_login" {
  count                      = var.session_host_count
  name                       = "AADLoginForWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.sh[count.index].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    mdmId = ""
  })
}

# AVD agent registration via DSC
resource "azurerm_virtual_machine_extension" "avd_dsc" {
  count                      = var.session_host_count
  name                       = "Microsoft.PowerShell.DSC"
  virtual_machine_id         = azurerm_windows_virtual_machine.sh[count.index].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    modulesUrl            = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02990.697.zip"
    configurationFunction = "Configuration.ps1\\AddSessionHost"
    properties = {
      hostPoolName                           = azurerm_virtual_desktop_host_pool.this.name
      registrationInfoToken                  = azurerm_virtual_desktop_host_pool_registration_info.this.token
      aadJoin                                = true
      UseAgentDownloadEndpoint               = true
      aadJoinPreview                         = false
      mdmId                                  = ""
      sessionHostConfigurationLastUpdateTime = ""
    }
  })

  depends_on = [azurerm_virtual_machine_extension.aad_login]
}
