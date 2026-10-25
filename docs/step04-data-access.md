# Step 4: Data Access

Step 4 introduces persistent data access to the application by using Azure SQL Database.

The implementation evolves in three stages:

- Step 4.1: Provision Azure SQL Database
- Step 4.2: Replace resource-based Fortune data with Azure SQL
- Step 4.3: Add Fortune management

The final application flow is:

```text
Browser
  │
  ▼
Azure Static Web Apps
  │
  └── React + Vite
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

The backend supports two data-access profiles:

- `resource`: Reads Fortune data from application resources.
- `database`: Reads and manages Fortune data in Azure SQL Database.

The `resource` profile remains available as a simple baseline implementation, while the `database` profile represents the Azure deployment architecture.

---

## Step 4.1: Azure SQL Database Infrastructure

### Goal

Provision Azure SQL Database and establish the database foundation required by the Spring Boot backend.

The database configuration uses Microsoft Entra authentication rather than SQL authentication.

### Azure SQL Resources

The development environment includes:

- Azure SQL logical server
- Azure SQL Database named `fortune`
- Microsoft Entra-only authentication
- `dbo.fortunes` table
- Initial Fortune data
- Database principal for the Container App User Assigned Managed Identity

Database-related infrastructure is managed separately from the application schema and database security configuration.

### Database Schema

Fortune data is stored in:

```text
dbo.fortunes
```

The table contains:

```text
id       bigint
message  nvarchar(max)
```

`id` identifies each Fortune.

`message` stores the Fortune text and supports multiline values.

### Seed Data

The initial database contains the Fortune data used by the application.

Seed data is deployed separately from the schema so that the database structure and initial application data remain independently understandable.

### Microsoft Entra-only Authentication

The Azure SQL environment does not rely on SQL usernames and passwords for application access.

The application uses Microsoft Entra authentication.

In Azure Container Apps, the Spring Boot application connects to Azure SQL by using its User Assigned Managed Identity.

For local development, the developer connects to Azure SQL through the local Microsoft Entra authentication path.

### Database Deployment

Database deployment is automated through:

```text
scripts/deploy-database.ps1
```

Environment-specific resource names are loaded from:

```text
config/dev.psd1
```

This keeps non-secret environment configuration centralized and reusable.

### Database Verification

Database configuration is verified through:

```text
scripts/verify-database.ps1
```

The verification covers:

- Database connectivity
- Database name and collation
- `dbo.fortunes` table structure
- Managed Identity database principal
- Database role membership
- Object-level permissions

### Step 4.1 Exit Criteria

Step 4.1 is complete when:

- Azure SQL Database is provisioned.
- Microsoft Entra-only authentication is enabled.
- `dbo.fortunes` exists.
- Initial Fortune data is available.
- The Container App Managed Identity exists as a database principal.
- Database deployment and verification can be performed through scripts.

---

## Step 4.2: Azure SQL-backed Fortune Data Access

### Goal

Replace the resource-backed Fortune implementation with an Azure SQL-backed implementation while preserving the existing Fortune API contract.

The existing resource implementation remains available through a Spring profile.

### Repository Abstraction

The application separates the Fortune API from the underlying storage implementation.

The same Fortune service can use different repository implementations depending on the active Spring profile.

```text
FortuneController
  │
  ▼
FortuneService
  │
  ▼
FortuneRepository
  │
  ├── resource profile
  │     └── ResourceFortuneRepository
  │
  └── database profile
        └── DatabaseFortuneRepository
```

This allows the application to retain a lightweight resource-based implementation while introducing persistent Azure SQL access.

### Resource Profile

The `resource` profile uses Fortune data bundled with the application.

This profile remains useful for:

- Simple local execution
- Baseline application behavior
- Tests that do not require Azure SQL
- Comparing resource-backed and database-backed implementations

### Database Profile

The `database` profile uses Azure SQL Database.

The backend can be started locally with the database profile by using:

```powershell
Push-Location .\backend

.\mvnw.cmd spring-boot:run `
  "-Dspring-boot.run.profiles=database"

Pop-Location
```

The database-backed implementation retrieves Fortune data from:

```text
dbo.fortunes
```

### Random Fortune API

The existing Fortune endpoint continues to provide a random Fortune.

```text
GET /api/fortune
```

The API contract remains independent of the repository implementation.

With the `database` profile active, the Fortune is retrieved from Azure SQL.

### Azure Container Apps and Managed Identity

In Azure, the data-access path is:

