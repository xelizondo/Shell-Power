targetScope = 'resourceGroup'

@description('Name of an existing Linux Azure VM in this resource group.')
param vmName string

@description('Azure region of the existing VM.')
param vmLocation string

@description('Resource ID of the Data Collection Rule.')
param dataCollectionRuleId string

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: vmName
}

resource ama 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'AzureMonitorLinuxAgent'
  location: vmLocation
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

resource association 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: 'linux-performance-dcr'
  scope: vm
  properties: {
    description: 'Associates the Linux performance troubleshooting DCR with this VM.'
    dataCollectionRuleId: dataCollectionRuleId
  }
  dependsOn: [
    ama
  ]
}

output vmResourceId string = vm.id
