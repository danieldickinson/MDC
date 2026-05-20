param location string
param appName string
param planName string
param tags object

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  sku: { name: 'P1v3', tier: 'PremiumV3' }
  kind: 'linux'
  properties: { reserved: true }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  tags: tags
  kind: 'app,linux'
  properties: {
    serverFarmId: plan.id
    httpsOnly: false  // intentionally — to allow testing
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      ftpsState: 'AllAllowed'
      scmType: 'None'
    }
  }
}

output appUrl string = 'https://${app.properties.defaultHostName}'
