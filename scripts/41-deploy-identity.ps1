[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StaticWebAppHostname,

    [ValidateNotNullOrEmpty()]
    [string]$ApplicationDisplayName = "spring-azure-serverless-demo-auth"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "Deploy Identity"
Write-Host "========================================"

#
# Normalize input
#

$StaticWebAppHostname = $StaticWebAppHostname.Trim()
$StaticWebAppHostname = $StaticWebAppHostname `
    -replace '^https?://', '' `
    -replace '/+$', ''

$redirectUri = "https://$StaticWebAppHostname/.auth/login/aad/callback"

#
# Authentication tenant
#

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

$currentAccountName = az account show `
    --query name `
    --output tsv

if ($LASTEXITCODE -ne 0) {
    throw "Unable to determine the active Azure account."
}

Write-Host ""
Write-Host "Active Account        : $currentAccountName"
Write-Host "Authentication Tenant : $currentTenantId"
Write-Host "Redirect URI          : $redirectUri"

#
# App Registration
#

Write-Host ""
Write-Host "Checking App Registration..."

$appResultsJson = az ad app list `
    --display-name $ApplicationDisplayName `
    --query "[].{id:id,appId:appId,displayName:displayName}" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to search for the App Registration."
}

$appResults = @($appResultsJson | ConvertFrom-Json)

if ($appResults.Count -gt 1) {
    throw "Multiple App Registrations were found with the display name '$ApplicationDisplayName'. Use a unique application display name."
}

if ($appResults.Count -eq 0) {
    Write-Host "Creating App Registration..."

    $appJson = az ad app create `
        --display-name $ApplicationDisplayName `
        --sign-in-audience AzureADMyOrg `
        --enable-access-token-issuance false `
        --enable-id-token-issuance true `
        --web-redirect-uris $redirectUri `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the App Registration."
    }

    $app = $appJson | ConvertFrom-Json
}
else {
    $app = $appResults[0]

    Write-Host "App Registration already exists."
}

$appId = $app.appId

if (-not $appId) {
    throw "The App Registration client ID could not be determined."
}

#
# Converge App Registration settings
#

Write-Host ""
Write-Host "Updating App Registration settings..."

az ad app update `
    --id $appId `
    --sign-in-audience AzureADMyOrg `
    --enable-access-token-issuance false `
    --enable-id-token-issuance true `
    --web-redirect-uris $redirectUri `
    --output none

if ($LASTEXITCODE -ne 0) {
    throw "Failed to update the App Registration."
}

#
# Verify App Registration settings
#

Write-Host ""
Write-Host "Verifying App Registration settings..."

$appJson = az ad app show `
    --id $appId `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to retrieve the App Registration."
}

$app = $appJson | ConvertFrom-Json

if ($app.signInAudience -ne "AzureADMyOrg") {
    throw "Unexpected sign-in audience: $($app.signInAudience)"
}

if (-not $app.web.implicitGrantSettings.enableIdTokenIssuance) {
    throw "ID token issuance is not enabled."
}

if ($app.web.implicitGrantSettings.enableAccessTokenIssuance) {
    throw "Access token issuance through the implicit flow is unexpectedly enabled."
}

if ($redirectUri -notin $app.web.redirectUris) {
    throw "The expected redirect URI was not found."
}

#
# Service Principal
#

Write-Host ""
Write-Host "Checking Service Principal..."

$servicePrincipalJson = az ad sp list `
    --filter "appId eq '$appId'" `
    --query "[0]" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to search for the Service Principal."
}

$servicePrincipal = $servicePrincipalJson | ConvertFrom-Json

if (-not $servicePrincipal) {
    Write-Host "Creating Service Principal..."

    az ad sp create `
        --id $appId `
        --output none

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the Service Principal."
    }

    $servicePrincipalJson = az ad sp list `
        --filter "appId eq '$appId'" `
        --query "[0]" `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve the created Service Principal."
    }

    $servicePrincipal = $servicePrincipalJson | ConvertFrom-Json
}
else {
    Write-Host "Service Principal already exists."
}

if (-not $servicePrincipal) {
    throw "The Service Principal could not be found after deployment."
}

#
# Result
#

Write-Host ""
Write-Host "========================================"
Write-Host "Identity Deployment Completed"
Write-Host "========================================"
Write-Host ""
Write-Host "Application Name         : $ApplicationDisplayName"
Write-Host "Application Client ID    : $appId"
Write-Host "Application Object ID    : $($app.id)"
Write-Host "Service Principal ID     : $($servicePrincipal.id)"
Write-Host "Redirect URI             : $redirectUri"
Write-Host "Authentication Tenant ID : $currentTenantId"
Write-Host "ID Token Issuance        : Enabled"
Write-Host "Implicit Access Token    : Disabled"
Write-Host ""
Write-Host "Client Secret and Azure Static Web Apps application settings"
Write-Host "are not configured by this version of the script."