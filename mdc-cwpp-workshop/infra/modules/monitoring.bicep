param location string
param workspaceName string
param tags object

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    features: { enableLogAccessUsingOnlyResourcePermissions: true }
  }
}

resource sentinel 'Microsoft.SecurityInsights/onboardingStates@2023-11-01' = {
  scope: law
  name: 'default'
  properties: {}
}

// Microsoft Defender for Cloud → Microsoft Sentinel data connector
resource mdcConnector 'Microsoft.SecurityInsights/dataConnectors@2023-11-01' = {
  scope: law
  name: guid(law.id, 'mdc-connector')
  kind: 'MicrosoftDefenderAdvancedThreatProtection'
  properties: {
    dataTypes: {
      alerts: { state: 'enabled' }
    }
    tenantId: subscription().tenantId
  }
}

output workspaceName string = law.name
output workspaceId string = law.id
@secure()
output workspaceKey string = listKeys(law.id, '2023-09-01').primarySharedKey
