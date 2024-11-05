@description('Specifies the name of the OpenAI instance.')
param openAIName string

@description('Specifies the location for resource.')
param location string

resource openAI 'Microsoft.CognitiveServices/accounts@2022-12-01' = {
  name: openAIName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    customSubDomainName: openAIName
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}
