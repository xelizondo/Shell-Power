variable "subscription_id" {
  description = "Azure Subscription ID where AVD resources will be deployed."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "centralus"
}

variable "resource_group_name" {
  description = "Resource group name (created by this configuration)."
  type        = string
  default     = "rg-avd-centralus"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    workload    = "avd"
    environment = "prod"
    managed_by  = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------
variable "vnet_address_space" {
  description = "VNet address space."
  type        = list(string)
  default     = ["10.50.1.0/24"]
}

variable "subnet_address_prefixes" {
  description = "Subnet prefix for AVD session hosts."
  type        = list(string)
  default     = ["10.50.1.0/24"]
}

# -----------------------------------------------------------------------------
# Session hosts
# -----------------------------------------------------------------------------
variable "session_host_count" {
  description = "Number of session hosts to deploy."
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "VM size for session hosts."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "vm_name_prefix" {
  description = "Computer name prefix for session hosts (max 11 chars; suffix -NN appended)."
  type        = string
  default     = "avdshv"
}

variable "local_admin_username" {
  description = "Local administrator username on the session hosts."
  type        = string
  default     = "az-admin"
}

# Win11 25H2 multi-session, no Office
variable "image_publisher" {
  description = "Marketplace image publisher."
  type        = string
  default     = "MicrosoftWindowsDesktop"
}

variable "image_offer" {
  description = "Marketplace image offer."
  type        = string
  default     = "windows-11"
}

variable "image_sku" {
  description = "Marketplace image SKU (Win11 multi-session, no Office)."
  type        = string
  default     = "win11-25h2-avd"
}

# -----------------------------------------------------------------------------
# AVD
# -----------------------------------------------------------------------------
variable "host_pool_name" {
  description = "AVD host pool name."
  type        = string
  default     = "hp-avd-pooled"
}

variable "workspace_name" {
  description = "AVD workspace name."
  type        = string
  default     = "ws-avd"
}

variable "app_group_name" {
  description = "AVD application group name (RemoteApp)."
  type        = string
  default     = "ag-avd-remoteapp"
}

variable "max_sessions_per_host" {
  description = "Max concurrent sessions per host."
  type        = number
  default     = 10
}

# -----------------------------------------------------------------------------
# Assignments / Identity
# -----------------------------------------------------------------------------
variable "avd_user_object_ids" {
  description = "List of Entra ID object IDs (users or groups) to grant access to the Application Group and VM login on session hosts."
  type        = list(string)
  default     = []
}
