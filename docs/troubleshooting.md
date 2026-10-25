# Troubleshooting
This document records troubleshooting scenarios encountered while building
and operating spring-azure-serverless-demo.

The focus is on symptoms, verified causes, diagnostic steps, and resolutions.

Architecture and deployment procedures are documented separately:

```text
docs/architecture.md
docs/deployment.md
```

Roadmap-specific implementation details are documented under:

```text
docs/stepNN-*.md
```

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



## Azure CLI Context*
### Symptom

Azure commands fail *ecause a resource cannot be found,*even though the
resource is known *o exist.

Example:

```text
Resour*eNotFound
```

### Check

Verify t*e current Azure CLI context:

```p*wershell
az account show `
  --que*y "{tenantId:tenantId,subscription*d:id,subscriptionName:name}" `
  -*output table
```

Also verify that*the Resource Group and resource na*e match the selected
environment c*nfiguration.

### Resolution

Sign*in to the correct tenant and selec* the correct subscription before
r*nning the command.

```powershell
*z login `
  --tenant <AZURE_SUBSCR*PTION_TENANT_ID>

az account set `*  --subscription <AZURE_SUBSCRIPTI*N_ID>
```

Avoid depending on impl*cit Azure CLI defaults when the ta*get Resource Group
can be specifie* explicitly.

---

## Bicep BCP081*Warning

### Symptom

Bicep report* a warning similar to:

```text
BC*081: Resource type does not have t*pes available.
```

### Context

T*e project can use Azure resource A*I versions for which matching Bice* type
information is not available*locally.

### Check

Build the Bic*p template:

```powershell
az bice* build `
  --file .\infra\main.bic*p
```

Review whether the operatio* reports a warning or an actual bu*ld error.

### Resolution

Treat t*e message as a diagnostic warning *hen the template still builds
succ*ssfully.

Deployment results must *till be verified against Azure.

-*-

## NestedDeploymentShortCircuit*d During What-If

### Symptom

Azu*e deployment What-If reports:

```*ext
NestedDeploymentShortCircuited*```

### Context

The application *ses subscription-scoped deployment*and nested deployment
behavior.

#*# Check

Run:

```powershell
.\scr*pts\whatif-infra.ps1
```

Review t*e complete What-If result rather t*an interpreting the diagnostic in
*solation.

### Resolution

Evaluat* the actual resource changes repor*ed by What-If.

Remember that the *zure Container App is deployed sep*rately from the shared
infrastruct*re deployment.

---

## Container *untime Is Not Available

### Sympt*m

The Spring Boot Buildpacks buil* cannot connect to the container r*ntime.

### Check

Run:

```powers*ell
docker info
```

Verify that t*e Docker-compatible runtime respon*s successfully.

### Resolution

E*sure the configured container runt*me is running and that the Docker *LI can
reach it.

This project use* Rancher Desktop as the local Dock*r-compatible runtime.

---

## Bui*dpacks Fails with exec format erro*

### Symptom

The backend Buildpa*ks build fails with:

```text
exec*/cnb/lifecycle/creator: exec forma* error
```

The log can also show * run image being selected for:

``*text
linux/arm64
```

even though *he local Docker server is:

```tex*
linux/amd64
```

### Check the Do*ker Architecture

Run:

```powersh*ll
docker version `
  --format "Cl*ent={{.Client.Arch}} Server={{.Ser*er.Arch}}"

docker info `
  --form*t "Architecture={{.Architecture}} *SType={{.OSType}}"
```

The local *nvironment used by this project is*expected to report an AMD64
Docker*server.

### Check the Builder Ima*e

Run:

```powershell
docker imag* inspect `
  paketobuildpacks/buil*er-noble-java-tiny:latest `
  --fo*mat "Builder={{.Os}}/{{.Architectu*e}}"
```

During troubleshooting, *he mutable `latest` builder resolv*d to:

```text
linux/arm64
```

wh*le the Docker server was AMD64.

#*# Check a Multi-architecture Build*r

A versioned builder can be insp*cted with:

```powershell
docker b*ildx imagetools inspect `
  paketo*uildpacks/builder-noble-java-tiny:*.0.197
```

The inspected version *rovides both:

```text
linux/amd64*linux/arm64
```

### Resolution

T*e backend build uses a versioned b*ilder:

```text
paketobuildpacks/b*ilder-noble-java-tiny:0.0.197
```
*and explicitly sets:

```text
linu*/amd64
```

through the Spring Boo* Buildpacks image-platform configu*ation.

After building, verify the*generated backend image:

```power*hell
docker image inspect `
  <BAC*END_IMAGE> `
  --format "Backend={*.Os}}/{{.Architecture}} SpringBoot*{{index .Config.Labels `"org.sprin*framework.boot.version`"}}"
```

T*e expected platform is:

