targetScope = 'subscription'
// https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration
// In the link above:
// groupids     = subresource
// resoureType  = Private Link Resource Type
// privateDNSZoneName = Private DNS zone name
var endpoints = [
  {
    groupIds : [
      'sites'
    ]
    resourceType : 'Microsoft.Web/sites'
    privateDNSZoneName : 'privatelink.azurewebsites.net'
  }
  {
    groupIds : [
      'blob'
      'blob_secondary'
    ]
    resourceType : 'Microsoft.Storage/storageAccounts'
    privateDNSZoneName : 'privatelink.blob.core.windows.net'
  }
  {
    groupIds : [
      'table'
      'table_secondary'
    ]
    resourceType : 'Microsoft.Storage/storageAccounts'
    privateDNSZoneName : 'privatelink.table.core.windows.net'
  }
  {
    groupIds : [
      'queue'
      'queue_secondary'
    ]
    resourceType : 'Microsoft.Storage/storageAccounts'
    privateDNSZoneName : 'privatelink.queue.core.windows.net'
  }
  {
    groupIds : [
      'file'
      'file_secondary'
    ]
    resourceType : 'Microsoft.Storage/storageAccounts'
    privateDNSZoneName : 'privatelink.file.core.windows.net'
  }
  {
    groupIds : [
      'web'
      'web_secondary'
    ]
    resourceType : 'Microsoft.Storage/storageAccounts'
    privateDNSZoneName : 'privatelink.web.core.windows.net'
  }
  {
    groupIds : [
      'vault'      
    ]
    resourceType : 'Microsoft.KeyVault/vaults'
    privateDNSZoneName : 'privatelink.vaultcore.azure.net'
  }
]

param privateDnsZoneId string

resource createRequiredDNSZone 'Microsoft.Authorization/policyDefinitions@2020-09-01' = {
  name: 'createRequiredDNSZone'
  properties: {
    mode: 'Indexed'
    policyRule: {
      if: {
        allOf: [
          { 
            field: 'type'
            equals: 'Microsoft.Network/privateEndpoints'
          }
          {
            count: {
              field: 'Microsoft.Network/privateEndpoints/privateLinkServiceConnections[*].groupIds[*]'
              where: {
                anyOf: [for endpoint in endpoints: {                  
                  field: 'Microsoft.Network/privateEndpoints/privateLinkServiceConnections[*].groupIds[*]'
                  equals: endpoint.groupId
                }]
              }
            }
          }
        ]
      }
    }
  }
}