```text
Azure Container Apps
  │
  ▼
Spring Boot
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

No database password is stored in the application configuration.

### Local Development

Local execution uses the developer's Microsoft Entra authentication path rather than the Container App Managed Identity.

This allows the same Azure SQL Database to be used during local development without introducing SQL credentials into the repository.

### Deployment Verification

After deploying the database-backed backend to Azure Container Apps, the existing Fortune API is used to verify that the deployed application can retrieve Fortune data through Azure SQL.

This verifies the deployed backend path rather than an end-user scenario.

### Step 4.2 Exit Criteria

Step 4.2 is complete when:

- The `resource` profile continues to work.
- The `database` profile retrieves Fortune data from Azure SQL.
- Local database-backed execution succeeds.
- Azure Container Apps connects to Azure SQL through Managed Identity.
- The existing `/api/fortune` contract remains available.

---

## Step 4.3: Fortune Management

### Goal

Add a Fortune management capability on top of the Azure SQL-backed implementation.

The management feature supports:

- Listing Fortunes
- Adding Fortunes
- Deleting Fortunes

An update operation is intentionally not included in the current implementation.

### Backend Architecture

The management flow is:

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

The management components are available only when the `database` profile is active.

This prevents the resource-backed application from attempting to create database-specific management components.

### Fortune Management API

The management API is exposed under:

```text
/api/admin/fortunes
```

#### List Fortunes

```text
GET /api/admin/fortunes
```

Returns the Fortune records stored in Azure SQL.

#### Add a Fortune

```text
POST /api/admin/fortunes
```

The request contains a Fortune message.

The backend validates the message before inserting the record.

#### Delete a Fortune

```text
DELETE /api/admin/fortunes/{id}
```

Deletes the selected Fortune.

A successful deletion returns:

```text
204 No Content
```

### Request Validation

Fortune creation validates that the message is not blank.

Validation is enforced by the backend even when the frontend also prevents blank submissions.

The frontend validation improves the user experience.

The backend validation protects the API boundary.

### Database Permissions

The Container App Managed Identity follows a least-privilege database permission model.

It is not assigned a broad data-reader or data-writer role for the application database.

Instead, the identity receives object-level permissions on:

```text
dbo.fortunes
```

The granted permissions are:

```text
SELECT
INSERT
DELETE
```

`UPDATE` is intentionally not granted because the current Fortune Management API does not provide an update operation.

### Database Permission Verification

The database verification script confirms that:

- The Managed Identity database principal exists.
- The Managed Identity has no fixed database role membership.
- `SELECT` is granted on `dbo.fortunes`.
- `INSERT` is granted on `dbo.fortunes`.
- `DELETE` is granted on `dbo.fortunes`.

The absence of unnecessary permissions is part of the verification.

### Fortune Management Frontend

The React frontend includes a Fortune Management section.

The UI supports:

- Displaying existing Fortune records
- Entering a new Fortune message
- Adding a Fortune
- Deleting a Fortune
- Displaying API errors

The frontend uses the same API base URL configuration as the existing Fortune feature.

### Local Frontend Development

The Vite development server runs on:

```text
http://localhost:5173
```

When `VITE_API_BASE_URL` is not defined, the frontend uses:

```text
http://localhost:8080
```

as the backend API base URL.

### Production Build Preview

A production frontend build can be created with:

```powershell
npm run build
```

The generated output can be previewed with:

```powershell
npm run preview
```

The Vite preview server uses:

```text
http://localhost:4173
```

The Spring Boot CORS configuration therefore permits both local frontend origins:

```text
http://localhost:5173
http://localhost:4173
```

Azure Static Web Apps origins are also permitted through the existing Azure Static Web Apps origin pattern.

### Frontend Build-time Configuration

The deployed frontend receives its backend API URL during the frontend build.

The build script sets:

```text
VITE_API_BASE_URL
VITE_BUILD_VERSION
```

These values are produced by the build process and are not prerequisites that the developer needs to configure manually.

The frontend falls back to:

```text
http://localhost:8080
```

when `VITE_API_BASE_URL` is not supplied.

### Required Environment Variables

The application scripts require the following environment variables to be prepared by the developer when applicable:

```text
ENTRA_TENANT_ID
SWA_DEPLOYMENT_TOKEN
```

`ENTRA_TENANT_ID` is required by the frontend authentication build configuration.

`SWA_DEPLOYMENT_TOKEN` is required when deploying the frontend to Azure Static Web Apps.

Secret values must not be committed to the repository.

---

## Build and Deployment

### Backend Build

The backend OCI image is built with Spring Boot Buildpacks.

The build uses a versioned Paketo Noble Java Tiny builder instead of relying on the mutable `latest` tag.

The build also explicitly targets:

```text
linux/amd64
```

This makes the expected deployment platform explicit and avoids relying on automatic architecture selection.

### Backend Deployment

The backend is deployed to Azure Container Apps through:

```text
scripts/deploy-backend.ps1
```

The deployment uses the OCI image created by:

```text
scripts/build-backend.ps1
```

### Frontend Build

The frontend production build is created through:

```text
scripts/build-frontend.ps1
```

The script determines the deployed Container App API URL and provides it to the Vite build.

### Frontend Deployment

The generated frontend is deployed through:

```text
scripts/deploy-frontend.ps1
```

The deployment script uses Azure Static Web Apps CLI through `npx`, so a globally installed `swa` executable is not required by the deployment script.

---

## Testing and Verification

Step 4 uses several different levels of testing and verification.

These levels are intentionally distinguished by purpose.

### Backend Automated Tests

Backend automated tests verify application behavior such as:

- Application context behavior
- Fortune API behavior
- Resource-backed Fortune behavior
- Fortune Management HTTP behavior
- Fortune Management request validation

The management controller tests run with the `database` profile while mocking the service dependency.

They do not require a live Azure SQL connection.

### Frontend Component Tests

Frontend tests use Vitest and Testing Library.

The tests focus on behavior visible to the user rather than internal implementation details.

Examples include:

- A returned Fortune is displayed.
- A Fortune API failure produces an error message.
- Existing Fortunes are displayed.
- A user can add a Fortune and see it appear.
- A user can delete a Fortune and see it disappear.
- A Fortune Management load failure is displayed.

The tests intentionally avoid making assertions about implementation details such as exact `fetch` call counts.

### Local Feature Verification

Local feature verification confirms that the React frontend and Spring Boot backend work together while the backend uses Azure SQL.

The local path is:

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
Azure SQL Database
```

