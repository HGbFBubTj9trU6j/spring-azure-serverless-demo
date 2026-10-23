targetScope = 'resourceGroup'

param location string
param containerAppName string
param containerAppsEnvironmentId string
param containerRegistryLoginServer string
param containerImage string
param identityId string
param identityClientId string
param sqlServerName string
param sqlDatabaseName string

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
        transport: 'http'
      }
    }

    template: {
      containers: [
        {
          name: 'backend'
          image: '${containerRegistryLoginServer}/${containerImage}'

          env: [
            {
                name: 'SPRING_PROFILES_ACTIVE'
                value: 'database'
            }
            {
                name: 'SPRING_DATASOURCE_URL'
                value: 'jdbc:sqlserver://${sqlServerName}.database.windows.net:1433;database=${sqlDatabaseName};encrypt=true;trustServerCertificate=false;authentication=ActiveDirectoryManagedIdentity;msiClientId=${identityClientId}'
            }
          ]

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