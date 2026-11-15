# Authentication Setup

This document describes how to reproduce and verify the current Microsoft Entra ID authentication and authorization configuration for `spring-azure-serverless-demo`.

The current implementation uses:

- React and MSAL for interactive user sign-in.
- A single-tenant SPA App Registration for the frontend.
- A separate App Registration for the backend API.
- OAuth 2.0 access tokens for frontend-to-backend calls.
- Spring Security as the backend resource server.
- The `access_as_user` delegated scope for API access.
- The `Fortune.Admin` app role for administrative operations.
- Azure Static Web Apps for static frontend hosting only.

For the overall deployment sequence, see:

```text
docs/deployment.md
```

For architecture and trust-boundary details, see:

```text
docs/authentication.md
docs/architecture.md
```

---

## Overview

Authentication resources and application resources may exist in different Microsoft Entra ID tenant contexts.

```text
Azure Subscription Tenant
  │
  ├── Azure Static Web Apps
  ├── Azure Container Apps
  ├── Azure Container Registry
  ├── Azure SQL Database
  └── User Assigned Managed Identity

Authentication Tenant
  │
  ├── spring-azure-serverless-demo-client
  │     ├── SPA platform configuration
  │     ├── Production and local redirect URIs
  │     └── access_as_user delegated permission
  │
  └── spring-azure-serverless-demo-api
        ├── Application ID URI
        ├── access_as_user delegated scope
        ├── Fortune.Admin app role
        └── Service Principal
```

The application authentication flow is:

```text
Browser
  │
  ▼
Azure Static Web Apps
  │  serves the React application
  ▼
React / MSAL
  │  authorization code flow with PKCE
  ▼
Microsoft Entra ID
  │  issues an access token for the API
  ▼
Spring Boot / Spring Security
  │  validates the token, scope, and role
  ▼
Protected Fortune API operations
```

Azure Static Web Apps does not perform user authentication in this architecture. It hosts the compiled frontend and its static configuration.

The React SPA is a public client. It must not use or store a confidential client credential.

---

## Authentication Setup Flow

The setup sequence is:

```text
Verify prerequisites
        │
        ▼
Select the Azure subscription and obtain the Static Web Apps hostname
        │
        ▼
Switch to the authentication tenant
        │
        ▼
Run 41-deploy-identity.ps1
        │
        ├── Create or update the backend API App Registration
        ├── Configure access_as_user
        ├── Configure Fortune.Admin
        ├── Create or verify the API Service Principal
        ├── Create or update the React SPA App Registration
        ├── Configure production and local SPA redirect URIs
        └── Configure the client-to-API delegated permission
        │
        ▼
Verify the two App Registrations
        │
        ▼
Deploy the backend with the authentication tenant configuration
        │
        ▼
Build and deploy the frontend
        │
        ▼
Verify sign-in, API access, authorization, and sign-out
```

The identity deployment is intentionally idempotent. The script reuses matching App Registrations when possible and converges their configuration to the expected state.

---

## Prerequisites

Before configuring authentication, confirm that:

- Azure Static Web Apps has been deployed.
- Its production hostname is available.
- The user can access the Azure subscription tenant.
- The user can manage applications, Service Principals, scopes, permissions, and app roles in the authentication tenant.
- Azure CLI is installed and authenticated.
- PowerShell is available.
- The repository scripts are available locally.
- The backend and frontend can be built and deployed.
- The target users exist in, or have been invited to, the authentication tenant as required.
- A tenant administrator can grant consent or assign app roles when the tenant policy requires it.

The Azure infrastructure should normally be deployed before the identity script is run because the production Static Web Apps hostname is used as an SPA redirect URI.

---

## Required Information

The setup uses the following values:

```text
Authentication Tenant ID
Azure Subscription Tenant ID
Azure Subscription ID
Azure Static Web Apps name
Azure Static Web Apps Resource Group
Azure Static Web Apps production hostname
Backend API App Registration name
React SPA App Registration name
```

The default App Registration names are:

```text
spring-azure-serverless-demo-api
spring-azure-serverless-demo-client
```

Environment-specific non-secret Azure resource names are loaded from:

```text
config/dev.psd1
```

Do not place credentials, tokens, or other secret values in the environment configuration file.

---

## Required Environment Variables

### ENTRA_TENANT_ID

The backend deployment requires:

```text
ENTRA_TENANT_ID
```

This value identifies the Microsoft Entra ID tenant whose tokens the backend accepts. It is not a secret.

