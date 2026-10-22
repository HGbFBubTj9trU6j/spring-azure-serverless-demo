@description('Azure region where the SQL resources are deployed.')
param location string

@description('Globally unique name of the Azure SQL logical server.')
param sqlServerName string

@description('Name of the Azure SQL database.')
param databaseName string

@description('Display name of the Microsoft Entra administrator.')
param entraAdministratorLogin string

@description('Object ID of the Microsoft Entra administrator.')
param entraAdministratorObjectId string

@description('Microsoft Entra tenant ID.')
param entraTenantId string = tenant().tenantId

@description('Type of the Microsoft Entra administrator principal.')
@allowed([
  'User'
  'Group'
  'Application'
])
param entraAdministratorPrincipalType string = 'User'

@description('Whether public network access is enabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Whether Azure services are allowed to access the SQL logical server.')
param allowAzureServices bool = true

@description('Delay in minutes before the serverless database automatically pauses.')
@minValue(60)
param autoPauseDelay int = 60

@description('Resource tags.')
param tags object = {}

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags

  properties: {
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: publicNetworkAccess
    restrictOutboundNetworkAccess: 'Disabled'

    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      principalType: entraAdministratorPrincipalType
      login: entraAdministratorLogin
      sid: entraAdministratorObjectId
      tenantId: entraTenantId
    }
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  name: databaseName
  parent: sqlServer
  location: location
  tags: tags

  sku: {
    name: 'GP_S_Gen5_2'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 2
  }

  properties: {
    createMode: 'Default'
    collation: 'Japanese_CI_AS'

    useFreeLimit: true
    freeLimitExhaustionBehavior: 'AutoPause'

    autoPauseDelay: autoPauseDelay

    // Azure SQL supports 0.5 vCores, but the current Bicep type
    // definition incorrectly expects an integer.
    #disable-next-line BCP036
    minCapacity: '0.5'

    maxSizeBytes: 34359738368
    requestedBackupStorageRedundancy: 'Local'

    zoneRedundant: false
    readScale: 'Disabled'
  }
}

resource allowAzureServicesFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = if (allowAzureServices && publicNetworkAccess == 'Enabled') {
  name: 'AllowAzureServices'
  parent: sqlServer

  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output sqlServerName string = sqlServer.name

output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

output databaseName string = sqlDatabase.name

output databaseResourceId string = sqlDatabase.id