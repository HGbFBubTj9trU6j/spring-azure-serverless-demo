# Troubleshooting

This document records verified troubleshooting scenarios for `spring-azure-serverless-demo`. It focuses on symptoms, checks, confirmed causes, and resolutions for the current implementation.

For design and setup details, see:

```text
docs/architecture.md
docs/deployment.md
docs/authentication.md
docs/authentication-setup.md
docs/step05-entra-id-authentication-authorization.md
docs/step06-cicd.md
```

---

## Azure CLI Context Is Incorrect

### Symptom

Azure commands cannot find a resource that is known to exist, or Microsoft Entra ID commands appear to query the wrong tenant.

### Check

```powershell
az account show `
  --query "{TenantId:tenantId,Subscription:name,SubscriptionId:id}" `
  -o table
```

A Microsoft Entra tenant can be accessible without containing an Azure subscription. In that case Azure CLI can show a tenant-level account such as `N/A (tenant level account)`.

### Resolution

Use the tenant and subscription that own the Azure resources before running resource-management commands:

```powershell
az login --tenant <AZURE_RESOURCE_TENANT_ID>
az account set --subscription <AZURE_SUBSCRIPTION_ID>
```

For identity-only work in a tenant without a subscription:

```powershell
az login --tenant <IDENTITY_TENANT_ID> --allow-no-subscription
```

Always verify the active context before changing Azure resources or App Registrations.

---

## Bicep Warning: BCP081

### Symptom

`az bicep build` reports a warning similar to:

```text
BCP081: Resource type does not have types available.
```

### Cause

A recent Azure resource API version can be available before matching Bicep type information is available locally.

### Resolution

If the template still builds successfully, treat this as a warning rather than a deployment failure. Verify the actual Azure deployment separately.

---

## What-If Warning: NestedDeploymentShortCircuited

### Symptom

Azure deployment What-If reports:

```text
NestedDeploymentShortCircuited
```

### Interpretation

Some nested deployment values depend on module outputs that cannot be fully resolved during What-If evaluation.

### Resolution

Review the full What-If result. Distinguish intended `Create`, `Modify`, and `Delete` operations from diagnostic output. Do not apply unrelated changes merely to test a single infrastructure or RBAC modification.

---

## GitHub Actions Cannot Read Azure Static Web Apps

### Symptom

`Verify frontend deployment` fails while resolving the Static Web Apps hostname and Azure CLI reports:

```text
AuthorizationFailed
Microsoft.Web/staticSites/read
```

### Cause

GitHub Actions authenticated successfully to Azure through OIDC, but the GitHub Actions User Assigned Managed Identity did not have permission to read the target Static Web App.

Authentication success does not imply authorization to a resource.

### Check

Confirm that Azure CLI is using the subscription that contains the application resources. Then inspect the role assignments for the GitHub Actions Managed Identity.

The intended resource-scoped permissions are:

```text
Azure Container Registry  -> AcrPush
Azure Container App       -> Container Apps Contributor
Azure Static Web App      -> Reader
```

### Resolution

The Static Web App `Reader` role is managed through:

```text
infra/modules/github-actions-static-web-app-role.bicep
```

It is scoped to the individual Static Web App and allows the workflow to run `az staticwebapp show` and retrieve `defaultHostname`.

After the initial Container App exists, configure its GitHub Actions permission with:

```powershell
./scripts/setup-github-actions.ps1
```

Do not work around this error by hardcoding the generated `azurestaticapps.net` hostname in the workflow.

---

## ACR or Container App Authorization Fails in GitHub Actions

### Symptom

OIDC login succeeds, but image push or backend deployment fails with an Azure authorization error.

### Check

Verify the resource-scoped roles for the GitHub Actions Managed Identity:

```text
ACR             -> AcrPush
Container App   -> Container Apps Contributor
```

`AcrPush` is integrated with the shared infrastructure deployment. `Container Apps Contributor` is configured after the initial Container App deployment by `scripts/setup-github-actions.ps1`.

Also confirm that `GithubActionsIdentityName`, `AcrName`, `ContainerAppName`, and `ResourceGroup` in `config/dev.psd1` identify the intended environment.

---

## React / MSAL Sign-In Fails

### Symptom

The React application does not complete Microsoft Entra ID sign-in, or MSAL reports an authority, redirect, or application configuration error.

### Check

Verify:

