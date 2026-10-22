$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "Deploy Infrastructure"
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

Write-Host ""
Write-Host "SQL Microsoft Entra administrator:"
Write-Host "  Login: $($entraAdmin.login)"
Write-Host "  Object ID: $($entraAdmin.objectId)"
Write-Host ""

az deployment sub create `
    --location japaneast `
    --template-file .\infra\main.bicep `
    --parameters .\infra\dev.bicepparam `
    --parameters sqlEntraAdministratorLogin=$($entraAdmin.login) `
    --parameters sqlEntraAdministratorObjectId=$($entraAdmin.objectId)

if ($LASTEXITCODE -ne 0) {
    throw "Infrastructure deployment failed."
}