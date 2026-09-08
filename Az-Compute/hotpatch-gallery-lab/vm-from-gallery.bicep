/*
  Hotpatch retention lab - stage 2
  Deploys the TEST VM from a captured Azure Compute Gallery image version.

  This is the deployment that answers the question. Watch for either:
    a) deployment rejected / enableHotpatching silently reverted to false, or
    b) VM deploys but Azure Update Manager reports hotpatch as not applicable.
*/

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Prefix used for resource names. Must match the stage 1 deployment.')
param namePrefix string = 'hplab'

@description('Full resource ID of the gallery image version captured from the sysprepped builder VM.')
param galleryImageVersionId string

@description('Local administrator user name.')
param adminUsername string

@description('Local administrator password.')
@secure()
param adminPassword string

@description('VM size. Must support Trusted Launch / nested VBS.')
param vmSize string = 'Standard_D2s_v5'

@description('Set false to deploy the gallery VM without requesting hotpatch, to isolate whether the request itself is rejected.')
param requestHotpatching bool = true

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: '${namePrefix}-vnet'
}

resource pip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${namePrefix}-test-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${namePrefix}-test-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/lab'
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
  }
}

resource testVm 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: '${namePrefix}-test'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    storageProfile: {
      // No publisher/offer/sku here - this is exactly why platform hotpatch
      // orchestration cannot match the VM against the supported image list.
      imageReference: {
        id: galleryImageVersionId
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: '${namePrefix}-test'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          assessmentMode: 'AutomaticByPlatform'
          enableHotpatching: requestHotpatching
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

@description('Echoes back what the platform actually persisted for enableHotpatching. Compare against requestHotpatching.')
output persistedEnableHotpatching bool = testVm.properties.osProfile.windowsConfiguration.patchSettings.enableHotpatching

output testVmName string = testVm.name
output testVmPublicIp string = pip.properties.ipAddress