- `VITE_ENTRA_TENANT_ID`
- `VITE_ENTRA_CLIENT_ID`
- `VITE_API_SCOPE`
- The React SPA App Registration
- Local and deployed SPA redirect URIs
- Delegated permission to the backend API `access_as_user` scope

### Resolution

Correct the SPA App Registration or build configuration and rebuild the frontend.

Azure Static Web Apps hosts the frontend but is not the authentication boundary. The current application does not use `/.auth/me`, `/.auth/login/aad`, or an Azure Static Web Apps authentication Client Secret for user authentication.

---

## Protected Backend API Returns 401 Unauthorized

### Symptom

A direct request to a protected Azure Container Apps API returns:

```text
401 Unauthorized
```

### Interpretation

This is expected when the request does not contain a valid backend API bearer token. Spring Security independently protects the API.

### Check

Confirm that the React application can acquire an API access token through MSAL and that protected requests include:

```text
Authorization: Bearer <access-token>
```

If a token is already present, verify:

- Backend `ENTRA_TENANT_ID`
- Microsoft Entra issuer
- Backend API audience
- `access_as_user`
- Token expiration

Do not treat an unauthenticated `401` as evidence that the Container App deployment failed.

---

## Backend API Returns 403 Forbidden

### Symptom

The user is authenticated, but an administrative Fortune request returns:

```text
403 Forbidden
```

### Interpretation

Keep authentication and authorization separate. A `403` can indicate that the authenticated user lacks the required authorization.

### Check

For Fortune Management operations, confirm that the access token contains the backend API app role:

```text
Fortune.Admin
```

Frontend UI visibility does not replace backend authorization.

---

## Backend API Is Not Reachable

### Symptom

The frontend loads, but API requests fail before authentication or application behavior can be evaluated.

### Check

Verify:

- Container App deployment completed successfully
- External ingress is enabled
- The configured backend FQDN is correct
- Frontend `VITE_API_BASE_URL` points to the intended backend

When calling a protected endpoint directly, remember that `401 Unauthorized` can confirm that the endpoint and Spring Security boundary are reachable even though the request was not authenticated.

---

## Azure SQL Connection Fails

### Symptom

The application cannot retrieve or manage Fortune data through Azure SQL.

### First Check

Verify the database independently:

```powershell
./scripts/verify-database.ps1
```

This should confirm database connectivity, `dbo.fortunes`, the Managed Identity database principal, and expected object-level permissions.

### Isolation

If local execution with the `database` profile works while the deployed application fails, investigate the Azure-specific Managed Identity and deployment path before changing SQL statements or permissions.

---

## Managed Identity Has No Fixed Database Role

### Symptom

Database verification shows no broad fixed database role for the application Managed Identity.

### Interpretation

This is expected for the current least-privilege design.

The Managed Identity should have object-level grants on:

```text
dbo.fortunes
```

for:

```text
SELECT
INSERT
DELETE
```

Use `scripts/verify-database.ps1` to verify the effective grants.

---

## Container Image Build Fails

### Symptom

`scripts/build-backend.ps1` fails while creating the backend OCI image.

### Check

The Spring Boot Buildpacks build requires a Docker-compatible runtime:

```powershell
docker info
```

The project can use Rancher Desktop as the local Docker-compatible runtime.

---

## Buildpacks Fails with `exec format error`

### Symptom

The Buildpacks lifecycle fails with an architecture error.

### Check

Compare the Docker server architecture with the builder image platform.

The backend build pins:

```text
paketobuildpacks/builder-noble-java-tiny:0.0.197
```

and targets:

```text
linux/amd64
```

Do not replace the builder solely to make the build pass without checking platform and Spring Boot compatibility.

---

## Azure Container Apps API Returns HTTP 500

### Symptom

A deployed API operation returns `500 Internal Server Error`.

### Isolation Strategy

1. Reproduce the equivalent operation locally with the same application profile where practical.
2. Verify an existing deployed API operation.
3. Compare the failing API operation.
4. Separate application code, SQL behavior, Managed Identity, authentication, and deployment-specific behavior.

Do not modify SQL permissions or application code solely because an HTTP 500 was observed at the application boundary.

---

## Azure Container Apps Logs Fail with `eventStreamEndpoint`

### Symptom

`az containerapp logs show` fails with an `eventStreamEndpoint` error.

### Resolution

