# Variables for Azure Migrate Project Deployment

variable "subscription_id" {
  description = "Azure subscription ID where resources will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to create"
  type        = string
}

variable "location" {
  description = "Location for the resource group and Azure Migrate project"
  type        = string
  default     = "westus2"
}

variable "project_name" {
  description = "Name of the Azure Migrate project"
  type        = string
}

variable "public_network_access" {
  description = "Public network access for the Azure Migrate project"
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Enabled", "Disabled"], var.public_network_access)
    error_message = "Public network access must be either 'Enabled' or 'Disabled'."
  }
}
