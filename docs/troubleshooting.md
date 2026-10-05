# Troubleshooting

This document contains issues encountered while building this sample application and their resolutions.

---

## Bicep Warning: BCP081

### Symptom

Running the following command:

```powershell
az bicep build `
  --file .\infra\main.bicep
```

may produce warnings similar to:

```text
BCP081: Resource type does not have types available.
```

---

### Cause

Azure resource providers sometimes publish API versions before Bicep type definitions become available.

The project currently uses recent Azure Container Apps API versions.

---

### Resolution

The warning does not prevent deployment.

The Bicep template can still be compiled and deployed successfully.

---

## What-If Warning: NestedDeploymentShortCircuited

### Symptom

Running:

```powershell
az deployment sub what-if
```

may generate:

```text
NestedDeploymentShortCircuited
```

---

### Cause

Some deployment values depend on outputs from other modules.

Examples include:

- Container Apps Environment ID
- Managed Identity ID
- Container Registry Login Server

These values are not always fully resolvable during What-If evaluation.

---

### Resolution

This message does not automatically indicate a deployment failure.

Review the remaining What-If output and proceed if the expected resource changes are shown.

---

## Frontend Deploys to Preview Instead of Production

### Symptom

After deployment, the application appears in the Preview environment instead of Production.

---

### Cause

Azure Static Web Apps CLI deploys to the resolved target environment.

If no environment is specified, the CLI may deploy to Preview.

---

### Resolution

Explicitly specify the production environment.

```powershell
swa deploy `
  .\dist `
  --env production `
  --deployment-token <TOKEN>
```

---

## Azure Static Web Apps Login Fails

### Symptom

After selecting Microsoft Entra ID authentication:

```text
AADSTS700054:
response_type 'id_token' is not enabled for the application
```

---

### Cause

The App Registration did not allow the authentication flow required by Azure Static Web Apps.

---

### Resolution

Review the Microsoft Entra ID App Registration configuration and ensure the required authentication settings are configured.

After updating the App Registration, redeploy the Static Web Apps configuration and retry authentication.

---

## Application Returns 401 After Deployment

### Symptom

The application returns:

```text
401 Unauthorized
```

immediately after deployment.

---

### Cause

The Azure Static Web Apps authentication configuration requires users to sign in before accessing protected routes.

The deployment itself is successful.

---

### Resolution

Verify that:

1. Authentication configuration is deployed.
2. Microsoft Entra ID login succeeds.
3. The browser returns to the application after authentication.

Accessing:

```text
/.auth/me
```

can be used to verify the authenticated user context.

---

## Unable to Retrieve User Information

### Symptom

The application appears to be authenticated but user information is not available.

---

### Verification

Navigate to:

```text
/.auth/me
```

Expected response:

```json
{
  "clientPrincipal": {
    "identityProvider": "aad"
  }
}
```

---

### Resolution

If the endpoint does not return `clientPrincipal`, verify:

- Authentication succeeded
- Static Web Apps configuration was deployed
- The correct Entra ID application configuration is being used

---

## Backend API Is Not Reachable

### Symptom

The frontend loads successfully, but API requests fail.

---

### Verification

Test the backend directly:

```powershell
Invoke-RestMethod `
  "https://<CONTAINER_APP_FQDN>/api/hello"