Verify that it is available without printing the value:

```powershell
if ($env:ENTRA_TENANT_ID) {
    Write-Host "ENTRA_TENANT_ID is configured."
}
else {
    Write-Host "ENTRA_TENANT_ID is not configured."
}
```

Set it for the current PowerShell session when necessary:

```powershell
$env:ENTRA_TENANT_ID = "<AUTHENTICATION_TENANT_ID>"
```

To store it as a Windows user environment variable:

```powershell
[System.Environment]::SetEnvironmentVariable(
    "ENTRA_TENANT_ID",
    "<AUTHENTICATION_TENANT_ID>",
    "User"
)
```

Open a new PowerShell session after setting a Windows user environment variable.

### SWA_DEPLOYMENT_TOKEN

Frontend deployment requires:

```text
SWA_DEPLOYMENT_TOKEN
```

This is a deployment credential, not a user-authentication credential. Handle it as a secret and do not commit it.

---

## Step 1: Verify the Azure Subscription Context

Sign in to the tenant that contains the Azure subscription resources:

```powershell
az login `
  --tenant <AZURE_SUBSCRIPTION_TENANT_ID>
```

Select the target subscription:

```powershell
az account set `
  --subscription <AZURE_SUBSCRIPTION_ID>
```

Verify the active Azure CLI context:

```powershell
az account show `
  --query "{tenantId:tenantId,subscriptionId:id,subscriptionName:name}" `
  --output table
```

Confirm that:

- The active tenant is the Azure subscription tenant.
- The selected subscription contains the deployed Static Web App.
- The expected Resource Group is available.

---

## Step 2: Obtain the Azure Static Web Apps Hostname

Retrieve the production hostname:

```powershell
$swaHostname = az staticwebapp show `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --query defaultHostname `
  --output tsv
```

Verify the result:

```powershell
if (-not $swaHostname) {
    throw "The Azure Static Web Apps hostname could not be determined."
}

Write-Host "Static Web Apps hostname: $swaHostname"
```

The value must be a hostname without the URI scheme, for example:

```text
<STATIC_WEB_APP_HOSTNAME>
```

The corresponding production SPA redirect URI is:

```text
https://<STATIC_WEB_APP_HOSTNAME>
```

Use the actual Static Web Apps name and Resource Group from the selected environment when they differ from the development example.

---

## Step 3: Switch to the Authentication Tenant

Sign in to the authentication tenant:

```powershell
az login `
  --tenant <AUTHENTICATION_TENANT_ID> `
  --allow-no-subscriptions
```

Verify the active tenant:

```powershell
az account show `
  --query tenantId `
  --output tsv
```

The result must match the authentication tenant before running the identity deployment script.

The authentication tenant may not contain the target Azure subscription. The `--allow-no-subscriptions` option supports directory-level identity operations in that case.

---

## Step 4: Create or Update the Identity Configuration

Run the identity deployment script from the repository root:

```powershell
.\scripts\41-deploy-identity.ps1 `
  -StaticWebAppHostname $swaHostname
```

By default, the script manages:

```text
spring-azure-serverless-demo-api
spring-azure-serverless-demo-client
```

The backend API registration contains:

- An Application ID URI.
- The `access_as_user` delegated permission scope.
- The `Fortune.Admin` app role.
- A Service Principal in the authentication tenant.

The React SPA registration contains:

- The `https://<STATIC_WEB_APP_HOSTNAME>` production redirect URI.
- The `http://localhost:5173` local-development redirect URI.
- Delegated permission to the API's `access_as_user` scope.

The script output includes the tenant ID, application IDs, object IDs, scope ID, role ID, Service Principal ID, and redirect URIs. Treat those values as environment-specific configuration data. Do not copy real identifiers into committed documentation.

### Optional Display-name Overrides

If the repository script supports display-name parameters for another environment, use the parameter names defined by the script. Keep API and SPA registrations distinct and use unique names within the tenant.

Do not create an additional registration for the Static Web Apps host. The current host is not an OAuth confidential client.

---

## Step 5: Verify the Backend API App Registration

Retrieve the API application:

```powershell
$apiApp = az ad app list `
  --display-name "spring-azure-serverless-demo-api" `
  --query "[0]" `
  --output json | ConvertFrom-Json