```text
l*nux/amd64
```

Do not use an old l*cal builder merely to make the bui*d pass without first
understanding*its Spring Boot and Buildpacks ver*ions.

---

## Azure SQL Connectio* Fails

### Symptom

The applicati*n cannot retrieve Fortune data fro* Azure SQL.

### First Check

Veri*y the database independently of th* application:

```powershell
.\scr*pts\verify-database.ps1
```

The v*rification should confirm:

- Data*ase connectivity
- `dbo.fortunes`
* Managed Identity database princip*l
- Database role membership
- Obj*ct-level permissions

### Local Ap*lication Check

Start the backend *ith the database profile:

```powe*shell
Push-Location .\backend

.\m*nw.cmd spring-boot:run `
  "-Dspri*g-boot.run.profiles=database"

Pop*Location
```

Verify:

```powershe*l
curl.exe `
  http://localhost:80*0/api/admin/fortunes
```

If local*Azure SQL access works while the d*ployed application fails, investig*te
the Azure-specific identity and*configuration path rather than cha*ging the SQL
query immediately.

-*-

## Managed Identity Has No Data*ase Role

### Symptom

Database ve*ification displays:

```text
Manag*d Identity database roles
--------*-------------------------------

(* rows affected)
```

### Explanati*n

For the current application thi* is expected.

The Managed Identit* follows a least-privilege object-*evel permission model
instead of b*oad fixed database role membership*

### Expected Permissions

The id*ntity should have the following pe*missions on:

```text
dbo.fortunes*```

```text
DELETE
INSERT
SELECT
*``

### Verification

Run:

```pow*rshell
.\scripts\verify-database.p*1
```

The intended state is:

```*ext
Database principal      exists*Fixed database roles    none
DELET*                   GRANT
INSERT   *               GRANT
SELECT       *           GRANT
```

The absence *f broad role membership is itself *art of the verification.

---

## *ortune Management Returns HTTP 400*
### Symptom

A request to create * Fortune returns:

```text
400 Bad*Request
```

### PowerShell curl.e*e Check

When using `curl.exe` fro* PowerShell, a JSON value enclosed*in PowerShell
single quotes does n*t require backslash escaping of it* double quotes.

Use:

```powershe*l
curl.exe `
  -X POST `
  -H "Con*ent-Type: application/json" `
  -d*'{"message":"Fortune management ve*ification"}' `
  https://<CONTAINE*_APP_FQDN>/api/admin/fortunes
```
*Avoid passing a JSON body containi*g unnecessary backslashes.

### Va*idation Check

The backend also re*ects blank Fortune messages.

The *rontend prevents blank submissions*for user experience, while the bac*end
validation protects the API bo*ndary.

---

## Azure Container Ap*s API Returns HTTP 500

### Sympto*

A deployed API request returns:
*```text
500 Internal Server Error
*``

### Isolation Strategy

First *erify whether the equivalent opera*ion works locally with the databas*
profile.

Then verify an existing*deployed API such as:

```text
GET*/api/fortune
```

and compare it w*th:

```text
GET /api/admin/fortun*s
```

This helps separate:

- Rep*sitory or SQL behavior
- Local aut*entication
- Managed Identity beha*ior
- Deployment-specific behavior*
  Do not change SQL permissions or *pplication code solely on the basi* of an
  HTTP 500 response without i*entifying the actual failing bound*ry.

---

## Azure Container Apps *ogs Fail with eventStreamEndpoint
*### Symptom

Running:

```powershe*l
az containerapp logs show
```

f*ils with:

```text
KeyError: 'even*StreamEndpoint'
```

### Check

Id*ntify the active revision:

```pow*rshell
az containerapp revision li*t `
  --name <CONTAINER_APP_NAME> *
  --resource-group <RESOURCE_GROU*> `
  --output table
```

Identify*the replica:

```powershell
az con*ainerapp replica list `
  --name <*ONTAINER_APP_NAME> `
  --resource-*roup <RESOURCE_GROUP> `
  --revisi*n <REVISION_NAME> `
  --output tab*e
```

If log retrieval continues *o fail even when revision and repl*ca are specified,
treat the CLI lo*-stream failure separately from th* application failure.

### Log Ana*ytics Check

Inspect the Container*Apps Environment logging configura*ion:

```powershell
az containerap* env show `
  --name <CONTAINER_AP*S_ENVIRONMENT> `
  --resource-grou* <RESOURCE_GROUP> `
  --query prop*rties.appLogsConfiguration `
  --o*tput json
```

In the development *nvironment investigated during Ste* 4, the result was:

```text
desti*ation: null
logAnalyticsConfigurat*on: null
```

Therefore Log Analyt*cs was not available as an alterna*ive application-log
source in that*environment.

### Alternative Diag*ostic Path

