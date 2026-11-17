param location string
param vaultReaderObjectId string
param vaultReaderPrincipalType string
param adminUsername string
@secure()
param adminPasswords object
param imageVersions object

var definitions = loadJsonContent('../vm-images.json')
var allowedSource = '162.207.71.133/32'
var vaultName = 'kv-sql-${uniqueString(resourceGroup().id)}'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          value: allowedSource
        }
      ]
    }
  }
}

resource secretReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, vaultReaderObjectId, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: vaultReaderObjectId
    principalType: vaultReaderPrincipalType
  }
}

resource passwords 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = [for definition in definitions: {
  parent: keyVault
  name: '${definition.name}-admin-password'
  properties: {
    value: adminPasswords[definition.name]
    contentType: 'Local Windows administrator password for az-admin'
    attributes: {
      enabled: true
    }
  }
}]

resource recoveryVault 'Microsoft.RecoveryServices/vaults@2024-04-01' = {
  name: 'rsv-sql-lab'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    redundancySettings: {
      crossRegionRestore: 'Disabled'
      standardTierStorageRedundancy: 'GeoRedundant'
    }
  }
}

resource backupStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'sqlbackup${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_RAGRS'
  }
  properties: {
    accessTier: 'Hot'
    isHnsEnabled: false
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'None'
      ipRules: []
      virtualNetworkRules: []
    }
    routingPreference: {
      routingChoice: 'MicrosoftRouting'
      publishMicrosoftEndpoints: true
      publishInternetEndpoints: false
    }
  }
}

resource backupBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: backupStorage
  name: 'default'
  properties: {
    containerDeleteRetentionPolicy: {
      enabled: false
    }
    deleteRetentionPolicy: {
      enabled: false
    }
    isVersioningEnabled: false
  }
}

resource backupContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: backupBlobService
  name: 'sqlbackups'
  properties: {
    publicAccess: 'None'
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-sql-lab'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-From-Admin'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedSource
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
      {
        name: 'Deny-All-Other-Inbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-sql-lab'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.52.0.0/16']
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: 'snet-sql'
  properties: {
    addressPrefix: '10.52.1.0/24'
    defaultOutboundAccess: false
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

module vms 'sql-vm.bicep' = [for (definition, i) in definitions: {
  name: 'vm-${definition.name}'
  params: {
    location: location
    vmName: definition.name
    offer: definition.offer
    imageSku: definition.sku
    imageVersion: imageVersions[definition.name]
    sqlEdition: definition.edition
    sqlLicenseType: definition.licenseType
    subnetId: subnet.id
    adminUsername: adminUsername
    adminPassword: adminPasswords[definition.name]
  }
  dependsOn: [
    passwords[i]
  ]
}]

output keyVaultName string = keyVault.name
output recoveryServicesVaultName string = recoveryVault.name
output backupStorageAccountName string = backupStorage.name
output backupContainerName string = backupContainer.name
output backupContainerUrl string = '${backupStorage.properties.primaryEndpoints.blob}${backupContainer.name}'
output virtualMachines array = [for (definition, i) in definitions: {
  name: definition.name
  publicIp: vms[i].outputs.publicIp
  passwordSecret: '${definition.name}-admin-password'
}]
