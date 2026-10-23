param(
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

$config = Import-PowerShellDataFile ".\config\$Environment.psd1"

$location = $config.Location
$acrName = $config.AcrName
$resourceGroup = $config.ResourceGroup
$containerAppName = $config.ContainerAppName
$containerAppsEnvironmentName = $config.ContainerAppsEnvironmentName
$identityName = $config.IdentityName
$sqlServerName = $config.SqlServerName
$sqlDatabaseName = $config.SqlDatabaseName
$acrLoginServer = "$acrName.azurecr.io"

$dirty = git status --porcelain

if ($dirty) {
    $tag = "$(git rev-parse --short HEAD)-dirty"
}
else {
    $tag = git rev-parse --short HEAD
}

$image = "$acrLoginServer/backend:$tag"
$containerImage = "backend:$tag"

Write-Host "========================================"
Write-Host "Deploy Backend"
Write-Host "========================================"
Write-Host "Image: $image"
Write-Host ""

Write-Host "Logging in to ACR..."

az acr login `
    --name $AcrName

if ($LASTEXITCODE -ne 0) {
    throw "ACR login failed."
}

Write-Host "Pushing image..."

docker push $image

if ($LASTEXITCODE -ne 0) {
    throw "Docker push failed."
}

$environmentId = az containerapp env show `
    --name $ContainerAppsEnvironmentName `
    --resource-group $ResourceGroup `
    --query id `
    -o tsv

$identityId = az identity show `
    --name $IdentityName `
    --resource-group $ResourceGroup `
    --query id `
    -o tsv

$identityClientId = az identity show `
    --name $IdentityName `
    --resource-group $ResourceGroup `
    --query clientId `
    -o tsv

Write-Host "Deploying Container App..."

az deployment group create `
    --name backend `
    --resource-group $ResourceGroup `
    --template-file .\infra\modules\container-app.bicep `
    --parameters `
        location=$location `
        containerAppName=$ContainerAppName `
        containerAppsEnvironmentId=$environmentId `
        containerRegistryLoginServer=$acrLoginServer `
        containerImage=$containerImage `
        identityId=$identityId `
        identityClientId=$identityClientId `
        sqlServerName=$sqlServerName `
        sqlDatabaseName=$sqlDatabaseName

if ($LASTEXITCODE -ne 0) {
    throw "Container App deployment failed."
}

Write-Host ""
Write-Host "Deployment completed."
Write-Host "Image: $image"

az containerapp show `
    --name $ContainerAppName `
    --resource-group $ResourceGroup `
    --query "{fqdn:properties.configuration.ingress.fqdn,image:properties.template.containers[0].image}" `
    --output table