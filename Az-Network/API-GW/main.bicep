targetScope = 'subscription'

@description('Azure region for the resource group and all lab resources.')
param location string = 'canadacentral'

@description('Resource group that contains the APIM networking comparison lab.')
param resourceGroupName string = 'rg-apim-v2-network-lab'

@description('Short lowercase prefix used in globally unique APIM names.')
@minLength(3)
@maxLength(12)
param namePrefix string = 'apimv2cmp'

@description('API Management publisher email address.')
param publisherEmail string

@description('API Management publisher display name.')
param publisherName string = 'APIM v2 Network Lab'

@description('Tags applied to resources that support tags.')
param tags object = {
  environment: 'lab'
  purpose: 'apim-v2-private-network-comparison'
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module lab './modules/lab.bicep' = {
  name: 'apim-v2-network-comparison'
  scope: resourceGroup
  params: {
    location: location
    namePrefix: namePrefix
    publisherEmail: publisherEmail
    publisherName: publisherName
    tags: tags
  }
}

output resourceGroupName string = resourceGroup.name
output standardV2Name string = lab.outputs.standardV2Name
output premiumV2Name string = lab.outputs.premiumV2Name
output virtualNetworkName string = lab.outputs.virtualNetworkName
output privateDnsZoneName string = lab.outputs.privateDnsZoneName
