//*******************************************************************************
// General documentation
//*******************************************************************************

// This is a Bicep template. Bicep is a Domain Specific Language (DSL) that is used to deploy Azure resources.
// Bicep is a declarative language, meaning that you declare the desired state of the resources you want to deploy.
// Bicep is a transpiler, meaning that it takes the Bicep code and transpiles it into ARM JSON. This ARM JSON is then used to deploy the resources.

// In this template we're making heavy use of modules. For more information on modules refer to: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/modules

// To learn how to deploy Bicep templates please refer to this documentation:
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-vscode
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cli
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-powershell
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cloud-shell

//*******************************************************************************
// Parameters section of template
//*******************************************************************************

// General parameters
// To learn more about creating parameters refer to: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameters

@description('Specifies the prefix for resource names.')
param prefix string

@allowed([
  'eastus'
  'southcentralus'
  'westeurope'
])
@description('Specifies the location for resource.')
param location string

//*******************************************************************************
// Variables section of template
//*******************************************************************************

// Variables related to setting naming conventions for resources
// Below are examples of string concatenation in Bicep. Refer to: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-string#concat
// Worth mentioning is that Storage Accounts have unique naming standards compared to other resources: https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview#storage-account-name
var resourceGroupName = '${prefix}-rg'
var keyVaultName = '${prefix}-kv'
var keyVaultKEKName = '${prefix}-kek'
var storageAccountName = '${prefix}stor'
var userManagedIdentityName = '${prefix}-uami'
var openAIName = '${prefix}-oai'

// Variables related to Storage Account configuration
// To see possible values refer to: https://learn.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts?pivots=deployment-language-bicep#sku
var storageAccountType = 'Standard_ZRS'

// Variables related to the Key Vault Key used for encryption
// To see possible values refer to: https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults/keys?pivots=deployment-language-bicep
var keySize = 4096
var keyType = 'RSA'
var keyCurve = 'P-256'
var keyOps = [
  'decrypt'
  'encrypt'
  'sign'
  'unwrapKey'
  'verify'
  'wrapKey'
]
// These specific variables relate to the keys lifecycle management settings. For more information on Key Vault Auto Rotation
// refer to: https://learn.microsoft.com/en-us/azure/key-vault/keys/how-to-configure-key-rotation
// And to see valid values refer to: https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults/keys?pivots=deployment-language-bicep#rotationpolicy
var keyExpiryTime = 'P365D'
var keyRotationDate = 'P358D'
var keyNotificationDaysBeforeExpiry = 'P30D'

// Variables related to Role Assignments
// For a list of built-in roles refer to: https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var userManagedIdentityKeyVaultRoleDefinitionID = '12338af0-0e69-4776-bea7-57ae8d297424'

//*******************************************************************************
// Resource section of template
//*******************************************************************************

// This is the root of the overall deployment. We must first create the Resource Group 
// that will house all of the resources required by ADP to support OAI.
// Resource Groups exist directly below the Subscription level. Therefore, we must specify the scope of the deployment to be the Subscription.
// You can learn more about setting scope here: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-to-subscription#set-scope
// For all subsequent resources we will set the scope to be the Resource Group we're creating here.
targetScope = 'subscription'
resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  properties: {}
}

// Then we inflate the Resource Group with a Key Vault. This Key Vault will be used to store
// the key used for encrypting the Storage Account we're going to create later in the deployment.
module deployKeyVault './modules/deployKeyVaultAndKey.bicep' = {
  name: 'DeployKeyVault'
  scope: resourceGroup
  params: {
    keyVaultName: keyVaultName
    location: location
    keyVaultKEKName: keyVaultKEKName
    keySize: keySize
    keyType: keyType
    keyCurve: keyCurve
    keyOps: keyOps
    keyExpiryTime: keyExpiryTime
    keyRotationDate: keyRotationDate
    keyNotificationDaysBeforeExpiry: keyNotificationDaysBeforeExpiry
  }
}

// This deploys a User Managed Identity. This identity will be used to grant the Storage Account access to the Key Vault secret for encryption.
module deployUserManagedIdentity './modules/deployUserManagedIdentity.bicep' = {
  name: 'DeployUserManagedIdentity'
  scope: resourceGroup
  params: {
    userManagedIdentityName: userManagedIdentityName
    location: location
  }
}

// Grants the User Managed Identity the 'Key Vault Crypto User' role on the Key Vault. This is the least privileged built-in role
// that allows the User Managed Identity to access the Key Vault for encryption purposes.
// Below is an example of using an output from the deployment of another module. Refer to: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/outputs
module deployRoleAssignment './modules/deployRoleAssignment.bicep' = {
  name: 'DeployRoleAssignment'
  scope: resourceGroup
  dependsOn: [
    deployUserManagedIdentity
    deployKeyVault
  ]
  params: {
    resourceGroupName: resourceGroupName
    principalId: deployUserManagedIdentity.outputs.userManagedIdentityPrincipalID
    roleDefinitionID: userManagedIdentityKeyVaultRoleDefinitionID
  }
}

// Now that the User Managed Identity, the Key Vault, the Key, and the Role Assignment have been created, we'll go ahead and create the Storage Account.
// Below is an example of declaring dependencies. Not all dependencies need to be declares. Some dependencies are automatically detected by Bicep.
// Refer to: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/resource-dependencies for more information.
module deployStorageAccount './modules/deployStorageAccount.bicep' = {
  name: 'DeployStorageAccount'
  scope: resourceGroup
  dependsOn: [
    deployKeyVault
    deployUserManagedIdentity
    deployRoleAssignment
  ]
  params: {
    storageAccountName: storageAccountName
    location: location
    storageAccountType: storageAccountType
    keyVaultURI: deployKeyVault.outputs.keyVaultURI
    keyName: keyVaultKEKName
    userManagedIdentityID: deployUserManagedIdentity.outputs.userManagedIdentityID
  }
}

// Finally, we create a Cognitive Services of the kind OpenAI. 
module deployOpenAi './modules/deployOpenAI.bicep' = {
  name: 'DeployOpenAI'
  scope: resourceGroup
  params: {
    openAIName: openAIName
    location: location
  }
}
