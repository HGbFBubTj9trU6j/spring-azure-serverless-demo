$ErrorActionPreference = "Stop"

if (-not $env:SWA_DEPLOYMENT_TOKEN) {
    throw "SWA_DEPLOYMENT_TOKEN is not set."
}

Write-Host "========================================"
Write-Host "Deploy Frontend"
Write-Host "========================================"

Push-Location frontend

try {
    npx @azure/static-web-apps-cli deploy `
        ./dist `
        --env production `
        --deployment-token $env:SWA_DEPLOYMENT_TOKEN `
        --verbose

    if ($LASTEXITCODE -ne 0) {
        throw "Frontend deployment failed."
    }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Frontend deployment completed."