```

Expected response:

```json
{
  "message": "hello"
}
```

---

### Resolution

Verify:

- Container App deployment completed successfully
- External ingress is enabled
- Backend endpoint is reachable
- Frontend API base URL points to the correct backend

---

## Container Image Build Fails

### Symptom

Running:

```powershell
.\scripts\build-backend.ps1
```

fails during image creation.

---

### Cause

The backend image is built using Spring Boot Buildpacks and requires a Docker-compatible container runtime.

---

### Resolution

Verify:

```powershell
docker info
```

returns successfully.

A running container runtime is required before executing the backend build.

---

## Docker Connection Errors

### Symptom

Commands such as:

```powershell
docker info
```

or

```powershell
docker images
```

fail.

---

### Resolution

Verify that a Docker-compatible runtime is running.

Examples include:

- Rancher Desktop
- Docker Desktop

After starting the container runtime, retry the build process.

---

## Authentication Verification Checklist

Successful authentication was verified using the following tests.

### Registered External User

Expected:

```text
Access Granted
```

Status:

```text
Verified
```

---

### Registered Native Tenant User

Expected:

```text
Access Granted
```

Status:

```text
Verified
```

---

### Unregistered User

Expected:

```text
Access Denied
```

Status:

```text
Verified
```

This confirms that application access is controlled by tenant registration rather than email domain.


---
Some Microsoft.App and Azure Static Web Apps properties appear in What-If results as service-managed properties and may not indicate actual configuration drift.

---
## Useful Azure CLI Commands

Azure subscriptions and Microsoft Entra ID tenants are separate concepts. A tenant may be accessible to the signed-in user even if the tenant has no Azure subscription.

### Check the Azure CLI Version

```powershell
az version
```

Some commands in this section, such as `az account tenant list`, may require the Azure CLI `account` extension. The extension is normally installed automatically when the command is first used.

### Check the Current Azure Context

Before deploying infrastructure or configuring Microsoft Entra ID, verify the currently selected tenant and subscription.

```powershell
az account show --query "{User:user.name,TenantId:tenantId,Subscription:name,SubscriptionId:id,Default:isDefault}" -o table
```

This check is particularly important when the Azure resources and the Microsoft Entra ID application are managed in different tenants.

### List Accessible Tenant IDs

Use the following command to list the tenants accessible to the signed-in account:

```powershell
az account tenant list -o table
```

Example:

```text
TenantId
------------------------------------
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
```

> [!NOTE]
> `az account tenant list` is currently an experimental command. Depending on the Azure CLI and extension versions, it may return only the tenant IDs and not the tenant display names.

To inspect the complete response:

```powershell
az account tenant list -o json
```

### List Accessible Azure Subscriptions

```powershell
az account list --all --query "[].{Subscription:name,SubscriptionId:id,TenantId:tenantId,Default:isDefault}" -o table
```

This command lists Azure subscriptions accessible to the signed-in account. It does not necessarily list every accessible Microsoft Entra ID tenant.

If a tenant has no accessible Azure subscription, it may appear in `az account tenant list` but not in `az account list --all`.

### Sign In to a Specific Tenant

For a tenant that contains an accessible Azure subscription:

```powershell
az login --tenant <tenant-id>
```

For a Microsoft Entra ID tenant that has no accessible Azure subscription:

```powershell
az login --tenant <tenant-id> --allow-no-subscription
```

Example:

```powershell
az login --tenant xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx --allow-no-subscription
```

When the tenant has no subscription, Azure CLI may display an entry similar to the following:

```text
Subscription name          Subscription ID                       Tenant
-------------------------  ------------------------------------  ------------------------------------
N/A(tenant level account)  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

This means that authentication to the tenant succeeded, but no Azure subscription is available in that tenant.

Azure CLI may still display a selection prompt when only one tenant-level entry is available. Press `Enter` to accept the default selection.

### Get the Tenant ID and Display Name

After signing in to the target tenant, query Microsoft Graph:

```powershell
az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=id,displayName' --query "value[0].{TenantName:displayName,TenantId:id}" -o table
```

Example output:

