param location string
param vaultName string
param tags object

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  tags: tags
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
    networkAcls: { defaultAction: 'Allow', bypass: 'AzureServices' }
  }
}

resource demoSecret1 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'demo-db-password'
  properties: { value: 'fake-not-real-please-rotate' }
}

resource demoSecret2 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'demo-api-key'
  properties: { value: 'fake-not-real-please-rotate' }
}

resource demoSecret3 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'demo-storage-key'
  properties: { value: 'fake-not-real-please-rotate' }
}

output vaultName string = kv.name
output vaultUri string = kv.properties.vaultUri
