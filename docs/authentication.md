# Authentication

This document describes the Microsoft Entra ID authentication implementation used by this sample application.

---

## Overview

Azure Static Web Apps (SWA) is integrated with Microsoft Entra ID to protect access to the application.

Authentication is performed using a dedicated Microsoft Entra ID tenant that contains:

- App Registration
- OpenID Connect configuration
- User registration and access control policies

Only registered users can access the application.

---

## Architecture

```text
External User
     │
     ▼
Home Tenant
     │
     ▼
Authentication Tenant
     │
     ▼
Azure Static Web Apps
     │
     ▼
React Application
```

The authentication tenant is responsible for:

- Application registration
- Token issuance
- Access control
- Authentication policies

---

## Azure Static Web Apps Configuration

The application uses a custom Microsoft Entra ID identity provider configured through:

```json
{
  "auth": {
    "identityProviders": {
      "azureActiveDirectory": {
        "registration": {
          "openIdIssuer": "...",
          "clientIdSettingName": "...",
          "clientSecretSettingName": "..."
        }
      }
    }
  }
}
```

Configuration values are injected during the frontend build process.

Secrets are stored in Azure Static Web Apps application settings and are not committed to source control.

---

## Authentication Scenarios

### Scenario 1 – Registered External User

A user belonging to another Microsoft Entra ID tenant accesses the application.

```text
User
 ↓
Azure Static Web Apps
 ↓
Authentication Tenant
 ↓
Home Tenant Authentication
 ↓
Authentication Tenant Validation
 ↓
Token Issuance
 ↓
Application Access
```

Expected result:

- Login succeeds
- User is redirected to the application
- Application becomes available

---

### Scenario 2 – Registered Native Tenant User

A user created directly in the authentication tenant accesses the application.

```text
User
 ↓
Azure Static Web Apps
 ↓
Authentication Tenant
 ↓
Authentication
 ↓
Token Issuance
 ↓
Application Access
```

Expected result:

- Login succeeds
- User is redirected to the application
- Application becomes available

---

### Scenario 3 – Unregistered User

A user who is not registered in the authentication tenant attempts to sign in.

```text
User
 ↓
Azure Static Web Apps
 ↓
Authentication Tenant
 ↓
Authentication Denied
```

Expected result:

- Login fails
- Application access is denied

---

## Validation Results

| Scenario | Expected Result | Validation |
|-----------|-----------|-----------|
| Registered External User | Access Granted | ✅ |
| Registered Native Tenant User | Access Granted | ✅ |
| Unregistered User | Access Denied | ✅ |

---

## Access Control Verification

The validation confirmed that application access is controlled by user registration within the authentication tenant rather than by email domain.

| User Type | Registration Status | Result |
|------------|------------|------------|
| External User | Registered | Access Granted |
| Native Tenant User | Registered | Access Granted |
| Unregistered User | Not Registered | Access Denied |

This demonstrates that the authentication tenant acts as the authorization boundary for application access.

---

## User Identity Verification

After a successful sign-in, the following endpoint can be used to inspect the authenticated user context:

```text
/.auth/me
```

The endpoint was used to verify:

- Authenticated user information
- Authentication provider
- Token audience
- Token issuer
- Successful identity propagation to SWA

Example response:

```json
{
  "clientPrincipal": {
    "identityProvider": "aad",
    "userRoles": [
      "authenticated"
    ]
  }
}
```

---

## Security Considerations

### Secrets

The following values must never be committed to source control:

- Client Secret
- Deployment Token
- Tenant-specific secrets

These values should be stored in:

- Azure Static Web Apps Application Settings
- GitHub Secrets
- Azure Key Vault

### Authentication Boundary

Current authentication protection applies at the Azure Static Web Apps layer.

Authenticated users can access the application UI.

API-level authorization is not yet implemented.

---

## Step Completion Criteria

The following validation activities were completed:

- [x] Microsoft Entra ID integration
- [x] Login functionality
- [x] Logout functionality
- [x] Authentication redirect
- [x] User identity verification through `/.auth/me`
- [x] External user authentication
- [x] Native tenant user authentication
- [x] Unregistered user rejection
- [x] Access control verification

---

## Current Limitations

The following capabilities are intentionally out of scope for this stage.

### Identity Lifecycle Management

- User onboarding
- User invitation workflows
- Self-service registration
- Approval workflows
- User deprovisioning
- Access reviews

### API Authentication and Authorization

- SWA-to-API token propagation
- JWT validation
- Spring Security integration
- Role-based authorization
- API-level access control

These topics are planned for future stages of the project.

---

## Future Enhancements

Planned improvements include:

- API authentication using OAuth 2.0 access tokens
- JWT validation in Spring Boot
- User and role-based authorization
- Identity lifecycle management
- Automated user onboarding workflows