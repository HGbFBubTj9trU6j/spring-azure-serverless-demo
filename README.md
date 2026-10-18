# spring-azure-serverless-demo

A hands-on project that incrementally evolves a Spring Boot web application into a serverless architecture on Microsoft Azure.

The current implementation combines:

- React and Vite
- Azure Static Web Apps
- Spring Boot
- Azure Container Apps
- Azure Container Registry
- Microsoft Entra ID authentication
- Infrastructure as Code with Bicep
- Cloud Native Buildpacks

The frontend is hosted on Azure Static Web Apps and communicates with a Spring Boot REST API running on Azure Container Apps.

> This repository is intended for learning, experimentation, and architecture validation. Review all settings before using the project in a production environment.

---

## Roadmap

### Completed

- [x] Step 1: Azure infrastructure provisioning with Bicep
- [x] Step 2: React frontend integration with Azure Static Web Apps
- [x] Step 3: Microsoft Entra ID authentication

### Planned

- [ ] Step 4: Data access
- [ ] Step 5: CI/CD
- [ ] Step 6: API authentication and authorization
- [ ] Step 7: Identity lifecycle management
- [ ] Step 8: Replace Static Web Apps with a Buildpacks-based frontend container as an alternative architecture

---

## Architecture

### Azure environment

```text
Browser
  │
  ▼
Azure Static Web Apps
  │
  ├── React + Vite
  │
  └── Microsoft Entra ID authentication
  │
  │ HTTPS / CORS
  ▼
Azure Container Apps
  │
  └── Spring Boot REST API
```

### Local development

```text
React + Vite
localhost:5173
  │
  ▼
Spring Boot
localhost:8080
```

During local development, the frontend uses the local backend when `VITE_API_BASE_URL` is not set.

For additional architectural details and design decisions, see docs/architecture.md.

---

## Repository Structure

```text
spring-azure-serverless-demo/
├── backend/
├── frontend/
├── config/
│   └── dev.psd1
├── infra/
│   ├── main.bicep
│   ├── dev.bicepparam
│   └── modules/
│       ├── container-apps-environment.bicep
│       ├── container-registry.bicep
│       ├── container-app-identity.bicep
│       ├── container-app.bicep
│       └── static-web-app.bicep
├── scripts/
│   ├── whatif-infra.ps1
│   ├── deploy-infra.ps1
│   ├── build-backend.ps1
│   ├── deploy-backend.ps1
│   ├── build-frontend.ps1
│   ├── deploy-frontend.ps1
│   ├── 41-deploy-identity.ps1
│   ├── 42-create-client-secret.ps1
│   ├── 43-configure-swa-auth.ps1
│   └── staticwebapp.config.template.json
├── docs/
│   ├── architecture.md
│   ├── authentication.md
│   ├── authentication-setup.md
│   ├── deployment.md
│   └── troubleshooting.md
└── swa-cli.config.json
```

Environment-specific settings used by the application build and deployment scripts are stored under config.

The default development environment uses:

config/dev.psd1

---

## Azure Infrastructure

Azure infrastructure is defined with Bicep under the `infra` directory.

The development environment consists of:

```text
Resource Group
├── Azure Container Registry
├── User Assigned Managed Identity
│   └── AcrPull role assignment
├── Azure Static Web Apps
└── Azure Container Apps Environment
```
The Azure Container App is deployed separately after the backend OCI image has been built and pushed to Azure Container Registry.

Its configuration remains managed with Bicep through infra/modules/container-app.bicep.

Azure Static Web Apps is deployed to East Asia because the service is not available in Japan East for the subscription and resource type used by this project.

The remaining development resources are deployed to Japan East.

---

## Prerequisites

The following tools are required:

- Azure CLI
- Bicep CLI
- Azure Container Apps CLI extension
- Java 21
- Maven Wrapper
- Node.js and npm
- Docker-compatible container runtime
- Azure Static Web Apps CLI
- Git
- PowerShell

