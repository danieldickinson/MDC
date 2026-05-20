param location string
param apimName string
param publisherEmail string
param tags object

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: apimName
  location: location
  tags: tags
  sku: { name: 'Developer', capacity: 1 }
  identity: { type: 'SystemAssigned' }
  properties: {
    publisherEmail: publisherEmail
    publisherName: 'MDC CWPP Workshop'
  }
}

// Sample backend API (Petstore Swagger v2)
resource api 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'petstore'
  properties: {
    displayName: 'Swagger Petstore'
    path: 'petstore'
    protocols: ['https']
    serviceUrl: 'https://petstore.swagger.io/v2'
    subscriptionRequired: false
    format: 'openapi-link'
    value: 'https://petstore.swagger.io/v2/swagger.json'
  }
}

output gatewayUrl string = apim.properties.gatewayUrl
