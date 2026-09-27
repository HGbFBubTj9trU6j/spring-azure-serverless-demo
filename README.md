# spring-azure-serverless-demo
Spring BootのWebアプリをAzureのサーバーレス構成で育てていく検証

## Azure infrastructure

Azure infrastructure is defined with Bicep under the `infra` directory.

### Structure

    infra/
    ├── main.bicep
    ├── dev.bicepparam
    └── modules/
        ├── container-apps-environment.bicep
        ├── container-registry.bicep
        ├── container-app-identity.bicep
        └── container-app.bicep

The development environment consists of:

    Resource Group
    ├── Azure Container Registry
    ├── User Assigned Managed Identity
    │   └── AcrPull
    └── Azure Container Apps Express Environment
        └── Container App
            └── External HTTPS Ingress

### Build the Bicep template

Run from the repository root:

    az bicep build `
      --file .\infra\main.bicep

This generates `infra/main.json`.

`main.json` is a generated ARM template and is not committed to Git.

The following warning may currently be displayed:

    BCP081: Resource type does not have types available.

The project currently uses:

    Microsoft.App/managedEnvironments@2026-07-01
    Microsoft.App/containerApps@2026-07-01

Bicep may not yet have type information for these API versions. The warning does not prevent deployment, but Bicep cannot perform full compile-time property validation.

### Preview infrastructure changes

    az deployment sub what-if `
      --name spring-azure-serverless-demo `
      --location japaneast `
      --parameters .\infra\dev.bicepparam

The following diagnostic may appear:

    NestedDeploymentShortCircuited

The Container App module receives outputs from other modules, including the Container Apps Environment ID, ACR login server, and Managed Identity ID.

These values may require ARM `reference()` evaluation. What-if cannot always fully evaluate these values before deployment and may therefore skip validation of the nested Container App deployment.

This diagnostic does not by itself indicate that the deployment will fail.

### Deploy

    az deployment sub create `
      --name spring-azure-serverless-demo `
      --location japaneast `
      --parameters .\infra\dev.bicepparam

The deployment is subscription-scoped because `main.bicep` creates the Resource Group itself.

## Push the backend image to ACR

Log in to ACR:

    az acr login `
      --name springazureserverlessdemoacr `
      --resource-group spring-azure-serverless-demo-rg

Tag the local image:

    docker tag backend:0.0.1-SNAPSHOT `
      springazureserverlessdemoacr.azurecr.io/backend:0.0.1-SNAPSHOT

Push the image:

    docker push `
      springazureserverlessdemoacr.azurecr.io/backend:0.0.1-SNAPSHOT

Verify the repository:

    az acr repository list `
      --name springazureserverlessdemoacr `
      --output table

Verify the image tag:

    az acr repository show-tags `
      --name springazureserverlessdemoacr `
      --repository backend `
      --output table

The expected tag is:

    0.0.1-SNAPSHOT

## Verify the Container App

List the Container Apps:

    az containerapp list `
      --resource-group spring-azure-serverless-demo-rg `
      --query "[].{name:name,state:properties.provisioningState,fqdn:properties.configuration.ingress.fqdn}" `
      --output table

Get the Container App FQDN:

    $fqdn = az containerapp show `
      --name spring-azure-serverless-dev-ca `
      --resource-group spring-azure-serverless-demo-rg `
      --query properties.configuration.ingress.fqdn `
      --output tsv

Verify the Spring Boot endpoint:

    Invoke-RestMethod "https://$fqdn/hello"

Expected response:

    message
    -------
    hello

## Development resource names

| Resource | Name |
| --- | --- |
| Resource Group | `spring-azure-serverless-demo-rg` |
| Container Registry | `springazureserverlessdemoacr` |
| Container Apps Environment | `spring-azure-serverless-demo-dev-cae` |
| Managed Identity | `spring-azure-serverless-demo-dev-id` |
| Container App | `spring-azure-serverless-dev-ca` |

The Container App name is shorter than the other resource names because Azure Container Apps limits application names to 32 characters.

## Azure CLI defaults

Azure CLI defaults can affect commands that do not explicitly specify a Resource Group.

Check configured defaults with:

    az configure --list-defaults

This project explicitly specifies the Resource Group where practical to avoid dependence on local Azure CLI defaults.