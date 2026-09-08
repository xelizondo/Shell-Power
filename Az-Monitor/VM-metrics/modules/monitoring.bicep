targetScope = 'resourceGroup'

param location string
param logAnalyticsWorkspaceName string
param dataCollectionRuleName string
param retentionInDays int
param samplingFrequencyInSeconds int
param sreAgentPrincipalId string
param deploySreAgentWorkspaceRbac bool

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource dcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: dataCollectionRuleName
  location: location
  kind: 'Linux'
  properties: {
    description: 'Generic Linux VM performance and warning-or-higher Syslog collection for performance troubleshooting.'
    dataSources: {
      performanceCounters: [
        {
          name: 'linuxPerformanceCounters'
          streams: [
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: samplingFrequencyInSeconds
          counterSpecifiers: [
            '\\Processor(_Total)\\% Processor Time'
            '\\Processor(_Total)\\% User Time'
            '\\Processor(_Total)\\% Privileged Time'
            '\\Processor(_Total)\\% IO Wait Time'
            '\\Memory\\Available MBytes Memory'
            '\\Memory\\% Available Memory'
            '\\Memory\\Used MBytes Memory'
            '\\Memory\\% Used Memory'
            '\\Memory\\Pages/sec'
            '\\Memory\\Available MBytes Swap'
            '\\Memory\\Used MBytes Swap'
            '\\Memory\\% Used Swap Space'
            '\\Logical Disk(*)\\% Free Space'
            '\\Logical Disk(*)\\Free Megabytes'
            '\\Logical Disk(*)\\% Used Space'
            '\\Logical Disk(*)\\Disk Reads/sec'
            '\\Logical Disk(*)\\Disk Writes/sec'
            '\\Logical Disk(*)\\Disk Read Bytes/sec'
            '\\Logical Disk(*)\\Disk Write Bytes/sec'
            '\\Logical Disk(*)\\Avg. Disk sec/Read'
            '\\Logical Disk(*)\\Avg. Disk sec/Write'
            '\\Logical Disk(*)\\Avg. Disk Queue Length'
            '\\Network(*)\\Bytes Total/sec'
            '\\Network(*)\\Packets Received Errors'
            '\\Network(*)\\Packets Transmitted Errors'
          ]
        }
      ]
      syslog: [
        {
          name: 'linuxSyslog'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'kern'
            'daemon'
            'syslog'
            'user'
            'local0'
          ]
          logLevels: [
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'logAnalyticsDestination'
          workspaceResourceId: workspace.id
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Perf'
        ]
        destinations: [
          'logAnalyticsDestination'
        ]
      }
      {
        streams: [
          'Microsoft-Syslog'
        ]
        destinations: [
          'logAnalyticsDestination'
        ]
      }
    ]
  }
}

var logAnalyticsReaderRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '73c42c96-874c-492b-b04d-ab87d138a893')

resource sreLawReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deploySreAgentWorkspaceRbac) {
  name: guid(workspace.id, sreAgentPrincipalId, logAnalyticsReaderRoleDefinitionId)
  scope: workspace
  properties: {
    principalId: sreAgentPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: logAnalyticsReaderRoleDefinitionId
  }
}

output logAnalyticsWorkspaceId string = workspace.id
output dataCollectionRuleId string = dcr.id
