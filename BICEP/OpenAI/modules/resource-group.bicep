targetScope = 'subscription'

@description('Name of the resourceGroup to create')
param rgName string

@description('Location for the resourceGroup')
param rgLocation string

resource newRg 'Microsoft.Resources/resourceGroups@2019-10-01' = {
  name: rgName
  location: rgLocation
  tags: {
    Note: 'subscription level deployment'
  }
  properties: {}
}

output newRgId string = newRg.id