When deployed logs are*unavailable, reproduce the same ba*kend operation locally
with the `d*tabase` profile where practical.

*his does not replace deployed veri*ication, but it helps determine wh*ther the
problem belongs to applic*tion data access or the Azure-spec*fic execution path.

---

## VITE_*PI_BASE_URL Points to the Wrong Ba*kend

### Symptom

A local fronten* production preview unexpectedly c*nnects to the deployed Azure
Conta*ner App instead of:

```text
http:*/localhost:8080
```

### Check the*Current PowerShell Environment

Ru*:

```powershell
Get-ChildItem `
 *Env:VITE_API_BASE_URL `
  -ErrorAc*ion SilentlyContinue
```

During t*oubleshooting, `VITE_API_BASE_URL`*remained set in the PowerShell
ses*ion from an earlier frontend build*

### Resolution

Remove the envir*nment variable from the current se*sion:

```powershell
Remove-Item `*  Env:VITE_API_BASE_URL `
  -Error*ction SilentlyContinue
```

Remove*the existing production output whe* a clean rebuild is desired:

```p*wershell
Remove-Item `
  .\dist `
* -Recurse `
  -Force `
  -ErrorAct*on SilentlyContinue
```

Rebuild:
*```powershell
npm run build
```

W*en `VITE_API_BASE_URL` is absent, *he frontend application falls back*to:

```text
http://localhost:8080*```

### Verify the Generated Arti*act

Inspect the built JavaScript:*
```powershell
Select-String `
  -*ath .\dist\assets\*.js `
  -Patter* "localhost:8080","azurecontainera*ps.io"
```

This verifies the actu*l endpoint embedded into the produ*tion build instead of
inferring it*from browser behavior.

---

## np* run preview Is Blocked by CORS

#*# Symptom

The frontend started wi*h:

```powershell
npm run preview
*``

attempts to call:

```text
htt*://localhost:8080
```

but the bro*ser reports:

```text
No 'Access-C*ntrol-Allow-Origin' header is pres*nt
```

### Explanation

The Vite *evelopment server and preview serv*r use different local origins.

Th* project uses:

```text
npm run de*      -> http://localhost:5173
npm*run preview  -> http://localhost:4*73
```

The backend must explicitl* permit the local origins used by *he frontend.

### Resolution

The *pring Boot CORS configuration perm*ts:

```text
http://localhost:5173*http://localhost:4173
```

The fir*t origin supports the Vite develop*ent server.

The second origin sup*orts the Vite production-build pre*iew.

Do not use CORS configuratio* as a substitute for API authentic*tion or
authorization.

---

## sw* Command Is Not Recognized

### Sy*ptom

The frontend deployment scri*t fails with:

```text
The term 's*a' is not recognized
```

### Caus*

The previous deployment script d*pended on a globally installed Azu*e Static Web
Apps CLI executable.
*### Resolution

The deployment scr*pt invokes Azure Static Web Apps C*I through:

```text
npx @azure/sta*ic-web-apps-cli
```

A globally in*talled `swa` command is therefore *ot required by the normal
deployme*t script.

Before deployment, veri*y that:

```text
SWA_DEPLOYMENT_TO*EN
```

is configured.

---

## Fr*ntend Is Deployed to the Wrong Sta*ic Web Apps Environment

### Sympt*m

The frontend is deployed succes*fully, but the production site doe* not contain
the expected applicat*on version.

### Check

List Stati* Web Apps environments:

```powers*ell
az staticwebapp environment li*t `
  --name <STATIC_WEB_APP_NAME>*`
  --resource-group <RESOURCE_GRO*P> `
  --output table
```

### Res*lution

The deployment explicitly *pecifies:

```text
--env productio*
```

The production Azure Static *eb Apps environment is represented*by:

```text
default
```

Verify t*at the production environment reac*es the ready state after deploymen*.

---

## Vitest Takes About One *inute or Times Out Before Running *ests

### Symptom

Running:

```po*ershell
npm test
```

takes approx*mately one minute and can fail bef*re any tests start.

Example diagn*stics include:

```text
Failed to *tart threads worker
Timeout waitin* for worker to respond
Test Files  no tests
Tests       no tests
```

### Isolation Check

Limit the worker count:

```powershell
npx vitest run `
  --maxWorkers=1
```

If the same worker startup timeout occurs, the problem is not simply excessive
test parallelism.

### Change the Worker Pool

Run:

```powershell
npx vitest run `
  --pool=forks `
  --maxWorkers=1
