git clone https://github.com/Azure/ALZ-Bicep.git
git clone https://github.com/Azure/terraform-azurerm-caf-enterprise-scale.git
curl -O https://github.com/jtracey93/PublicScripts/blob/master/Azure/PowerShell/Enterprise-scale/Wipe-ESLZAzTenant.ps1

New-AzTenantDeployment `
-TemplateFile infra-as-code/bicep/modules/managementGroups/managementGroups.bicep `
-TemplateParameterFile infra-as-code/bicep/modules/managementGroups/parameters/managementGroups.parameters.all.json `
-Location EastUS -DeploymentName "alz-bicep"


# For Azure global regions

$inputObject = @{
    DeploymentName        = 'alz-MGDeployment-{0}' -f (-join (Get-Date -Format 'yyyyMMddTHHMMssffffZ')[0..63])
    Location              = 'EastUS'
    TemplateFile          = "infra-as-code/bicep/modules/managementGroups/managementGroups.bicep"
    TemplateParameterFile = 'infra-as-code/bicep/modules/managementGroups/parameters/managementGroups.parameters.all.json'
  }
  New-AzTenantDeployment @inputObject

  

  .\Wipe-ESLZAzTenant.ps1 -tenantRootGroupID "132736d4-bb30-4536-a172-f2ed120852ec" -intermediateRootGroupID "alz-demo"