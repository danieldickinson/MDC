param location string
param storageAccountName string
param tags object

resource sa 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: true   // intentionally on for S-STO-04
    minimumTlsVersion: 'TLS1_2'
    networkAcls: { defaultAction: 'Allow', bypass: 'AzureServices' }
    encryption: {
      services: {
        blob: { enabled: true }
        file: { enabled: true }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource blobSvc 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: sa
  name: 'default'
  properties: {
    deleteRetentionPolicy: { enabled: true, days: 7 }
    containerDeleteRetentionPolicy: { enabled: true, days: 7 }
  }
}

resource tcon 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobSvc
  name: 'tcon'
  properties: { publicAccess: 'None' }
}

// Enable Defender for Storage (per-resource), with malware scanning and sensitive-data detection
resource defenderForStorage 'Microsoft.Security/defenderForStorageSettings@2022-12-01-preview' = {
  scope: sa
  name: 'current'
  properties: {
    isEnabled: true
    malwareScanning: {
      onUpload: { isEnabled: true, capGBPerMonth: 50 }
      scanResultsEventGridTopicResourceId: ''
    }
    sensitiveDataDiscovery: { isEnabled: true }
    overrideSubscriptionLevelSettings: true
  }
}

output storageAccountName string = sa.name
output storageAccountId string = sa.id
