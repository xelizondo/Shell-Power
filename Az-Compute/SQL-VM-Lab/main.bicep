targetScope = 'subscription'

@description('Resource group for the SQL lab.')
param resourceGroupName string = 'RG-SQL'

@allowed(['canadacentral'])
param location string = 'canadacentral'

@description('Object ID of the user or service principal allowed to read the VM passwords.')
param vaultReaderObjectId string

@allowed(['User', 'ServicePrincipal', 'Group'])
param vaultReaderPrincipalType string = 'User'

@allowed(['az-admin'])
param adminUsername string = 'az-admin'

@description('One strong administrator password per VM, keyed by SQL2025, SQL2022, and SQL2017. Use the deployment script.')
@secure()
param adminPasswords object

@description('Exact Marketplace image versions resolved by the deployment script.')
param imageVersions object = {
  SQL2025: 'latest'
  SQL2022: 'latest'
  SQL2017: 'latest'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: {
    purpose: 'SQL backup demo lab'
  }
}

module lab 'modules/lab.bicep' = {
  name: 'sql-vm-lab'
  scope: rg
  params: {
    location: location
    vaultReaderObjectId: vaultReaderObjectId
    vaultReaderPrincipalType: vaultReaderPrincipalType
    adminUsername: adminUsername
    adminPasswords: adminPasswords
    imageVersions: imageVersions
  }
}

output keyVaultName string = lab.outputs.keyVaultName
output recoveryServicesVaultName string = lab.outputs.recoveryServicesVaultName
output virtualMachines array = lab.outputs.virtualMachines