```

During Step 4 troubleshooting, this allowed the test suite to start and complete.

The frontend tests themselves completed successfully once the `forks` pool was
used.

### Interpretation

A timeout before:

```text
Test Files
Tests
```

are discovered is different from a failing React test.

Do not modify application code merely because the Vitest worker fails to start.

First separate test-runner startup problems from actual test failures.

---

## FortuneManagement Test Fails with fortunes.map Is Not a Function

### Symptom

After adding Fortune Management to `App`, the existing App test fails with:

```text
TypeError: fortunes.map is not a function
```

### Cause

The existing `App` test provided a global `fetch` mock intended for:

```text
GET /api/fortune
```

After Fortune Management was added, rendering `App` also triggered its initial
Fortune list request.

The same mock response was therefore supplied to two different features.

The Fortune Management component expected an array but received the random
Fortune response object.

### Resolution

Keep the test responsibilities separate.

`App.test.tsx` verifies the existing random Fortune user behavior.

`FortuneManagement.test.tsx` verifies the Fortune Management behavior.

In the App tests, Fortune Management is replaced with a simple test double so
that the App test does not need to reproduce management API behavior.

Avoid building a URL-aware global `fetch` simulation merely to duplicate the
application implementation inside the test.

---

## Spring Boot Test Context Fails When Fortune Management Is Added

### Symptom

An existing Spring Boot test using the `resource` profile fails during context
initialization after database-only Fortune Management components are introduced.

The failure indicates that a `FortuneManagementRepository` bean cannot be
resolved.

### Cause

The database repository exists only under the `database` profile.

If the management service or controller is created under the `resource` profile,
Spring attempts to resolve a database-only dependency that does not exist in that
profile.

### Resolution

The Fortune Management controller and service belong to the `database` profile.

Controller tests that exercise Fortune Management explicitly activate:

```text
database
```

and mock the service dependency.

This keeps:

```text
resource profile
```

free of database-only management components while still allowing the management
controller to be tested independently.

---

## Database Permissions Appear Correct but Application Behavior Differs

### Check the Verification Layers

Use the following sequence to locate the boundary.

### 1. Database Verification

```powershell
.\scripts\verify-database.ps1
```

### 2. Local Backend Verification

Start the database profile and call the management API.

```powershell
curl.exe `
  http://localhost:8080/api/admin/fortunes
```

### 3. Deployed Backend Verification

Call the Azure Container Apps endpoint directly.

```powershell
curl.exe `
  https://<CONTAINER_APP_FQDN>/api/admin/fortunes
```

### 4. Deployed User Scenario

Use the deployed Azure Static Web Apps UI.

These checks answer different questions and should not be described as the same
type of verification.

Direct GET, POST, and DELETE operations against the API are deployed feature
verification.

The complete Fortune Management workflow through the deployed frontend is the
E2E scenario verification.

---

## Authentication Failure

### Symptom

The Azure Static Web Apps application does not complete the expected Microsoft
Entra ID sign-in flow.

Possible symptoms include:

```text
401 Unauthorized
login redirect failure
unexpected access denial
```

### Check

Verify:

- Active authentication tenant
- App Registration
- Service Principal
- Redirect URI
- ID-token configuration
- Azure Static Web Apps application settings
- Client Secret configuration

The expected redirect URI format is:

```text
https://<STATIC_WEB_APP_HOSTNAME>/.auth/login/aad/callback
```

Detailed authentication troubleshooting and setup are documented in:

```text
docs/authentication.md
docs/authentication-setup.md
```

---

## Generated Files Contain Environment-specific Values

### Symptom

Generated frontend files contain tenant-specific or environment-specific values.

### Explanation

The frontend build intentionally generates deployment-specific artifacts under:

```text
frontend/dist
```

This can include:

```text
staticwebapp.config.json
```

### Resolution

Do not commit generated files under:

```text
frontend/dist
```

Do not manually edit generated deployment artifacts.

Change the source template or build configuration and regenerate the output
instead.

---

## Diagnostic Principles

When troubleshooting this project, use the following sequence.

### Verify the Layer That Failed

Separate:

```text
Source code
Build
Local runtime
Cloud deployment
Authentication
Database identity
Database authorization
Frontend browser behavior
```

Do not change a different layer simply because an error is visible at the
application boundary.

### Prefer Direct Verification

Examples:

```text
docker image inspect
verify-database.ps1
curl.exe
az ... show
generated dist inspection
```

Prefer checking the actual generated or deployed state over inferring it from
configuration alone.

### Preserve Verification Boundaries

Use precise terminology:

```text
Automated test
Local feature verification
Deployed backend feature verification
E2E scenario verification
```

An API request is not automatically an E2E scenario merely because it passes
through multiple infrastructure components.

E2E verification should represent a user or business scenario from entry point
to the intended outcome.

---

## Related Documentation

Architecture:

```text
docs/architecture.md
```

Deployment:

```text
docs/deployment.md
```

Local development:

```text
docs/local-development.md
```

Testing and verification:

```text
docs/testing.md
```

Step 4 data access:

```text
docs/step04-data-access.md
```

Authentication:

```text
docs/authentication.md
docs/authentication-setup.md
```
