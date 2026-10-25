# Authentication Setup

This document describes how to reproduce and verify the current Microsoft Entra ID authentication configuration for spring-azure-serverless-demo.

The application uses Azure Static Web Apps as the authenticated frontend entry point.

For the current authentication architecture, trust boundaries, and limitations, see:

```text
docs/authentication.md
```

For the overall deployment sequence, see:

```text
docs/deployment.md
```

---

## Overview

Authentication configuration spans two Microsoft Entra ID tenant contexts.

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
  ├── App Registration
  ├── Service Principal
  └── Registered users
```

The authentication tenant contains the Microsoft Entra ID identity resources.

The Azure subscription tenant contains the deployed application resources and Azure Static Web Apps application settings.

The setup process therefore requires switching the active Azure CLI context between the two tenants.

---

## Authentication Setup Flow

The setup sequence is:

```text
Verify prerequisites
        │
        ▼
Obtain Azure Static Web Apps hostname
        │
        ▼
Switch to the authentication tenant
        │
        ▼
Create or update the App Registration
        │
        ▼
Create or verify the Service Principal
        │
        ▼
Configure redirect URI and ID tokens
        │
        ▼
Create or reuse a Client Secret
        │
        ▼
Switch back to the Azure subscription tenant
        │
        ▼
Configure Azure Static Web Apps application settings
        │
        ▼
Build and deploy the frontend
        │
        ▼
Verify authentication scenarios
```

The project scripts automate the identity deployment, Client Secret creation, and Azure Static Web Apps configuration steps.

---

## Prerequisites

The following prerequisites must be satisfied before configuring authentication:

- Azure Static Web Apps has been deployed.
- The Azure Static Web Apps production hostname is available.
- The user can access the Azure subscription tenant.
- The user can manage applications in the authentication tenant.
- Azure CLI is installed.
- PowerShell is available.
- The project scripts are available locally.
- `ENTRA_TENANT_ID` is configured before building the frontend.
- The frontend can be deployed to Azure Static Web Apps.

The application infrastructure should normally be deployed before authentication is configured.

This is necessary because the Azure Static Web Apps hostname is used to construct the Microsoft Entra ID redirect URI.

---

## Required Information

The authentication setup uses the following values.

```text
Authentication Tenant ID
Azure Subscription Tenant ID
Azure Subscription ID
Azure Static Web Apps name
Azure Static Web Apps Resource Group
Azure Static Web Apps hostname
Application Client ID
Client Secret
```

Environment-specific non-secret Azure resource names are loaded from:

```text
config/dev.psd1
```

Secret values must not be written to this configuration file.

---

## Required Environment Variable

The frontend authentication configuration requires:

```text
ENTRA_TENANT_ID
```

Verify that it is available without displaying its value:

```powershell
if ($env:ENTRA_TENANT_ID) {
    Write-Host "ENTRA_TENANT_ID is configured."
}
else {
    Write-Host "ENTRA_TENANT_ID is not configured."
}
```

If necessary, set it for the current PowerShell session:

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

`ENTRA_TENANT_ID` is not a secret, but environment-specific identifiers should still be handled carefully in public documentation and example output.

---

## Step 1: Verify the Azure Subscription Context

Sign in to the tenant that contains the Azure subscription resources.

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
- The selected subscription contains the deployed Azure Static Web App.
- The expected Resource Group is available.

---

## Step 2: Obtain the Azure Static Web Apps Hostname

Retrieve the production hostname.

```powershell
$swaHostname = az staticwebapp show `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --query defaultHostname `
  --output tsv
```

Display the hostname:

```powershell
Write-Host $swaHostname
```

The result should be a hostname without the URI scheme.

Example form:

```text
<STATIC_WEB_APP_HOSTNAME>
```

The authentication callback URI is constructed from this hostname.

```text
https://<STATIC_WEB_APP_HOSTNAME>/.auth/login/aad/callback
```

Use the actual Azure Static Web Apps name and Resource Group from the selected environment configuration when they differ from the development example.

---

## Step 3: Switch to the Authentication Tenant

Sign in to the authentication tenant.

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

The result must match the authentication tenant before running the identity deployment scripts.

The authentication tenant may not contain the target Azure subscription. The `--allow-no-subscriptions` option supports signing in when only directory-level identity operations are required.

---

## Step 4: Create or Update the Authentication Identity

Run the identity deployment script from the repository root.

```powershell
.\scripts\41-deploy-identity.ps1 `
  -StaticWebAppHostname $swaHostname
```

The script creates or updates the authentication identity configuration.

It manages:

- App Registration
- Service Principal
- Azure Static Web Apps redirect URI
- ID-token configuration

The redirect URI uses:

```text
https://<STATIC_WEB_APP_HOSTNAME>/.auth/login/aad/callback
```