Install Azure Static Web Apps CLI:

```powershell
npm install -g @azure/static-web-apps-cli
```

Verify the installation:

```powershell
swa --version
```

Verify that the container runtime is available:

```powershell
docker info
```

> This project does not require a Dockerfile for the backend. The backend OCI image is created with Spring Boot Buildpacks. A Docker-compatible runtime is still required to execute the Buildpacks build locally.

---

## Getting Started

The deployment sequence is:

```text
Provision shared Azure infrastructure
        │
        ▼
Build backend OCI image
        │
        ▼
Push image and deploy Container App
        │
        ▼
Build frontend
        │
        ▼
Deploy frontend
        │
        ▼
Configure Microsoft Entra ID authentication
        │
        ▼
Verify authentication and connectivity
```

For a more detailed deployment guide, see docs/deployment.md.

---

## Deployment Order

This solution spans two independent administrative boundaries:

```text
Tenant A
(Azure Subscription Tenant)
│
├─ Azure Static Web Apps
├─ Azure Container Apps
├─ Azure Container Registry
└─ Managed Identity

Tenant B
(Authentication Tenant)
│
├─ App Registration
└─ Service Principal
```
The Azure subscription and authentication tenant have independent lifecycles. The Azure resources can be rebuilt in another subscription while the existing App Registration in the authentication tenant is reused.

The Azure infrastructure must be provisioned before the authentication infrastructure because the Microsoft Entra ID application requires the Azure Static Web Apps hostname when configuring its redirect URI.

### Step 1: Deploy Azure Infrastructure

Sign in to the Azure subscription tenant and deploy the infrastructure.

```powershell
.\scripts\deploy-infra.ps1
```

This creates:

- Resource Group
- Azure Container Registry
- Azure Container Apps Environment
- User Assigned Managed Identity
- AcrPull role assignment
- Azure Static Web Apps

The Azure Container App is intentionally not created during infrastructure provisioning. It is deployed after the backend image has been built and pushed to Azure Container Registry.

### Step 2: Deploy the Application

#### Build and deploy the backend.

```powershell
.\scripts\build-backend.ps1
.\scripts\deploy-backend.ps1
```

By default, the backend scripts use the dev environment configuration from config/dev.psd1.

To use another environment configuration, specify the environment name:

```powershell
.\scripts\build-backend.ps1 -Environment prod
.\scripts\deploy-backend.ps1 -Environment prod
```

#### Build and deploy the frontend.

```powershell
.\scripts\build-frontend.ps1
.\scripts\deploy-frontend.ps1
```

At this stage:

- Azure Static Web Apps is available
- Azure Container Apps is available
- The application is deployed
- The SWA hostname can be determined

### Step 3: Configure Microsoft Entra ID Authentication

Authentication configuration spans two different Microsoft Entra ID tenants.

The identity resources are managed in the authentication tenant, while the Azure Static Web Apps application settings are configured in the Azure subscription tenant.

#### Obtain the Azure Static Web Apps hostname

Before switching to the authentication tenant, obtain the Azure Static Web Apps hostname.

```powershell
az staticwebapp show `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --query defaultHostname `
  --output tsv
```

Example output:

```text
<STATIC_WEB_APP_HOSTNAME>
```

#### Switch to the authentication tenant.

If necessary, sign in to the authentication tenant:

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

#### Create or update the App Registration

Run:

```powershell
.\scripts\41-deploy-identity.ps1 `
  -StaticWebAppHostname "<STATIC_WEB_APP_HOSTNAME>"
