targetScope = 'managementGroup'  

param subscriptionId1 string
param subscriptionId2 string
param subscriptionId3 string
param resourceGroupName string = 'RG-Storage'
param dateTime string = utcNow() 

module rg1 './modules/resource-group.bicep' = {
  name: 'resourceGroupDeployment-${dateTime}'
  params: {
    rgName: reference(resourceId(subscriptionId3, 'Microsoft.Resources/resourceGroups', resourceGroupName), '2019-10-01').name
    rgLocation: 'westus2'
  }
  scope: subscription(subscriptionId1)
}

module rg2 './modules/resource-group.bicep' = {
  name: 'resourceGroupDeployment-${dateTime}'
  dependsOn: [
    rg1
  ]
  params: {
    rgName: rg1.outputs.newRgId
    rgLocation: 'westus2'
  }
  scope: subscription(subscriptionId2)
}
