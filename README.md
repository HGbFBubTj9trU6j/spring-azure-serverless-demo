# spring-azure-serverless-demo

A hands-on project that incrementally evolves a Spring Boot web application into a serverless architecture on Microsoft Azure.

The current implementation combines:

- React and Vite
- Azure Static Web Apps
- Spring Boot
- Azure Container Apps
- Azure Container Registry
- Azure SQL Database
- Microsoft Entra ID authentication
- User Assigned Managed Identity
- Infrastructure as Code with Bicep
- Cloud Native Buildpacks

The React frontend is hosted on Azure Static Web Apps and communicates with a Spring Boot REST API running on Azure Container Apps.

Application data is stored in Azure SQL Database. The deployed backend accesses the database through a User Assigned Managed Identity.

> This repository is intended for learning, experimentation, and architecture validation. Review all settings before using the project in a production environment.

---

## Current Implementation

The application currently supports:

- Microsoft Entra ID authentication through Azure Static Web Apps
- Authenticated access to the React frontend
- Random Fortune retrieval
- Azure SQL-backed Fortune data
- Resource-backed and database-backed Spring profiles
- Fortune listing
- Fortune creation
- Fortune deletion
- Fortune Management through the React frontend
- Managed Identity-based Azure SQL access
- Least-privilege, object-level database permissions
- Azure infrastructure deployment with Bicep
- Backend OCI image creation with Cloud Native Buildpacks
- Script-based build, deployment, and verification

---

## Roadmap

### Completed

- [x] Step 1: Azure infrastructure provisioning with Bicep
- [x] Step 2: React frontend integration with Azure Static Web Apps
- [x] Step 3: Microsoft Entra ID authentication
- [x] Step 4: Data access
  - [x] Step 4.1: Azure SQL Database infrastructure
  - [x] Step 4.2: Azure SQL-backed Fortune data access
  - [x] Step 4.3: Fortune management

Step 4 implementation details are documented in:

```text
docs/step04-data-access.md
```

### Planned

- [ ] Step 5: CI/CD
- [ ] Step 6: API authentication and authorization
- [ ] Step 7: Identity lifecycle management
- [ ] Step 8: Replace Static Web Apps with a Buildpacks-based frontend container as an alternative architecture

Future roadmap documents will use the following naming pattern:

```text
docs/step05-cicd.md
docs/step06-api-authorization.md
docs/step07-identity-lifecycle.md
docs/step08-frontend-container.md
```

---

## Architecture

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
        │
        │ User Assigned Managed Identity
        ▼
Azure SQL Database
  │
  └── dbo.fortunes
```

Azure Static Web Apps provides the authenticated frontend entry point.

Azure Container Apps hosts the Spring Boot backend.

Azure SQL Database provides persistent Fortune data.

The backend accesses Azure SQL through a User Assigned Managed Identity without storing a database password in the application.

For the current system structure, component responsibilities, identity boundaries, and data-access profiles, see:

```text
docs/architecture.md
```

---

## Repository Structure

```text
spring-azure-serverless-demo/
├── backend/
│   └── Spring Boot application
│
├── frontend/
│   └── React + Vite application
│
├── database/
│   └── Azure SQL schema, seed data, and security configuration
│
├── config/
│   └── Environment-specific non-secret configuration
│
├── infra/
│   └── Azure infrastructure defined with Bicep
│
├── scripts/
│   └── Build, deployment, configuration, and verification scripts
│
├── docs/
│   └── Roadmap and reference documentation
│
├── swa-cli.config.json
└── README.md
```

Environment-specific non-secret settings are stored under:

```text
config/
```

The default development environment is defined in:

```text
config/dev.psd1
```

Secret values must not be stored in this file.

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
- Git
- PowerShell
- sqlcmd

Verify the local container runtime:

```powershell
docker info
```

The backend does not require a Dockerfile.

The backend OCI image is created with Spring Boot Buildpacks. A Docker-compatible runtime is still required to execute the Buildpacks build locally.

Azure Static Web Apps CLI is invoked through `npx` by the frontend deployment script.

A globally installed `swa` command is not required by the normal deployment flow.

---

## Required Environment Variables

Some build and deployment operations require environment variables that must be prepared by the developer.

```text
ENTRA_TENANT_ID
SWA_DEPLOYMENT_TOKEN
```

`ENTRA_TENANT_ID` is used when generating the Azure Static Web Apps authentication configuration.

`SWA_DEPLOYMENT_TOKEN` is used when deploying the generated frontend to Azure Static Web Apps.

Verify their availability without printing their values:

```powershell
if ($env:ENTRA_TENANT_ID) {
    Write-Host "ENTRA_TENANT_ID is configured."
}
else {
    Write-Host "ENTRA_TENANT_ID is not configured."
}

