# build-frontend.ps1
param(
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

$config = Import-PowerShellDataFile ".\config\$Environment.psd1"

$resourceGroup = $config.ResourceGroup
$containerApp = $config.ContainerAppName

if (-not $env:ENTRA_TENANT_ID) {
    throw "ENTRA_TENANT_ID environment variable is not set."
}

$template = Get-Content `
  "scripts/staticwebapp.config.template.json" `
  -Raw

$config = $template.Replace(
  "__OPENID_ISSUER__",
  "https://login.microsoftonline.com/$($env:ENTRA_TENANT_ID)/v2.0"
)

Set-Content `
  "frontend/public/staticwebapp.config.json" `
  $config

$fqdn = az containerapp show `
  --name $containerApp `
  --resource-group $resourceGroup `
  --query properties.configuration.ingress.fqdn `
  -o tsv

$env:VITE_API_BASE_URL = "https://$fqdn"

$commit = (git rev-parse --short HEAD).Trim()

$dirty = git status --porcelain

if ($dirty) {
    $buildVersion = "$commit-dirty"
}
else {
    $buildVersion = $commit
}

$env:VITE_BUILD_VERSION = $buildVersion

Push-Location frontend

npm run build

Pop-Location

Write-Host "API URL      : $env:VITE_API_BASE_URL"
Write-Host "Build Version: $env:VITE_BUILD_VERSION"