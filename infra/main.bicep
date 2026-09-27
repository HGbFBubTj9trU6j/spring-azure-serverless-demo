targetScope = 'subscription'

@description('Azure region')
param location string = 'japaneast'

@description('Resource Group name')
param resourceGroupName string

@description('Azure Container Registry name')
param containerRegistryName string

@description('Container Apps Environment name')
param containerAppsEnvironmentName string

@description('Managed Identity name')
param identityName string

@description('Container App name')
param containerAppName string

@description('Container image')
param containerImage string

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
}

module containerRegistry 'modules/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    location: location
    containerRegistryName: containerRegistryName
  }
}

module containerAppsEnvironment 'modules/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  scope: rg
  params: {
    location: location
    containerAppsEnvironmentName: containerAppsEnvironmentName
  }
}

module containerAppIdentity 'modules/container-app-identity.bicep' = {
  name: 'container-app-identity'
  scope: rg
  params: {
    location: location
    identityName: identityName
    containerRegistryName: containerRegistryName
  }
  dependsOn: [
    containerRegistry
  ]
}

module containerApp 'modules/container-app.bicep' = {
  name: 'container-app'
  scope: rg
  params: {
    location: location
    containerAppName: containerAppName
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.environmentId
    containerRegistryLoginServer: containerRegistry.outputs.loginServer
    containerImage: containerImage
    identityId: containerAppIdentity.outputs.identityId
  }
}

output resourceGroupId string = rg.id

output containerRegistryId string = containerRegistry.outputs.registryId

output containerRegistryLoginServer string = containerRegistry.outputs.loginServer

output environmentId string = containerAppsEnvironment.outputs.environmentId

output environmentMode string = containerAppsEnvironment.outputs.environmentMode

output defaultDomain string = containerAppsEnvironment.outputs.defaultDomain

output containerAppId string = containerApp.outputs.containerAppId
output containerAppFqdn string = containerApp.outputs.fqdn
