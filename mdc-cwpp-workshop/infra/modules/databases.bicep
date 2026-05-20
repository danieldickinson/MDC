param location string
param suffix string
param envTag string
param adminUsername string
@secure()
param adminPassword string
param allowedSourceCidr string
param tags object

// ---------- PostgreSQL flexible ----------
resource pg 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: 'pg-mdc-${envTag}-${suffix}'
  location: location
  tags: tags
  sku: { name: 'Standard_B1ms', tier: 'Burstable' }
  properties: {
    version: '16'
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    storage: { storageSizeGB: 32 }
    network: { publicNetworkAccess: 'Enabled' }
    highAvailability: { mode: 'Disabled' }
    backup: { backupRetentionDays: 7, geoRedundantBackup: 'Disabled' }
  }
}

resource pgFw 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = {
  parent: pg
  name: 'allowedClient'
  properties: {
    startIpAddress: split(allowedSourceCidr, '/')[0]
    endIpAddress: split(allowedSourceCidr, '/')[0]
  }
}

// ---------- MySQL flexible ----------
resource mysql 'Microsoft.DBforMySQL/flexibleServers@2023-12-30' = {
  name: 'mysql-mdc-${envTag}-${suffix}'
  location: location
  tags: tags
  sku: { name: 'Standard_B1ms', tier: 'Burstable' }
  properties: {
    version: '8.0.21'
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    storage: { storageSizeGB: 32 }
    network: { publicNetworkAccess: 'Enabled' }
    highAvailability: { mode: 'Disabled' }
    backup: { backupRetentionDays: 7, geoRedundantBackup: 'Disabled' }
  }
}

resource mysqlFw 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2023-12-30' = {
  parent: mysql
  name: 'allowedClient'
  properties: {
    startIpAddress: split(allowedSourceCidr, '/')[0]
    endIpAddress: split(allowedSourceCidr, '/')[0]
  }
}

// ---------- Cosmos DB (Core SQL API) ----------
resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: 'cosmos-mdc-${envTag}-${suffix}'
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [ { locationName: location, failoverPriority: 0 } ]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    publicNetworkAccess: 'Enabled'
    networkAclBypass: 'AzureServices'
    capabilities: [ { name: 'EnableServerless' } ]
  }
}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  parent: cosmos
  name: 'db1'
  properties: { resource: { id: 'db1' } }
}

resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  parent: cosmosDb
  name: 'c1'
  properties: {
    resource: {
      id: 'c1'
      partitionKey: { paths: ['/pk'], kind: 'Hash' }
    }
  }
}

output postgresFqdn string = pg.properties.fullyQualifiedDomainName
output mysqlFqdn string = mysql.properties.fullyQualifiedDomainName
output cosmosEndpoint string = cosmos.properties.documentEndpoint