if (-not $apiApp) {
    throw "The backend API App Registration was not found."
}
```

Verify its principal configuration without writing real values to a repository file:

```powershell
az ad app show `
  --id $apiApp.id `
  --query "{displayName:displayName,appId:appId,identifierUris:identifierUris,scopes:api.oauth2PermissionScopes[].{value:value,isEnabled:isEnabled},roles:appRoles[].{value:value,isEnabled:isEnabled}}" `
  --output json
```

Confirm that:

- The Application ID URI exists.
- The `access_as_user` scope exists and is enabled.
- The `Fortune.Admin` app role exists and is enabled.
- The role's allowed member types match the intended assignment model.

### Verify the API Service Principal

```powershell
az ad sp list `
  --filter "appId eq '$($apiApp.appId)'" `
  --query "[].{displayName:displayName,appId:appId,id:id}" `
  --output table
```

Exactly one expected Service Principal should be present.

The Service Principal is the tenant-local representation used for permission consent and app-role assignment. Do not delete it while the API registration is in use.

---

## Step 6: Verify the React SPA App Registration

Retrieve the client application:

```powershell
$clientApp = az ad app list `
  --display-name "spring-azure-serverless-demo-client" `
  --query "[0]" `
  --output json | ConvertFrom-Json

if (-not $clientApp) {
    throw "The React SPA App Registration was not found."
}
```

Inspect its SPA redirect URIs:

```powershell
az ad app show `
  --id $clientApp.id `
  --query "spa.redirectUris" `
  --output json
```

The expected values are:

```text
https://<STATIC_WEB_APP_HOSTNAME>
http://localhost:5173
```

Redirect URI comparison is exact. Check the scheme, hostname, port, path, and trailing slash.

Inspect delegated API permissions:

```powershell
az ad app show `
  --id $clientApp.id `
  --query "requiredResourceAccess" `
  --output json
```

Confirm that the client requests the backend API's `access_as_user` scope. The permission entry must reference the backend API application and the scope ID produced by the identity script.

### Consent

Depending on tenant policy, a user or administrator may need to grant consent for the delegated permission.

Consent does not replace authorization checks. The backend must still validate the token and require the expected scope and role for each protected operation.

---

## Step 7: Configure App-role Assignments

Assign `Fortune.Admin` only to users or groups that require administrative Fortune operations.

App-role assignment is an administrative tenant operation. Verify assignments in Microsoft Entra ID or with an approved administrative process.

After changing an assignment:

1. Sign out of the application.
2. End the existing browser session when necessary.
3. Sign in again to obtain a new token.
4. Verify that the new token contains the expected role claim.

An old cached token does not gain a newly assigned role automatically.

Do not grant `Fortune.Admin` merely to make authentication succeed. Authentication, delegated API access, and administrative authorization are separate controls.

---

## Step 8: Return to the Azure Subscription Tenant

Sign in to the Azure subscription tenant:

```powershell
az login `
  --tenant <AZURE_SUBSCRIPTION_TENANT_ID>
```

Select the target subscription:

```powershell
az account set `
  --subscription <AZURE_SUBSCRIPTION_ID>
```

Verify the active context:

```powershell
az account show `
  --query "{tenantId:tenantId,subscriptionId:id,subscriptionName:name}" `
  --output table
```

Do not continue until the active tenant and subscription identify the target application environment.

---

## Step 9: Deploy the Backend Authentication Configuration

Verify `ENTRA_TENANT_ID` before backend deployment:

```powershell
if (-not $env:ENTRA_TENANT_ID) {
    throw "ENTRA_TENANT_ID is not configured."
}
```

Deploy the backend using the repository deployment procedure:

```powershell
.\scripts\deploy-backend.ps1
```

The backend deployment passes the authentication tenant configuration to the Azure Container App.

After deployment, confirm that the backend starts successfully and that Spring Security is configured as an OAuth 2.0 resource server.

The backend must validate at least:

- Token signature.
- Issuer and tenant.
- Token audience for the backend API.
- Token lifetime.
- The `access_as_user` scope for delegated API access.
- The `Fortune.Admin` role for administrative operations.

Do not rely on the frontend to enforce backend authorization. Frontend controls improve usability but are not a security boundary.

---

## Step 10: Build the Frontend

Build the frontend with the current environment configuration:

```powershell
.\scripts\build-frontend.ps1
```

The build script prepares the frontend API endpoint and build metadata, then runs the Vite production build.

The generated files are written to:

```text
frontend/dist
```

Do not commit the generated `dist` directory.

The Static Web Apps configuration must remain consistent with the hosting-only role of Azure Static Web Apps. It must not introduce a second user-authentication flow in front of MSAL.

