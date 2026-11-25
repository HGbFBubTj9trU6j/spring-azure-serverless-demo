# Authentication

This document describes the current user authentication and application authorization architecture of the spring-azure-serverless-demo application.

Authentication setup and reproduction procedures are documented separately in:

```text
docs/authentication-setup.md
```

Deployment procedures are documented in:

```text
docs/deployment.md
```

Step 5 implementation details are documented in:

```text
docs/step05-entra-id-authentication-authorization.md
```

---

## Overview

The application uses Microsoft Entra ID for user authentication.

The React SPA performs sign-in and access-token acquisition with MSAL. Azure Static Web Apps hosts the generated frontend, but it is not the authentication boundary for the application.

The current user-to-API flow is:

```text
User
  │
  ▼
React + MSAL
  │
  ▼
Microsoft Entra ID
  │
  ├─ ID token / authenticated SPA session
  │
  └─ Backend API access token
            │
            ▼
Azure Container Apps
            │
            ▼
Spring Security OAuth 2.0 Resource Server
            │
            ├─ JWT validation
            ├─ access_as_user
            └─ Fortune.Admin
```

Authentication and authorization are deliberately separated:

- Authentication establishes who the signed-in user is.
- The delegated `access_as_user` scope represents access to the backend API on behalf of the signed-in user.
- The `Fortune.Admin` app role protects administrative Fortune operations.
- UI visibility is aligned with the user's role, but backend authorization remains the security boundary.

---

## Authentication Architecture

The deployed authentication flow is:

```text
Browser
  │
  ▼
Azure Static Web Apps
  │
  └─ React + Vite frontend
          │
          ▼
        MSAL
          │
          ▼
   Microsoft Entra ID
          │
          ▼
   Backend API access token
          │ HTTPS / CORS
          ▼
Azure Container Apps
          │
          ▼
Spring Boot REST API
          │
          ▼
Spring Security JWT validation
```

Azure Static Web Apps is responsible for static frontend hosting and deployment. React/MSAL is responsible for the interactive user authentication flow and access-token acquisition.

Spring Boot independently authenticates protected API requests by validating Microsoft Entra ID access tokens.

---

## Microsoft Entra ID Application Registrations

The current design uses two application registrations.

### Backend API Application

The backend API application registration represents the Spring Boot API.

It:

- Exposes the delegated `access_as_user` scope.
- Defines the `Fortune.Admin` app role.
- Provides the audience expected by the Spring Security Resource Server.

### React SPA Application

The React application registration represents the browser-based SPA.

It:

- Uses the Authorization Code Flow with PKCE through MSAL.
- Contains SPA redirect URIs for supported local and deployed frontend origins.
- Is granted delegated permission to the backend API's `access_as_user` scope.

No client secret is required by the React SPA authentication flow.

---

## Authentication Flow

The sign-in flow is:

```text
Unauthenticated user
  │
  ▼
React application
  │
  ▼
MSAL
  │
  ▼
Microsoft Entra ID authorization endpoint
  │
  ▼
User authentication
  │
  ▼
Authorization Code Flow with PKCE
  │
  ▼
Authenticated React application
```

After sign-in, MSAL can acquire an access token for the backend API by requesting the configured API scope.

The same MSAL-based model is used for local development and the Azure-hosted frontend, reducing environment-specific authentication behavior.

---

## Backend API Authentication

Protected requests include a bearer access token:

```text
Authorization: Bearer <access-token>
```

The Spring Boot backend is configured as an OAuth 2.0 Resource Server.

Spring Security validates the JWT before protected requests reach application logic. Validation includes the Microsoft Entra ID issuer configuration and the token audience expected by the backend API.

`ENTRA_TENANT_ID` is supplied to the deployed backend so that the application can construct the Microsoft Entra issuer configuration.

An unauthenticated request to a protected backend API is therefore expected to receive:

```text
401 Unauthorized
```

This is intentional and confirms that backend authentication is enforced independently of frontend hosting.

---

## Delegated API Access

The backend API exposes:

```text
access_as_user
```

The React SPA requests an access token containing this delegated permission and sends that token when calling protected backend APIs.

This scope represents normal signed-in user access to the backend API. It is distinct from administrative authorization.

---

## Role-Based Authorization

Administrative Fortune operations are protected by the app role:

```text
Fortune.Admin
```

The role is defined on the backend API application registration and assigned through Microsoft Entra ID.

The backend checks the token's `roles` claim and enforces the administrative boundary with Spring Security.

Conceptually:

```text
Signed-in user
  │
  ├─ access_as_user
  │      └─ normal protected API access
  │
  └─ Fortune.Admin
         └─ Fortune Management operations
```

The React frontend also uses role information to control whether Fortune Management UI elements are displayed. Frontend visibility is a user-experience control only; the backend remains responsible for authorization.

---

## Backend API Boundary

The backend is deployed as an independently reachable Azure Container Apps endpoint.

The security boundary is therefore the backend's own Spring Security configuration, not the fact that a request came from Azure Static Web Apps.