The script reuses the existing App Registration when possible.

This allows the authentication identity to remain stable when the Azure application environment is updated or rebuilt.

### Verify the App Registration

Inspect the application information if required:

```powershell
az ad app list `
  --display-name <APPLICATION_DISPLAY_NAME> `
  --query "[].{displayName:displayName,appId:appId,id:id}" `
  --output table
```

Do not copy real Client IDs or Object IDs into committed documentation.

### Verify the Service Principal

Inspect the Service Principal if required:

```powershell
az ad sp list `
  --display-name <APPLICATION_DISPLAY_NAME> `
  --query "[].{displayName:displayName,appId:appId,id:id}" `
  --output table
```

### Verify the Redirect URI

Inspect the App Registration web configuration if required:

```powershell
az ad app show `
  --id <APPLICATION_OBJECT_ID> `
  --query web.redirectUris `
  --output json
```

The expected redirect URI is:

```text
https://<STATIC_WEB_APP_HOSTNAME>/.auth/login/aad/callback
```

### Verify ID-token Configuration

Inspect the implicit-grant settings if required:

```powershell
az ad app show `
  --id <APPLICATION_OBJECT_ID> `
  --query web.implicitGrantSettings `
  --output json
```

The authentication configuration must support the ID-token flow required by the current Azure Static Web Apps provider configuration.

---

## Step 5: Create or Reuse a Client Secret

Run:

```powershell
.\scripts\42-create-client-secret.ps1
```

The script checks the existing application credentials.

If a credential already exists, the script does not create another Client Secret by default.

This avoids creating unnecessary duplicate credentials.

### Create an Additional Client Secret

When a new Azure Static Web Apps environment needs a new credential, run:

```powershell
.\scripts\42-create-client-secret.ps1 `
  -CreateNew
```

The existing credentials are preserved.

Use the newly generated Client Secret only for the configuration operation that requires it.

### Client Secret Visibility

A Client Secret value is displayed only when the credential is created.

The value cannot be retrieved later.

If the value is lost, create a new Client Secret rather than attempting to retrieve the old value.

### Client Secret Handling

Do not:

- Commit the Client Secret.
- Write it into `config/dev.psd1`.
- Store it in README files.
- Store it in committed Markdown files.
- Include it in screenshots.
- Include it in shell history where avoidable.
- Include it in Git commit messages.
- Copy it into generated source files.

Use the Client Secret immediately to configure Azure Static Web Apps.

---

## Step 6: Store the Client ID and Client Secret Temporarily

Store the Application Client ID in the current PowerShell session.

```powershell
$clientId = "<APPLICATION_CLIENT_ID>"
```

Read the newly created Client Secret as a SecureString:

```powershell
$clientSecret = Read-Host `
  "Enter the newly created Client Secret" `
  -AsSecureString
```

Do not print the SecureString value.

The SecureString remains in the current PowerShell session only for the following configuration step.

---

## Step 7: Switch Back to the Azure Subscription Tenant

Sign in to the Azure subscription tenant.

```powershell
az login `
  --tenant <AZURE_SUBSCRIPTION_TENANT_ID>
```

Select the target Azure subscription.

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

Do not continue until the active tenant and subscription identify the environment containing the target Azure Static Web App.

---

## Step 8: Configure Azure Static Web Apps Authentication

Run:

```powershell
.\scripts\43-configure-swa-auth.ps1 `
  -ClientId $clientId `
  -ClientSecret $clientSecret
```

By default, the script loads the target Azure Static Web Apps name and Resource Group from:

```text
config/dev.psd1
```

To target another supported environment:

```powershell
.\scripts\43-configure-swa-auth.ps1 `
  -Environment prod `
  -ClientId $clientId `
  -ClientSecret $clientSecret
