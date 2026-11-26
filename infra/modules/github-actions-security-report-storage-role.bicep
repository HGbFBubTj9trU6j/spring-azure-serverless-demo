targetScope = 'resourceGroup'

param storageAccountName string
param containerName string
param githubActionsIdentityName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' existing = {
  name: storageAccountName
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-06-01' existing = {
  parent: storageAccount
  name: 'default'
}

resource securityReportsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' existing = {
  parent: blobService
  name: containerName
}

resource githubActionsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: githubActionsIdentityName
}

var storageBlobDataContributorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
)

resource storageBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    securityReportsContainer.id,
    githubActionsIdentity.id,
    storageBlobDataContributorRoleDefinitionId
  )

  scope: securityReportsContainer

  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinitionId
    principalId: githubActionsIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = storageBlobDataContributor.id