CORS permits the expected local and deployed frontend origins. CORS is a browser access-control mechanism and is not used as authentication or authorization.

The current request flow is:

```text
Authenticated user
  │
  ▼
React + MSAL
  │
  ▼
Backend API access token
  │
  ▼
Azure Container Apps ingress
  │
  ▼
Spring Security
  │
  ├─ authenticate JWT
  └─ authorize scope / role
```

---

## Tenant Boundary

The Azure subscription resources and Microsoft Entra ID resources can have independent lifecycles.

```text
Azure Subscription
  │
  ├─ Azure Static Web Apps
  ├─ Azure Container Apps
  ├─ Azure Container Registry
  ├─ Azure SQL Database
  └─ User Assigned Managed Identities

Microsoft Entra tenant used by the application
  │
  ├─ React SPA App Registration
  ├─ Backend API App Registration
  ├─ Service Principals
  ├─ Delegated API scope
  ├─ App role
  └─ Users / role assignments
```

The Azure environment can be rebuilt while the Microsoft Entra application registrations are reused or reconfigured as appropriate.

---

## User Identity and Database Identity

User authentication and backend database authentication are separate security boundaries.

### User Identity

```text
User
  │
  ▼
Microsoft Entra ID
  │
  ▼
MSAL access token
  │
  ▼
Spring Security
```

This identity is used for backend API authentication and application authorization.

### Application Database Identity

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

The deployed backend does not store a database password.

The database receives the application's Managed Identity rather than the end user's identity. The Managed Identity has only the object-level permissions required by the Fortune functionality:

```text
SELECT
INSERT
DELETE
```

on:

```text
dbo.fortunes
```

For data-access architecture and database permissions, see:

```text
docs/step04-data-access.md
```

---

## Build-Time Authentication Configuration

The frontend build receives the Microsoft Entra configuration needed by MSAL through environment variables.

The relevant Vite values include:

```text
VITE_ENTRA_TENANT_ID
VITE_ENTRA_CLIENT_ID
VITE_API_SCOPE
```

The deployment scripts prepare the frontend build without hardcoding environment-specific identity values into the application source.

Generated files under:

```text
frontend/dist
```

are build artifacts and must not be committed.

---

## Authentication Setup and Reproduction

The setup procedure for the two App Registrations, delegated API permission, and app role is maintained in:

```text
docs/authentication-setup.md
```

The setup process includes the information required to reproduce:

- The backend API App Registration.
- The React SPA App Registration.
- The `access_as_user` delegated scope.
- Delegated permission from the SPA to the backend API.
- The `Fortune.Admin` app role.
- Required SPA redirect URIs.
- Application configuration used by the frontend and backend.

---

## Authentication and Authorization Verification

The current implementation is considered verified when the following behaviors are confirmed:

- A configured user can sign in through the React application with MSAL.
- The React application can acquire a backend API access token.
- A protected backend endpoint rejects unauthenticated requests with `401 Unauthorized`.
- A valid access token allows normal protected API access.
- The `Fortune.Admin` role allows protected Fortune Management operations.
- A user without the administrative role cannot perform protected administrative operations.
- The frontend hides administrative UI elements when the user does not have the required role.
- Logout completes successfully.
- No access token, refresh token, client secret, or other credential is committed to the repository.

Deployment verification and application E2E scenario verification are separate from these authentication and authorization checks.

---

## Current Limitations

The current identity design intentionally retains the following boundaries:

- The end user's identity is not propagated to Azure SQL Database.
- Database access uses the backend application's User Assigned Managed Identity.
- Identity lifecycle automation is not yet implemented.
- User invitation and onboarding are not yet automated.
- Access reviews are not yet implemented.

These are separate roadmap concerns and do not mean that backend API authentication or role-based authorization is missing from the current implementation.

---

## Future Direction

Future identity work focuses on lifecycle management rather than adding the already implemented backend authentication boundary.

Planned areas include:

- User invitation
- Onboarding
- Offboarding
- Self-service sign-up
- Access reviews

---

## Security Requirements

Do not commit:

- Access tokens
- Refresh tokens
- Client secrets used by tools or other integrations
- Tenant-specific secret values
- Azure Static Web Apps deployment tokens
- Real user identities
- Private certificates or keys
- Local environment files containing credentials

Avoid placing real identity values in:

- README files
- Example output
- Test fixtures
- Screenshots
- Generated files tracked by Git
- Git commit messages

Use appropriate secret-storage locations such as:

- GitHub Actions secrets
- Azure Key Vault
- Local user environment variables

---

## Related Documentation

Authentication setup and reproduction:

```text
docs/authentication-setup.md
```

Current system architecture:

```text
docs/architecture.md
```

Deployment procedures:

```text
docs/deployment.md
```

Step 4 data-access and Managed Identity details:

```text
docs/step04-data-access.md
```

Step 5 Microsoft Entra ID authentication and authorization:

```text
docs/step05-entra-id-authentication-authorization.md
```

Step 6 CI/CD and deployment verification:

```text
docs/step06-cicd.md
```

Troubleshooting:

```text
docs/troubleshooting.md
```
