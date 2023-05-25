param storageAccountName string
param resourceGroupName string
param location string
param virtualNetworkName string
param subnetName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: [
        {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          action: 'Allow'
        }
      ]
    }
    isHnsEnabled: true
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = {
  name: '${storageAccountName}-privateEndpoint'
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
    }
    privateLinkServiceConnections: [
      {
        name: '${storageAccountName}-privateEndpointConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateDnsZoneGroups@2021-06-01' = {
  name: '${storageAccountName}-privateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: '${storageAccountName}-privateDnsZoneConfig'
        properties: {
          privateDnsZoneId: privateEndpoint.properties.dnsSettings.privateDnsZoneConfigs[0].privateDnsZoneId
          visibility: 'Private'
        }
      }
    ]
  }
}

output storageAccountOutput string = storageAccount.id
output privateEndpointOutput string = privateEndpoint.id