Treat the Azure CLI log-stream failure separately from the application failure. Identify the active revision and replica and inspect the Container Apps Environment logging configuration. When deployed logs are unavailable, local reproduction can help isolate application behavior from the Azure-specific execution path.

---

## `VITE_API_BASE_URL` Points to the Wrong Backend

### Symptom

A local production preview connects to the deployed Container App rather than the intended local backend.

### Check

Inspect the current PowerShell environment:

```powershell
Get-ChildItem Env:VITE_API_BASE_URL -ErrorAction SilentlyContinue
```

A previous build can leave the environment variable set in the current shell.

### Resolution

Remove the stale value when appropriate, rebuild, and inspect the generated frontend artifact rather than inferring the embedded endpoint from browser behavior.

---

## `npm run preview` Is Blocked by CORS

The Vite development server and preview server use different local origins. The backend CORS configuration must permit the intended local origins.

CORS is a browser access-control mechanism. It must not be used as a substitute for API authentication or authorization.

---

## `swa` Command Is Not Recognized

The normal frontend deployment script invokes Azure Static Web Apps CLI through:

```text
npx @azure/static-web-apps-cli
```

A globally installed `swa` command is not required. Verify that `SWA_DEPLOYMENT_TOKEN` is configured before deployment.

---

## Frontend Deploys to Preview Instead of Production

### Symptom

The deployment succeeds but the production site does not contain the expected application version.

### Resolution

The deployment must explicitly target the production Static Web Apps environment. Verify the environments with Azure CLI and confirm that the production environment serves the expected version.

---

## Frontend Deployment Verification Does Not Match GitHub SHA

### Symptom

The deployment command succeeds, but frontend verification repeatedly reports a different version.

### Check

The workflow resolves the Static Web Apps `defaultHostname` dynamically and retrieves:

```text
/version.json
```

The `version` value must match `${{ github.sha }}`.

A successful deployment command alone does not prove that the intended frontend version is already being served.

---

## Fortune Management Returns HTTP 400

Check the JSON request body and confirm that the Fortune message is not blank. When using `curl.exe` from PowerShell, avoid unnecessary backslash escaping inside a single-quoted JSON string.

---

## Vitest Times Out Before Running Tests

### Symptom

Vitest spends a long time starting workers and reports no discovered tests.

### Isolation

First distinguish a test-runner startup problem from an assertion failure. If needed, compare worker pool configurations such as `forks` and reduce workers for diagnosis before modifying application code.

---

## FortuneManagement Test Fails with `fortunes.map Is Not a Function`

### Cause

A global fetch mock intended for random Fortune retrieval can accidentally be reused by the Fortune Management request, which expects an array.

### Resolution

Keep the test responsibilities separate. Test random Fortune behavior in the application test and Fortune Management behavior in its own component test. Do not create an application-scale fetch simulator merely to reproduce implementation details in unit tests.

---

## Spring Boot Test Context Fails with the `resource` Profile

Database-only Fortune Management components must not be created when the `resource` profile is active. Tests for management controllers should activate the `database` profile and mock the required service dependency.

---

## Verification Boundaries

Use precise terminology when isolating failures:

```text
Automated test
Local feature verification
Deployed backend feature verification
End-to-end scenario verification
```

A direct API GET, POST, or DELETE is deployed backend feature verification. It is not automatically an E2E scenario.

The Fortune Management E2E scenario starts from the deployed frontend and verifies that the signed-in user can complete the intended workflow through the backend and database.

---

## Diagnostic Principles

### Verify the Layer That Failed

Separate:

```text
Source code
Build
Local runtime
Cloud deployment
User authentication
API authorization
CI/CD identity and RBAC
Database identity
Database authorization
Frontend browser behavior
```

Do not change another layer merely because the error becomes visible at the application boundary.

### Prefer Direct Verification

Useful checks include:

```text
docker image inspect
scripts/verify-database.ps1
scripts/verify-backend-deployment.ps1
scripts/verify-frontend-deployment.ps1
curl.exe
az ... show
generated frontend artifact inspection
```

Prefer checking the actual generated or deployed state rather than inferring it from configuration alone.

---

## Related Documentation

```text
docs/architecture.md
docs/deployment.md
docs/authentication.md
docs/authentication-setup.md
docs/step04-data-access.md
docs/step05-entra-id-authentication-authorization.md
docs/step06-cicd.md
```
