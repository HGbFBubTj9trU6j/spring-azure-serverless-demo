@description('Azure region for Static Web Apps')
param location string

@description('Static Web App name')
param staticWebAppName string

@allowed([
  'Free'
  'Standard'
])
param staticWebAppSku string = 'Free'

resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' = {
  name: staticWebAppName
  location: location

  sku: {
    name: staticWebAppSku
    tier: staticWebAppSku
  }

  properties: {}
}

output staticWebAppName string = staticWebApp.name
output staticWebAppId string = staticWebApp.id