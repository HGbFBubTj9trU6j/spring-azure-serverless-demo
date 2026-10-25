# Authentication

This document describes the current authentication architecture, trust boundaries, verified user scenarios, and known limitations of the spring-azure-serverless-demo application.

Authentication setup and reproduction procedures are documented separately in:

```text
docs/authentication-setup.md
```

Deployment procedures are documented in:

```text
docs/deployment.md
```

---

## Overview

The application uses Microsoft Entra ID authentication through Azure Static Web Apps.

Azure Static Web Apps is currently the authenticated entry point for the React application.

```text
User
  │
  ▼
Microsoft Entra ID
  │
  ▼
Azure Static Web Apps
  │
  ▼
React application
```

The current implementation authenticates users before allowing access to the deployed frontend.

The Spring Boot backend running on Azure Container Apps does not yet independently validate the authenticated user's token.

Backend API authentication and authorization are planned for a later roadmap step.

---

## Authentication Architecture

The deployed authentication flow is:

```text
Browser
  │
  ▼
Azure Static Web Apps
  │
  ├── Microsoft Entra ID authentication
  │
  └── React + Vite frontend
  │
  │ HTTPS / CORS
  ▼
Azure Container Apps
  │
  └── Spring Boot REST API
```

Azure Static Web Apps is responsible for:

- Starting the sign-in flow
- Redirecting the user to Microsoft Entra ID
- Processing the authentication callback
- Providing the authenticated frontend entry point
- Exposing authenticated user information through `/.auth/me`
- Providing the logout endpoint

The React application relies on the authentication state established by Azure Static Web Apps.

---

## Tenant Boundary

The application separates the Azure subscription resources from the authentication resources.

```text
Azure Subscription Tenant
  │
  ├── Azure Static Web Apps
  ├── Azure Container Apps
  ├── Azure Container Registry
  ├── Azure SQL Database
  └── User Assigned Managed Identity

Authentication Tenant
  │
  ├── App Registration
  ├── Service Principal
  └── Registered users
```

The Azure subscription tenant contains the deployed application infrastructure.

The authentication tenant contains the Microsoft Entra ID resources used to authenticate users of Azure Static Web Apps.

This separation allows the Azure environment and the authentication environment to have independent lifecycles.

For example, the Azure resources can be rebuilt in another subscription while the existing App Registration is reused where appropriate.

---

## Authentication Components

The current authentication configuration uses the following components.

### Azure Static Web Apps

Azure Static Web Apps provides:

- Frontend hosting
- Authentication integration
- Authentication callback handling
- Authenticated user information
- Logout handling

### Microsoft Entra ID App Registration

The App Registration identifies the application to Microsoft Entra ID.

Its configuration includes:

- Application Client ID
- Redirect URI
- ID-token configuration
- Client credential used by Azure Static Web Apps

### Service Principal

The Service Principal represents the application within the authentication tenant.

The identity deployment script creates or reuses the Service Principal associated with the App Registration.

### Client Secret

Azure Static Web Apps uses a Client Secret associated with the App Registration.

The Client Secret is configured as an Azure Static Web Apps application setting.

The secret value must not be committed to the repository or written to generated source files.

---

## Authentication Flow

The current sign-in flow is:

```text
Unauthenticated user
  │
  ▼
Azure Static Web Apps
  │
  ▼
Microsoft Entra ID authorization endpoint
  │
  ▼
Authentication Tenant
  │
  ▼
User authentication
  │
  ▼
Azure Static Web Apps callback
  │
  ▼
Authenticated React application
```

The expected callback URI follows this form:

```text
https://<STATIC_WEB_APP_HOSTNAME>/.auth/login/aad/callback
```

The callback URI belongs to Azure Static Web Apps rather than directly to the React application.

---

## Authentication Entry Point

The deployed Azure Static Web Apps application is the authenticated user entry point.

Unauthenticated access starts the configured Microsoft Entra ID authentication flow.

After successful authentication, the user is redirected back to the deployed application.

The frontend can then retrieve the authentication information exposed by Azure Static Web Apps.