```

The script verifies that:

- The target Azure Static Web App exists in the active subscription.
- The Application Client ID is configured.
- The Client Secret application setting exists.

The script must not display the Client Secret.

The Client Secret must not be written to a repository file.

---

## Step 9: Verify Azure Static Web Apps Application Settings

List the Azure Static Web Apps application-setting names if required.

Do not print secret values into shared output or committed documentation.

Verify that the settings referenced by the generated authentication configuration exist.

The generated configuration is based on:

```text
scripts/staticwebapp.config.template.json
```

The generated build artifact is written to:

```text
frontend/dist/staticwebapp.config.json
```

Do not manually edit the generated file.

Modify the source template or build configuration and regenerate the frontend instead.

---

## Step 10: Build the Frontend

Before building, verify that `ENTRA_TENANT_ID` is configured.

```powershell
if (-not $env:ENTRA_TENANT_ID) {
    throw "ENTRA_TENANT_ID is not configured."
}
```

Build the frontend:

```powershell
.\scripts\build-frontend.ps1
```

The script:

1. Loads the selected environment configuration.
2. Retrieves the Azure Container App API endpoint.
3. Sets `VITE_API_BASE_URL`.
4. Calculates `VITE_BUILD_VERSION`.
5. Generates the Azure Static Web Apps authentication configuration.
6. Runs the Vite production build.

The generated files are written to:

```text
frontend/dist
```

Do not commit the generated `dist` directory.

---

## Step 11: Configure the Static Web Apps Deployment Token

The frontend deployment requires:

```text
SWA_DEPLOYMENT_TOKEN
```

Retrieve the token while signed in to the Azure subscription tenant:

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

Open a new PowerShell session.

Verify that the variable is available without printing its value:

```powershell
if ($env:SWA_DEPLOYMENT_TOKEN) {
    Write-Host "SWA_DEPLOYMENT_TOKEN is configured."
}
else {
    Write-Host "SWA_DEPLOYMENT_TOKEN is not configured."
}
```

Do not store the deployment token in the repository.

The deployment token is used for frontend deployment. It is separate from the Microsoft Entra ID Client Secret used by the authentication provider.

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

The deployment script invokes Azure Static Web Apps CLI through:

```text
npx @azure/static-web-apps-cli
```

A globally installed `swa` executable is not required by the normal deployment script.

The production deployment explicitly uses:

```text
--env production
```

This avoids unintentionally targeting another resolved environment.

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

---

## Step 14: Verify the Authentication Flow

Retrieve the application hostname:

```powershell
$swaHostname = az staticwebapp show `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --query defaultHostname `
  --output tsv
```

Display the application URL:

```powershell
Write-Host "https://$swaHostname"
```

Open the displayed URL in a browser.

Verify the following flow:

1. Access the deployed application without an authenticated session.
2. Confirm that the configured authentication flow starts.
3. Sign in through Microsoft Entra ID.
4. Confirm that the user returns to the deployed React application.
5. Confirm that the application is displayed.
6. Confirm that the frontend build version is visible.
7. Complete logout.
8. Access the application again.
9. Confirm that authentication is required again.

---

## Step 15: Verify Authenticated Identity

Open:

```text
https://<STATIC_WEB_APP_HOSTNAME>/.auth/me
```

Verify the expected identity information.

The response can include:

- Authentication provider
- User identity information
- Token audience
- Token issuer
- User roles

Do not copy a real response into the repository.

Do not commit:

- Real user details
- Tenant IDs
- Client IDs
- Object IDs
- Access tokens
- ID tokens
- Claims containing personal information

Use `/.auth/me` only for verification and diagnostics.

---

## Step 16: Verify User Scenarios

Verify the supported authentication scenarios.

### Registered External User

Expected result:

```text
Access granted
```

Verify that a user from another tenant who is registered in the authentication tenant can sign in and access the application.

### Native Authentication-tenant User

Expected result:

```text
Access granted
```

Verify that a native user in the authentication tenant can sign in and access the application.

### Unregistered User

Expected result:

```text
Access denied
```

Verify that a user who is not registered in the authentication tenant cannot access the application.

These scenarios verify that access is associated with registration in the authentication tenant rather than email-domain matching alone.

---

## Step 17: Verify Logout

Complete the logout flow from the deployed application.

After logout:

1. The authenticated application session should be ended.
2. The application should no longer behave as an authenticated session.
3. Accessing the protected application again should start the authentication flow.

Logout verification is part of the authentication exit criteria.

---

## Rebuilding the Azure Environment

The Azure subscription resources and authentication resources have independent lifecycles.

When Azure resources are rebuilt:

1. Deploy the new Azure Static Web App.
2. Obtain the new Static Web Apps hostname.
3. Switch to the authentication tenant.
4. Run `41-deploy-identity.ps1` with the new hostname.
5. Create an additional Client Secret if required.
6. Switch back to the Azure subscription tenant.
7. Configure the new Azure Static Web App.
8. Build and deploy the frontend.
9. Verify authentication.

The existing App Registration is reused when possible.

A new redirect URI can be added for the newly deployed Azure Static Web App.

Do not remove an existing redirect URI until the corresponding environment no longer requires it.

---

## Client Secret Lifecycle

Client Secrets must be managed deliberately.

### Existing Credential

When an existing credential is sufficient, do not create a duplicate credential.

### New Azure Static Web App

A newly deployed Azure Static Web App may require a new Client Secret because an old secret value cannot be retrieved.

Create an additional credential with:

```powershell
.\scripts\42-create-client-secret.ps1 `
  -CreateNew
```

### Secret Rotation

When rotating a secret:

1. Create a new credential.
2. Configure the target Azure Static Web App with the new value.
3. Verify authentication.
4. Retain the previous credential until the new configuration is confirmed.
5. Remove obsolete credentials through an explicit administrative process.

