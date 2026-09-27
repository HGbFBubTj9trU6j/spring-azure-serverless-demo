targetScope = 'resourceGroup'

@description('Azure Container Registry name')
param containerRegistryName string

@description('Azure region')
param location string

resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: containerRegistryName
  location: location

  sku: {
    name: 'Basic'
  }

  properties: {
    adminUserEnabled: false
  }
}

output registryId string = registry.id
output loginServer string = registry.properties.loginServer