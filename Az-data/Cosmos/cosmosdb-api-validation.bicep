@description('Azure region for the validation resources.')
param location string = resourceGroup().location

@description('Short lowercase prefix used in globally unique resource names.')
@minLength(2)
@maxLength(16)
param namePrefix string = 'cmdbcosmos'

@description('Deploy the retired Azure Cosmos DB for PostgreSQL resource type. This creates billable compute and is disabled by default.')
param deployPostgreSql bool = false

@secure()
@description('Required only when deployPostgreSql is true. Use a strong password of 8-128 characters.')
param postgresAdministratorPassword string = ''

var uniqueSuffix = uniqueString(subscription().subscriptionId, resourceGroup().id)
var accountDefinitions = [
  {
    suffix: 'nosql'
    apiType: 'NoSQL API'
    kind: 'GlobalDocumentDB'
    capability: ''
  }
  {
    suffix: 'mongo'
    apiType: 'MongoDB API (RU-based)'
    kind: 'MongoDB'
    capability: 'EnableMongo'
  }
  {
    suffix: 'cassandra'
    apiType: 'Cassandra API'
    kind: 'GlobalDocumentDB'
    capability: 'EnableCassandra'
  }
  {
    suffix: 'gremlin'
    apiType: 'Gremlin API'
    kind: 'GlobalDocumentDB'
    capability: 'EnableGremlin'
  }
  {
    suffix: 'table'
    apiType: 'Table API'
    kind: 'GlobalDocumentDB'
    capability: 'EnableTable'
  }
]

resource cosmosAccounts 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = [for account in accountDefinitions: {
  name: '${namePrefix}-${account.suffix}-${uniqueSuffix}'
  location: location
  kind: account.kind
  tags: {
    purpose: 'cmdb-arg-validation'
    expectedApiType: account.apiType
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    capabilities: empty(account.capability) ? [] : [
      {
        name: account.capability
      }
    ]
    publicNetworkAccess: 'Enabled'
  }
}]

resource postgresCluster 'Microsoft.DBforPostgreSQL/serverGroupsv2@2022-11-08' = if (deployPostgreSql) {
  name: '${namePrefix}-pg-${uniqueSuffix}'
  location: location
  tags: {
    purpose: 'cmdb-arg-validation'
    expectedApiType: 'PostgreSQL (retired Cosmos DB service)'
  }
  properties: {
    administratorLoginPassword: postgresAdministratorPassword
    coordinatorServerEdition: 'GeneralPurpose'
    coordinatorVCores: 4
    coordinatorStorageQuotaInMb: 262144
    coordinatorEnablePublicIpAccess: false
    enableShardsOnCoordinator: true
    nodeCount: 0
    nodeServerEdition: 'MemoryOptimized'
    nodeVCores: 4
    nodeStorageQuotaInMb: 524288
    nodeEnablePublicIpAccess: false
    enableHa: false
    postgresqlVersion: '15'
    citusVersion: '12.0'
  }
}

output cosmosAccounts array = [for (account, index) in accountDefinitions: {
  name: cosmosAccounts[index].name
  expectedApiType: account.apiType
  resourceId: cosmosAccounts[index].id
}]
output postgresResourceId string = deployPostgreSql ? postgresCluster.id : 'Not deployed'