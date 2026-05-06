output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "host_pool_name" {
  value = azurerm_virtual_desktop_host_pool.this.name
}

output "workspace_name" {
  value = azurerm_virtual_desktop_workspace.this.name
}

output "application_group_name" {
  value = azurerm_virtual_desktop_application_group.remoteapp.name
}

output "remote_apps" {
  value = [
    azurerm_virtual_desktop_application.notepad.friendly_name,
    azurerm_virtual_desktop_application.edge.friendly_name,
    azurerm_virtual_desktop_application.mstsc.friendly_name,
  ]
}

output "session_host_names" {
  value = azurerm_windows_virtual_machine.sh[*].name
}

output "key_vault_name" {
  value = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.this.vault_uri
}

output "local_admin_username" {
  value = var.local_admin_username
}

output "local_admin_password_secret_name" {
  value = azurerm_key_vault_secret.local_admin_password.name
}