---

## Step 11: Configure the Static Web Apps Deployment Token

Retrieve the deployment token while signed in to the Azure subscription tenant:

```powershell
$token = az staticwebapp secrets list `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --query properties.apiKey `
  --output tsv
```

Store it as a Windows user environment variable:

```powershell
[System.Environment]::SetEnvironmentVariable(
    "SWA_DEPLOYMENT_TOKEN",
    $token,
    "User"
)
```

Open a new PowerShell session and verify that the variable is available without printing its value:

```powershell
if ($env:SWA_DEPLOYMENT_TOKEN) {
    Write-Host "SWA_DEPLOYMENT_TOKEN is configured."
}
else {
    Write-Host "SWA_DEPLOYMENT_TOKEN is not configured."
}
```

Do not store the deployment token in the repository.

---

## Step 12: Deploy the Frontend

Deploy the generated frontend:

```powershell
.\scripts\deploy-frontend.ps1
```

The script deploys:

```text
frontend/dist
```

to the Azure Static Web Apps production environment.

The deployment token authorizes deployment only. It is not used by MSAL and is not presented to the backend API.

---

## Step 13: Verify the Production Environment

List the Azure Static Web Apps environments:

```powershell
az staticwebapp environment list `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --output table
```

The production environment is represented by:

```text
default
```

Verify that the production environment is ready before testing authentication.

Retrieve and display the application URL:

```powershell
$swaHostname = az staticwebapp show `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --query defaultHostname `
  --output tsv

