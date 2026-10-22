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

@description('Static Web App name')
param staticWebAppName string

@description('Static Web App region')
param staticWebAppLocation string

@allowed([
  'Free'
  'Standard'
])
param staticWebAppSku string = 'Free'

// Azure SQL
@description('Globally unique name of the Azure SQL logical server.')
param sqlServerName string

@description('Name of the Azure SQL database.')
param sqlDatabaseName string

@description('Display name or UPN of the Microsoft Entra administrator.')
param sqlEntraAdministratorLogin string

@description('Object ID of the Microsoft Entra administrator.')
param sqlEntraAdministratorObjectId string

@description('Type of the Microsoft Entra administrator principal.')
@allowed([
  'User'
  'Group'
  'Application'
])
param sqlEntraAdministratorPrincipalType string = 'User'

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

module staticWebApp './modules/static-web-app.bicep' = {
  name: 'staticWebApp'
  scope: resourceGroup(resourceGroupName)

  params: {
    location: staticWebAppLocation
    staticWebAppName: staticWebAppName
    staticWebAppSku: staticWebAppSku
  }
}

// Azure SQL
module sqlDatabase './modules/sql-database.bicep' = {
  name: 'sql-database'
  scope: rg
  params: {
    location: location
    sqlServerName: sqlServerName
    databaseName: sqlDatabaseName

    entraAdministratorLogin: sqlEntraAdministratorLogin
    entraAdministratorObjectId: sqlEntraAdministratorObjectId
    entraAdministratorPrincipalType: sqlEntraAdministratorPrincipalType

    entraTenantId: tenant().tenantId

    publicNetworkAccess: 'Enabled'
    allowAzureServices: true

    autoPauseDelay: 60
  }
}

output resourceGroupId string = rg.id

output containerRegistryId string = containerRegistry.outputs.registryId

output containerRegistryLoginServer string = containerRegistry.outputs.loginServer

output environmentId string = containerAppsEnvironment.outputs.environmentId

output environmentMode string = containerAppsEnvironment.outputs.environmentMode

output defaultDomain string = containerAppsEnvironment.outputs.defaultDomain

// Azure SQL
output sqlServerName string = sqlDatabase.outputs.sqlServerName

output sqlServerFqdn string = sqlDatabase.outputs.sqlServerFqdn

output sqlDatabaseName string = sqlDatabase.outputs.databaseName

output sqlDatabaseResourceId string = sqlDatabase.outputs.databaseResourceId