The current script does not automatically delete previous credentials.

### Expired Credential

If authentication fails because a credential expired:

1. Create a new Client Secret.
2. Update the Azure Static Web Apps application setting.
3. Rebuild and redeploy only when the generated authentication configuration also changed.
4. Verify authentication.
5. Remove the obsolete credential when safe.

---

## Configuration Update Scenarios

### Authentication Tenant ID Changed

If the authentication tenant changes:

1. Set the new `ENTRA_TENANT_ID`.
2. Deploy or select the corresponding App Registration.
3. Configure the Azure Static Web App with the new Client ID and Client Secret.
4. Rebuild the frontend authentication configuration.
5. Redeploy the frontend.
6. Verify token issuer and audience through `/.auth/me`.

### Static Web Apps Hostname Changed

If the Azure Static Web Apps hostname changes:

1. Retrieve the new hostname.
2. Update the App Registration through `41-deploy-identity.ps1`.
3. Verify the new redirect URI.
4. Build the frontend.
5. Deploy the frontend.
6. Verify login and callback behavior.

### Client Secret Changed

If only the Client Secret changes:

1. Configure the Azure Static Web Apps application setting with the new value.
2. Verify authentication.

A frontend rebuild is not necessarily required when only the secret application setting changes and the generated frontend configuration remains unchanged.

---

## Authentication Exit Criteria

Authentication setup is complete when:

- The App Registration exists.
- The Service Principal exists.
- The expected redirect URI is configured.
- ID-token configuration is enabled.
- Azure Static Web Apps contains the required application settings.
- A registered external user can sign in.
- A native authentication-tenant user can sign in.
- An unregistered user is denied access.
- Post-login redirection succeeds.
- Authenticated identity information is available through `/.auth/me`.
- Logout succeeds.
- No Client Secret or token value is committed to the repository.

---

## Current Security Boundary

The current authentication flow protects the Azure Static Web Apps frontend.

The Azure Container Apps backend does not yet independently validate the authenticated user's token.

Therefore, successful frontend authentication does not currently provide backend-enforced API authorization.

CORS restrictions do not replace API authentication.

Backend API authentication and authorization are planned for a later roadmap step.

For the current trust-boundary explanation, see:

```text
docs/authentication.md
```

---

## Troubleshooting

### Login Redirect Fails

Verify:

- Static Web Apps hostname
- Redirect URI
- Authentication tenant
- App Registration
- Azure Static Web Apps application settings
- Generated `staticwebapp.config.json`

The redirect URI must exactly match:

```text
https://<STATIC_WEB_APP_HOSTNAME>/.auth/login/aad/callback
```

### 401 Unauthorized

Verify that:

- The sign-in flow completed.
- The user is registered in the authentication tenant.
- The App Registration configuration is correct.
- The Azure Static Web Apps settings reference the expected Client ID and secret setting.
- The Client Secret is valid.

### Existing Client Secret Cannot Be Retrieved

This is expected.

Create a new Client Secret:

```powershell
.\scripts\42-create-client-secret.ps1 `
  -CreateNew
```

Use the new value immediately to configure the target Azure Static Web App.

### Wrong Tenant Is Active

Verify:

```powershell
az account show `
  --query "{tenantId:tenantId,subscriptionId:id,subscriptionName:name}" `
  --output table
```

Switch to the tenant required by the current step before rerunning the command.

### Generated Authentication Configuration Is Incorrect

Verify:

```text
ENTRA_TENANT_ID
```

Then rebuild the frontend:

```powershell
.\scripts\build-frontend.ps1
```

Do not manually modify:

```text
frontend/dist/staticwebapp.config.json
```

### Authentication Works but Backend Is Not Protected

This is the current expected architecture.

Azure Static Web Apps authenticates access to the frontend.

The backend does not yet independently validate the authenticated user.

Backend API authentication and authorization are introduced in a later roadmap step.

For additional diagnostics, see:

```text
docs/troubleshooting.md
```

---

## Security Requirements

Never commit:

- Client Secrets
- Azure Static Web Apps deployment tokens
- Access tokens
- Refresh tokens
- ID tokens
- Real `/.auth/me` responses
- Real user information
- Private certificates or keys
- Generated frontend files containing environment-specific values
- Local environment files containing credentials

Do not include secret or identity values in:

- Git commit messages
- Pull request descriptions
- Screenshots
- Test fixtures
- Markdown examples
- Command history where avoidable

Use appropriate secret-storage locations such as:

- Azure Static Web Apps application settings
- GitHub Actions secrets
- Azure Key Vault
- Local user environment variables

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

Step 3 implementation history:

```text
docs/step03-authentication.md
```

Testing and verification definitions:

```text
docs/testing.md
```
