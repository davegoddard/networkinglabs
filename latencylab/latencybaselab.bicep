@description('Admin username')
param adminUsername string

@description('Admin password')
@secure()
param adminPassword string

var vNet1Name = 'LatencyLabVNet1'
param vNet1Location string = 'westus2'
var vNet2Name = 'LatencyLabVNet2'
param vNet2Location string = 'northeurope'

//var storageAccountName = uniqueString(resourceGroup().id)

resource vnet1 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vNet1Name
  location: vNet1Location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.12.4.0/24'
      ]
    }
    subnets: [
      {
        name: 'defualt'
        properties: {
          addressPrefix: '10.12.4.0/26'
        }
      }
    ]
  }
}

resource vnet2 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vNet2Name
  location: vNet2Location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.12.5.0/24'
      ]
    }
    subnets: [
      {
        name: 'defualt'
        properties: {
          addressPrefix: '10.12.5.0/26'
        }
      }
    ]
  }
}

resource peering1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  name: 'peering-vnet1-to-vnet2'
  parent: vnet1
  properties: {
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: {
      id: vnet2.id
    }
  }
}

resource peering2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
 name: 'peering-vnet2-to-vnet1' 
 parent: vnet2
 properties: {
  allowVirtualNetworkAccess: true
  remoteVirtualNetwork: {
    id: vnet1.id
  }
 }
}

// Create a public IP address
resource publicIp 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: 'LatencyLabPublicIP'
  location: vNet1Location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

resource vnet1vm1nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vNet1Name}VM1Nic'
  location: vNet1Location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddressVersion: 'IPv4'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet1.properties.subnets[0].id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource vnet1vm2nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vNet1Name}VM2Nic'
  location: vNet1Location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddressVersion: 'IPv4'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet1.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

resource vnet2vm1nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vNet2Name}VM1Nic'
  location: vNet2Location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddressVersion: 'IPv4'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet2.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

// Create an availability set
resource vnet1AS 'Microsoft.Compute/availabilitySets@2020-06-01' = {
  name: 'VNet1AS'
  location: vNet1Location
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 5
  }
}

// Create a virtual machine
resource vnet1VM1 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: 'VNet1VM1'
  location: vNet1Location
  properties: {
    availabilitySet: {
      id: vnet1AS.id
    }
    hardwareProfile: {
      vmSize: 'Standard_B1ls'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'VNet1VM1'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vnet1vm1nic.id
        }
      ]
    }
  }
}

resource vnet1VM2 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: 'VNet1VM2'
  location: vNet1Location
  properties: {
    availabilitySet: {
      id: vnet1AS.id
    }
    hardwareProfile: {
      vmSize: 'Standard_B1ls'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'VNet1VM2'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vnet1vm2nic.id
        }
      ]
    }
  }
}

resource vnet2VM1 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: 'VNet2VM1'
  location: vNet2Location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ls'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'VNet2VM1'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vnet2vm1nic.id
        }
      ]
    }
  }
}

