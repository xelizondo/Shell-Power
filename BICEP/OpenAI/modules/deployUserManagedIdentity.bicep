@description('Specifies the name of the managed identity.')
param userManagedIdentityName string

@description('Specifies the location for the resource.')
param location string

resource userManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: userManagedIdentityName
  location: location
}

// Below is an example of generating an output from the deployment for use in another deployment/module. 
// Refer to: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/outputs


// This outputs the Resource ID of the managed identity we just created. An example of the output would be: 
// "/subscriptions/04354afc-xxxx-xxxx-xxxx-a2baa8ed304a/resourcegroups/example-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/example-uami"
// This output is used in the creation of the Storage Account to set encryption to use an encryption key you've generated (Customer Managed Keys).
output userManagedIdentityID string = userManagedIdentity.id

// This outputs the Principal ID of the managed identity we just created. This is different from the Resource ID.
// An example of the output would be: "1d7d21fc-xxxx-xxxx-xxxx-68261e22df5e"
// This output is used in the creation of the role assignment that grants the managed identity access to the key vault.
output userManagedIdentityPrincipalID string = userManagedIdentity.properties.principalId

