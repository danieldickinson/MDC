param location string
param serverName string
param adminUsername string
@secure()
param adminPassword string
param allowedSourceCidr string
param workspaceId string
param tags object

resource srv 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: serverName
  location: location
  tags: tags
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    publicNetworkAccess: 'Enabled'
    minimalTlsVersion: '1.2'
  }
}

resource fw 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: srv
  name: 'allowedClient'
  properties: {
    startIpAddress: split(allowedSourceCidr, '/')[0]
    endIpAddress: split(allowedSourceCidr, '/')[0]
  }
}

resource fwAzure 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: srv
  name: 'allowAzure'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource db 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: srv
  name: 'dbpoc'
  location: location
  tags: tags
  sku: { name: 'Basic' }
  properties: { collation: 'SQL_Latin1_General_CP1_CI_AS' }
}

resource sqlDefender 'Microsoft.Sql/servers/securityAlertPolicies@2023-08-01-preview' = {
  parent: srv
  name: 'Default'
  properties: {
    state: 'Enabled'
    emailAccountAdmins: true
    retentionDays: 30
  }
}

resource sqlAudit 'Microsoft.Sql/servers/auditingSettings@2023-08-01-preview' = {
  parent: srv
  name: 'Default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
  }
}

resource sqlDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: db
  name: 'toLaw'
  properties: {
    workspaceId: workspaceId
    logs: [
      { category: 'SQLSecurityAuditEvents', enabled: true }
      { category: 'SQLInsights', enabled: true }
    ]
    metrics: [ { category: 'AllMetrics', enabled: true } ]
  }
}

output serverFqdn string = srv.properties.fullyQualifiedDomainName
