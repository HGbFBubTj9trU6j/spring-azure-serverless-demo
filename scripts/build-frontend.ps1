# build-frontend.ps1

$resourceGroup = "spring-azure-serverless-demo-rg"
$containerApp = "spring-azure-serverless-dev-ca"

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