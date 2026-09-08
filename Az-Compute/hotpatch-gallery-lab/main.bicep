/*
  Hotpatch retention lab - stage 1
  Deploys:
    - VNet/NSG/Bastion-less networking (RDP restricted to allowedRdpSourcePrefix)
    - CONTROL VM  : marketplace 2025-datacenter-azure-edition, hotpatch enabled  -> expected PASS
    - BUILDER VM  : marketplace 2025-datacenter-azure-edition, to be sysprepped and captured
    - Azure Compute Gallery + image definition (Gen2 / TrustedLaunchSupported)

  Stage 2 (vm-from-gallery.bicep) deploys the TEST VM from the captured image version.
*/

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Prefix used for resource names.')
@minLength(2)
@maxLength(10)
param namePrefix string = 'hplab'

@description('Public IP / CIDR allowed to RDP into the lab VMs, e.g. 203.0.113.10/32.')
param allowedRdpSourcePrefix string

@description('Local administrator user name.')
param adminUsername string

@description('Local administrator password.')
@secure()
param adminPassword string

@description('VM size. Must support Trusted Launch / nested VBS.')
param vmSize string = 'Standard_D2s_v5'

@description('Marketplace SKU under MicrosoftWindowsServer/WindowsServer that supports hotpatching.')
param marketplaceSku string = '2025-datacenter-azure-edition'

var suffix = uniqueString(resourceGroup().id)
var galleryName = '${namePrefix}gal${suffix}'
var imageDefinitionName = 'ws2025-azureedition-custom'

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${namePrefix}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-From-Admin'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedRdpSourcePrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: '${namePrefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.30.0.0/16']
    }
    subnets: [
      {
        name: 'lab'
        properties: {
          addressPrefix: '10.30.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource gallery 'Microsoft.Compute/galleries@2024-03-03' = {
  name: galleryName
  location: location
  properties: {
    description: 'Hotpatch retention validation lab'
  }
}

// TrustedLaunchSupported + V2 is required so the captured image can boot with vTPM/Secure Boot,
// which VBS (and therefore hotpatch) depends on.
resource imageDefinition 'Microsoft.Compute/galleries/images@2024-03-03' = {
  parent: gallery
  name: imageDefinitionName
  location: location
  properties: {
    osType: 'Windows'
    osState: 'Generalized'
    hyperVGeneration: 'V2'
    architecture: 'x64'
    identifier: {
      publisher: 'lab'
      offer: 'WindowsServer'
      sku: 'ws2025-azure-edition-packer'
    }
    features: [
      {
        name: 'SecurityType'
        value: 'TrustedLaunchSupported'
      }
    ]
  }
}

var vms = [
  {
    role: 'control'
    // Hotpatch orchestration is expected to engage on this one.
    enableHotpatching: true
  }
  {
    role: 'builder'
    // Source machine for sysprep + capture. Hotpatch left on so the OS-side
    // artifacts are present before generalization.
    enableHotpatching: true
  }
]

resource pip 'Microsoft.Network/publicIPAddresses@2024-05-01' = [
  for vm in vms: {
    name: '${namePrefix}-${vm.role}-pip'
    location: location
    sku: {
      name: 'Standard'
    }
    properties: {
      publicIPAllocationMethod: 'Static'
    }
  }
]

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = [
  for (vm, i) in vms: {
    name: '${namePrefix}-${vm.role}-nic'
    location: location
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            subnet: {
              id: vnet.properties.subnets[0].id
            }
            privateIPAllocationMethod: 'Dynamic'
            publicIPAddress: {
              id: pip[i].id
            }
          }
        }
      ]
    }
  }
]

resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-11-01' = [
  for (vm, i) in vms: {
    name: '${namePrefix}-${vm.role}'
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
        imageReference: {
          publisher: 'MicrosoftWindowsServer'
          offer: 'WindowsServer'
          sku: marketplaceSku
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      }
      osProfile: {
        computerName: '${namePrefix}-${vm.role}'
        adminUsername: adminUsername
        adminPassword: adminPassword
        windowsConfiguration: {
          provisionVMAgent: true
          enableAutomaticUpdates: true
          patchSettings: {
            patchMode: 'AutomaticByPlatform'
            assessmentMode: 'AutomaticByPlatform'
            enableHotpatching: vm.enableHotpatching
          }
        }
      }
      networkProfile: {
        networkInterfaces: [
          {
            id: nic[i].id
          }
        ]
      }
    }
  }
]

output galleryName string = gallery.name
output imageDefinitionId string = imageDefinition.id
output builderVmName string = virtualMachine[1].name
output controlVmName string = virtualMachine[0].name
output publicIps array = [for (vm, i) in vms: '${vm.role}: ${pip[i].properties.ipAddress}']