if ($env:SWA_DEPLOYMENT_TOKEN) {
    Write-Host "SWA_DEPLOYMENT_TOKEN is configured."
}
else {
    Write-Host "SWA_DEPLOYMENT_TOKEN is not configured."
}
```

The following Vite values are generated by the frontend build process and are not normally prepared manually:

```text
VITE_API_BASE_URL
VITE_BUILD_VERSION
```

Secret values must not be committed to the repository.

---

## Getting Started

The overall deployment flow is:

```text
Verify prerequisites and Azure context
        │
        ▼
Provision shared Azure infrastructure
        │
        ▼
Deploy and verify Azure SQL
        │
        ▼
Build the backend OCI image
        │
        ▼
Deploy the backend to Azure Container Apps
        │
        ▼
Build the React frontend
        │
        ▼
Deploy the frontend to Azure Static Web Apps
        │
        ▼
Configure Microsoft Entra ID authentication
        │
        ▼
Verify the deployed application
```

The primary application deployment scripts are:

```text
scripts/whatif-infra.ps1
scripts/deploy-infra.ps1
scripts/deploy-database.ps1
scripts/verify-database.ps1
scripts/build-backend.ps1
scripts/deploy-backend.ps1
scripts/build-frontend.ps1
scripts/deploy-frontend.ps1
```

Authentication setup uses:

```text
scripts/41-deploy-identity.ps1
scripts/42-create-client-secret.ps1
scripts/43-configure-swa-auth.ps1
```

For the complete deployment order, prerequisites, tenant switching, build settings, and verification commands, see:

```text
docs/deployment.md
```

---

## Local Development

The Spring Boot backend normally runs on:

```text
http://localhost:8080
```

The React development server normally runs on:

```text
http://localhost:5173
```

When `VITE_API_BASE_URL` is not supplied, the frontend uses:

```text
http://localhost:8080
```

as the backend API base URL.

The backend supports two data-access profiles:

```text
resource
database
```

The `resource` profile reads Fortune data bundled with the application.

The `database` profile uses Azure SQL Database.

A frontend production build can also be tested locally through the Vite preview server:

```text
http://localhost:4173
```

The backend CORS configuration permits both local frontend origins:

```text
http://localhost:5173
http://localhost:4173
```

Step 4-specific local execution and data-access details are documented in:

```text
docs/step04-data-access.md
```

---

## Build and Deployment

The backend image is built with Spring Boot Buildpacks.

The build uses:

```text
Paketo Noble Java Tiny Builder
linux/amd64
```

A versioned builder image is used instead of relying on the mutable `latest` tag.

The frontend build resolves the deployed Azure Container App endpoint and supplies it to Vite through:

```text
VITE_API_BASE_URL
```

The frontend deployment script invokes Azure Static Web Apps CLI through:

```text
npx @azure/static-web-apps-cli
```

Detailed build and deployment instructions are maintained in:

```text
docs/deployment.md
```

---

## Authentication

The application uses Microsoft Entra ID authentication through Azure Static Web Apps.

Azure Static Web Apps is currently the authenticated entry point for the React frontend.

The authentication resources belong to an authentication tenant that can have a lifecycle independent from the Azure subscription resources.

The current backend does not yet independently validate and authorize the authenticated user's token.

For the current authentication architecture, trust boundaries, verified user scenarios, and known limitations, see:

```text
docs/authentication.md
```

For the authentication provisioning and configuration procedure, see:

```text
docs/authentication-setup.md
```

---

## Data Access

Azure SQL Database stores persistent Fortune data.

The deployed backend accesses Azure SQL through a User Assigned Managed Identity.

The application currently grants the Managed Identity the following object-level permissions on `dbo.fortunes`:

```text
SELECT
INSERT
DELETE
```

Broad fixed database role membership is not required by the current Fortune functionality.

The application provides:

```text
GET    /api/fortune

