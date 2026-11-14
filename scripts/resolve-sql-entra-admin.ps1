$ErrorActionPreference = "Stop"

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

Write-Output $entraAdmin
