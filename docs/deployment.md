# Deployment Guide

This document describes how to provision Azure resources and deploy the application.

---

## Deployment Overview

The deployment process consists of:

1. Provision Azure infrastructure
2. Build the backend container image
3. Deploy the backend to Azure Container Apps
4. Build the frontend
5. Deploy the frontend to Azure Static Web Apps

```text
Infrastructure
      │
      ▼
Backend Build
      │
      ▼
Backend Deployment
      │
      ▼
Frontend Build
      │
      ▼
Frontend Deployment
```

---

## Prerequisites

The following tools are required:

- Azure CLI
- Bicep CLI
- Azure Container Apps CLI Extension
- Java 21
- Maven Wrapper
- Node.js
- npm
- Docker-compatible container runtime
- Azure Static Web Apps CLI
- Git

### Verify Azure CLI

```powershell
az version
```

### Verify Bicep

```powershell
az bicep version
```

### Verify Azure Static Web Apps CLI

```powershell
swa --version
```

---

## Infrastructure Provisioning

Infrastructure is defined using Bicep and stored under:

```text
infra/
```

### Build the Bicep Template

```powershell
az bicep build `
  --file .\infra\main.bicep
```

Expected output:

```text
infra/main.json
```

This ARM template is generated and should not be committed to source control.

---

### Preview Infrastructure Changes

Run a What-If operation before deployment:

```powershell
az deployment sub what-if `
  --name spring-azure-serverless-demo `
  --location japaneast `
  --parameters .\infra\dev.bicepparam
```

This step allows infrastructure changes to be reviewed before deployment.

---

### Deploy Infrastructure

```powershell
az deployment sub create `
  --name spring-azure-serverless-demo `
  --location japaneast `
  --parameters .\infra\dev.bicepparam
```

The deployment is subscription-scoped because the Resource Group is created by the Bicep template.

---

## Backend Deployment

### Build Backend Image

The backend is packaged as an OCI container image using Spring Boot Buildpacks.

```powershell
.\scripts\build-backend.ps1
```

The build process:

1. Retrieves the current Git commit hash
2. Detects uncommitted changes
3. Generates an image tag
4. Builds the application using Buildpacks
5. Produces a local OCI image

Example image tags:

```text
backend:abc1234
backend:abc1234-dirty
```

The `-dirty` suffix indicates that uncommitted source changes were present during the build.

---

### Deploy Backend

```powershell
.\scripts\deploy-backend.ps1
```

The deployment process:

1. Authenticates with Azure Container Registry
2. Pushes the image
3. Updates Azure Container Apps
4. Creates a new revision when required

---

### Verify Backend Deployment

Retrieve the backend endpoint and verify the API.

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

Verify application version:

```powershell
Invoke-RestMethod `
  "https://<CONTAINER_APP_FQDN>/api/version"
```

---

## Frontend Deployment

### Build Frontend

```powershell
.\scripts\build-frontend.ps1
```

The build process:

1. Retrieves the backend endpoint
2. Sets the API base URL
3. Generates build version metadata
4. Executes a Vite production build

Output directory:

```text
frontend/dist
```

---

## Configure SWA Deployment Token

Retrieve the deployment token:

```powershell
$token = az staticwebapp secrets list `
  --name <STATIC_WEB_APP_NAME> `
  --resource-group <RESOURCE_GROUP> `
  --query properties.apiKey `
  --output tsv
```

Store the token as a user environment variable:

```powershell
[System.Environment]::SetEnvironmentVariable(
  "SWA_DEPLOYMENT_TOKEN",
  $token,
  "User"
)
```

Open a new PowerShell session after setting the variable.

Verify configuration:

```powershell
if ($env:SWA_DEPLOYMENT_TOKEN) {
    Write-Host "SWA deployment token is configured."
}
else {
    Write-Host "SWA deployment token is not configured."
}
```

Never commit deployment tokens to source control.

---

### Deploy Frontend

```powershell
.\scripts\deploy-frontend.ps1
```

The deployment script publishes the contents of:

```text
frontend/dist
```

to the production environment of Azure Static Web Apps.

Equivalent deployment command:

```powershell
Push-Location .\frontend

swa deploy `
  .\dist `
  --env production `
  --deployment-token $env:SWA_DEPLOYMENT_TOKEN

Pop-Location
```

---

## Verify Frontend Deployment

Retrieve the production hostname:

```powershell
$swaHostname = az staticwebapp show `
  --name <STATIC_WEB_APP_NAME> `
  --resource-group <RESOURCE_GROUP> `
  --query defaultHostname `
  --output tsv
```

Open:

```text
https://<STATIC_WEB_APP_HOSTNAME>
```

Verify:

- Application loads successfully
- Frontend version is displayed
- Backend connectivity works
- API requests succeed

---

## Deployment Validation Checklist

### Infrastructure

- [ ] Resource Group deployed
- [ ] Azure Container Registry deployed
- [ ] Azure Container Apps Environment deployed
- [ ] Azure Container App deployed
- [ ] Azure Static Web Apps deployed

### Backend

- [ ] Image built successfully
- [ ] Image pushed to ACR
- [ ] Container App updated
- [ ] `/api/hello` returns expected response
- [ ] `/api/version` returns expected response

### Frontend

- [ ] Build completed successfully
- [ ] SWA deployment completed successfully
- [ ] Application loads in browser
- [ ] Frontend can call backend API

### Authentication

- [ ] Login succeeds for registered users
- [ ] Unregistered users are denied access
- [ ] Logout succeeds
- [ ] `/.auth/me` returns authenticated user information

---

## Troubleshooting

### Bicep Type Warnings

Warnings similar to the following may appear:

```text
BCP081: Resource type does not have types available
```

This typically occurs when Bicep type definitions are not yet available for newer Azure resource API versions.

The warning does not necessarily prevent deployment.

---

### What-If Validation Warnings

The following message may appear during What-If operations:

```text
NestedDeploymentShortCircuited
```

This can occur when dependent resource outputs are evaluated during deployment.

The warning does not automatically indicate deployment failure.

---

### SWA Deployment Goes to Preview

If the deployment appears in the Preview environment rather than Production, verify that:

```text
--env production
```

is specified during deployment.

---

## Related Documents

- `README.md`
- `docs/architecture.md`
- `docs/authentication.md`