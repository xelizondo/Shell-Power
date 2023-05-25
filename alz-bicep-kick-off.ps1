git clone https://github.com/Azure/ALZ-Bicep.git
git clone https://github.com/Azure/terraform-azurerm-caf-enterprise-scale.git
git clone https://github.com/xelizondo/bicep-lz-vending.git
curl -O https://raw.githubusercontent.com/jtracey93/PublicScripts/master/Azure/PowerShell/Enterprise-scale/Wipe-ESLZAzTenant.ps1

New-AzTenantDeployment `
-TemplateFile infra-as-code/bicep/modules/managementGroups/managementGroups.bicep `
-TemplateParameterFile infra-as-code/bicep/modules/managementGroups/parameters/managementGroups.parameters.all.json `
-Location EastUS -DeploymentName "alz-bicep"


#-1 Deploy MGMT groups or Azure global regions
$inputObject = @{
    DeploymentName        = 'alz-MGDeployment-{0}' -f (-join (Get-Date -Format 'yyyyMMddTHHMMssffffZ')[0..63])
    Location              = 'EastUS'
    TemplateFile          = "infra-as-code/bicep/modules/managementGroups/managementGroups.bicep"
    TemplateParameterFile = 'infra-as-code/bicep/modules/managementGroups/parameters/managementGroups.parameters.all.json'
  }
  New-AzTenantDeployment @inputObject

#- Deploy Custom Role definitions
$inputObject = @{
  DeploymentName        = 'alz-CustomRoleDefsDeployment-{0}' -f (-join (Get-Date -Format 'yyyyMMddTHHMMssffffZ')[0..63])
  Location              = 'eastus'
  ManagementGroupId     = 'alz'
  TemplateFile          = "infra-as-code/bicep/modules/customRoleDefinitions/customRoleDefinitions.bicep"
  TemplateParameterFile = 'infra-as-code/bicep/modules/customRoleDefinitions/parameters/customRoleDefinitions.parameters.all.json'
}
New-AzManagementGroupDeployment @inputObject



#- CLEANUP
Install-Module -Name Az.ResourceGraph
.\Wipe-ESLZAzTenant.ps1 -tenantRootGroupID "132736d4-bb30-4536-a172-f2ed120852ec" -intermediateRootGroupID "adpdev"