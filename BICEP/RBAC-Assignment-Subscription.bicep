//Define the parameters and variables needed for the template. Here's an example:
param subscriptionId string
param ownerObjectId string
param contributorObjectId string

var ownerRoleId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // Azure predefined Owner role ID
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Azure predefined Contributor role ID

//Define the resources to create the RBAC roles. Here's an example:

resource ownerRole 'Microsoft.Authorization/roleDefinitions@2020-04-01' = {
  name: 'Owner Role'
  properties: {
    roleName: 'Owner'
    description: 'Can manage everything in the subscription.'
    assignableScopes: [
      '/subscriptions/${subscriptionId}'
    ]
    permissions: [
      {
        actions: [
          '*'
        ]
        notActions: []
        dataActions: [
          '*'
        ]
        notDataActions: []
      }
    ]
    type: 'CustomRole'
    roleType: 'CustomRole'
  }
}

resource contributorRole 'Microsoft.Authorization/roleDefinitions@2020-04-01' = {
  name: 'Contributor Role'
  properties: {
    roleName: 'Contributor'
    description: 'Can manage everything except access.'
    assignableScopes: [
      '/subscriptions/${subscriptionId}'
    ]
    permissions: [
      {
        actions: [
          'Microsoft.Authorization/*/read',
          'Microsoft.Resources/subscriptions/resourceGroups/read',
          'Microsoft.Resources/subscriptions/resourceGroups/resources/read',
          'Microsoft.Support/*'
        ]
        notActions: [
          'Microsoft.Authorization/*/write',
          'Microsoft.Authorization/elevateAccess/Action',
          'Microsoft.Resources/subscriptions/resourceGroups/write',
          'Microsoft.Resources/subscriptions/resourceGroups/resources/write'
        ]
        dataActions: [
          '*'
        ]
        notDataActions: []
      }
    ]
    type: 'CustomRole'
    roleType: 'CustomRole'
  }
}

//Define the resources to assign the RBAC roles to the specified users or groups. Here's an example:
resource ownerAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01' = {
  name: 'Owner Assignment'
  properties: {
    roleDefinitionId: ownerRoleId
    principalId: ownerObjectId
    scope: '/subscriptions/${subscriptionId}'
  }
}

resource contributorAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01' = {
  name: 'Contributor Assignment'
  properties: {
    roleDefinitionId: contributorRoleId
    principalId: contributorObjectId
    scope: '/subscriptions/${subscriptionId}'
  }
}


