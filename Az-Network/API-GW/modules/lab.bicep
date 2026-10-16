@description('Azure region for every lab resource.')
param location string

@description('Short lowercase resource name prefix.')
param namePrefix string

@description('API Management publisher email address.')
param publisherEmail string

@description('API Management publisher display name.')
param publisherName string

@description('Tags applied to resources that support tags.')
param tags object

var suffix = uniqueString(subscription().id, resourceGroup().id)
var virtualNetworkName = 'vnet-${namePrefix}-lab'
var standardSubnetName = 'snet-apim-standardv2-integration'
var premiumSubnetName = 'snet-apim-premiumv2-injection'
var privateEndpointSubnetName = 'snet-private-endpoints'
var testSubnetName = 'snet-test-clients'
var standardNsgName = 'nsg-${namePrefix}-standardv2'
var premiumNsgName = 'nsg-${namePrefix}-premiumv2'
var standardV2Name = take('${namePrefix}-stdv2-${suffix}', 50)
var premiumV2Name = take('${namePrefix}-premv2-${suffix}', 50)
var privateDnsZoneName = 'privatelink.azure-api.net'
var standardSubnetResourceId = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, standardSubnetName)
var premiumSubnetResourceId = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, premiumSubnetName)
var privateEndpointSubnetResourceId = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, privateEndpointSubnetName)

module standardNsg 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'standard-v2-nsg'
  params: {
    name: standardNsgName
    location: location
    securityRules: [
      {
        name: 'Allow-AzureKeyVault-Outbound'
        properties: {
          access: 'Allow'
          destinationAddressPrefix: 'AzureKeyVault'
          destinationPortRange: '443'
          direction: 'Outbound'
          priority: 100
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
        }
      }
    ]
    tags: tags
  }
}

module premiumNsg 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'premium-v2-nsg'
  params: {
    name: premiumNsgName
    location: location
    securityRules: [
      {
        name: 'Allow-AzureKeyVault-Outbound'
        properties: {
          access: 'Allow'
          destinationAddressPrefix: 'AzureKeyVault'
          destinationPortRange: '443'
          direction: 'Outbound'
          priority: 100
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
        }
      }
    ]
    tags: tags
  }
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.10.0' = {
  name: 'comparison-vnet'
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: [
      '10.42.0.0/16'
    ]
    subnets: [
      {
        name: standardSubnetName
        addressPrefix: '10.42.0.0/24'
        networkSecurityGroupResourceId: standardNsg.outputs.resourceId
        delegation: 'Microsoft.Web/serverFarms'
      }
      {
        name: premiumSubnetName
        addressPrefix: '10.42.1.0/24'
        networkSecurityGroupResourceId: premiumNsg.outputs.resourceId
        delegation: 'Microsoft.Web/hostingEnvironments'
      }
      {
        name: privateEndpointSubnetName
        addressPrefix: '10.42.2.0/24'
        privateEndpointNetworkPolicies: 'Disabled'
      }
      {
        name: testSubnetName
        addressPrefix: '10.42.3.0/24'
      }
    ]
    tags: tags
  }
}

module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.8.0' = {
  name: 'apim-private-dns-zone'
  params: {
    name: privateDnsZoneName
    virtualNetworkLinks: [
      {
        name: 'link-${virtualNetworkName}'
        registrationEnabled: false
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
    tags: tags
  }
}

module standardV2 'br/public:avm/res/api-management/service:0.14.4' = {
  name: 'standard-v2-apim'
  params: {
    name: standardV2Name
    location: location
    publisherEmail: publisherEmail
    publisherName: publisherName
    sku: 'StandardV2'
    skuCapacity: 1
    virtualNetworkType: 'External'
    subnetResourceId: standardSubnetResourceId
    publicNetworkAccess: 'Enabled'
    managedIdentities: {
      systemAssigned: true
    }
    privateEndpoints: [
      {
        name: 'pep-${standardV2Name}-gateway'
        service: 'Gateway'
        subnetResourceId: privateEndpointSubnetResourceId
        privateDnsZoneGroup: {
          name: 'default'
          privateDnsZoneGroupConfigs: [
            {
              name: 'apim'
              privateDnsZoneResourceId: privateDnsZone.outputs.resourceId
            }
          ]
        }
      }
    ]
    tags: tags
  }
}

module premiumV2 'br/public:avm/res/api-management/service:0.14.4' = {
  name: 'premium-v2-apim'
  params: {
    name: premiumV2Name
    location: location
    publisherEmail: publisherEmail
    publisherName: publisherName
    sku: 'PremiumV2'
    skuCapacity: 1
    availabilityZones: []
    virtualNetworkType: 'Internal'
    subnetResourceId: premiumSubnetResourceId
    publicNetworkAccess: 'Enabled'
    managedIdentities: {
      systemAssigned: true
    }
    privateEndpoints: [
      {
        name: 'pep-${premiumV2Name}-gateway'
        service: 'Gateway'
        subnetResourceId: privateEndpointSubnetResourceId
        privateDnsZoneGroup: {
          name: 'default'
          privateDnsZoneGroupConfigs: [
            {
              name: 'apim'
              privateDnsZoneResourceId: privateDnsZone.outputs.resourceId
            }
          ]
        }
      }
    ]
    tags: tags
  }
}

output standardV2Name string = standardV2.outputs.name
output premiumV2Name string = premiumV2.outputs.name
output virtualNetworkName string = virtualNetworkName
output privateDnsZoneName string = privateDnsZoneName
