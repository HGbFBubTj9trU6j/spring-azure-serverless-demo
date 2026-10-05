# Microsoft Entra ID Authentication Setup

This document describes how to reproduce the Microsoft Entra ID resources and Azure Static Web Apps settings used by this project.

## Deployment Boundaries

The solution spans two administrative boundaries.

```text
Authentication Tenant
├── App Registration
└── Service Principal

Azure Subscription Tenant
└── Azure Static Web Apps
    └── Application Settings
```

The Microsoft Entra ID resources and Azure resources may belong to different tenants.

For this reason, identity provisioning and Azure resource configuration are performed as separate deployment steps.

## Provisioned Identity Resources

The identity Bicep template creates:

- Microsoft Entra ID App Registration
- Web redirect URI for Azure Static Web Apps
- ID token issuance configuration
- Single-tenant sign-in configuration
- Service Principal

The following redirect URI is configured:

```text
https://<STATIC_WEB_APP_HOSTNAME>/.auth/login/aad/callback
```

## Prerequisites

The deploying identity must be permitted to create Microsoft Entra ID applications and service principals in the authentication tenant.

The following tools are required:

- Azure CLI
- Bicep CLI
- PowerShell

## Deploy the Identity Resources

Run:

```powershell
.\scripts\deploy-identity.ps1 `
  -AuthenticationTenantId "<AUTHENTICATION_TENANT_ID>" `
  -StaticWebAppHostname "<STATIC_WEB_APP_HOSTNAME>"
```

The script signs in to the authentication tenant and performs a tenant-scope Bicep deployment.

The deployment outputs:

- Application Client ID
- Application Object ID
- Service Principal Object ID
- Redirect URI
- OpenID Issuer

No Client Secret is returned by the Bicep deployment.

## Configure the Client Secret and SWA Application Settings

Run:

```powershell
.\scripts\configure-swa-auth.ps1 `
  -AuthenticationTenantId "<AUTHENTICATION_TENANT_ID>" `
  -AzureSubscriptionTenantId "<AZURE_SUBSCRIPTION_TENANT_ID>" `
  -AzureSubscriptionId "<AZURE_SUBSCRIPTION_ID>" `
  -ApplicationDisplayName "spring-azure-serverless-demo-auth" `
  -StaticWebAppName "<STATIC_WEB_APP_NAME>" `
  -ResourceGroupName "<RESOURCE_GROUP>"
```

The script:

1. Signs in to the authentication tenant.
2. Locates the App Registration.
3. Creates a Client Secret.
4. Signs in to the Azure subscription tenant.
5. Configures the Azure Static Web Apps application settings.
6. Does not write the Client Secret to a repository file.

The following SWA application settings are configured:

```text
AZURE_CLIENT_ID
AZURE_CLIENT_SECRET
```

## Build the Frontend Authentication Configuration

The committed template is:

```text
scripts/staticwebapp.config.template.json
```

The frontend build generates:

```text
frontend/dist/staticwebapp.config.json
```

The generated file contains the tenant-specific OpenID issuer.

Do not manually edit or commit files under `frontend/dist`.

## Deploy the Frontend

After identity and SWA settings have been configured, rebuild and deploy the frontend.

```powershell
.\scripts\build-frontend.ps1
.\scripts\deploy-frontend.ps1
```

## Validate Authentication

Open the Azure Static Web Apps production URL in a private browser window.

Verify the following scenarios:

| Scenario | Expected Result |
| --- | --- |
| Registered external tenant user | Access granted |
| Registered authentication tenant user | Access granted |
| Unregistered user | Access denied |

After a successful sign-in, open:

```text
https://<STATIC_WEB_APP_HOSTNAME>/.auth/me
```

Verify:

- `identityProvider` is `aad`
- the token issuer belongs to the authentication tenant
- the token tenant ID belongs to the authentication tenant
- the user has the `authenticated` role

## Logout

Open:

```text
https://<STATIC_WEB_APP_HOSTNAME>/.auth/logout
```

Verify that the SWA authentication session is cleared.

## Secret Rotation

Running `43-configure-swa-auth.ps1` creates a new Client Secret.

After confirming that authentication works with the new secret, remove expired or superseded credentials from the App Registration.

Never store Client Secrets in:

- Git
- Bicep parameter files
- PowerShell source files
- generated frontend files
- README files
- GitHub issue content

## Current Limitations

This setup protects access to Azure Static Web Apps.

The Azure Container Apps backend does not yet independently validate an access token.

SWA-to-ACA token propagation and Spring Security integration are planned as a separate step.