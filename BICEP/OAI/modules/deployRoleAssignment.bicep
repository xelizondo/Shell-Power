@description('Name of the resourceGroup to create')
param resourceGroupName string

@description('principalId of the user that will be given contributor access to the resourceGroup')
param principalId string

@description('roleDefinition to apply to the resourceGroup - default is contributor')
param roleDefinitionID string

// The name of a role assignment must be a unique GUID. Refer to: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/scenarios-rbac
var roleAssignmentName= guid(principalId, roleDefinitionID, resourceGroupName)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionID)
  }
}