```

This creates or updates:
- App Registration
- Service Principal
- Redirect URI
- ID token configuration


The redirect URI uses the Azure Static Web Apps hostname:

```text
https://<STATIC_WEB_APP_HOSTNAME>/.auth/login/aad/callback
```
The existing App Registration is reused when possible.

#### Prepare the Client Secret

Run:

```powershell
.\scripts\42-create-client-secret.ps1
```
If no Client Secret exists, the script creates one.

If an existing credential is found, the script does not create another Client Secret by default.

Existing Client Secret values cannot be retrieved after creation.

When configuring a newly deployed Azure Static Web App, such as after rebuilding the Azure environment in another subscription, create an additional Client Secret:

```powershell
.\scripts\42-create-client-secret.ps1 -CreateNew
```
The existing credentials are preserved.

Store the newly created Client Secret only temporarily and use it immediately when configuring Azure Static Web Apps. Do not add it to the repository.

#### Switch back to the Azure subscription tenant

Sign in to the tenant that contains the target Azure subscription and select the target subscription.

Verify the active Azure CLI context:

```powershell
az login `
  --tenant <AZURE_SUBSCRIPTION_TENANT_ID>

az account set `
  --subscription <AZURE_SUBSCRIPTION_ID>

az account show `
  --query "{tenantId:tenantId,subscriptionId:id,subscriptionName:name}" `
  --output table
```

#### Configure Azure Static Web Apps authentication

Store the new Client Secret as a SecureString:

```powershell
$clientId = "<APPLICATION_CLIENT_ID>"

$clientSecret = Read-Host `
  "Enter the newly created Client Secret" `
  -AsSecureString
```

Configure Azure Static Web Apps:

```powershell
.\scripts\43-configure-swa-auth.ps1 `
  -ClientId $clientId `
  -ClientSecret $clientSecret
```
By default, the script loads the Azure Static Web Apps name and Resource Group from:

```text
config/dev.psd1
```
A different environment can be selected with:

```powershell
.\scripts\43-configure-swa-auth.ps1 `
  -Environment prod `
  -ClientId $clientId `
  -ClientSecret $clientSecret
```

The script verifies that:

- The target Azure Static Web App exists in the active subscription.
- The Application Client ID was configured.
- The Client Secret setting exists.

The Client Secret is not written to a file or displayed by the script.

### Step 4: Verify Authentication

Open the Azure Static Web Apps URL and verify:

- Registered external users can sign in
- Registered native tenant users can sign in
- Unregistered users are denied access
- Authentication information is available through `/.auth/me`

---

## Build the Bicep Template

Run the following command from the repository root:

```powershell
az bicep build `
  --file .\infra\main.bicep
```

This generates:

```text
infra/main.json
```

`main.json` is a generated ARM template and should not be committed to Git.

A warning similar to the following may be displayed:

```text
BCP081: Resource type does not have types available.
```

The project uses recent Azure Container Apps API versions:

```text
Microsoft.App/managedEnvironments@2026-07-01
Microsoft.App/containerApps@2026-07-01
```

If matching Bicep type information is not available, Bicep cannot perform full compile-time property validation. This warning does not necessarily prevent deployment.

---

## Preview Infrastructure Changes

Run an Azure deployment What-If operation before applying infrastructure changes:

```powershell
az deployment sub what-if `
  --name spring-azure-serverless-demo `
  --location japaneast `
  --parameters .\infra\dev.bicepparam
```

The following diagnostic may appear:

```text
NestedDeploymentShortCircuited
```
The infrastructure What-If operation covers the resources managed by infra/main.bicep.

The Azure Container App is deployed separately by deploy-backend.ps1 and is therefore outside the infrastructure What-If scope.

Azure may add service-managed properties to deployed resources. These properties can appear as modifications in later What-If results even when the Bicep-managed configuration has not changed.

---

## Deploy the Infrastructure

Run:

```powershell
.\scripts\deploy-infra.ps1
```

The script performs a subscription-scoped Bicep deployment because infra/main.bicep creates the Resource Group.

This deployment creates the shared Azure infrastructure required before application deployment.

The Azure Container App itself is deployed separately by deploy-backend.ps1.

---

## Local Development

### Start the Spring Boot Backend

```powershell
Push-Location .\backend

.\mvnw.cmd spring-boot:run

Pop-Location
```

The backend listens on:

```text
http://localhost:8080
```

Verify the API:

