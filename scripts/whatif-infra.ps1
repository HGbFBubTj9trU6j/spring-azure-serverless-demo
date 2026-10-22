$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "Infrastructure What-If"
Write-Host "========================================"

$entraAdminJson = az ad signed-in-user show `
    --query "{login:userPrincipalName,objectId:id}" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to query the signed-in Microsoft Entra user."
}

$entraAdmin = $entraAdminJson | ConvertFrom-Json

if (-not $entraAdmin.login -or -not $entraAdmin.objectId) {
    throw "Failed to resolve the signed-in Microsoft Entra user."
}

$env:SQL_ENTRA_ADMIN_LOGIN = $entraAdmin.login
$env:SQL_ENTRA_ADMIN_OBJECT_ID = $entraAdmin.objectId

Write-Host ""
Write-Host "SQL Microsoft Entra administrator:"
Write-Host "  Login: $($entraAdmin.login)"
Write-Host "  Object ID: $($entraAdmin.objectId)"
Write-Host ""

az deployment sub what-if `
    --location japaneast `
    --template-file .\infra\main.bicep `
    --parameters .\infra\dev.bicepparam

if ($LASTEXITCODE -ne 0) {
    throw "Infrastructure what-if failed."
}
