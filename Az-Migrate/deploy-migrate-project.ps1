# Deploy Azure Migrate Project with Data Collector
# This script deploys a minimal Azure Migrate project for use with the new data collector

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ParameterFile = ".\AzMigrateProject-DataCollector.parameters.json",
    
    [Parameter(Mandatory=$false)]
    [string]$TemplateFile = ".\AzMigrateProject-DataCollector.json"
)

# Set the subscription context
Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Cyan
Set-AzContext -SubscriptionId $SubscriptionId

# Deploy the template at subscription level
Write-Host "Deploying Azure Migrate Project..." -ForegroundColor Cyan
$deployment = New-AzSubscriptionDeployment `
    -Name "AzMigrate-Deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    -Location "westus2" `
    -TemplateFile $TemplateFile `
    -TemplateParameterFile $ParameterFile `
    -Verbose

if ($deployment.ProvisioningState -eq "Succeeded") {
    Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
    Write-Host "Resource Group: $($deployment.Outputs.resourceGroupName.Value)" -ForegroundColor Yellow
    Write-Host "Project Name: $($deployment.Outputs.projectName.Value)" -ForegroundColor Yellow
    Write-Host "Location: $($deployment.Outputs.location.Value)" -ForegroundColor Yellow
    Write-Host "`nYou can now use the Azure Migrate data collector to upload your assessment data." -ForegroundColor Green
} else {
    Write-Host "`nDeployment failed with state: $($deployment.ProvisioningState)" -ForegroundColor Red
}