```text
TenantName       TenantId
---------------  ------------------------------------
Example Tenant   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

This command identifies the display name associated with the tenant ID currently used by Azure CLI.

If the command returns an authorization error, verify that the intended account and tenant were selected during `az login`.

### Get the Tenant's Verified Domains

To display the tenant name together with its verified domains:

```powershell
az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=id,displayName,verifiedDomains' -o json
```

The response may include the initial `onmicrosoft.com` domain and other verified domains configured for the tenant.

### Map All Accessible Tenant IDs to Their Names

First, list the accessible tenant IDs:

```powershell
az account tenant list -o table
```

For each tenant ID, sign in and query the organization information:

```powershell
az login --tenant <tenant-id> --allow-no-subscription
az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=id,displayName' --query "value[0].{TenantName:displayName,TenantId:id}" -o table
```

Repeat these commands for each tenant ID returned by `az account tenant list`.

### Select an Azure Subscription

To select a subscription by name:

```powershell
az account set --subscription "<subscription-name>"
```

To avoid ambiguity, selecting it by subscription ID is recommended:

```powershell
az account set --subscription "<subscription-id>"
```

Verify the result:

```powershell
az account show --query "{TenantId:tenantId,Subscription:name,SubscriptionId:id}" -o table
```

### Return to the Azure Resource Tenant

Before deploying Azure resources, sign in to the tenant that owns the Azure subscription:

```powershell
az login --tenant <azure-resource-tenant-id>
az account set --subscription "<subscription-id>"
az account show --query "{TenantId:tenantId,Subscription:name,SubscriptionId:id}" -o table
```

Run the infrastructure deployment only after confirming both the tenant ID and subscription ID.

### Switch to the Identity Tenant

Before managing the Microsoft Entra ID application, sign in to the identity tenant:

```powershell
az login --tenant <identity-tenant-id> --allow-no-subscription
```

Verify the selected tenant:

```powershell
az account show --query "{User:user.name,TenantId:tenantId,Subscription:name}" -o table
```

If the identity tenant has no Azure subscription, the subscription may be displayed as a tenant-level account or as `N/A`.

### Clear Cached Azure CLI Account Information

If Azure CLI appears to use an unexpected account, tenant, or subscription:

```powershell
az logout
az account clear
```

Sign in again after clearing the cached account information:

```powershell
az login --tenant <tenant-id> --allow-no-subscription
```

> [!CAUTION]
> `az account clear` removes cached subscription information from Azure CLI. A new login is required afterward.


### Verify That You Are Using the Intended Identity Tenant

Before modifying an App Registration, confirm that Azure CLI is connected to the expected Microsoft Entra ID tenant.

Display the current tenant:

```powershell
az account show --query "{TenantId:tenantId,Subscription:name}" -o table
```

Display the tenant name:

```powershell
az rest `
  --method GET `
  --url "https://graph.microsoft.com/v1.0/organization?\$select=id,displayName" `
  --query "value[0].{TenantName:displayName,TenantId:id}" `
  -o table
```

Example:

```text
TenantName            TenantId
--------------------  ------------------------------------
mytenant.onmicrosoft  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

If the displayed tenant is not the intended identity tenant, sign in again:

```powershell
az login --tenant <tenant-id> --allow-no-subscription
```

This is a common cause of failures when creating or updating App Registrations.

---

### List App Registrations in the Current Tenant

Display all App Registrations visible to the signed-in account:

```powershell
az ad app list --all --query "[].{DisplayName:displayName,AppId:appId}" -o table
```

Example:

```text
DisplayName          AppId
-------------------  ------------------------------------
test-swa-auth-app    xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

This command is useful for confirming the actual application name when documentation, screenshots, or portal navigation are inconsistent.

---

### Find an App Registration by Name

```powershell
az ad app list `
  --display-name "test-swa-auth-app" `
  --query "[].{DisplayName:displayName,AppId:appId}" `
  -o table
```

---

### Find an App Registration by Client ID

When only the Client ID is known:

```powershell
az ad app show `
  --id <client-id> `
  --query "{DisplayName:displayName,AppId:appId}" `
  -o table
```

Example:

```powershell
az ad app show --id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Example output:

```text
DisplayName          AppId
-------------------  ------------------------------------
test-swa-auth-app    xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

This command is useful when troubleshooting Azure Static Web Apps authentication settings because the Client ID is often configured before the application name is documented.

---

### Verify Redirect URIs

Display the configured redirect URIs:

```powershell
az ad app show `
  --id <client-id> `
  --query "web.redirectUris"
```

Verify that the expected Azure Static Web Apps authentication callback URL is present.

---

### Verify That an App Registration Exists Before Deployment

Check whether the expected application exists:

```powershell
az ad app list `
  --display-name "test-swa-auth-app" `
  --query "length(@)"
```

Expected result:

```text
1
```

If the result is:

```text
0
```

the App Registration either does not exist or is being searched in the wrong tenant.

In that case, first verify the current tenant using:

```powershell
az rest --method GET --url "https://graph.microsoft.com/v1.0/organization?\$select=id,displayName"
```