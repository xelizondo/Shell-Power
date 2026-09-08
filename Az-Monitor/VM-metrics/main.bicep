targetScope = 'subscription'

@description('Azure region for the monitoring resource group, workspace, and DCR.')
param location string

@description('Resource group that will contain the monitoring resources.')
param monitoringResourceGroupName string = 'rg-monitoring'

@description('Log Analytics workspace name.')
param logAnalyticsWorkspaceName string = 'law-linux-performance'

@description('Data Collection Rule name.')
param dataCollectionRuleName string = 'dcr-linux-performance'

@description('Retention for data stored in Log Analytics.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Sampling interval for Linux performance counters. Use 60 by default; 10-30 seconds increases ingestion.')
@allowed([10, 15, 30, 60])
param samplingFrequencyInSeconds int = 60

@description('Existing Linux Azure VMs to onboard. Each object requires subscriptionId, resourceGroupName, name, and location.')
param linuxVms array

@description('Optional principal ID of the Azure SRE Agent managed identity. Leave empty to skip RBAC.')
param sreAgentPrincipalId string = ''

@description('Deploy read-only RBAC for the SRE Agent identity at subscription and workspace scope.')
param deploySreAgentRbac bool = !empty(sreAgentPrincipalId)

resource monitoringRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: monitoringResourceGroupName
  location: location
}

module monitoring './modules/monitoring.bicep' = {
  name: 'deploy-monitoring-foundation'
  scope: monitoringRg
  params: {
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    dataCollectionRuleName: dataCollectionRuleName
    retentionInDays: retentionInDays
    samplingFrequencyInSeconds: samplingFrequencyInSeconds
    sreAgentPrincipalId: sreAgentPrincipalId
    deploySreAgentWorkspaceRbac: deploySreAgentRbac
  }
}

module vmOnboarding './modules/vm-onboarding.bicep' = [for (vm, i) in linuxVms: {
  name: 'onboard-${i}-${uniqueString(vm.subscriptionId, vm.resourceGroupName, vm.name)}'
  scope: resourceGroup(vm.subscriptionId, vm.resourceGroupName)
  params: {
    vmName: vm.name
    vmLocation: vm.location
    dataCollectionRuleId: monitoring.outputs.dataCollectionRuleId
  }
}]

var readerRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
var monitoringReaderRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '43d0d8ad-25c7-4714-9337-8ba259a9fe05')

resource sreReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deploySreAgentRbac) {
  name: guid(subscription().id, sreAgentPrincipalId, readerRoleDefinitionId)
  properties: {
    principalId: sreAgentPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: readerRoleDefinitionId
  }
}

resource sreMonitoringReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deploySreAgentRbac) {
  name: guid(subscription().id, sreAgentPrincipalId, monitoringReaderRoleDefinitionId)
  properties: {
    principalId: sreAgentPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: monitoringReaderRoleDefinitionId
  }
}

output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId
output dataCollectionRuleId string = monitoring.outputs.dataCollectionRuleId
output onboardedVmCount int = length(linuxVms)
