# Azure Migrate Project - Minimal Configuration for Data Collector
# Creates a resource group and Azure Migrate project

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Resource Group
resource "azurerm_resource_group" "migrate" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Purpose        = "Azure Migrate"
    DeploymentDate = timestamp()
  }
}

# Azure Migrate Project
resource "azurerm_resource_group_template_deployment" "migrate_project" {
  name                = "azureMigrateProject"
  resource_group_name = azurerm_resource_group.migrate.name
  deployment_mode     = "Incremental"

  template_content = jsonencode({
    "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    resources = [
      {
        type       = "Microsoft.Migrate/MigrateProjects"
        apiVersion = "2020-06-01-preview"
        name       = var.project_name
        location   = var.location
        tags = {
          MigrateProjectName = var.project_name
        }
        identity = {
          type = "SystemAssigned"
        }
        properties = {
          publicNetworkAccess = var.public_network_access
        }
      }
    ]
    outputs = {
      projectResourceId = {
        type  = "string"
        value = "[resourceId('Microsoft.Migrate/MigrateProjects', '${var.project_name}')]"
      }
    }
  })
}
