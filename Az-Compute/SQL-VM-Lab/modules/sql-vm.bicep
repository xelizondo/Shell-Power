param location string
param vmName string
param offer string
param imageSku string
param imageVersion string
param sqlEdition string
param sqlLicenseType string
param subnetId string
param adminUsername string
@secure()
param adminPassword string

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${vmName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2alds_v6'
    }
    licenseType: 'Windows_Server'
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftSQLServer'
        offer: offer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        name: '${vmName}-os'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          name: '${vmName}-data'
          lun: 0
          createOption: 'Empty'
          diskSizeGB: 64
          caching: 'ReadOnly'
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
        {
          name: '${vmName}-log'
          lun: 1
          createOption: 'Empty'
          diskSizeGB: 64
          caching: 'None'
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// Registration installs/manages the SQL IaaS Agent extension; do not install it twice.
resource sqlVm 'Microsoft.SqlVirtualMachine/sqlVirtualMachines@2023-10-01' = {
  name: vm.name
  location: location
  properties: {
    virtualMachineResourceId: vm.id
    sqlManagement: 'Full'
    sqlImageOffer: offer
    sqlImageSku: sqlEdition
    sqlServerLicenseType: sqlLicenseType
    storageConfigurationSettings: {
      diskConfigurationType: 'NEW'
      storageWorkloadType: 'GENERAL'
      sqlDataSettings: {
        luns: [0]
        defaultFilePath: 'F:\\SQLData'
      }
      sqlLogSettings: {
        luns: [1]
        defaultFilePath: 'G:\\SQLLog'
      }
      sqlTempDbSettings: {
        luns: [0]
        defaultFilePath: 'F:\\SQLTempDB'
      }
      sqlSystemDbOnDataDisk: true
    }
    serverConfigurationsManagementSettings: {
      sqlConnectivityUpdateSettings: {
        connectivityType: 'LOCAL'
      }
      sqlInstanceSettings: {
        maxServerMemoryMB: 2048
      }
    }
  }
}

resource shutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vm.name}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: '1900'
    }
    timeZoneId: 'Eastern Standard Time'
    targetResourceId: vm.id
    notificationSettings: {
      status: 'Disabled'
    }
  }
}

output publicIp string = publicIp.properties.ipAddress