```powershell
Invoke-RestMethod `
  "http://localhost:8080/api/hello"
```

Expected PowerShell output:

```text
message
-------
hello
```

Verify the backend version endpoint:

```powershell
Invoke-RestMethod `
  "http://localhost:8080/api/version"
```

---

### Start the React Frontend

```powershell
Push-Location .\frontend

npm install
npm run dev

Pop-Location
```

The frontend development server listens on:

```text
http://localhost:5173
```

If `VITE_API_BASE_URL` is not supplied, the frontend uses the following local backend URL:

```text
http://localhost:8080
```

The Spring Boot CORS configuration permits requests from the local frontend origin:

```text
http://localhost:5173
```

It also permits Azure Static Web Apps origins matching:

```text
https://*.azurestaticapps.net
```

---

## Build the Backend

The backend image is built with Spring Boot Buildpacks through the Maven Wrapper.

```powershell
.\scripts\build-backend.ps1
```

By default, the script loads environment-specific settings from `config/dev.psd1`.

A different environment can be selected with:

```powershell
.\scripts\build-backend.ps1 -Environment prod
```

The build script:

1. Loads the selected environment configuration.
2. Gets the current Git commit hash.
3. Detects whether the working tree contains uncommitted changes.
4. Generates an image tag.
5. Runs a clean Spring Boot Buildpacks build.
6. Creates an OCI image in the local container runtime.

Example image tags:

```text
<registry>.azurecr.io/backend:abc1234
<registry>.azurecr.io/backend:abc1234-dirty
```

The `-dirty` suffix indicates that the image was built from a working tree containing uncommitted changes.

---

## Deploy the Backend

```powershell
.\scripts\deploy-backend.ps1
```

By default, the script loads environment-specific settings from `config/dev.psd1`.

A different environment can be selected with:

```powershell
.\scripts\deploy-backend.ps1 -Environment prod
```

The deployment script:

1. Loads the selected environment configuration.
2. Determines the image tag from the current Git state.
3. Signs in to Azure Container Registry.
4. Pushes the previously built OCI image.
5. Resolves the Container Apps Environment and Managed Identity resource IDs.
6. Deploys the Azure Container App using `infra/modules/container-app.bicep`.
7. Displays the deployed Container App FQDN and image.

The same Bicep deployment path is used for both the initial Container App creation and subsequent updates.

Verify the deployed image:

```powershell
az containerapp show `
  --name spring-azure-serverless-dev-ca `
  --resource-group spring-azure-serverless-demo-rg `
  --query properties.template.containers[0].image `
  --output tsv
```

---

## Verify the Container App

List the Container Apps:

```powershell
az containerapp list `
  --resource-group spring-azure-serverless-demo-rg `
  --query "[].{name:name,state:properties.provisioningState,fqdn:properties.configuration.ingress.fqdn}" `
  --output table
```

Get the Container App FQDN:

```powershell
$fqdn = az containerapp show `
  --name spring-azure-serverless-dev-ca `
  --resource-group spring-azure-serverless-demo-rg `
  --query properties.configuration.ingress.fqdn `
  --output tsv
```

Verify the Spring Boot endpoint:

```powershell
Invoke-RestMethod `
  "https://$fqdn/api/hello"
```

Expected PowerShell output:

```text
message
-------
hello
```

Verify the backend version endpoint:

```powershell
Invoke-RestMethod `
  "https://$fqdn/api/version"
