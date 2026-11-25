output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "vm_public_ip" {
  description = "Use this IP for RDP from the allowed source; it is not the storage network identifier."
  value       = azurerm_public_ip.vm.ip_address
}

output "storage_network_identifier_ip" {
  description = "Public IP used as the subnet's storage network identifier and allowed by the NSP."
  value       = azurerm_public_ip.identifier.ip_address
}

output "storage_account_name" {
  value = azapi_resource.storage.name
}

output "container_url" {
  value = "https://${local.storage_name}.blob.core.windows.net/container1"
}

output "upload_folder_url" {
  value = "https://${local.storage_name}.blob.core.windows.net/container1/folder-in"
}

output "download_folder_url" {
  value = "https://${local.storage_name}.blob.core.windows.net/container1/folder-out"
}

output "vm_name" {
  value = azurerm_windows_virtual_machine.vm.name
}

output "key_vault_name" {
  description = "Key Vault containing the generated Windows administrator password."
  value       = azurerm_key_vault.lab.name
}

output "vm_password_secret_name" {
  value = azurerm_key_vault_secret.vm_admin.name
}
