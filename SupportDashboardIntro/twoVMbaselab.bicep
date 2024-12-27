@description('Admin username')
param adminUsername string

@description('Admin password')
@secure()
param adminPassword string

@description('Your public IP to allow SSH traffic from:')
param allowPublicIP string

@description('Region to deploy lab to (e.g. westus2)')
param labLocation string

var vNet1Name = 'NetworkingLabVNet1'
var lbName = 'NetworkingLabLoadBalancer'
var lbProbeName = 'HttpProbe'
var lbFeConfigName = 'FEconfig'
var lbBePoolName = 'VmSnatPool'

resource labNsg 'Microsoft.Network/networkSecurityGroups@2022-01-01'  = {
  name: 'DefaultNsg'
  location: labLocation
  properties: {
    securityRules: [
      {
        id: 'AllowSsh'
        name: 'AllowSsh'
        properties: {
          access: 'Allow'
          description: 'Allow SSH traffic from trusted source'
          priority: 100
          destinationAddressPrefix: '*'
          destinationPortRange: '2224'
          protocol: 'Tcp'
          sourceAddressPrefix: allowPublicIP
          sourcePortRange: '*'
          direction: 'Inbound'
        }
      }
      {
        id: 'AllowHttp'
        name: 'AllowHttp'
        properties: {
          access: 'Allow'
          description: 'Allow HTTP'
          priority: 200
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource vnet1 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vNet1Name
  location: labLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.12.14.0/24'
      ]
    }
  }
}

resource vnet1DefaultSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = {
  parent: vnet1
  name: 'Default'
  properties: {
    addressPrefix: '10.12.14.0/27'
    networkSecurityGroup: { 
      id: labNsg.id
    }
  }
}

// Create a public IP address
resource labPublicIp 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: 'LabPublicIP'
  location: labLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}
// Create a LB to facilitate NAT rule and outbound connectivity
resource lb 'Microsoft.Network/loadBalancers@2021-08-01' = {
  name: lbName
  location: labLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: lbFeConfigName
        properties: {
          publicIPAddress: {
            id: labPublicIp.id            
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: lbBePoolName
      }
    ]
    loadBalancingRules: [
      {
        name: 'HTTP'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, lbFeConfigName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, lbBePoolName)
          }
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 15
          protocol: 'Tcp'
          enableTcpReset: true
          loadDistribution: 'Default'
          disableOutboundSnat: true
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, lbProbeName)
          }
        }
      }
    ] 
    inboundNatRules: [
      {
        name: 'VMSshNatRule'
        properties: {
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, lbBePoolName)
          }
          frontendPortRangeStart: 2201
          frontendPortRangeEnd: 2209
          backendPort: 2224
          enableFloatingIP: false
          enableTcpReset: true
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, lbFeConfigName)
          }
          idleTimeoutInMinutes: 30
          protocol: 'Tcp'
        }
      }
    ]
    probes: [
      {
        name: lbProbeName
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]    
    outboundRules: [
      {
        name: 'OutboundRule1'
        properties: {
          allocatedOutboundPorts: 10000
          protocol: 'All'
          enableTcpReset: true
          idleTimeoutInMinutes: 15
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, lbBePoolName)
          }
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, lbFeConfigName)
            }
          ]
        }
      }
    ]
  }
}


resource vnet1vm1nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vNet1Name}VM1Nic'
  location: labLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddressVersion: 'IPv4'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet1DefaultSubnet.id
          }
          loadBalancerBackendAddressPools: [ 
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, lbBePoolName)

            }
          ]
        }
      }
    ]
  }
  dependsOn: [ lb ]
}

resource vnet1vm2nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vNet1Name}VM2Nic'
  location: labLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddressVersion: 'IPv4'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet1DefaultSubnet.id
          }
          loadBalancerBackendAddressPools: [ 
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'VmSnatPool')

            }
          ]
        }
      }
    ]
  }
  dependsOn: [ lb. vnet1vm1nic ]
}

// Create an availability set
resource vnet1AS 'Microsoft.Compute/availabilitySets@2020-06-01' = {
  name: 'VNet1AS'
  location: labLocation
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
  location: labLocation
  properties: {
    availabilitySet: {
      id: vnet1AS.id
    }
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
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

resource vnet1VM1_customScript 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  parent: vnet1VM1
  name: 'customScript-vm1'
  location: labLocation
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: []
      commandToExecute: 'wget -P /usr/local/bin https://raw.githubusercontent.com/davegoddard/networkinglabs/refs/heads/main/latencylab/tcpserver4.py ; wget -P /usr/local/bin https://raw.githubusercontent.com/davegoddard/networkinglabs/refs/heads/main/latencylab/mtclient.py ; wget -P /usr/local/sbin https://raw.githubusercontent.com/davegoddard/networkinglabs/refs/heads/main/latencylab/configure-sshd.sh ; chmod 755 /usr/local/bin/*.py ; chmod 755 /usr/local/sbin/configure-sshd.sh ; /usr/local/sbin/configure-sshd.sh'
    }
  }
}

resource vnet1VM2 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: 'VNet1VM2'
  location: labLocation
  properties: {
    availabilitySet: {
      id: vnet1AS.id
    }
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
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

resource vnet1VM2_customScript 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  parent: vnet1VM1
  name: 'customScript-vm2'
  location: labLocation
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: []
      commandToExecute: 'wget -P /usr/local/bin https://raw.githubusercontent.com/davegoddard/networkinglabs/refs/heads/main/latencylab/tcpserver4.py ; wget -P /usr/local/bin https://raw.githubusercontent.com/davegoddard/networkinglabs/refs/heads/main/latencylab/mtclient.py ; wget -P /usr/local/sbin https://raw.githubusercontent.com/davegoddard/networkinglabs/refs/heads/main/latencylab/configure-sshd.sh ; chmod 755 /usr/local/bin/*.py ; chmod 755 /usr/local/sbin/configure-sshd.sh ; /usr/local/sbin/configure-sshd.sh'
    }
  }
}