---

## User Registration Boundary

Access is determined by whether the user can authenticate through the configured authentication tenant.

The validation performed for this project confirms that access is associated with registration in the authentication tenant rather than the user's email domain alone.

The following user types were verified:

- External user registered in the authentication tenant
- Native user in the authentication tenant
- User not registered in the authentication tenant

---

## Verified Authentication Scenarios

| User type | Registered in authentication tenant | Expected result | Verified |
| --- | ---: | --- | ---: |
| External tenant user | Yes | Access granted | Yes |
| Native authentication tenant user | Yes | Access granted | Yes |
| Unregistered user | No | Access denied | Yes |

The verified behavior demonstrates that both native and external users can access the application when they are registered in the authentication tenant.

A user who is not registered in the authentication tenant is denied access.

---

## Identity Verification

After successful authentication, authenticated user information can be inspected through:

```text
https://<STATIC_WEB_APP_HOSTNAME>/.auth/me
```

The endpoint was used to verify:

- Authenticated user information
- Authentication provider
- Token audience
- Token issuer
- User roles
- Successful identity handling by Azure Static Web Apps

Real user details, tenant IDs, client IDs, object IDs, and token values must not be included in committed documentation.

The `/.auth/me` endpoint is used for verification and diagnostics.

The repository must not contain copied production responses from this endpoint.

---

## Logout

Azure Static Web Apps provides the logout path used by the application.

A successful logout verification confirms that:

- The authenticated application session is ended.
- The user leaves the authenticated application flow.
- Accessing the protected application again starts the configured authentication flow.

Logout verification is part of the Step 3 exit criteria.

---

## Authentication and Application Authorization

Authentication answers:

```text
Who is the user?
```

Authorization answers:

```text
What is the user allowed to do?
```

The current implementation establishes user authentication at the Azure Static Web Apps layer.

It does not yet implement backend API authorization based on the authenticated user's identity or roles.

The current Fortune Management UI is therefore not protected by backend-enforced application roles.

Backend authorization is planned for a later roadmap step.

---

## Current Trust Boundary

The current user trust boundary is:

```text
User
  │
  ▼
Microsoft Entra ID
  │
  ▼
Azure Static Web Apps
```

Azure Static Web Apps protects the deployed frontend entry point.

However, the Azure Container Apps backend is deployed as a separate API endpoint.

The backend does not yet independently verify that a request originated from an authenticated Azure Static Web Apps user.

Therefore:

```text
Authenticated access to the frontend
```

does not currently mean:

```text
Independent authentication and authorization at the backend API
```

This limitation is intentional in the current roadmap and is addressed in a later step.

---

## Backend API Boundary

The current frontend-to-backend request flow is:

```text
Authenticated user
  │
  ▼
Azure Static Web Apps
  │
  ▼
React frontend
  │
  ▼
Azure Container Apps ingress
  │
  ▼
Spring Boot REST API
```

The browser calls the Azure Container Apps endpoint configured during the frontend build.

CORS permits expected frontend origins, including the deployed Azure Static Web Apps origin.

CORS is a browser access-control mechanism.

CORS is not an authentication or authorization mechanism.

The backend API currently relies on the frontend entry-point architecture rather than independently validating a user token.

---

## User Identity and Database Identity

The application uses two separate identity concepts.

### User Identity

The user's identity is established through:

```text
Microsoft Entra ID
  │
  ▼
Azure Static Web Apps
```

This identity determines whether the user can access the authenticated frontend.

### Application Database Identity

The backend's database identity is established through:

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

This identity allows the Spring Boot application to access Azure SQL Database.

The database does not receive or authorize the end user's identity in the current architecture.

Therefore:

```text
User identity
```

and:

```text
Application database identity
```

are separate security boundaries.

For data-access architecture and database permissions, see:

```text
docs/step04-data-access.md
```

---

## Azure SQL Authentication Boundary

The deployed Spring Boot backend authenticates with Azure SQL Database through a User Assigned Managed Identity.