Write-Host "https://$swaHostname"
```

---

## Step 14: Verify Sign-in and Token Acquisition

Use a new InPrivate or Incognito browser window to avoid relying on an old session.

1. Open the deployed React application.
2. Confirm that the application loads before sign-in.
3. Select **Sign in**.
4. Confirm that MSAL redirects to the expected Microsoft Entra ID tenant.
5. Sign in with a registered user.
6. Confirm that the browser returns to the React application at the configured SPA redirect URI.
7. Confirm that the signed-in state is displayed.
8. Trigger a Fortune API request.
9. Confirm that MSAL acquires an access token for the backend API scope.
10. Confirm that the backend accepts the token.

Do not paste a real access token into documentation, issue trackers, chat, screenshots, or test fixtures.

When token inspection is required for diagnostics, verify only the necessary claims in an approved local tool and then discard the token.

Expected claim categories include:

- Issuer and tenant.
- Audience.
- Subject or object identifier.
- Delegated scope.
- App roles when assigned.
- Issued-at and expiration times.

---

## Step 15: Verify Authorization Scenarios

### User with Delegated API Access

Expected result:

```text
Read-only or ordinary protected operations succeed when access_as_user is present.
```

Verify that the backend, not only the frontend, rejects a request that lacks the delegated scope.

### User with Fortune.Admin

Expected result:

```text
Administrative Fortune operations succeed.
```

Verify:

- Administrative UI controls are displayed appropriately.
- Fortune list operations succeed.
- Fortune creation succeeds.
- Fortune deletion succeeds.
- The backend independently enforces the role.

### User without Fortune.Admin

Expected result:

```text
Ordinary permitted operations follow the application policy, but administrative operations are denied.
```

Hiding an administrative button is not sufficient. Direct API calls without the role must also be denied.

### Unregistered or Disallowed User

Expected result:

```text
Sign-in or API access is denied according to tenant and application policy.
```

Verify that access is based on tenant registration, consent, token validity, scope, and role rather than email-domain matching alone.

---

## Step 16: Verify Sign-out

Complete sign-out from the React application.

After sign-out:

1. The application must clear its MSAL account and token state.
2. Protected API calls must no longer succeed with the previous application session.
3. A subsequent protected action must require authentication again.
4. Signing in again must obtain fresh tokens.

Browser single sign-on can allow Microsoft Entra ID to authenticate the same account again without prompting for credentials. That behavior does not mean the application sign-out failed.

---

## Rebuilding the Azure Environment

The Azure subscription resources and authentication resources have independent lifecycles.

When the Azure environment is rebuilt:

1. Deploy the new Static Web App.
2. Obtain its production hostname.
3. Switch to the authentication tenant.
4. Run `41-deploy-identity.ps1` with the new hostname.
5. Verify the backend API and React SPA registrations.
6. Verify or grant delegated permission consent.
7. Verify app-role assignments.
8. Return to the Azure subscription tenant.
9. Deploy the backend with the correct `ENTRA_TENANT_ID`.
10. Build and deploy the frontend.
11. Repeat sign-in, API, authorization, and sign-out verification.

The script reuses the existing App Registrations when possible.

When replacing an environment, do not remove an old SPA redirect URI until the corresponding frontend is no longer used. Confirm that no deployment, custom domain, or test environment still depends on it.

---

## Configuration Update Scenarios

### Authentication Tenant Changed

If the authentication tenant changes:

1. Set the new `ENTRA_TENANT_ID`.
2. Sign in to the new tenant with sufficient directory permissions.
3. Create or select the two App Registrations in that tenant.
4. Configure the API scope, app role, Service Principal, SPA redirect URIs, and delegated permission.
5. Grant consent and assign roles in the new tenant.
6. Redeploy the backend.
7. Rebuild and redeploy the frontend when its MSAL configuration changes.
8. Verify issuer, audience, scope, and role claims.
9. Complete the full end-to-end test.

Objects and consent do not automatically move between tenants.

### Static Web Apps Hostname Changed

If the production hostname changes:

1. Retrieve the new hostname.
2. Run `41-deploy-identity.ps1` with the new hostname.
3. Verify the new SPA redirect URI.
4. Rebuild and deploy the frontend.
5. Verify login and redirect behavior.
6. Remove the old redirect URI only after the old environment is retired.

### API Application Changed

If the backend API registration changes:

1. Verify the new Application ID URI.
2. Verify the `access_as_user` scope and its identifier.
3. Verify the `Fortune.Admin` role and its identifier.
4. Update the React SPA delegated permission.
5. Grant consent when required.
6. Update backend and frontend configuration that depends on the API identifier.
7. Redeploy both application components.
8. Obtain new tokens and repeat authorization tests.

### SPA Application Changed

If the React SPA registration changes:

1. Verify production and local redirect URIs.
2. Verify the delegated permission to the backend API.
3. Update the frontend MSAL client configuration.
4. Rebuild and redeploy the frontend.
5. Clear stale browser state and obtain a new token.
6. Repeat the sign-in and API tests.

### Fortune.Admin Assignment Changed

If only an app-role assignment changes:

1. Verify the assignment against the backend API Service Principal.
2. Sign out.
3. Discard cached tokens.
4. Sign in again.
5. Confirm that the new token has, or no longer has, the role.
6. Verify both the UI and direct API behavior.

---

## Authentication Exit Criteria

Authentication and authorization setup is complete when:

- The backend API App Registration exists.
- Its Application ID URI is configured.
- The `access_as_user` delegated scope exists and is enabled.
- The `Fortune.Admin` app role exists and is enabled.
- The backend API Service Principal exists.
- The React SPA App Registration exists.
- The production and local SPA redirect URIs are configured.
- The SPA requests the API's delegated scope.
- Required consent has been granted.
- Required app-role assignments are present.
- The backend validates access tokens as a resource server.
- A permitted user can sign in through MSAL.
- A token with `access_as_user` can call the protected API.
- Requests without a valid token are rejected.
- Requests without the required scope are rejected.
- Administrative requests without `Fortune.Admin` are rejected.
- Administrative requests with `Fortune.Admin` succeed.
- Fortune list, create, and delete behavior matches the authorization policy.
- Sign-out succeeds.
- No token or deployment credential is committed to the repository.

---

## Current Security Boundary

The current security boundary is the backend API.

```text
React / MSAL
  │
  │ Bearer access token
  ▼
Spring Security Resource Server
  ├── signature validation
  ├── issuer and tenant validation
  ├── audience validation
  ├── access_as_user enforcement
  └── Fortune.Admin enforcement
