targetScope = 'resourceGroup'

param staticWebAppName string
param githubActionsIdentityName string

resource staticWebApp 'Microsoft.Web/staticSites@2025-03-01' existing = {
  name: staticWebAppName
}

resource githubActionsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: githubActionsIdentityName
}

var readerRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'acdd72a7-3385-48ef-bd42-f606fba81ae7'
)

resource reader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    staticWebApp.id,
    githubActionsIdentity.id,
    readerRoleDefinitionId
  )
  scope: staticWebApp

  properties: {
    roleDefinitionId: readerRoleDefinitionId
    principalId: githubActionsIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
