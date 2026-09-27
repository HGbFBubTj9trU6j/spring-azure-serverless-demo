targetScope = 'resourceGroup'

param location string
param containerAppsEnvironmentName string

resource environment 'Microsoft.App/managedEnvironments@2026-07-01' = {
  name: containerAppsEnvironmentName
  location: location

  properties: {
    environmentMode: 'Express'
    publicNetworkAccess: 'Enabled'

    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
        enableFips: false
      }
    ]

    peerAuthentication: {
      mtls: {
        enabled: false
      }
    }

    peerTrafficConfiguration: {
      encryption: {
        enabled: false
      }
    }
  }
}

output environmentId string = environment.id
output environmentMode string = environment.properties.environmentMode
output defaultDomain string = environment.properties.defaultDomain