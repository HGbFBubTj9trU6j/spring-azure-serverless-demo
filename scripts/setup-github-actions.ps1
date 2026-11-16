param(
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

$config = Import-PowerShellDataFile ".\config\$Environment.psd1"

$resourceGroup = $config.ResourceGroup
$containerAppName = $config.ContainerAppName
$githubActionsIdentityName = $config.GithubActionsIdentityName

Write-Host "========================================"
Write-Host "Set Up GitHub Actions"
Write-Host "========================================"
Write-Host "GitHub Actions identity: $githubActionsIdentityName"
Write-Host "Container App:           $containerAppName"
Write-Host ""

az deployment group create `
    --resource-group $resourceGroup `
    --template-file .\infra\modules\github-actions-container-app-role.bicep `
    --parameters `
        containerAppName=$containerAppName `
        githubActionsIdentityName=$githubActionsIdentityName `
    --output none

if ($LASTEXITCODE -ne 0) {
    throw "GitHub Actions Container Apps Contributor role assignment failed."
}

Write-Host "GitHub Actions setup completed."
