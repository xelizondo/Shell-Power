using './main.bicep'

param location = 'canadacentral'
param resourceGroupName = 'rg-apim-v2-network-lab'
param namePrefix = 'apimv2cmp'
param publisherEmail = 'xavier.elizondo@microsoft.com'
param publisherName = 'APIM v2 Network Lab'
param tags = {
  environment: 'lab'
  owner: 'xavier.elizondo@microsoft.com'
  purpose: 'apim-v2-private-network-comparison'
}