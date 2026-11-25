variable "subscription_id" {
  description = "Azure subscription ID for the lab."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the new lab resource group."
  type        = string
  default     = "rg-adls-windows-lab"
}

variable "vm_size" {
  description = "Windows VM size; verify quota and availability before deployment."
  type        = string
  default     = "Standard_B2ms"
}

variable "admin_username" {
  description = "Local Windows administrator username."
  type        = string
  default     = "labadmin"
}

variable "rdp_source_cidr" {
  description = "Your public IPv4 CIDR permitted to connect to RDP, for example 203.0.113.10/32."
  type        = string

  validation {
    condition = can(cidrnetmask(var.rdp_source_cidr)) && try(
      tonumber(split("/", var.rdp_source_cidr)[1]) >= 24, false
    )
    error_message = "Provide a specific IPv4 CIDR with a prefix between /24 and /32."
  }
}

variable "key_vault_source_cidr" {
  description = "Public IPv4 CIDR of the Terraform operator accessing Key Vault; defaults to rdp_source_cidr."
  type        = string
  default     = null

  validation {
    condition = var.key_vault_source_cidr == null ? true : (
      can(cidrnetmask(var.key_vault_source_cidr)) && try(
        tonumber(split("/", var.key_vault_source_cidr)[1]) >= 24, false
      )
    )
    error_message = "Provide a specific IPv4 CIDR with a prefix between /24 and /32."
  }
}
