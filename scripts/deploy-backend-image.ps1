param(
    [string]$Environment = "dev",

    [Parameter(Mandatory = $true)]
    [string]$ImageTag
)

$ErrorActionPreference = "Stop"

$config = Import-PowerShellDataFile "./config/$Environment.psd1"

$acrName = $config.AcrName
$resourceGroup = $config.ResourceGroup
$containerAppName = $config.ContainerAppName
$acrLoginServer = "$acrName.azurecr.io"
$image = "$acrLoginServer/backend:$ImageTag"

Write-Host "========================================"
Write-Host "Deploy Backend Image"
Write-Host "========================================"
Write-Host "Container App: $containerAppName"
Write-Host "Image:         $image"
Write-Host ""

az containerapp update `
    --name $containerAppName `
    --resource-group $resourceGroup `
    --image $image `
    --output none

if ($LASTEXITCODE -ne 0) {
    throw "Container App image update failed."
}

Write-Host "Container App image update completed."
