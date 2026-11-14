targetScope = 'resourceGroup'

param containerRegistryName string
param githubActionsIdentityName string

resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: containerRegistryName
}

resource githubActionsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: githubActionsIdentityName
}

var acrPushRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '8311e382-0749-4cb8-b61a-304f252e45ec'
)

resource acrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    registry.id,
    githubActionsIdentity.id,
    acrPushRoleDefinitionId
  )
  scope: registry

  properties: {
    roleDefinitionId: acrPushRoleDefinitionId
    principalId: githubActionsIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