```

---

## Build the Frontend

```powershell
.\scripts\build-frontend.ps1
```

The frontend build script:

1. Gets the Container App FQDN from Azure.
2. Sets `VITE_API_BASE_URL` for the Vite build.
3. Creates build-version metadata from the current Git commit.
4. Adds the `-dirty` suffix when the working tree contains uncommitted changes.
5. Generates the production authentication configuration from its template.
6. Runs the Vite production build.

The Container App API base URL is obtained from Azure instead of being stored as a production URL in source control.

The build output is generated under:

```text
frontend/dist
```

The generated authentication configuration is placed under:

```text
frontend/dist/staticwebapp.config.json
```

Do not manually edit files under `frontend/dist`. The directory contains generated build output.

---

## Configure Microsoft Entra ID Authentication

Authentication resources are deployed separately from the Azure infrastructure because they belong to a different Microsoft Entra ID tenant. See the Deployment Order section above and `docs/authentication-setup.md` for provisioning details.

The project uses a custom Microsoft Entra ID provider for Azure Static Web Apps.

The source template is stored at:

```text
scripts/staticwebapp.config.template.json
```

A generated configuration is written to:

```text
frontend/dist/staticwebapp.config.json
```

Tenant-specific authentication values are supplied during the authentication configuration and build processes and should not be hard-coded in committed generated files.

The Azure Static Web Apps resource must have application settings corresponding to the setting names referenced by the generated configuration.

Sensitive values must not be committed to source control.

Examples of values that must remain outside the repository include:

- Client secrets
- Deployment tokens
- Tenant-specific secret values
- Production credentials

For authentication architecture, validation scenarios, and current limitations, see docs/authentication.md.

---

## Configure the Static Web Apps Deployment Token

Get the deployment token:

```powershell
$token = az staticwebapp secrets list `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --query properties.apiKey `
  --output tsv
```

Store the token as a Windows user environment variable:

```powershell
[System.Environment]::SetEnvironmentVariable(
  "SWA_DEPLOYMENT_TOKEN",
  $token,
  "User"
)
```

Open a new PowerShell session after setting the user environment variable.

Verify that the variable is available without printing its value:

```powershell
if ($env:SWA_DEPLOYMENT_TOKEN) {
  Write-Host "SWA deployment token is configured."
}
else {
  Write-Host "SWA deployment token is not configured."
}
```

Do not store the deployment token in the repository.

---

## Azure Static Web Apps CLI Configuration

The `swa-cli.config.json` file contains the project configuration used by Azure Static Web Apps CLI.

Review the resolved configuration:

```powershell
swa --print-config
```

The project uses:

```text
App location: frontend
Output location: dist
App build command: npm run build
App development server URL: http://localhost:5173
```

---

## Deploy the Frontend to Production

```powershell
.\scripts\deploy-frontend.ps1
```

The deployment script explicitly specifies:

```text
--env production
```

This deploys the contents of `frontend/dist` to the Azure Static Web Apps production environment.

Equivalent command:

```powershell
Push-Location .\frontend

swa deploy `
  .\dist `
  --env production `
  --deployment-token $env:SWA_DEPLOYMENT_TOKEN

Pop-Location
```

If `--env production` is omitted, Azure Static Web Apps CLI uses its resolved environment configuration. In this project, that can result in deployment to the `preview` environment.

---

## Verify Static Web Apps Environments

```powershell
az staticwebapp environment list `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --output table
```

The environment named `default` is the production environment.

The environment named `preview` is the preview environment.

After a successful production deployment, the `default` environment should have the following status:

```text
Ready
```

---

## Verify the Deployed Application

Get the Azure Static Web Apps production hostname:

```powershell
$swaHostname = az staticwebapp show `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --query defaultHostname `
  --output tsv

