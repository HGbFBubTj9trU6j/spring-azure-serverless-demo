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

// GitHub Actions
@description('GitHub Actions managed identity name')
param githubActionsIdentityName string

@description('GitHub Actions OIDC subject')
param githubActionsSubject string

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

// DevSecOps
@description('Storage account name for security reports')
param securityReportStorageAccountName string

@description('Blob container name for security reports')
param securityReportContainerName string

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

// GitHub Actions
module githubActionsIdentity 'modules/github-actions-identity.bicep' = {
  name: 'github-actions-identity'
  scope: rg
  params: {
    location: location
    identityName: githubActionsIdentityName
    githubSubject: githubActionsSubject
  }
}
module githubActionsAcrRole 'modules/github-actions-acr-role.bicep' = {
  name: 'github-actions-acr-role'
  scope: rg
  params: {
    containerRegistryName: containerRegistryName
    githubActionsIdentityName: githubActionsIdentityName
  }
  dependsOn: [
    containerRegistry
    githubActionsIdentity
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

// GitHub Actions role assignment for Static Web App
module githubActionsStaticWebAppRole 'modules/github-actions-static-web-app-role.bicep' = {
  name: 'github-actions-static-web-app-role'
  scope: rg
  params: {
    staticWebAppName: staticWebAppName
    githubActionsIdentityName: githubActionsIdentityName
  }
  dependsOn: [
    githubActionsIdentity
    staticWebApp
  ]
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

// DevSecOps
module securityReportStorage 'modules/security-report-storage.bicep' = {
  name: 'security-report-storage'
  scope: rg
  params: {
    location: location
    storageAccountName: securityReportStorageAccountName
    containerName: securityReportContainerName
  }
}

// GitHub Actions role assignment for security reports
module githubActionsSecurityReportStorageRole 'modules/github-actions-security-report-storage-role.bicep' = {
  name: 'github-actions-security-report-storage-role'
  scope: rg
  params: {
    storageAccountName: securityReportStorageAccountName
    containerName: securityReportContainerName
    githubActionsIdentityName: githubActionsIdentityName
  }
  dependsOn: [
    securityReportStorage
    githubActionsIdentity
  ]
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
