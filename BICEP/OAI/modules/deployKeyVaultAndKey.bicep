@description('Name of the key vault to be created. Must be globally unique.')
param keyVaultName string

@description('Location for the resource.')
param location string

// The below Parameters are all related to the creation of the key we'll use for encrypting the Storage Account.
// To see possible values refer to: https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults/keys?pivots=deployment-language-bicep
@description('Name of the key used to the encrypt the Storage Account.')
param keyVaultKEKName string
param keySize int
param keyType string
param keyCurve string
param keyOps array
param keyExpiryTime string
param keyRotationDate string
param keyNotificationDaysBeforeExpiry string

// You have to have the tenantID of the Azure AD instance your Key Vault lives in for deployment. 
// The below var just retrieves this information for us.
var tenantId = subscription().tenantId

resource vault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    tenantId: tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    accessPolicies: []
    enableSoftDelete: true
    enableRbacAuthorization: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
  }
}

// Worth mentioning. The below configuration implements auto key rotation and notification of upcoming key expiry.
// This is done in the rotationPolicy section. For more details on auto rotation please refer to:
// https://learn.microsoft.com/en-us/azure/key-vault/keys/how-to-configure-key-rotation
resource key 'Microsoft.KeyVault/vaults/keys@2022-07-01' = {
  name: keyVaultKEKName
  parent: vault
  properties: {
    attributes: {
      enabled: true
      exportable: false
    }
    keyOps: keyOps
    curveName: keyCurve
    keySize: keySize
    kty: keyType
    rotationPolicy: {
      attributes: {
        expiryTime: keyExpiryTime
      }
      lifetimeActions: [
        {
          action: {
            type: 'rotate'
          }
          trigger: {
            timeAfterCreate: keyRotationDate
          }
        }
        {
          action: {
            type: 'notify'
          }
          trigger: {
            timeBeforeExpiry: keyNotificationDaysBeforeExpiry
          }
        }
      ]
    }
  }
}

output keyVaultID string = vault.id
output keyVaultURI string = vault.properties.vaultUri
