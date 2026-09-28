# spring-azure-serverless-demo

Spring Boot の Web アプリを Azure のサーバーレス構成で育てていく検証プロジェクトです。

現在は、React フロントエンドを Azure Static Web Apps に配置し、Azure Container Apps Express 上の Spring Boot バックエンドと連携する構成になっています。

## Architecture

```text
Browser
  |
  v
React + Vite
  |
  v
Azure Static Web Apps
  |
  | HTTPS / CORS
  v
Azure Container Apps
  |
  v
Spring Boot REST API
```

ローカル開発時は、次の構成になります。

```text
React + Vite
http://localhost:5173
  |
  v
Spring Boot
http://localhost:8080
```

## Repository structure

```text
spring-azure-serverless-demo/
├── backend/
├── frontend/
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
│   ├── build-backend.ps1
│   ├── deploy-backend.ps1
│   ├── build-frontend.ps1
│   └── deploy-frontend.ps1
└── swa-cli.config.json
```

## Azure infrastructure

Azure infrastructure is defined with Bicep under the `infra` directory.

The development environment consists of:

```text
Resource Group
├── Azure Container Registry
├── User Assigned Managed Identity
│   └── AcrPull
├── Azure Static Web App
└── Azure Container Apps Express Environment
    └── Container App
        └── External HTTPS Ingress
```

Azure Static Web Apps is deployed to the East Asia region because the service is not available in Japan East for this subscription and resource type.

The remaining development resources are deployed to Japan East.

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

Install Azure Static Web Apps CLI:

```powershell
npm install -g @azure/static-web-apps-cli
```

Verify the installation:

```powershell
swa --version
```

## Build the Bicep template

Run from the repository root:

```powershell
az bicep build `
  --file .\infra\main.bicep
```

This generates `infra/main.json`.

`main.json` is a generated ARM template and is not committed to Git.

The following warning may currently be displayed:

```text
BCP081: Resource type does not have types available.
```

The project currently uses:

```text
Microsoft.App/managedEnvironments@2026-07-01
Microsoft.App/containerApps@2026-07-01
```

Bicep may not yet have type information for these API versions. The warning does not prevent deployment, but Bicep cannot perform full compile-time property validation.

## Preview infrastructure changes

Run a What-If operation before deployment:

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

The Container App module receives outputs from other modules, including the Container Apps Environment ID, ACR login server, and Managed Identity ID.

These values may require ARM `reference()` evaluation. What-If cannot always fully evaluate these values before deployment and may therefore skip validation of the nested Container App deployment.

This diagnostic does not by itself indicate that the deployment will fail.

Azure may also add service-managed properties to deployed resources. These properties can appear as modifications in later What-If results even when the Bicep-managed settings have not changed.

## Deploy the infrastructure

```powershell
az deployment sub create `
  --name spring-azure-serverless-demo `
  --location japaneast `
  --parameters .\infra\dev.bicepparam
```

The deployment is subscription-scoped because `main.bicep` creates the Resource Group itself.

## Local development

### Start the Spring Boot backend

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

Expected response:

```text
message
-------
hello
```

### Start the React frontend

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

If `VITE_API_BASE_URL` is not supplied at build time, the frontend uses the following local backend URL:

```text
http://localhost:8080
```

The Spring Boot CORS configuration permits requests from:

```text
http://localhost:5173
```

and Azure Static Web Apps origins matching:

```text
https://*.azurestaticapps.net
```

## Build the backend

The backend image is built with Spring Boot Buildpacks through the Maven Wrapper.

```powershell
.\scripts\build-backend.ps1
```

The build script:

1. Gets the current Git commit hash.
2. Detects whether the working tree contains uncommitted changes.
3. Generates the image tag.
4. Runs a clean Spring Boot Buildpacks build.
5. Creates the OCI image locally.

Example image tags:

```text
backend:abc1234
backend:abc1234-dirty
```

The `-dirty` suffix indicates that the image was built from a working tree containing uncommitted changes.

## Deploy the backend

```powershell
.\scripts\deploy-backend.ps1
```

The deployment script:

1. Logs in to Azure Container Registry.
2. Pushes the previously built OCI image.
3. Updates the Azure Container App to use that image.
4. Creates a new Container App revision when the image reference changes.

Verify the deployed image:

```powershell
az containerapp show `
  --name spring-azure-serverless-dev-ca `
  --resource-group spring-azure-serverless-demo-rg `
  --query properties.template.containers[0].image `
  --output tsv
```

## Build the frontend

```powershell
.\scripts\build-frontend.ps1
```

The frontend build script:

1. Gets the Container App FQDN from Azure.
2. Sets `VITE_API_BASE_URL` for the Vite build.
3. Creates build-version metadata from the current Git commit.
4. Adds the `-dirty` suffix when the working tree has uncommitted changes.
5. Runs the Vite production build.

The Container App API base URL is therefore obtained from Azure instead of being stored as a production URL in the source code.

The build output is generated under:

```text
frontend/dist
```

## Configure the Static Web Apps deployment token

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

Verify that the variable is available without printing the full secret:

```powershell
if ($env:SWA_DEPLOYMENT_TOKEN) {
  Write-Host "SWA deployment token is configured."
}
else {
  Write-Host "SWA deployment token is not configured."
}
```

Do not store the deployment token in the repository.

## Azure Static Web Apps CLI configuration

The `swa-cli.config.json` file contains the project configuration used by Azure Static Web Apps CLI.

Review the resolved configuration:

```powershell
swa --print-config
```

The project currently uses:

```text
App location: frontend
Output location: dist
App build command: npm run build
App development server URL: http://localhost:5173
```

## Deploy the frontend to Production

```powershell
.\scripts\deploy-frontend.ps1
```

The deployment script explicitly specifies:

```text
--env production
```

This deploys the contents of `frontend/dist` to the Static Web Apps production environment.

Equivalent command:

```powershell
Push-Location .\frontend

swa deploy `
  .\dist `
  --env production `
  --deployment-token $env:SWA_DEPLOYMENT_TOKEN

Pop-Location
```

If `--env production` is omitted, SWA CLI uses its resolved environment setting. In the current CLI configuration, the default resolved environment is `preview`.

## Verify Static Web Apps environments

```powershell
az staticwebapp environment list `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --output table
```

The environment named `default` is the Production environment.

The environment named `preview` is the Preview environment.

After a successful Production deployment, the `default` environment should have the following status:

```text
Ready
```

## Verify the deployed application

Get the Static Web App production hostname:

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

- The React page is displayed.
- The frontend build version is displayed.
- The backend build version can be retrieved.
- The API call returns `hello`.

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

Expected response:

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

## Development resource names

| Resource | Name | Region |
| --- | --- | --- |
| Resource Group | `spring-azure-serverless-demo-rg` | Japan East |
| Container Registry | `springazureserverlessdemoacr` | Japan East |
| Container Apps Environment | `spring-azure-serverless-demo-dev-cae` | Japan East |
| Managed Identity | `spring-azure-serverless-demo-dev-id` | Japan East |
| Container App | `spring-azure-serverless-dev-ca` | Japan East |
| Static Web App | `spring-azure-serverless-demo-dev-swa` | East Asia |

The Container App name is shorter than the other resource names because Azure Container Apps limits application names to 32 characters.

## Azure CLI defaults

Azure CLI defaults can affect commands that do not explicitly specify a Resource Group.

Check configured defaults with:

```powershell
az configure --list-defaults
```

This project explicitly specifies the Resource Group where practical to avoid dependence on local Azure CLI defaults.