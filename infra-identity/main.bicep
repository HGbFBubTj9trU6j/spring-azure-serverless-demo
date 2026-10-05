targetScope = 'tenant'

extension microsoftGraphV1

@description('Microsoft Entra ID application display name')
param applicationDisplayName string

@description('Unique name used for idempotent deployments')
param applicationUniqueName string

@description('Azure Static Web Apps hostname without https://')
param staticWebAppHostname string

var staticWebAppUrl = 'https://${staticWebAppHostname}'
var redirectUri = '${staticWebAppUrl}/.auth/login/aad/callback'

resource application 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: applicationUniqueName
  displayName: applicationDisplayName

  signInAudience: 'AzureADMyOrg'

  web: {
    redirectUris: [
      redirectUri
    ]

    implicitGrantSettings: {
      enableAccessTokenIssuance: false
      enableIdTokenIssuance: true
    }
  }
}

resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: application.appId

  displayName: applicationDisplayName

  accountEnabled: true

  appRoleAssignmentRequired: false
}

output applicationObjectId string = application.id
output applicationClientId string = application.appId

output servicePrincipalObjectId string = servicePrincipal.id

output redirectUri string = redirectUri

output authenticationTenantId string = tenant().tenantId

output openIdIssuer string =
  'https://login.microsoftonline.com/${tenant().tenantId}/v2.0'