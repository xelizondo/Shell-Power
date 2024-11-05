@description('Name of the Private Endpoint to be created.')
param privateEndpointName string

@description('Location for the resource.')
param location string

@description('The resource ID of the resource to be provisioned with a Private Endpoint.')
param resourceID string

@description('The resource ID of the subnet to be used for the Private Endpoint.')
param subnetId string

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: resourceID
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}
