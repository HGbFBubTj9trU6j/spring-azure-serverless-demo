[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationDisplayName = "spring-azure-serverless-demo-auth",

    [ValidateRange(1, 2)]
    [int]$ValidityYears = 1
)

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "Create Client Secret"
Write-Host "========================================"

Write-Host ""
Write-Host "Detecting authentication tenant..."

$currentTenantId = az account show `
    --query tenantId `
    --output tsv

if ($LASTEXITCODE -ne 0) {
    throw "Unable to determine the active tenant."
}

if (-not $currentTenantId) {
    throw "The active tenant ID is empty."
}

Write-Host "Authentication Tenant : $currentTenantId"

Write-Host ""
Write-Host "Finding App Registration..."

$appId = az ad app list `
    --display-name $ApplicationDisplayName `
    --query "[0].appId" `
    --output tsv

if ($LASTEXITCODE -ne 0) {
    throw "Failed to search for the App Registration."
}

if (-not $appId) {
    throw "App Registration was not found: $ApplicationDisplayName"
}

Write-Host "Application Name      : $ApplicationDisplayName"
Write-Host "Application Client ID : $appId"

Write-Host ""
Write-Host "Checking existing credentials..."

$credentialsJson = az ad app credential list `
    --id $appId `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to list existing credentials."
}

$credentials = @($credentialsJson | ConvertFrom-Json)

if ($credentials.Count -gt 0) {

    Write-Host ""
    Write-Host "A Client Secret already exists."
    Write-Host ""
    Write-Host "No action was required."
    Write-Host "A new Client Secret was not created."
    Write-Host ""
    Write-Host "The existing Client Secret cannot be retrieved."
    Write-Host ""
    Write-Host "43-configure-swa-auth.ps1 is only required"
    Write-Host "when a new Client Secret has been created."
    Write-Host ""
    Write-Host "If Azure Static Web Apps authentication is already working,"
    Write-Host "no further action is required."
    Write-Host ""

    return
}

Write-Host ""
Write-Host "Creating Client Secret..."

$credentialJson = az ad app credential reset `
    --id $appId `
    --append `
    --display-name "swa-auth" `
    --years $ValidityYears `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create the Client Secret."
}

$credential = $credentialJson | ConvertFrom-Json
$clientSecret = $credential.password

if (-not $clientSecret) {
    throw "The Client Secret value was not returned."
}

Write-Host ""
Write-Host "========================================"
Write-Host "Client Secret Created"
Write-Host "========================================"
Write-Host ""
Write-Host "Authentication Tenant ID : $currentTenantId"
Write-Host "Application Client ID    : $appId"
Write-Host "Client Secret            : $clientSecret"
Write-Host ""
Write-Warning "The Client Secret is displayed only once."
Write-Warning "Do not save it in Git, source files, README files, or shell history."
Write-Warning "Use it immediately when configuring Azure Static Web Apps."
