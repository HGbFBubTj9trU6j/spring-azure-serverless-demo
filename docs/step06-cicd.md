# Step 6: CI/CD with GitHub Actions

Step 6 introduces CI/CD automation for the Spring Boot backend and React frontend using GitHub Actions.

The pipeline automates application testing, build, deployment, and deployment verification for Azure Container Apps and Azure Static Web Apps.

The GitHub Actions workflow is defined in:

```text
.github/workflows/cicd.yml
```

---

## Goals

The goals of Step 6 are:

- Run backend and frontend automated tests on every deployment pipeline execution.
- Build the Spring Boot backend as an OCI image with Cloud Native Buildpacks.
- Authenticate GitHub Actions to Azure without storing Azure credentials as long-lived secrets.
- Push backend OCI images to Azure Container Registry.
- Deploy the backend to Azure Container Apps.
- Build the React frontend with deployment-specific configuration.
- Deploy the frontend to Azure Static Web Apps.
- Verify that the artifacts created from the current Git commit are the artifacts actually deployed.
- Keep build, deployment, and verification logic reusable outside GitHub Actions by implementing the operations in PowerShell scripts.

---

## Pipeline Trigger

The project is currently maintained as a single-developer project.

Development is performed locally and completed changes are committed and pushed directly to `main`.

For this reason, the CI/CD workflow runs only when `main` is pushed:

```yaml
on:
  push:
    branches:
      - main
```

This establishes the following repository convention:

```text
Local Development
        │
        ▼
Commit
        │
        ▼
Push to main
        │
        ▼
GitHub Actions CI/CD
```

A push to another branch does not deploy the application.

Pull Request automation is not currently required by the project's development workflow. It can be introduced later if the repository moves to a branch-and-review development model.

---

## Pipeline Overview

The workflow contains independent backend and frontend jobs.

```text
main push
   │
   ├───────────────────────────────────┐
   │                                   │
   ▼                                   ▼
Backend                              Frontend
   │                                   │
   ├─ Maven tests                      ├─ npm install
   │                                   │
   ├─ Buildpacks OCI build             ├─ Vitest tests
   │                                   │
   ├─ Azure login with OIDC            ├─ Azure login with OIDC
   │                                   │
   ├─ ACR login                        ├─ Production build
   │                                   │
   ├─ OCI image tag                    ├─ SWA deployment
   │                                   │
   ├─ ACR push                         └─ Deployment verification
   │
   ├─ ACA deployment
   │
   └─ Deployment verification
```

Both deployment paths use the Git commit SHA as an immutable deployment identifier.

---

# Backend CI/CD

## Backend Tests

The backend pipeline first runs the Maven test suite:

```powershell
./mvnw clean test
```

Backend tests include the authentication and authorization behavior established in Step 5.

The tests do not depend on the real Microsoft Entra tenant.

A test-only tenant value is supplied to satisfy the Spring Security issuer configuration without coupling backend tests to an external tenant.

---

## Backend OCI Image Build

The backend is packaged as an OCI image using Spring Boot Buildpacks.

The pipeline uses:

```text
Paketo Noble Java Tiny Builder
linux/amd64
```

The OCI image is initially built locally on the GitHub Actions runner.

The Git commit SHA is used as the image version:

```text
spring-azure-serverless-demo/backend:<github-sha>
```

This provides a direct relationship between:

```text
Git commit
    ↓
OCI image
```

A Dockerfile is not required.

---

## GitHub Actions Authentication to Azure

GitHub Actions authenticates to Azure using OpenID Connect federation.

The workflow uses:

```text
azure/login
```

with:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

stored as GitHub Actions secrets.

The GitHub Actions identity is implemented as a User Assigned Managed Identity with a federated identity credential.

This avoids storing a long-lived Azure client secret in GitHub.

The identity used by GitHub Actions is separate from the runtime identity assigned to the Azure Container App.

Their responsibilities are:

```text
GitHub Actions Managed Identity
    │
    ├─ Push OCI images to ACR
    └─ Deploy Azure Container Apps


Container App Managed Identity
    │
    ├─ Pull OCI images at runtime
    └─ Access Azure SQL Database
```

Keeping these identities separate limits their responsibilities and permissions.

---

## Azure Container Registry Push

After Azure authentication, the workflow logs in to Azure Container Registry.

The locally built image is tagged as:

```text
<acr-login-server>/backend:<github-sha>
```

and pushed to Azure Container Registry.

The commit SHA therefore remains the deployment identifier across:

```text
Git commit
    ↓
Local OCI image
    ↓
ACR OCI image
    ↓
Azure Container Apps
```

---

## Backend Deployment

The backend is deployed using:

```text
scripts/deploy-backend.ps1
```

The script invokes the existing Bicep infrastructure definition rather than duplicating deployment logic inside GitHub Actions.

The Azure Container App receives the following runtime configuration:

