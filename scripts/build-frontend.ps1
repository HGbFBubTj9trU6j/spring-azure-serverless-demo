# build-frontend.ps1
param(
    [string]$Environment = "dev",
    [string]$BuildVersion
)

$ErrorActionPreference = "Stop"

$config = Import-PowerShellDataFile ".\config\$Environment.psd1"

$resourceGroup = $config.ResourceGroup
$containerApp = $config.ContainerAppName

Copy-Item `
  "scripts/staticwebapp.config.template.json" `
  "frontend/public/staticwebapp.config.json" `
  -Force

$fqdn = az containerapp show `
  --name $containerApp `
  --resource-group $resourceGroup `
  --query properties.configuration.ingress.fqdn `
  -o tsv

if ($LASTEXITCODE -ne 0) {
    throw "Failed to resolve the backend Container App FQDN."
}

if ([string]::IsNullOrWhiteSpace($fqdn)) {
    throw "Backend Container App FQDN is empty."
}

$env:VITE_API_BASE_URL = "https://$fqdn"

if ($BuildVersion) {
    $buildVersionValue = $BuildVersion
}
else {
    $commit = (git rev-parse --short HEAD).Trim()
    $dirty = git status --porcelain

    if ($dirty) {
        $buildVersionValue = "$commit-dirty"
    }
    else {
        $buildVersionValue = $commit
    }
}

$env:VITE_BUILD_VERSION = $buildVersionValue

@{
    version = $buildVersionValue
} |
        ConvertTo-Json |
        Set-Content `
        "frontend/public/version.json" `
        -Encoding utf8

Push-Location frontend

npm run build

Pop-Location

Remove-Item `
    "frontend/public/version.json" `
    -ErrorAction SilentlyContinue

Write-Host "API URL      : $env:VITE_API_BASE_URL"
Write-Host "Build Version: $env:VITE_BUILD_VERSION"