GET    /api/admin/fortunes
POST   /api/admin/fortunes
DELETE /api/admin/fortunes/{id}
```

For Azure SQL infrastructure, Spring profiles, repository design, database permissions, Fortune Management, and Step 4 verification details, see:

```text
docs/step04-data-access.md
```

---

## Testing and Verification

The project distinguishes between different verification purposes.

### Automated Tests

Backend and frontend automated tests verify application and component behavior without requiring the complete deployed user flow.

### Local Feature Verification

Local feature verification confirms frontend and backend behavior during development.

### Deployed Backend Feature Verification

Direct API verification against Azure Container Apps confirms that the deployed backend and its Azure SQL access work correctly.

Individual API operations such as Fortune Management GET, POST, and DELETE are treated as deployed backend feature verification.

They are not treated as the complete application E2E verification.

### End-to-End Scenario Verification

E2E verification is based on a user scenario.

For Fortune Management, Azure Static Web Apps is the user entry point.

The verified scenario includes:

1. Signing in to the deployed application.
2. Viewing existing Fortune records.
3. Adding a Fortune through the React UI.
4. Confirming that the Fortune appears in the management list.
5. Using the application with the updated Fortune data.
6. Deleting the added Fortune.
7. Confirming that the Fortune disappears from the management list.

The purpose of this verification is to confirm that the user's intended workflow succeeds through the deployed application.

Step 4-specific test and verification details are documented in:

```text
docs/step04-data-access.md
```

---

## Documentation

Documentation is divided into roadmap documents and cross-cutting reference documents.

### Roadmap Documentation

Roadmap documents describe the implementation and decisions introduced by a specific project step.

Currently available:

```text
docs/step04-data-access.md
```

Future roadmap documents will follow the same naming convention:

```text
docs/step05-cicd.md
docs/step06-api-authorization.md
docs/step07-identity-lifecycle.md
docs/step08-frontend-container.md
```

### Reference Documentation

Current architecture:

```text
docs/architecture.md
```

Deployment and environment setup:

```text
docs/deployment.md
```

Authentication architecture and boundaries:

```text
docs/authentication.md
```

Authentication provisioning and configuration:

```text
docs/authentication-setup.md
```

Known issues, diagnostics, and resolutions:

```text
docs/troubleshooting.md
```

---

## Security Notes

Authentication is currently enforced at the Azure Static Web Apps layer.

The Azure Container Apps backend does not yet independently validate the authenticated user's token.

API authentication and authorization are planned for Step 6.

The backend uses a User Assigned Managed Identity for Azure SQL access and does not store a database password in application source.

The database identity follows a least-privilege, object-level permission model.

Do not commit:

- Client Secrets
- Azure Static Web Apps deployment tokens
- Access tokens
- Refresh tokens
- ID tokens
- Real `/.auth/me` responses
- Real user identities
- Azure credentials
- SQL credentials
- Private certificates or keys
- Generated files containing environment-specific values
- Local environment files containing credentials

Suitable secret-storage locations include:

- Azure Static Web Apps application settings
- GitHub Actions secrets
- Azure Key Vault
- Local user environment variables

For authentication-specific security boundaries, see:

```text
docs/authentication.md
```

---

## Troubleshooting

Known issues, diagnostic procedures, and validated resolutions are documented in:

```text
docs/troubleshooting.md
```

Topics include:

- Azure CLI tenant and subscription context
- Bicep diagnostics
- Azure SQL authentication
- Managed Identity database permissions
- Container runtime connectivity
- Buildpacks architecture mismatch
- Azure Container Apps log retrieval
- Vite build-time environment variables
- Vite preview CORS
- Azure Static Web Apps CLI invocation
- Vitest worker-pool behavior
- Authentication and redirect failures

---

## Next Steps

### Step 5: CI/CD

The next step introduces CI/CD automation.

The goal is to automate:

- Backend testing
- Frontend testing
- Backend OCI image creation
- Infrastructure deployment
- Database deployment verification
- Backend deployment
- Frontend build and deployment
- Deployment verification

Later roadmap work includes:

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

Until a license is added, standard copyright rules apply.

If reuse and contribution are intended, add an appropriate open-source license before publishing or accepting external contributions.