```text
SPRING_PROFILES_ACTIVE
SPRING_DATASOURCE_URL
ENTRA_TENANT_ID
```

`SPRING_PROFILES_ACTIVE=database` enables Azure SQL-backed data access.

`SPRING_DATASOURCE_URL` configures Azure SQL access through the Container App User Assigned Managed Identity.

`ENTRA_TENANT_ID` is required by Spring Security to build the Microsoft Entra JWT issuer configuration used to validate backend API access tokens.

---

## Backend Deployment Verification

A successful Azure deployment command does not by itself prove that the expected application image is running.

Step 6 therefore performs deployment verification after the backend deployment.

The verification checks the deployed Container App image against the expected Git commit SHA.

Conceptually:

```text
Expected
github.sha
    │
    ▼
backend:<github.sha>


Actual
Azure Container Apps
    │
    ▼
running image tag
```

The deployment is considered verified only when the expected and deployed versions match.

This distinguishes:

```text
Deployment command succeeded
```

from:

```text
The artifact built from this Git commit is actually deployed
```

---

# Frontend CI/CD

## Frontend Tests

The frontend job installs dependencies with:

```powershell
npm ci
```

and runs the Vitest test suite:

```powershell
npm test -- --run
```

The frontend tests include:

- Fortune retrieval behavior
- API failure behavior
- `Fortune.Admin` UI visibility
- Fortune Management behavior

These tests run before the frontend is built or deployed.

---

## Frontend Production Build

The production frontend is built with:

```text
scripts/build-frontend.ps1
```

The script resolves the deployed Azure Container Apps backend FQDN and provides it to Vite through:

```text
VITE_API_BASE_URL
```

The GitHub Actions workflow supplies the Git commit SHA as:

```text
-BuildVersion "${{ github.sha }}"
```

The build script then provides the value to React through:

```text
VITE_BUILD_VERSION
```

The same value is also written to:

```text
version.json
```

before the Vite build.

The generated file is included in the deployment output as:

```text
frontend/dist/version.json
```

The temporary source file under `frontend/public` is removed after the build so generated environment-specific data does not remain in the working tree.

---

## Build Fail-Fast Behavior

The frontend production build depends on the deployed backend endpoint.

If the Azure Container App FQDN cannot be resolved, the build must not continue with an invalid API URL.

The build script therefore explicitly checks:

```text
az containerapp show exit code
```

and verifies that the returned FQDN is not empty.

Failure to resolve the backend endpoint terminates the build immediately.

This prevents a build such as:

```text
VITE_API_BASE_URL=https://
```

from being incorrectly treated as successful.

---

## Azure Static Web Apps Deployment

The production frontend is deployed using:

```text
scripts/deploy-frontend.ps1
```

Deployment uses:

```text
SWA_DEPLOYMENT_TOKEN
```

stored as a GitHub Actions secret.

Azure Static Web Apps is used as the static hosting layer.

Application user authentication is performed by React/MSAL rather than by an additional Azure Static Web Apps authentication layer.

This keeps the authentication flow consistent between local development and the deployed application.

```text
Local

React
  │
  ▼
MSAL
  │
  ▼
Microsoft Entra ID
  │
  ▼
Backend API Access Token
  │
  ▼
Spring Boot


Azure

Azure Static Web Apps
  │
  ▼
React
  │
  ▼
MSAL
  │
  ▼
Microsoft Entra ID
  │
  ▼
Backend API Access Token
  │
  ▼
Spring Boot
```

---

## Frontend Deployment Verification

A successful Static Web Apps deployment command does not prove that the newly built frontend is already being served.

Step 6 therefore adds frontend deployment verification.

The production build publishes:

```text
/version.json
```

containing:

```json
{
  "version": "<github-sha>"
}
```

After deployment, the CI/CD pipeline retrieves this file from Azure Static Web Apps.

Verification compares:

```text
Expected Version
    │
    └─ github.sha

Actual Version
    │
    └─ SWA /version.json
```

The deployment is successful only when both versions match.

The verification script is:

```text
scripts/verify-frontend-deployment.ps1
```

The script retries because a short delay can exist between completion of the deployment command and availability of the new static content.

The verification was tested for both cases:

```text
Expected == Actual
→ verification succeeds
```

and:

```text
Expected != Actual
→ retries
→ verification fails
```

The verification uses HTTP directly and does not depend on the current Azure CLI tenant or subscription.

---

# Deployment Verification vs. E2E Verification

Step 6 intentionally distinguishes deployment verification from end-to-end scenario verification.

## Deployment Verification

Deployment verification answers:

> Was the artifact created from this Git commit actually deployed?

Backend:

```text
github.sha
==
deployed OCI image tag
```

Frontend:

```text
github.sha
==
deployed /version.json
```

These checks are automated by GitHub Actions.

## End-to-End Verification

E2E verification answers:

> Can a user complete the intended application scenario through the deployed system?

