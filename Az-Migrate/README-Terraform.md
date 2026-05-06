# Azure Migrate Project - Terraform Deployment

This Terraform configuration creates a minimal Azure Migrate project ready for use with the new Azure Migrate data collector.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated
- An Azure subscription

## Files

- `main.tf` - Main Terraform configuration with resources
- `variables.tf` - Input variable definitions
- `outputs.tf` - Output value definitions
- `terraform.tfvars` - Variable values (update with your settings)

## Deployment Steps

### 1. Update Configuration

Edit `terraform.tfvars` with your values:

```hcl
subscription_id       = "your-subscription-id"
resource_group_name   = "rg-azure-migrate"
location              = "westus2"
project_name          = "AzMigrate-DataCollector-Project"
public_network_access = "Enabled"
```

### 2. Authenticate to Azure

```bash
az login
az account set --subscription "your-subscription-id"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan the Deployment

```bash
terraform plan
```

### 5. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm the deployment.

### 6. View Outputs

After successful deployment:

```bash
terraform output
```

## What Gets Created

- **Resource Group**: A new resource group in your specified location
- **Azure Migrate Project**: A minimal migrate project with:
  - System-assigned managed identity
  - Configurable public network access
  - Ready for data collector input

## Using the Data Collector

Once deployed, you can upload your data collector zip file to the Azure Migrate project through the Azure Portal.

## Cleanup

To destroy all resources created by this configuration:

```bash
terraform destroy
```

## Notes

- The Azure Migrate resource is deployed using an ARM template within Terraform because native Terraform support for Azure Migrate projects is limited
- Tags are automatically applied with deployment metadata
- The project uses minimal configuration optimized for data collector scenarios
