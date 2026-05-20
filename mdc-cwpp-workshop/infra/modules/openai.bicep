param location string
param accountName string
param tags object

resource oai 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: accountName
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: { name: 'S0' }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
  }
}

resource deploy 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: oai
  name: 'gpt-4o-mini'
  sku: { name: 'Standard', capacity: 50 }
  properties: {
    model: { format: 'OpenAI', name: 'gpt-4o-mini', version: '2024-07-18' }
  }
}

output endpoint string = oai.properties.endpoint
