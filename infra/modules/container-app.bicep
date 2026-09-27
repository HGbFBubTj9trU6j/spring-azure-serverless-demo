targetScope = 'resourceGroup'

param location string
param containerAppName string
param containerAppsEnvironmentId string
param containerRegistryLoginServer string
param containerImage string
param identityId string

resource app 'Microsoft.App/containerApps@2026-07-01' = {
  name: containerAppName
  location: location

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }

  properties: {
    environmentId: containerAppsEnvironmentId

    configuration: {
      activeRevisionsMode: 'Single'

      registries: [
        {
          server: containerRegistryLoginServer
          identity: identityId
        }
      ]

      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
      }
    }

    template: {
      containers: [
        {
          name: 'backend'
          image: '${containerRegistryLoginServer}/${containerImage}'

            resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]

      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

output containerAppId string = app.id
output fqdn string = app.properties.configuration.ingress.fqdn