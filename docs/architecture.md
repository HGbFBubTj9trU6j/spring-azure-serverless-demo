# Architecture

This document describes the architecture of the `spring-azure-serverless-demo` project.

---

## Overview

The objective of this project is to incrementally evolve a Spring Boot application into a serverless architecture on Azure.

The current implementation consists of:

- React + Vite frontend
- Azure Static Web Apps (SWA)
- Spring Boot backend
- Azure Container Apps (ACA)
- Microsoft Entra ID authentication
- Infrastructure as Code (Bicep)

---

## Current Architecture

```text
┌─────────────────┐
│ Browser         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ React + Vite    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│ Azure Static Web Apps   │
└────────┬────────────────┘
         │ HTTPS
         ▼
┌─────────────────────────┐
│ Azure Container Apps    │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Spring Boot REST API    │
└─────────────────────────┘
```

---

## Local Development Architecture

During local development, both frontend and backend run on the developer workstation.

```text
┌─────────────────┐
│ React + Vite    │
│ localhost:5173  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Spring Boot     │
│ localhost:8080  │
└─────────────────┘
```

The frontend uses the local backend endpoint when no production API URL is supplied during the build process.

---

## Azure Infrastructure

The Azure environment is provisioned entirely through Bicep.

### Resources

```text
Resource Group
│
├── Azure Container Registry
│
├── User Assigned Managed Identity
│
├── Azure Static Web Apps
│
└── Azure Container Apps Environment
     │
     └── Azure Container App
```

---

## Frontend Layer

### Technology Stack

- React
- Vite
- TypeScript
- Azure Static Web Apps

### Responsibilities

- User interface
- User interaction
- Authentication entry point
- API consumption

The frontend is deployed as static assets to Azure Static Web Apps.

---

## Backend Layer

### Technology Stack

- Java 21
- Spring Boot
- Maven
- Cloud Native Buildpacks

### Responsibilities

- REST API endpoints
- Business logic
- Authentication context consumption
- Future data access integration

Current endpoints include:

```text
GET /api/hello
GET /api/version
```

---

## Container Platform

### Azure Container Apps

The backend is hosted on Azure Container Apps.

Benefits include:

- Serverless container hosting
- Automatic HTTPS ingress
- Simplified operations
- Managed scaling
- Native Azure integration

The container image is built using Spring Boot Buildpacks and stored in Azure Container Registry.

---

## Authentication Architecture

Authentication is implemented using Microsoft Entra ID and Azure Static Web Apps.

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
React Application
```

The authentication tenant is responsible for:

- Application registration
- User registration
- Token issuance
- Access control

Further details can be found in:

```text
docs/authentication.md
```

---

## Build and Deployment Flow

### Backend

```text
Source Code
      │
      ▼
Maven Wrapper
      │
      ▼
Spring Boot Buildpacks
      │
      ▼
OCI Image
      │
      ▼
Azure Container Registry
      │
      ▼
Azure Container Apps
```

### Frontend

```text
React Source
      │
      ▼
Vite Build
      │
      ▼
Static Assets
      │
      ▼
Azure Static Web Apps
```

---

## Infrastructure as Code

All infrastructure definitions are stored under:

```text
infra/
```

The deployment process is fully automated using:

- Bicep
- Azure CLI
- PowerShell

No manual Azure resource creation is required.

---

## Design Decisions

### Why Azure Static Web Apps?

Azure Static Web Apps provides:

- Global static content hosting
- Built-in authentication
- Simple deployment model
- Integrated developer experience

### Why Azure Container Apps?

Azure Container Apps provides:

- Serverless container execution
- Simplified operational model
- HTTPS ingress by default
- Fast application deployment

### Why Buildpacks Instead of Dockerfiles?

The project uses Cloud Native Buildpacks because they provide:

- Reduced maintenance
- Automatic runtime detection
- Consistent image creation
- Improved supply-chain management

---

## Security Considerations

Current security controls include:

- Microsoft Entra ID authentication
- Azure Static Web Apps authentication enforcement
- HTTPS communication
- Managed Identity for Azure resource access

Future enhancements include:

- API authorization
- JWT validation
- Role-based access control
- Data-layer authorization

---

## Planned Future Architecture

### Step 4 – Data Access

```text
React
  │
  ▼
Spring Boot API
  │
  ▼
Database
```

Candidate technologies:

- Azure SQL Database
- Azure Cosmos DB

### Step 5 – CI/CD

```text
GitHub
  │
  ▼
GitHub Actions
  │
  ▼
Azure Deployment
```

### Step 6 – API Authorization

```text
User
  │
  ▼
Microsoft Entra ID
  │
  ▼
Azure Static Web Apps
  │ Access Token
  ▼
Spring Boot API
  │ JWT Validation
  ▼
Protected Resources
```

### Step 7 – Identity Lifecycle Management

```text
User Registration
        │
        ▼
Identity Governance
        │
        ▼
Application Access
```

---

## Architecture Evolution

```text
Step 1
Infrastructure Provisioning
        │
        ▼
Step 2
Frontend Integration
        │
        ▼
Step 3
Authentication
        │
        ▼
Step 4
Data Access
        │
        ▼
Step 5
CI/CD
        │
        ▼
Step 6
API Authorization
        │
        ▼
Step 7
Identity Lifecycle Management
```

This repository intentionally evolves through these stages so that each topic can be implemented, validated, and documented independently.