Write-Host "https://$swaHostname"
```

Open the displayed URL in a browser.

Verify that:

- Unauthenticated access redirects to Microsoft Entra ID authentication.
- A registered user can sign in.
- The React page is displayed after authentication.
- The frontend build version is displayed.
- The backend build version can be retrieved.
- The API call returns `hello`.
- Logout completes successfully.

---

## Microsoft Entra ID Authentication

Azure Static Web Apps is integrated with Microsoft Entra ID and requires authentication before the application can be accessed.

A dedicated Microsoft Entra ID tenant is used for:

- App Registration
- OpenID Connect configuration
- Token issuance
- User registration
- Access control

### Authentication Scenarios

| User type | Registered in the authentication tenant | Expected result | Verified |
| --- | ---: | --- | ---: |
| External tenant user | Yes | Access granted | Yes |
| Native authentication tenant user | Yes | Access granted | Yes |
| Unregistered user | No | Access denied | Yes |

The validation confirms that access is determined by registration in the authentication tenant rather than by the user's email domain.

### Identity Verification

After a successful sign-in, open:

```text
https://<STATIC_WEB_APP_HOSTNAME>/.auth/me
```

The endpoint was used to verify:

- Authenticated user information
- Authentication provider
- Token audience
- Token issuer
- User roles
- Successful identity propagation to Azure Static Web Apps

No real user details, tenant IDs, client IDs, object IDs, or token values are included in this public repository.

### Step 3 Exit Criteria

- [x] Azure Static Web Apps integrated with Microsoft Entra ID
- [x] Login verified
- [x] Logout verified
- [x] Post-login redirection verified
- [x] Authenticated identity retrieved from `/.auth/me`
- [x] Registered external user granted access
- [x] Registered native tenant user granted access
- [x] Unregistered user denied access
- [x] Access control based on authentication-tenant registration verified

### Current Authentication Boundary

Authentication is currently enforced at the Azure Static Web Apps layer.

The backend API is exposed through Azure Container Apps and does not yet independently validate the authenticated user's token.

API authentication and authorization are planned as a separate step.

For full details, see docs/authentication.md.

To reproduce the Microsoft Entra ID resources and SWA application settings, see docs/authentication-setup.md.

---

## Security Notes

Before publishing or deploying this repository, verify that it does not contain:

- Real tenant IDs
- Client secrets
- Azure Static Web Apps deployment tokens
- Personal or company email addresses
- Access tokens
- Refresh tokens
- Real `/.auth/me` responses
- Generated files containing environment-specific values
- Local environment files
- Azure credentials
- Private certificates or keys

Keep secret values outside Git.

Suitable storage options include:

- Azure Static Web Apps application settings
- GitHub Actions secrets
- Azure Key Vault
- Local user environment variables

The public repository may contain setting names and templates, but it must not contain their secret values.

---

## Azure CLI Defaults

Azure CLI defaults can affect commands that do not explicitly specify a Resource Group.

Check configured defaults:

```powershell
az configure --list-defaults
```

This project explicitly specifies the Resource Group where practical to reduce dependence on local Azure CLI configuration.

---

## Known Diagnostics

The following diagnostics were encountered during implementation:

- Bicep `BCP081` warnings for recent Azure resource API versions
- `NestedDeploymentShortCircuited` during What-If evaluation
- Azure Static Web Apps deployment targeting Preview when Production was not explicitly specified
- Microsoft Entra ID login failure when the required ID-token setting was not enabled
- `401 Unauthorized` before completing the required sign-in flow
- Container runtime connectivity issues during Buildpacks image creation

See docs/troubleshooting.md for symptoms, causes, verification steps, and resolutions.

---

## Documentation

- docs/architecture.md
- docs/authentication.md
- docs/authentication-setup.md
- docs/deployment.md
- docs/troubleshooting.md

---

## Next Steps

### Step 4: Data Access

The next step adds persistent data access through the Spring Boot backend.

```text
React
  │
  ▼
Spring Boot REST API
  │
  ▼
Data Store
```

Candidate services include:

- Azure SQL Database
- Azure Cosmos DB

### Later Steps

Future work includes:

- CI/CD with GitHub Actions
- SWA-to-ACA token propagation
- JWT validation in Spring Boot
- Spring Security integration
- API-level authorization
- Role-based access control
- Identity lifecycle management
- User invitation and onboarding
- Self-service sign-up
- Access reviews
- Buildpacks-based frontend containerization
- An alternative architecture that replaces Azure Static Web Apps with Azure Container Apps

---

## License

No license has been declared yet.

Until a license is added, standard copyright rules apply. If reuse and contribution are intended, add an appropriate open-source license before publishing or accepting external contributions.