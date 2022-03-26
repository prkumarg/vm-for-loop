param hostname string = 'runner-postit-git-eus2-'
param sshpubkey string = 'changeme'
param vnetname string = 'vnet-postit-git-eus2-'
param vmsubnetname string = 'gitsnet'
param count int = 2

@description('Use ephemeral or disk')
@allowed([
  'Ephemeral'
  'Managed'
])
param osDiskType string = 'Ephemeral'

@description('Size of OS disk')
param osDiskSizeGB int = 80
param vmsize string = 'Standard_D2s_v3'
param vmusername string = 'azureuser'
param vmCustomData string = base64('#!/bin/bash\nusermod -aG docker ${vmusername}\naz aks install-cli\n')
param deploybastion bool = true
param publicIpAddressName string = 'pip-postit-git-eus2-'
param location string = resourceGroup().location

var name = resourceGroup().name
var rgvalues = split(name, '-')
var rgindex = int(last(rgvalues))

var dsvmimage = {
  publisher: 'microsoft-dsvm'
  offer: 'ubuntu-1804'
  sku: '1804-gen2'
  version: 'latest'
}
var ubuvmimage = {
  publisher: 'Canonical'
  offer: 'UbuntuServer'
  sku: '18.04-LTS'
  version: 'latest'
}
var Owner = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
var Contributor = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
var Reader = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
var vmsubnetid = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetname, vmsubnetname)

resource vnetname_resource 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: '${vnetname}00${rgindex}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: vmsubnetname
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.10.0/24'
        }
      }
    ]
  }
}

resource hostname_nic 'Microsoft.Network/networkInterfaces@2019-11-01' = [for i in range(0 + rgindex, rgindex + count): {
  name: '${hostname}00${i}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', '${vnetname}00${rgindex}', vmsubnetname)
          }
        }
      }
    ]
  }
  dependsOn: [
    vnetname_resource
  ]
}]

resource hostname_resource 'Microsoft.Compute/virtualMachines@2019-07-01' =  [for i in range(0 + rgindex, rgindex + count): {
  name: '${hostname}00${i}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmsize
    }
    osProfile: {
      computerName: '${hostname}00${i}'
      adminUsername: vmusername
      customData: vmCustomData
      linuxConfiguration: {
        ssh: {
          publicKeys: [
            {
              keyData: sshpubkey
              path: '/home/${vmusername}/.ssh/authorized_keys'
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: dsvmimage
      osDisk: {
        name: '${hostname}00${i}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: hostname_nic[i].id
        }
      ]
    }
  }
}]

resource DemoBastion 'Microsoft.Network/bastionHosts@2020-04-01' = if (deploybastion) {
  name: 'RunnerBastion'
  location: location
  properties: {
    ipConfigurations: [
      {
        id: 'string'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', '${vnetname}00${rgindex}', 'AzureBastionSubnet')
          }
          publicIPAddress: {
            id: publicIpAddressName_resource.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
        name: 'ipconfig1'
      }
    ]
  }
}

resource publicIpAddressName_resource 'Microsoft.Network/publicIpAddresses@2019-02-01' = if (deploybastion) {
  name: '${publicIpAddressName}00${rgindex}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}
