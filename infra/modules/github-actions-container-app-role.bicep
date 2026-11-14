targetScope = 'resourceGroup'

param containerAppName string
param githubActionsIdentityName string

resource containerApp 'Microsoft.App/containerApps@2026-07-01' existing = {
  name: containerAppName
}

resource githubActionsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: githubActionsIdentityName
}

var containerAppsContributorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '358470bc-b998-42bd-ab17-a7e34c199c0f'
)

resource containerAppsContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    containerApp.id,
    githubActionsIdentity.id,
    containerAppsContributorRoleDefinitionId
  )
  scope: containerApp

  properties: {
    roleDefinitionId: containerAppsContributorRoleDefinitionId
    principalId: githubActionsIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

