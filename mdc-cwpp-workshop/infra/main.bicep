targetScope = 'subscription'

// =====================================================================
// MDC CWPP Workshop — Lab Infrastructure
// =====================================================================
// Deploys all CWPP plans, a Log Analytics workspace + Sentinel,
// and one resource of each protected type so attendees can trigger
// every alert scenario.
// =====================================================================

@description('Two-letter env tag, e.g. "pc" for PoC.')
param envTag string = 'pc'

@description('Azure region for all resources.')
param location string = 'westeurope'

@description('Globally-unique suffix; defaults to a deterministic hash of the subscription.')
param uniqueSuffix string = substring(uniqueString(subscription().id), 0, 6)

@description('Admin username for VMs and PostgreSQL / MySQL.')
param adminUsername string = 'mdcadmin'

@secure()
@description('Admin password for VMs / DBs. Min 12 chars, upper/lower/digit/special.')
param adminPassword string

@description('CIDR allowed to RDP/SSH and reach DB endpoints. Use your office or VPN egress.')
param allowedSourceCidr string = '0.0.0.0/0'

@description('Tag applied to every resource.')
param tags object = {
  env: 'poc-mdc'
  workshop: 'cwpp-simulation'
  owner: 'replace-me@contoso.com'
  expires: '2026-06-30'
}

// ---------------------------------------------------------------------
// Resource groups
// ---------------------------------------------------------------------

resource rgEdge 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-mdc-${envTag}-edge'
  location: location
  tags: tags
}

resource rgServers 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-mdc-${envTag}-servers'
  location: location
  tags: tags
}

resource rgData 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-mdc-${envTag}-data'
  location: location
  tags: tags
}

resource rgApps 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-mdc-${envTag}-apps'
  location: location
  tags: tags
}

// ---------------------------------------------------------------------
// Monitoring + Sentinel + enable all MDC plans
// ---------------------------------------------------------------------

module monitoring 'modules/monitoring.bicep' = {
  name: 'mon-${uniqueSuffix}'
  scope: rgEdge
  params: {
    location: location
    workspaceName: 'law-mdc-${envTag}-${uniqueSuffix}'
    tags: tags
  }
}

module mdcPlans 'modules/mdc-plans.bicep' = {
  name: 'mdcPlans-${uniqueSuffix}'
  scope: subscription()
  params: {
    workspaceResourceId: monitoring.outputs.workspaceId
  }
}

// ---------------------------------------------------------------------
// Workload modules
// ---------------------------------------------------------------------

module servers 'modules/servers.bicep' = {
  name: 'servers-${uniqueSuffix}'
  scope: rgServers
  params: {
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    allowedSourceCidr: allowedSourceCidr
    workspaceId: monitoring.outputs.workspaceId
    workspaceKey: monitoring.outputs.workspaceKey
    tags: tags
  }
}

module containers 'modules/containers.bicep' = {
  name: 'aks-${uniqueSuffix}'
  scope: rgServers
  params: {
    location: location
    clusterName: 'aks-mdc-${envTag}-${uniqueSuffix}'
    workspaceId: monitoring.outputs.workspaceId
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'sto-${uniqueSuffix}'
  scope: rgData
  params: {
    location: location
    storageAccountName: 'stomdc${envTag}${uniqueSuffix}'
    tags: tags
  }
}

module sql 'modules/sql.bicep' = {
  name: 'sql-${uniqueSuffix}'
  scope: rgData
  params: {
    location: location
    serverName: 'sql-mdc-${envTag}-${uniqueSuffix}'
    adminUsername: adminUsername
    adminPassword: adminPassword
    allowedSourceCidr: allowedSourceCidr
    workspaceId: monitoring.outputs.workspaceId
    tags: tags
  }
}

module appsvc 'modules/appservice.bicep' = {
  name: 'app-${uniqueSuffix}'
  scope: rgApps
  params: {
    location: location
    appName: 'app-mdc-${envTag}-${uniqueSuffix}'
    planName: 'plan-mdc-${envTag}-${uniqueSuffix}'
    tags: tags
  }
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'kv-${uniqueSuffix}'
  scope: rgEdge
  params: {
    location: location
    vaultName: 'kv-mdc${envTag}${uniqueSuffix}'
    tags: tags
  }
}

module databases 'modules/databases.bicep' = {
  name: 'db-${uniqueSuffix}'
  scope: rgData
  params: {
    location: location
    suffix: uniqueSuffix
    envTag: envTag
    adminUsername: adminUsername
    adminPassword: adminPassword
    allowedSourceCidr: allowedSourceCidr
    tags: tags
  }
}

module apim 'modules/apim.bicep' = {
  name: 'apim-${uniqueSuffix}'
  scope: rgApps
  params: {
    location: location
    apimName: 'apim-mdc-${envTag}-${uniqueSuffix}'
    publisherEmail: tags.owner
    tags: tags
  }
}

module openai 'modules/openai.bicep' = {
  name: 'oai-${uniqueSuffix}'
  scope: rgApps
  params: {
    location: location
    accountName: 'oai-mdc-${envTag}-${uniqueSuffix}'
    tags: tags
  }
}

// ---------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------

output workspaceName string = monitoring.outputs.workspaceName
output workspaceId string = monitoring.outputs.workspaceId
output storageAccountName string = storage.outputs.storageAccountName
output sqlServerFqdn string = sql.outputs.serverFqdn
output appServiceUrl string = appsvc.outputs.appUrl
output keyVaultName string = keyvault.outputs.vaultName
output aksClusterName string = containers.outputs.clusterName
output apimGatewayUrl string = apim.outputs.gatewayUrl
output openAiEndpoint string = openai.outputs.endpoint
output postgresFqdn string = databases.outputs.postgresFqdn
output mysqlFqdn string = databases.outputs.mysqlFqdn
output cosmosEndpoint string = databases.outputs.cosmosEndpoint