The deployed application was manually revalidated using the Step 5 user scenario.

The verified flow included:

1. Opening the deployed React application.
2. Signing in through Microsoft Entra ID with MSAL.
3. Confirming the signed-in state.
4. Retrieving a Fortune.
5. Confirming role-based Fortune Management UI visibility.
6. Listing Fortune records as a `Fortune.Admin` user.
7. Adding a Fortune.
8. Confirming that the Fortune appears in the list.
9. Deleting the Fortune.
10. Confirming that the Fortune disappears from the list.
11. Confirming that users without `Fortune.Admin` cannot perform administrative operations.
12. Signing out.

Interactive Microsoft Entra authentication is not currently automated in GitHub Actions.

Automating that scenario would introduce additional concerns such as test-user lifecycle, MFA, Conditional Access, and credential handling.

For Step 6, automated CI/CD therefore ends with deployment verification, while the complete application E2E scenario remains a separate manual quality check.

---

# GitHub Actions Secrets

The CI/CD workflow requires the following GitHub Actions secrets:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID

ENTRA_TENANT_ID

VITE_ENTRA_TENANT_ID
VITE_ENTRA_CLIENT_ID
VITE_API_SCOPE

SWA_DEPLOYMENT_TOKEN
```

Their responsibilities are intentionally different.

| Secret | Purpose |
|---|---|
| `AZURE_CLIENT_ID` | GitHub Actions federated Azure identity |
| `AZURE_TENANT_ID` | Azure tenant used for GitHub OIDC login |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription containing deployed infrastructure |
| `ENTRA_TENANT_ID` | Microsoft Entra tenant used by Spring Security JWT issuer validation |
| `VITE_ENTRA_TENANT_ID` | Microsoft Entra tenant used by React/MSAL |
| `VITE_ENTRA_CLIENT_ID` | React/MSAL public-client application ID |
| `VITE_API_SCOPE` | Delegated backend API scope |
| `SWA_DEPLOYMENT_TOKEN` | Azure Static Web Apps deployment |

The authentication tenant can be different from the Azure subscription tenant.

This distinction is important in the current project architecture.

---

# CI/CD Failure Behavior

The pipeline is intended to fail rather than deploy or accept incomplete artifacts when prerequisite operations fail.

Examples include:

- Backend tests fail.
- Frontend tests fail.
- OCI image build fails.
- Azure login fails.
- ACR push fails.
- Backend deployment fails.
- Backend deployed-image verification fails.
- Backend Container App FQDN cannot be resolved during the frontend build.
- Frontend production build fails.
- Static Web Apps deployment fails.
- Frontend deployed-version verification fails.

This fail-fast behavior prevents a successful GitHub Actions run from masking an incomplete deployment.

---

# Verification Performed

Step 6 was validated through both automated pipeline execution and deployed application verification.

The completed checks include:

## GitHub Actions

```text
Backend tests                         PASS
Backend OCI build                     PASS
Azure OIDC login                      PASS
ACR push                              PASS
Azure Container Apps deployment       PASS
Backend deployment verification       PASS

Frontend tests                        PASS
Frontend production build             PASS
Azure Static Web Apps deployment      PASS
Frontend deployment verification      PASS
```

## Deployed Application

```text
Frontend Version == GitHub SHA         PASS
Sign in                               PASS
Sign out                              PASS
Fortune retrieval                     PASS
Role-based UI visibility              PASS
Fortune list                          PASS
Fortune creation                      PASS
Fortune deletion                      PASS
Backend authorization                 PASS
```

The deployed frontend version was confirmed to match the Git commit SHA processed by GitHub Actions.

---

# Result

Step 6 establishes a complete CI/CD path from a `main` branch push to verified Azure deployment.

```text
Local Development
        │
        ▼
Commit
        │
        ▼
Push to main
        │
        ▼
GitHub Actions CI/CD
        │
        ├────────────── Backend ──────────────┐
        │                                     │
        │ Test                                │
        │   ↓                                 │
        │ OCI Build                           │
        │   ↓                                 │
        │ ACR Push                            │
        │   ↓                                 │
        │ ACA Deploy                          │
        │   ↓                                 │
        │ Deployment Verification             │
        │                                     │
        └────────────── Frontend ─────────────┤
                                              │
          Test                                │
            ↓                                 │
          Production Build                    │
            ↓                                 │
          SWA Deploy                          │
            ↓                                 │
          Deployment Verification             │
                                              ▼
                                      Verified Azure Deployment
```

The pipeline verifies not only that deployment commands succeed, but also that the artifacts associated with the current Git commit are the artifacts actually deployed.

Complete user-scenario E2E verification remains a separate quality check.

---

## Related Documents

```text
README.md
docs/architecture.md
docs/deployment.md
docs/step04-data-access.md
docs/step05-entra-id-authentication-authorization.md
docs/troubleshooting.md
```
