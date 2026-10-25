# Architecture

This document describes the current architecture of the
spring-azure-serverless-demo application.

Roadmap-specific implementation history is documented separately under
the `docs/stepNN-*.md` files.

---

## Architecture Overview

The deployed application consists of a React frontend hosted on
Azure Static Web Apps, a Spring Boot backend hosted on Azure Container Apps,
and persistent application data stored in Azure SQL Database.

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

The major architectural boundaries are:

- Frontend hosting and user authentication
- Backend application execution
- Persistent data storage
- Application-to-database identity
- Infrastructure provisioning

---

## Frontend

The frontend is implemented with:

```text
React
Vite
TypeScript
```

It is hosted on Azure Static Web Apps.

The frontend provides:

- Random Fortune retrieval
- Fortune Management
- Microsoft Entra ID-protected application access
- Frontend build-version display

The frontend communicates with the Spring Boot backend through HTTPS.

The backend API base URL is supplied during the frontend build.

For local development, the frontend falls back to:

```text
http://localhost:8080
```

when `VITE_API_BASE_URL` is not defined.

---

## Frontend Authentication

Azure Static Web Apps is the current authentication boundary for the web application.

Microsoft Entra ID authentication is configured through Azure Static Web Apps.

The user accesses the React application only after completing the configured authentication flow.

Authentication-related resources are managed separately from the main Azure subscription resources because the authentication tenant and the Azure subscription tenant can have independent lifecycles.

Detailed authentication architecture is documented in:

```text
docs/authentication.md
```

Authentication provisioning and configuration are documented in:

```text
docs/authentication-setup.md
```

---

## Backend

The backend is implemented with Spring Boot and runs on Azure Container Apps.

The backend exposes REST APIs used by the React frontend.

Current Fortune-related APIs include:

```text
GET    /api/fortune

GET    /api/admin/fortunes
POST   /api/admin/fortunes
DELETE /api/admin/fortunes/{id}
```

The backend separates application logic from the underlying Fortune storage implementation through repository abstractions.

---

## Data Access Profiles

The backend supports two Spring profiles for Fortune data access.

```text
resource
database
```

### Resource Profile

The `resource` profile reads Fortune data bundled with the application.

```text
FortuneController
  │
  ▼
FortuneService
  │
  ▼
FortuneRepository
  │
  ▼
ResourceFortuneRepository
```

This profile provides a simple baseline implementation that does not require Azure SQL.

### Database Profile

The `database` profile uses Azure SQL Database.

```text
FortuneController
  │
  ▼
FortuneService
  │
  ▼
FortuneRepository
  │
  ▼
DatabaseFortuneRepository
  │
  ▼
Azure SQL Database
```

Fortune Management components are also enabled only for the `database` profile.

```text
FortuneManagementController
  │
  ▼
FortuneManagementService
  │
  ▼
FortuneManagementRepository
  │
  ▼
DatabaseFortuneRepository
  │
  ▼
Azure SQL Database
```

This keeps database-specific management behavior outside the resource-backed application configuration.

Detailed Step 4 implementation information is documented in:

```text
docs/step04-data-access.md
```

---

## Azure SQL Database

Azure SQL Database provides persistent Fortune data.

The application currently stores Fortune records in:

```text
dbo.fortunes
```

The backend uses Azure SQL for:

- Random Fortune retrieval
- Fortune listing
- Fortune creation
- Fortune deletion

The application does not currently provide a Fortune update operation.

---

## Database Identity

The deployed Spring Boot application does not use a database username and password.

Azure Container Apps uses a User Assigned Managed Identity to authenticate with Azure SQL Database.

```text
Azure Container Apps
  │
  ▼
User Assigned Managed Identity
  │
  ▼
Microsoft Entra authentication
  │
  ▼
Azure SQL Database
```

The Managed Identity exists as a database principal in the application database.

For local development, the developer uses a local Microsoft Entra authentication path instead of the Azure Container Apps Managed Identity.

---

## Database Authorization

Database authorization follows a least-privilege model.

The Container App Managed Identity is granted only the object-level permissions currently required on:

```text
dbo.fortunes
```

The required permissions are:

```text
SELECT
INSERT
DELETE
```

The application does not require broad data-reader or data-writer database role membership for the current Fortune functionality.

`UPDATE` is not granted because the current application does not provide an update operation.

Detailed database deployment and permission verification are documented in:

```text
docs/step04-data-access.md
```

---

## Backend Container Image

The Spring Boot backend is packaged as an OCI image with Cloud Native Buildpacks.

The application does not require a Dockerfile for the backend image.

The build process uses:

```text
Spring Boot Buildpacks
Paketo Noble Java Tiny Builder
linux/amd64
```

The resulting image is pushed to Azure Container Registry and deployed to Azure Container Apps.

The builder image is versioned rather than relying on a mutable `latest` builder tag.

Detailed build and deployment commands are documented in:

```text
docs/deployment.md
```

---

## Azure Container Registry

