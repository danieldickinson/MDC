param location string
param adminUsername string
@secure()
param adminPassword string
param allowedSourceCidr string
param workspaceId string
@secure()
param workspaceKey string
param tags object

// ---------- Network ----------
resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'vnet-mdc'
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: ['10.20.0.0/16'] }
    subnets: [
      { name: 'vm', properties: { addressPrefix: '10.20.1.0/24' } }
      { name: 'aks', properties: { addressPrefix: '10.20.10.0/23' } }
      { name: 'attacker', properties: { addressPrefix: '10.20.2.0/24' } }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-vm'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-rdp'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedSourceCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
      {
        name: 'allow-ssh'
        properties: {
          priority: 1010
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedSourceCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

// ---------- Windows VM ----------
resource winPip 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: 'pip-winvm'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource winNic 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: 'nic-winvm'
  location: location
  tags: tags
  properties: {
    networkSecurityGroup: { id: nsg.id }
    ipConfigurations: [
      {
        name: 'ipcfg'
        properties: {
          subnet: { id: '${vnet.id}/subnets/vm' }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: winPip.id }
        }
      }
    ]
  }
}

resource winVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-win-mdc'
  location: location
  tags: tags
  properties: {
    hardwareProfile: { vmSize: 'Standard_D2s_v5' }
    osProfile: {
      computerName: 'vm-win-mdc'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Premium_LRS' } }
    }
    networkProfile: { networkInterfaces: [ { id: winNic.id } ] }
  }
}

resource winMma 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: winVm
  name: 'AzureMonitorWindowsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

resource winMde 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: winVm
  name: 'MDE.Windows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.AzureDefenderForServers'
    type: 'MDE.Windows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

// ---------- Linux VM ----------
resource linPip 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: 'pip-linuxvm'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource linNic 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: 'nic-linuxvm'
  location: location
  tags: tags
  properties: {
    networkSecurityGroup: { id: nsg.id }
    ipConfigurations: [
      {
        name: 'ipcfg'
        properties: {
          subnet: { id: '${vnet.id}/subnets/vm' }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: linPip.id }
        }
      }
    ]
  }
}

resource linVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-lin-mdc'
  location: location
  tags: tags
  properties: {
    hardwareProfile: { vmSize: 'Standard_D2s_v5' }
    osProfile: {
      computerName: 'vm-lin-mdc'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: { disablePasswordAuthentication: false }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Premium_LRS' } }
    }
    networkProfile: { networkInterfaces: [ { id: linNic.id } ] }
  }
}

resource linMde 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: linVm
  name: 'MDE.Linux'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.AzureDefenderForServers'
    type: 'MDE.Linux'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

resource linAma 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: linVm
  name: 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

output windowsVmName string = winVm.name
output linuxVmName string = linVm.name
output linuxPublicIp string = linPip.properties.ipAddress
output windowsPublicIp string = winPip.properties.ipAddress
output vnetId string = vnet.id
