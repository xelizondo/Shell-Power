@description('Name of the storage account.')
param storageAccountName string

@description('Location for the resource.')
param location string

@description('Redundancy type used for this storage account.')
param storageAccountType string

@description('Full URL/URI of the Key Vault that contains the encryption key.')
param keyVaultURI string

@description('Name of the encryption key as listed in the Key Vault.')
param keyName string

@description('Resource ID of the user-assigned managed identity that will be used to access the Key Vault.')
param userManagedIdentityID string

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: toLower(storageAccountName)
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userManagedIdentityID}': {}
    }
  }
  properties: {
    allowedCopyScope:'AAD'
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
    encryption: {
      identity: {
        userAssignedIdentity: userManagedIdentityID
      }
      keyvaultproperties: {
        keyvaulturi: keyVaultURI
        keyname: keyName
        keyversion: ''
      }
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Keyvault'
    }
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}