Azure Container Registry stores backend OCI images.

The User Assigned Managed Identity used by the Container App has the Azure permissions required to retrieve the application image from the registry.

Container images use Git-derived tags so that deployed application images can be related back to source revisions.

A dirty working tree is identified separately by the build process.

---

## Azure Static Web Apps

Azure Static Web Apps hosts the production React frontend.

Its responsibilities currently include:

- Static frontend hosting
- Microsoft Entra ID authentication
- Authenticated application entry point

The frontend is built separately from the backend.

During the frontend build, the deployed Azure Container App API endpoint is provided through:

```text
VITE_API_BASE_URL
```

The resulting files are deployed to the Azure Static Web Apps production environment.

---

## CORS Boundary

The React frontend and Spring Boot backend are deployed as separate web origins.

The backend therefore explicitly permits expected frontend origins.

The local development origins include:

```text
http://localhost:5173
http://localhost:4173
```

These correspond to:

```text
npm run dev
npm run preview
```

Azure Static Web Apps origins are also permitted by the Spring Boot CORS configuration.

CORS controls browser access to the backend API.

It is not used as an API authentication or authorization mechanism.

---

## Infrastructure as Code

Azure infrastructure is defined with Bicep under:

```text
infra/
```

Infrastructure configuration includes resources such as:

- Resource Group
- Azure Container Registry
- User Assigned Managed Identity
- Azure Container Apps Environment
- Azure Static Web Apps
- Azure SQL resources

The Azure Container App is deployed after the backend OCI image has been built.

Its configuration remains managed through Bicep.

Environment-specific non-secret values are centralized under:

```text
config/
```

The default development environment uses:

```text
config/dev.psd1
```

---

## Tenant Boundary

The solution separates Azure subscription resources from authentication-tenant resources.

Conceptually:

```text
Azure Subscription Tenant
  │
  ├── Azure Static Web Apps
  ├── Azure Container Apps
  ├── Azure Container Registry
  ├── Azure SQL
  └── User Assigned Managed Identity

Authentication Tenant
  │
  ├── App Registration
  └── Service Principal
```

This allows the Azure resources and authentication resources to have independent lifecycles.

Authentication-specific details are documented separately.

---

## Local Architecture

During local development, the frontend and backend run as separate processes.

```text
Browser
  │
  ▼
React + Vite
localhost:5173
  │
  ▼
Spring Boot
localhost:8080
```

When the backend uses the `database` profile, the local flow extends to Azure SQL:

```text
Browser
  │
  ▼
React + Vite
  │
  ▼
Spring Boot
  │
  ▼
Local Microsoft Entra authentication
  │
  ▼
Azure SQL Database
```

A production frontend build can also be tested locally with the Vite preview server:

```text
http://localhost:4173
```

Detailed local execution instructions are maintained in:

```text
docs/local-development.md
```

---

## Security Boundaries

The architecture currently has distinct authentication and authorization boundaries.

### User Authentication

User authentication is enforced by Azure Static Web Apps through Microsoft Entra ID.

### Backend API

The Azure Container Apps backend is currently reachable independently of the authenticated frontend flow.

The backend does not yet independently validate the authenticated user's token.

Backend API authentication and authorization are planned for a later roadmap step.

### Database

The backend authenticates to Azure SQL independently of the end user's identity.

The application uses its User Assigned Managed Identity for deployed database access.

Therefore:

```text
User identity
```

and:

```text
Application database identity
```

are separate security concerns.

---

## Current Request Flow

A typical Fortune Management request follows this path:

```text
Authenticated user
  │
  ▼
Azure Static Web Apps
  │
  ▼
React Fortune Management UI
  │
  ▼
Azure Container Apps ingress
  │
  ▼
Spring Boot
  │
  ▼
FortuneManagementController
  │
  ▼
FortuneManagementService
  │
  ▼
DatabaseFortuneRepository
  │
  ▼
User Assigned Managed Identity
  │
  ▼
Azure SQL Database
```

The user interacts with the React application.

The backend performs the database operation using the application's Managed Identity.

---

## Current Architecture Boundary

The current architecture validates the following separation of concerns:

```text
Frontend
  └── User interaction and authentication entry point

Backend
  └── Application API and business behavior

Managed Identity
  └── Application-to-Azure resource identity

Azure SQL
  └── Persistent application data

Bicep
  └── Azure infrastructure definition

PowerShell
  └── Build, deployment, configuration, and verification automation
```

This separation is intentionally maintained as later roadmap steps introduce CI/CD and backend API authorization.

---

## Related Documentation

Roadmap implementation details:

```text
docs/step01-infrastructure.md
docs/step02-frontend.md
docs/step03-authentication.md
docs/step04-data-access.md
```

Cross-cutting reference documentation:

```text
docs/deployment.md
docs/local-development.md
docs/testing.md
docs/troubleshooting.md
```

Authentication-specific documentation:

```text
docs/authentication.md
docs/authentication-setup.md
```
