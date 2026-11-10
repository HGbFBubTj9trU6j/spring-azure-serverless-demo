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
- React authentication and access-token acquisition with MSAL
- Spring Security OAuth 2.0 Resource Server
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
- React authentication and backend API access-token acquisition with MSAL
- Authenticated access to the React frontend
- Backend API authentication with Microsoft Entra ID access tokens
- Spring Security JWT validation
- Delegated API access through the `access_as_user` scope
- Role-based API authorization with the `Fortune.Admin` app role
- Role-based Fortune Management UI visibility
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
- [x] Step 5: Microsoft Entra ID authentication and authorization
  - [x] React authentication with MSAL
  - [x] Backend API access tokens with `access_as_user`
  - [x] Spring Security JWT authentication
  - [x] `Fortune.Admin` app-role authorization
  - [x] Role-based Fortune Management UI

Step 4 implementation details are documented in:

```text
docs/step04-data-access.md
```

Step 5 implementation details are documented in:

```text
docs/step05-entra-id-authentication-authorization.md
```

### Planned

- [ ] Step 6: CI/CD
- [ ] Step 7: Spring Boot Diagnostics with AI-assisted local diagnostics using Spring Boot Actuator, BootUI, and BootUI MCP
- [ ] Step 8: Observability with OpenTelemetry and Apache SkyWalking for tracing across HTTP, Spring Boot, and Azure SQL
- [ ] Step 9: Identity lifecycle management
- [ ] Step 10: Replace Static Web Apps with a Buildpacks-based frontend container as an alternative architecture
- [ ] Step 11: AI / RAG with Azure OpenAI, RAG, and OpenTelemetry tracing for AI processing

Future roadmap documents will use the following naming pattern:

```text
docs/step06-cicd.md
docs/step07-spring-boot-diagnostics.md
docs/step08-observability.md
docs/step09-identity-lifecycle.md
docs/step10-frontend-container.md
docs/step11-ai-rag.md
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
  │     │
  │     ├── SWA sign-in: spring-azure-serverless-demo-auth
  │     │
  │     └── MSAL client: spring-azure-serverless-demo-client
  │             │
  │             │ access_as_user
  │             │ Backend API access token
  │             ▼
  │       spring-azure-serverless-demo-api
  │             │
  │             │ Authorization: Bearer <access-token>
  │             ▼
  └────────── HTTPS / CORS ──────────► Azure Container Apps
                                        │
                                        └── Spring Boot REST API
                                              │
                                              ├── Spring Security
                                              │     ├── JWT validation
                                              │     └── Fortune.Admin authorization
                                              │
                                              │ User Assigned Managed Identity
                                              ▼
                                        Azure SQL Database
                                              │
                                              └── dbo.fortunes
```

Azure Static Web Apps provides the authenticated frontend entry point. React also uses MSAL to acquire an access token whose audience is the backend API.

Azure Container Apps hosts the Spring Boot backend. Spring Security independently validates bearer JWT access tokens before protected API requests reach the application.

The `access_as_user` delegated scope represents signed-in user access to the backend API. The `Fortune.Admin` app role is carried in the backend API access token's `roles` claim and is required for administrative API operations.

Azure SQL Database provides persistent Fortune data.

The backend accesses Azure SQL through a User Assigned Managed Identity without storing a database password in the application.

For the current system structure, component responsibilities, identity boundaries, and data-access profiles, see:

```text
docs/architecture.md
```

For the Step 5 identity and authorization design, see:

