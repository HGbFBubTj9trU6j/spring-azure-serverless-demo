param(
    [string]$Environment = "dev",

    [Parameter(Mandatory = $true)]
    [string]$ImageTag
)

$ErrorActionPreference = "Stop"

$config = Import-PowerShellDataFile ".\config\$Environment.psd1"

$acrName = $config.AcrName
$resourceGroup = $config.ResourceGroup
$containerAppName = $config.ContainerAppName
$acrLoginServer = "$acrName.azurecr.io"

$expectedImage = "$acrLoginServer/backend:$ImageTag"

Write-Host "========================================"
Write-Host "Verify Backend Deployment"
Write-Host "========================================"
Write-Host "Expected image: $expectedImage"
Write-Host ""

$revisionName = az containerapp revision list `
    --name $containerAppName `
    --resource-group $resourceGroup `
    --query "[?properties.active].name | [0]" `
    --output tsv

if ($LASTEXITCODE -ne 0 -or -not $revisionName) {
    throw "Failed to resolve the active Container App revision."
}

$revisionImage = az containerapp revision show `
    --name $containerAppName `
    --resource-group $resourceGroup `
    --revision $revisionName `
    --query "properties.template.containers[0].image" `
    --output tsv

if ($LASTEXITCODE -ne 0 -or -not $revisionImage) {
    throw "Failed to resolve the image used by the active Container App revision."
}

if ($revisionImage -ne $expectedImage) {
    throw "Backend deployment verification failed. Expected: $expectedImage Actual: $revisionImage"
}

Write-Host "Backend deployment verified."
Write-Host "Revision: $revisionName"
Write-Host "Image:    $revisionImage"