The application does not use a database password for the deployed backend connection.

The Managed Identity receives only the object-level permissions required by the current Fortune functionality.

The current database permissions are:

```text
SELECT
INSERT
DELETE
```

on:

```text
dbo.fortunes
```

These permissions belong to the application identity, not to the authenticated frontend user.

---

## Build-time Authentication Configuration

The Azure Static Web Apps authentication configuration is generated during the frontend build.

The source template is stored in:

```text
scripts/staticwebapp.config.template.json
```

The generated configuration is written to:

```text
frontend/dist/staticwebapp.config.json
```

The build requires:

```text
ENTRA_TENANT_ID
```

The tenant-specific value is supplied during the build process rather than being hard-coded into the committed generated output.

Files under:

```text
frontend/dist
```

are generated artifacts and must not be committed.

---

## Azure Static Web Apps Application Settings

Azure Static Web Apps must contain the application settings referenced by the generated authentication configuration.

These settings include the values required by the custom Microsoft Entra ID authentication provider.

Sensitive values, including the Client Secret, are stored outside the repository.

The application settings are configured through the authentication setup process.

For the setup procedure, see:

```text
docs/authentication-setup.md
```

---

## App Registration Lifecycle

The App Registration belongs to the authentication tenant.

The identity deployment process reuses the existing App Registration when possible.

This supports rebuilding the Azure application environment while retaining the authentication identity configuration.

When a newly deployed Azure Static Web App requires authentication configuration, the existing App Registration can be updated with the required redirect URI and related settings.

The App Registration lifecycle is independent from the Azure subscription resource lifecycle.

---

## Client Secret Lifecycle

Client Secret values can be viewed only when they are created.

An existing secret value cannot be retrieved later.

The authentication setup scripts therefore distinguish between:

- Reusing an existing credential
- Creating an additional Client Secret
- Configuring a newly deployed Azure Static Web App

The default behavior avoids creating unnecessary duplicate credentials.

An additional secret can be created when required for a rebuilt Azure environment.

Existing credentials are preserved unless explicitly removed outside the current setup scripts.

Secrets must be handled only long enough to configure the target Azure Static Web App.

---

## Authentication Exit Criteria

The authentication implementation is considered verified when:

- Azure Static Web Apps is integrated with Microsoft Entra ID.
- Login succeeds for a registered external user.
- Login succeeds for a registered native authentication-tenant user.
- Access is denied for an unregistered user.
- The post-login application redirection succeeds.
- Authenticated identity information is available through `/.auth/me`.
- Logout succeeds.
- No Client Secret or token value is committed to the repository.

---

## Current Limitations

The current authentication implementation has the following intentional limitations:

- The backend does not independently validate the authenticated user's token.
- The backend does not implement user-based API authorization.
- Fortune Management operations are not protected by backend-enforced application roles.
- The end user's identity is not propagated to Azure SQL Database.
- Database access uses the application's Managed Identity rather than the end user's identity.
- Identity lifecycle automation is not yet implemented.
- User invitation and onboarding are not yet automated.
- Access reviews are not yet implemented.

These limitations are addressed by later roadmap steps.

---

## Future Direction

A later roadmap step introduces backend API authentication and authorization.

Planned areas include:

- Azure Static Web Apps to Azure Container Apps token propagation
- JWT validation in Spring Boot
- Spring Security integration
- API authentication
- API authorization
- Role-based access control
- Protected Fortune Management operations

Identity lifecycle work is planned separately and includes areas such as:

- User invitation
- Onboarding
- Offboarding
- Self-service sign-up
- Access reviews

---

## Security Requirements

Do not commit:

- Client Secrets
- Access tokens
- Refresh tokens
- Real `/.auth/me` responses
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

- Azure Static Web Apps application settings
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

Troubleshooting:

```text
docs/troubleshooting.md
```

Step 3 implementation history:

```text
docs/step03-authentication.md
```

Step 4 data-access and Managed Identity details:

```text
docs/step04-data-access.md
```

Testing and verification definitions:

```text
docs/testing.md
```
