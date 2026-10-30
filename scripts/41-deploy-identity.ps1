[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StaticWebAppHostname,

    [ValidateNotNullOrEmpty()]
    [string]$AuthApplicationDisplayName = "spring-azure-serverless-demo-auth",

    [ValidateNotNullOrEmpty()]
    [string]$ApiApplicationDisplayName = "spring-azure-serverless-demo-api"
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
    --display-name $AuthApplicationDisplayName `
    --query "[].{id:id,appId:appId,displayName:displayName}" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to search for the App Registration."
}

$appResults = @($appResultsJson | ConvertFrom-Json)

if ($appResults.Count -gt 1) {
    throw "Multiple App Registrations were found with the display name '$AuthApplicationDisplayName'. Use a unique application display name."
}

if ($appResults.Count -eq 0) {
    Write-Host "Creating App Registration..."

    $appJson = az ad app create `
        --display-name $AuthApplicationDisplayName `
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
# Backend API App Registration
#

Write-Host ""
Write-Host "Checking Backend API App Registration..."

$apiAppResultsJson = az ad app list `
    --display-name $ApiApplicationDisplayName `
    --query "[].{id:id,appId:appId,displayName:displayName}" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to search for the Backend API App Registration."
}

$apiAppResults = @($apiAppResultsJson | ConvertFrom-Json)

if ($apiAppResults.Count -gt 1) {
    throw "Multiple App Registrations were found with the display name '$ApiApplicationDisplayName'. Use a unique application display name."
}

if ($apiAppResults.Count -eq 0) {
    Write-Host "Creating Backend API App Registration..."

    $apiAppJson = az ad app create `
        --display-name $ApiApplicationDisplayName `
        --sign-in-audience AzureADMyOrg `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the Backend API App Registration."
    }

    $apiApp = $apiAppJson | ConvertFrom-Json
}
else {
    $apiApp = $apiAppResults[0]

    Write-Host "Backend API App Registration already exists."
}

$apiAppId = $apiApp.appId
$apiAppObjectId = $apiApp.id

if (-not $apiAppId) {
    throw "The Backend API Application client ID could not be determined."
}

if (-not $apiAppObjectId) {
    throw "The Backend API Application object ID could not be determined."
}

#
# Backend API Application ID URI
#

$apiIdentifierUri = "api://$apiAppId"

Write-Host ""
Write-Host "Updating Backend API Application ID URI..."

az ad app update `
    --id $apiAppId `
    --identifier-uris $apiIdentifierUri `
    --output none

if ($LASTEXITCODE -ne 0) {
    throw "Failed to update the Backend API Application ID URI."
}

#
# Backend API delegated permission scope
#

Write-Host ""
Write-Host "Checking Backend API delegated permission scope..."

$apiAppJson = az ad app show `
    --id $apiAppId `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to retrieve the Backend API App Registration."
}

$apiApp = $apiAppJson | ConvertFrom-Json

$accessAsUserScope = @(
    $apiApp.api.oauth2PermissionScopes |
        Where-Object { $_.value -eq "access_as_user" }
)

if ($accessAsUserScope.Count -gt 1) {
    throw "Multiple 'access_as_user' scopes were found."
}

if ($accessAsUserScope.Count -eq 0) {
    Write-Host "Creating access_as_user scope..."

    $accessAsUserScopeId = [guid]::NewGuid().ToString()

    $existingScopes = @($apiApp.api.oauth2PermissionScopes)

    $newScope = @{
        id                      = $accessAsUserScopeId
        value                   = "access_as_user"
        type                    = "User"
        isEnabled               = $true
        adminConsentDisplayName = "Access Fortune API"
        adminConsentDescription = "Access the Fortune API as the signed-in user"
        userConsentDisplayName  = "Access Fortune API"
        userConsentDescription  = "Access the Fortune API as the signed-in user"
    }

    $updatedScopes = @($existingScopes) + $newScope

    $requestBody = @{
        api = @{
            requestedAccessTokenVersion = 2
            oauth2PermissionScopes       = $updatedScopes
        }
    } | ConvertTo-Json -Depth 10 -Compress

    $tempFile = [System.IO.Path]::GetTempFileName()

    try {
        $requestBody | Set-Content `
            -Path $tempFile `
            -Encoding utf8 `
            -NoNewline

        az rest `
            --method PATCH `
            --url "https://graph.microsoft.com/v1.0/applications/$apiAppObjectId" `
            --headers "Content-Type=application/json" `
            --body "@$tempFile" `
            --output none

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create the access_as_user scope."
        }
    }
    finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}
else {
    $accessAsUserScopeId = $accessAsUserScope[0].id

    Write-Host "access_as_user scope already exists."
}

#
# Backend API Service Principal
#

Write-Host ""
Write-Host "Checking Backend API Service Principal..."

$apiServicePrincipalJson = az ad sp list `
    --filter "appId eq '$apiAppId'" `
    --query "[0]" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to search for the Backend API Service Principal."
}

$apiServicePrincipal = $apiServicePrincipalJson | ConvertFrom-Json

if (-not $apiServicePrincipal) {
    Write-Host "Creating Backend API Service Principal..."

    az ad sp create `
        --id $apiAppId `
        --output none

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the Backend API Service Principal."
    }

    $apiServicePrincipalJson = az ad sp list `
        --filter "appId eq '$apiAppId'" `
        --query "[0]" `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve the created Backend API Service Principal."
    }

    $apiServicePrincipal = $apiServicePrincipalJson | ConvertFrom-Json
}
else {
    Write-Host "Backend API Service Principal already exists."
}

if (-not $apiServicePrincipal) {
    throw "The Backend API Service Principal could not be found after deployment."
}

#
# Result
#

Write-Host ""
Write-Host "========================================"
Write-Host "Identity Deployment Completed"
Write-Host "========================================"
Write-Host ""
Write-Host "Application Name         : $AuthApplicationDisplayName"
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

Write-Host ""
Write-Host "Backend API"
Write-Host "-----------"
Write-Host "Application Name         : $ApiApplicationDisplayName"
Write-Host "Application Client ID    : $apiAppId"
Write-Host "Application Object ID    : $apiAppObjectId"
Write-Host "Service Principal ID     : $($apiServicePrincipal.id)"
Write-Host "Application ID URI       : $apiIdentifierUri"
Write-Host "access_as_user Scope ID  : $accessAsUserScopeId"
