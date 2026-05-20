param location string
param clusterName string
param workspaceId string
param tags object

resource aks 'Microsoft.ContainerService/managedClusters@2024-09-01' = {
  name: clusterName
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    dnsPrefix: clusterName
    agentPoolProfiles: [
      {
        name: 'sys'
        count: 2
        vmSize: 'Standard_D2s_v5'
        mode: 'System'
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
      }
    ]
    networkProfile: { networkPlugin: 'azure' }
    securityProfile: {
      defender: {
        logAnalyticsWorkspaceResourceId: workspaceId
        securityMonitoring: { enabled: true }
      }
      workloadIdentity: { enabled: true }
    }
    oidcIssuerProfile: { enabled: true }
    addonProfiles: {
      azurepolicy: { enabled: true }
      omsagent: {
        enabled: true
        config: { logAnalyticsWorkspaceResourceID: workspaceId }
      }
    }
  }
}

output clusterName string = aks.name
output clusterId string = aks.id