The Fortune Management UI is used to verify:

- Existing Fortune display
- Fortune creation
- Fortune deletion

### Deployed Backend Feature Verification

The deployed Fortune Management API is also verified directly through Azure Container Apps.

The verification covers:

```text
GET
POST
GET
DELETE
GET
```

This confirms that the deployed backend can list, create, and delete Fortune data through the Container App Managed Identity.

This verification is treated as deployed backend feature verification.

It is not treated as the application E2E verification.

### End-to-End Scenario Verification

E2E verification is based on a user scenario rather than individual API operations.

The deployed Azure Static Web Apps application is the scenario entry point.

The verified Fortune Management scenario is:

1. Sign in to the deployed application.
2. Open the Fortune Management UI.
3. Verify that the existing Fortunes are displayed.
4. Enter a new Fortune.
5. Add the Fortune.
6. Verify that the new Fortune appears in the management list.
7. Use the application with the updated Fortune data.
8. Delete the added Fortune.
9. Verify that the Fortune disappears from the management list.

The purpose of the E2E verification is to confirm that the user's intended workflow succeeds through the deployed application.

It is not defined merely by the number of technical components involved.

---

## Security Model

### Database Authentication

Azure SQL access uses Microsoft Entra authentication.

The deployed Spring Boot application uses a User Assigned Managed Identity.

Database credentials are not stored in the application source.

### Least-Privilege Database Access

The Managed Identity receives only the database permissions required by the current application:

```text
SELECT
INSERT
DELETE
```

These permissions apply to:

```text
dbo.fortunes
```

Broad database data-reader or data-writer role membership is not required by the current application.

### Current API Security Boundary

Authentication is currently enforced at the Azure Static Web Apps layer.

The Azure Container Apps backend does not yet independently validate and authorize the authenticated user for Fortune Management operations.

Backend API authentication and authorization are planned for a later step.

---

## Step 4 Result

Step 4 completes the transition from resource-based Fortune data to persistent Azure SQL-backed application data.

The application now supports:

- Azure SQL Database
- Microsoft Entra-only database authentication
- Managed Identity database access from Azure Container Apps
- Resource-backed and database-backed Spring profiles
- Persistent random Fortune retrieval
- Fortune listing
- Fortune creation
- Fortune deletion
- Least-privilege object-level SQL permissions
- Fortune Management through the React frontend
- Local production-build preview
- Automated backend and frontend tests
- Deployed user-scenario verification

The application data flow is now:

```text
Browser
  │
  ▼
Azure Static Web Apps
  │
  ▼
React
  │
  ▼
Azure Container Apps
  │
  ▼
Spring Boot
  │
  ▼
User Assigned Managed Identity
  │
  ▼
Azure SQL Database
```

---

## Troubleshooting

Detailed troubleshooting information is maintained separately in:

```text
docs/troubleshooting.md
```

Step 4 troubleshooting topics include:

- Azure SQL Microsoft Entra authentication
- Managed Identity database permissions
- Buildpacks builder architecture mismatch
- Vite preview CORS
- Vite build-time environment variables
- Vitest worker pool behavior
- Azure Container Apps log retrieval

---

## Next Step

Step 5 introduces CI/CD automation.

The goal is to automate the application build, test, and deployment flow while preserving the verification boundaries established in Step 4.
