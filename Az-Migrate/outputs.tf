# Outputs for Azure Migrate Deployment

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.migrate.name
}

output "resource_group_id" {
  description = "ID of the created resource group"
  value       = azurerm_resource_group.migrate.id
}

output "project_name" {
  description = "Name of the Azure Migrate project"
  value       = var.project_name
}

output "location" {
  description = "Location of the deployment"
  value       = var.location
}

output "deployment_output" {
  description = "ARM deployment outputs"
  value       = azurerm_resource_group_template_deployment.migrate_project.output_content
}