```text
docs/step05-entra-id-authentication-authorization.md
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
Configure Microsoft Entra ID app registrations, API scope, and app role
        │
        ▼
Build the React frontend
        │
        ▼
Deploy the frontend to Azure Static Web Apps
        │
        ▼
Configure Azure Static Web Apps authentication
        │
        ▼
Verify sign-in, access-token API calls, and role-based authorization
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

Azure Static Web Apps authentication setup uses:

```text
scripts/41-deploy-identity.ps1
scripts/42-create-client-secret.ps1
scripts/43-configure-swa-auth.ps1
```

The backend API app registration must also expose the `access_as_user` delegated scope and define the `Fortune.Admin` app role. The React client app registration must be granted delegated access to `access_as_user`. See the Step 5 document for the current configuration and verification procedure.

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

Protected API calls require a valid backend API access token. Local frontend authentication therefore also requires the React/MSAL redirect URI and backend API permission to be configured for the local origin.

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

Microsoft Entra ID, MSAL, backend JWT validation, and role-assignment details are maintained in:

```text
docs/step05-entra-id-authentication-authorization.md
```

---

## Authentication

The application uses Microsoft Entra ID for authentication.

Azure Static Web Apps remains the authenticated frontend entry point, while the React application also uses MSAL to sign users in and acquire an access token for the Spring Boot backend API.

The authentication resources belong to an authentication tenant that can have a lifecycle independent from the Azure subscription resources.

### App registrations

The identity architecture separates responsibilities across three app registrations:

- `spring-azure-serverless-demo-auth`
  - Provides Azure Static Web Apps authentication.
- `spring-azure-serverless-demo-client`
  - Represents the React/MSAL public client.
  - Requests the backend API's `access_as_user` delegated permission.
- `spring-azure-serverless-demo-api`
  - Represents the Spring Boot resource server.
  - Exposes the `access_as_user` delegated scope.
  - Defines the `Fortune.Admin` app role.

### Backend API access token

After sign-in, MSAL acquires a token for the backend API. React sends it on API requests as a bearer token:

```http
Authorization: Bearer <access-token>
```

The backend API access token and the React client ID token have different purposes. The API token is the source for backend API scopes and roles; the UI must not use `account.idTokenClaims.roles` to decide whether the user has the API's `Fortune.Admin` role.

An administrative user's backend API access token contains claims equivalent to:

```json
{
  "scp": "access_as_user",
  "roles": [
    "Fortune.Admin"
  ]
}
```

A non-administrative user's token can contain `access_as_user` without `Fortune.Admin`.

### Spring Security JWT authentication

The Spring Boot application operates as an OAuth 2.0 Resource Server. Spring Security independently validates bearer JWT access tokens and establishes the authenticated principal before endpoint authorization is evaluated.

The JWT authority conversion includes the access token's `roles` values so the backend can enforce the `Fortune.Admin` app role. An invalid, expired, missing, incorrectly issued, or wrong-audience access token must not be treated as an authenticated API call.

For the existing Azure Static Web Apps authentication architecture and provisioning procedure, see:

```text
docs/authentication.md
docs/authentication-setup.md
```

For the backend API token flow and Step 5 implementation, see:

```text
docs/step05-entra-id-authentication-authorization.md
```

### Authentication before authorization

Authentication and authorization are implemented and verified incrementally.

The project first establishes and tests:

1. Microsoft Entra ID sign-in.
2. Backend access-token acquisition with MSAL.
3. Bearer-token API calls.
4. Spring Security JWT validation.
5. Authenticated access to the general API.

Only after that baseline works and is covered by tests is role-based authorization added:

1. `Fortune.Admin` app-role definition and assignment.
2. Backend authorization for `/api/admin/**`.
3. `403 Forbidden` verification for authenticated users without the role.
4. Role-based Fortune Management UI visibility.

This separation avoids mixing authentication failures with authorization failures during implementation and troubleshooting.

---

## Authorization

Authentication answers whether a request carries a valid backend API access token. Authorization then decides what the authenticated user can do.

The current authorization model is:

| Operation | Authenticated user without `Fortune.Admin` | User with `Fortune.Admin` |
|---|---:|---:|
| Get Fortune | Allowed | Allowed |
| View Fortune Management | Hidden | Visible |
| List managed Fortunes | Forbidden | Allowed |
| Add Fortune | Forbidden | Allowed |
| Delete Fortune | Forbidden | Allowed |

Spring Security requires `Fortune.Admin` for:

```text
/api/admin/**
```

The backend is the security boundary. Authenticated users without `Fortune.Admin` receive `403 Forbidden` when they call administrative endpoints.

The React frontend acquires the backend API access token and reads its `roles` claim. Fortune Management is rendered only when the token contains `Fortune.Admin`.

Frontend token parsing controls the user experience only; it does not validate the token signature and must not be used as a security boundary. Hiding the management UI does not replace backend authorization.

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
GET    /api/fortune                  authenticated user

GET    /api/admin/fortunes           Fortune.Admin
POST   /api/admin/fortunes           Fortune.Admin
DELETE /api/admin/fortunes/{id}      Fortune.Admin
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

The Step 5 security coverage includes:

- Backend security tests for the Fortune Management GET, POST, and DELETE endpoints.
- Rejection of unauthenticated administrative requests.
- `403 Forbidden` for authenticated users without `Fortune.Admin`.
- Successful administrative requests when `Fortune.Admin` is present.
- Frontend tests that derive UI authorization from a test backend API access token rather than from the React client ID token.
- Fortune Management visibility when the access token contains `Fortune.Admin`.
- Fortune Management absence after token acquisition completes when the role is missing.
- Existing Fortune retrieval success and error behavior.

The frontend test suite contains four `App.test.tsx` tests and two `FortuneManagement.test.tsx` tests. The completed verification reported:

```text
npm test       6 tests passed
npm run build  succeeded
```

The production build emitted a non-blocking bundle-size warning for a chunk larger than 500 kB. The warning is separate from the authentication and authorization behavior.

### Local Feature Verification

Local feature verification confirms frontend and backend behavior during development.

The completed role-based UI check confirmed that Fortune Management is displayed for a user whose backend API access token contains `Fortune.Admin` and is not displayed for a user without that role.

### Deployed Backend Feature Verification

Direct API verification against Azure Container Apps confirms that the deployed backend, token validation, authorization, and Azure SQL access work correctly.

Individual API operations such as Fortune Management GET, POST, and DELETE are treated as deployed backend feature verification.

They are not treated as the complete application E2E verification.

### End-to-End Scenario Verification

E2E verification is based on a user scenario.

For Fortune Management, Azure Static Web Apps is the user entry point.

The verified scenario includes:

1. Signing in to the deployed application.
2. Acquiring a backend API access token.
3. Retrieving a Fortune through the authenticated API.
4. Confirming that Fortune Management is visible only for `Fortune.Admin`.
5. Viewing existing Fortune records as an administrator.
6. Adding a Fortune through the React UI.
7. Confirming that the Fortune appears in the management list.
8. Using the application with the updated Fortune data.
9. Deleting the added Fortune.
10. Confirming that the Fortune disappears from the management list.

The purpose of this verification is to confirm that the user's intended workflow succeeds through the deployed application and that frontend visibility agrees with backend authorization.

Step 4 data-access test and verification details are documented in:

```text
docs/step04-data-access.md
```

Step 5 authentication and authorization test details are documented in:

```text
docs/step05-entra-id-authentication-authorization.md
```

---

## Documentation

Documentation is divided into roadmap documents and cross-cutting reference documents.

### Roadmap Documentation

Roadmap documents describe the implementation and decisions introduced by a specific project step.

Currently available:

```text
docs/step04-data-access.md
docs/step05-entra-id-authentication-authorization.md
```

Future roadmap documents will follow the same naming convention:

```text
docs/step06-cicd.md
docs/step07-spring-boot-diagnostics.md
docs/step08-observability.md
docs/step09-identity-lifecycle.md
docs/step10-frontend-container.md
docs/step11-ai-rag.md
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

Azure Static Web Apps authentication architecture and boundaries:

```text
docs/authentication.md
```

Authentication provisioning and configuration:

```text
docs/authentication-setup.md
```

Microsoft Entra ID, React/MSAL, backend access tokens, Spring Security JWT authentication, and role-based authorization:

```text
docs/step05-entra-id-authentication-authorization.md
```

Known issues, diagnostics, and resolutions:

```text
docs/troubleshooting.md
```

---

## Security Notes

Authentication and authorization are enforced at multiple layers.

Azure Static Web Apps provides the authenticated frontend entry point.

The React application uses MSAL to acquire a backend API access token containing the `access_as_user` delegated scope. API requests send the token in the `Authorization: Bearer` header.

The Spring Boot backend independently validates bearer JWT access tokens through Spring Security.

Administrative endpoints under:

```text
/api/admin/**
```

require the `Fortune.Admin` app role.

The React frontend hides Fortune Management from users without `Fortune.Admin`, but frontend visibility is not a security boundary. The backend independently rejects authenticated administrative requests without the role with `403 Forbidden`.

The frontend reads roles from the backend API access token, not from the React client ID token. Frontend claim decoding does not perform signature validation and is used only to control presentation.

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
docs/step05-entra-id-authentication-authorization.md
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
- MSAL account and silent token-acquisition failures
- Backend API token audience, issuer, expiry, and signature failures
- Missing `access_as_user` scope or `Fortune.Admin` role claims
- Distinguishing `401 Unauthorized` authentication failures from `403 Forbidden` authorization failures
- ID token versus backend API access-token claim selection

---

## Next Steps

### Step 6: CI/CD

The next step introduces CI/CD automation.

The goal is to automate:

- Backend testing, including authentication and authorization tests
- Frontend testing, including Access Token-based role visibility tests
- Backend OCI image creation
- Infrastructure deployment
- Database deployment verification
- Backend deployment
- Frontend build and deployment
- Deployment verification

Later roadmap work includes:

- Step 7: Spring Boot Diagnostics with Spring Boot Actuator, BootUI, and BootUI MCP for AI-assisted local diagnostics
- Step 8: Observability with OpenTelemetry and Apache SkyWalking for tracing across HTTP, Spring Boot, and Azure SQL
- Step 9: Identity lifecycle management, including user invitation and onboarding, self-service sign-up, and access reviews
- Step 10: Buildpacks-based frontend containerization as an alternative architecture that replaces Azure Static Web Apps with Azure Container Apps
- Step 11: AI / RAG with Azure OpenAI, RAG, and OpenTelemetry tracing for AI processing

---

## License

No license has been declared yet.

Until a license is added, standard copyright rules apply.

If reuse and contribution are intended, add an appropriate open-source license before publishing or accepting external contributions.
