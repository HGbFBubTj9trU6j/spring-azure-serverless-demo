$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "Infrastructure What-If"
Write-Host "========================================"

$entraAdmin = .\scripts\resolve-sql-entra-admin.ps1
$env:SQL_ENTRA_ADMIN_LOGIN = $entraAdmin.login
$env:SQL_ENTRA_ADMIN_OBJECT_ID = $entraAdmin.objectId

Write-Host ""
Write-Host "SQL Microsoft Entra administrator:"
Write-Host "  Login: $($entraAdmin.login)"
Write-Host "  Object ID: $($entraAdmin.objectId)"
Write-Host ""

$githubSubject = .\scripts\resolve-github-actions-subject.ps1
$env:GITHUB_ACTIONS_SUBJECT = $githubSubject

Write-Host "GitHub Actions OIDC configuration:"
Write-Host "  Branch: main"
Write-Host "  Subject: $githubSubject"
Write-Host ""

az deployment sub what-if `
    --location japaneast `
    --template-file .\infra\main.bicep `
    --parameters .\infra\dev.bicepparam

if ($LASTEXITCODE -ne 0) {
    throw "Infrastructure what-if failed."
}