```

Azure Static Web Apps provides frontend hosting. It does not replace backend token validation.

Frontend route guards, disabled controls, and hidden buttons are user-experience features. They do not provide enforceable API authorization.

CORS limits which browser origins can call the API, but it does not authenticate a caller and does not replace OAuth 2.0 token validation.

Azure SQL access through managed identity is separate from end-user authentication. The backend's database identity does not represent the signed-in user.

---

## Troubleshooting

### MSAL Redirect Fails

Verify:

- The browser is using the expected frontend URL.
- The SPA registration contains the exact frontend origin as a redirect URI.
- The redirect URI is under the SPA platform configuration.
- The active tenant is the intended authentication tenant.
- The frontend uses the expected tenant and client application.
- The redirect URI has no unexpected path or trailing slash.

Expected production form:

```text
https://<STATIC_WEB_APP_HOSTNAME>
```

Expected local form:

```text
http://localhost:5173
```

### Consent or Scope Error

Verify:

- The backend API exposes `access_as_user`.
- The SPA's delegated permission references the correct API application.
- The permission references the current scope ID.
- User or administrator consent has been granted as required.
- The requested scope string uses the backend API Application ID URI.
- A fresh token was obtained after configuration changed.

### 401 Unauthorized

A 401 response normally means the request was not authenticated successfully.

Verify:

- An access token is attached as a Bearer token.
- The token is not expired.
- The token signature is valid.
- The issuer and tenant match `ENTRA_TENANT_ID`.
- The audience identifies the backend API.
- The backend is using the intended Entra configuration.
- The deployed backend received the current environment settings.

Do not diagnose a 401 by weakening token validation.

### 403 Forbidden

A 403 response normally means the caller is authenticated but lacks required authorization.

Verify:

- The token contains `access_as_user` for delegated API access.
- The administrative endpoint requires `Fortune.Admin` only where intended.
- The user or group has the app-role assignment.
- The role is emitted in a newly acquired token.
- Spring Security maps the scope and role claims to the expected authorities.

Do not change a protected endpoint to permit all callers merely to make a 403 disappear.

### Fortune.Admin Is Missing After Assignment

1. Verify the assignment against the backend API Service Principal.
2. Sign out of the application.
3. Close the private browser window or clear the MSAL cache.
4. Sign in again.
5. Inspect only the necessary token claims locally.
6. Confirm that the backend recognizes the mapped authority.

Role assignments affect newly issued tokens, not already cached tokens.

### Wrong Tenant Is Active

Verify the Azure CLI context:

```powershell
az account show `
  --query "{tenantId:tenantId,subscriptionId:id,subscriptionName:name}" `
  --output table
```

Switch to the tenant required by the current step before rerunning the command.

### Duplicate App Registrations

If the identity script reports more than one application with the same display name:

1. Stop the setup.
2. Identify the intended application by object ID and application ID.
3. Determine which deployments and permissions reference each object.
4. Rename or remove obsolete duplicates through an explicit administrative process.
5. Rerun the script only after the display name is unambiguous.

Do not delete an application solely because its name appears duplicated.

### Frontend Works but API Calls Fail

Verify the complete token path:

```text
React/MSAL configuration
  → requested API scope
  → issued token audience and scope
  → Authorization header
  → backend issuer and audience validation
  → endpoint authorization rule
```

Successful interactive sign-in proves only that the SPA can authenticate a user. It does not prove that the SPA acquired a valid token for the backend API.

### Static Frontend Does Not Load

Treat this as a hosting or deployment problem before changing identity configuration.

Verify:

- The frontend build succeeded.
- `frontend/dist` contains the expected assets.
- The deployment targeted the production environment.
- `SWA_DEPLOYMENT_TOKEN` is current.
- Static Web Apps routing serves the React entry point.

For additional diagnostics, see:

```text
docs/troubleshooting.md
```

---

## Security Requirements

Never commit:

- Azure Static Web Apps deployment tokens.
- Access tokens.
- Refresh tokens.
- ID tokens.
- Real user claims or personal information.
- Private certificates or keys.
- Local environment files containing credentials.
- Generated frontend files containing unintended environment-specific data.

Do not include token or identity values in:

- Git commit messages.
- Pull request descriptions.
- Screenshots.
- Test fixtures.
- Markdown examples.
- Shared terminal transcripts.
- Command history where avoidable.

The React SPA is a public client and must use authorization code flow with PKCE. Do not add a confidential credential to frontend code, Vite variables, static assets, or Static Web Apps settings.

Store deployment and automation credentials only in approved locations, such as:

- GitHub Actions secrets.
- Azure Key Vault.
- Local user environment variables for development-only workflows.
- Managed identity when supported by the deployment process.

Use least privilege for:

- Directory application administration.
- API consent.
- App-role assignment.
- Azure deployment access.
- Database access.

---

## Related Documentation

Authentication architecture and trust boundaries:

```text
docs/authentication.md
```

Current application architecture:

```text
docs/architecture.md
```

Deployment sequence:

```text
docs/deployment.md
```

Troubleshooting:

```text
docs/troubleshooting.md
```

Authentication implementation history:

```text
docs/step03-authentication.md
```

Testing and verification definitions:

```text
docs/testing.md
```
