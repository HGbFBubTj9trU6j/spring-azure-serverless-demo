[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string]$Environment = "dev",

    [Parameter(Mandatory = $true)]
    [ValidatePattern(
        '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    )]
    [string]$ClientId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [System.Security.SecureString]$ClientSecret
)

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "Configure SWA Authentication"
Write-Host "========================================"

#
# Environment configuration
#

Write-Host ""
Write-Host "Loading environment configuration..."

$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot "config\$Environment.psd1"

if (-not (Test-Path $configPath)) {
    throw "Environment configuration file was not found: $configPath"
}

$config = Import-PowerShellDataFile $configPath

$staticWebAppName = $config.StaticWebAppName
$resourceGroupName = $config.ResourceGroup

if (-not $staticWebAppName) {
    throw "StaticWebAppName is not defined in $configPath."
}

if (-not $resourceGroupName) {
    throw "ResourceGroup is not defined in $configPath."
}

Write-Host "Environment    : $Environment"
Write-Host "Configuration  : $configPath"
Write-Host "Static Web App : $staticWebAppName"
Write-Host "Resource Group : $resourceGroupName"

#
# Azure CLI context
#
# This script does not perform:
#   - az login
#   - az account set
#   - tenant switching
#   - subscription switching
#

Write-Host ""
Write-Host "Checking Azure CLI context..."

$accountJson = az account show `
    --query "{tenantId:tenantId,subscriptionId:id,subscriptionName:name}" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw @"
Unable to retrieve the active Azure CLI context.

Sign in to the Azure subscription tenant and select the target
subscription before running this script.

This script does not perform login or change the active subscription.
"@
}

$account = $accountJson | ConvertFrom-Json

if (-not $account.tenantId) {
    throw "The active Azure CLI tenant ID is empty."
}

if (-not $account.subscriptionId) {
    throw "The active Azure CLI subscription ID is empty."
}

Write-Host "Azure Tenant       : $($account.tenantId)"
Write-Host "Azure Subscription : $($account.subscriptionId)"
Write-Host "Subscription Name  : $($account.subscriptionName)"

#
# Static Web App
#

Write-Host ""
Write-Host "Checking Azure Static Web App..."

$staticWebAppJson = az staticwebapp show `
    --name $staticWebAppName `
    --resource-group $resourceGroupName `
    --query "{name:name,resourceGroup:resourceGroup,defaultHostname:defaultHostname}" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw @"
Failed to retrieve the Azure Static Web App.

Environment    : $Environment
Static Web App : $staticWebAppName
Resource Group : $resourceGroupName
Subscription   : $($account.subscriptionId)

Check the Azure CLI error displayed above.
"@
}

$staticWebApp = $staticWebAppJson | ConvertFrom-Json

if (-not $staticWebApp.name) {
    throw "The Azure Static Web App could not be retrieved."
}

if (-not $staticWebApp.defaultHostname) {
    throw "The Azure Static Web App default hostname could not be determined."
}

Write-Host "Static Web App : $($staticWebApp.name)"
Write-Host "Resource Group : $($staticWebApp.resourceGroup)"
Write-Host "Hostname       : $($staticWebApp.defaultHostname)"

#
# Configure application settings
#

$clientSecretPlainText = $null

try {
    $clientSecretPlainText =
        [System.Net.NetworkCredential]::new(
            "",
            $ClientSecret
        ).Password

    if (-not $clientSecretPlainText) {
        throw "The Client Secret is empty."
    }

    Write-Host ""
    Write-Host "Configuring Azure Static Web Apps authentication settings..."

    az staticwebapp appsettings set `
        --name $staticWebAppName `
        --resource-group $resourceGroupName `
        --setting-names `
            "AZURE_CLIENT_ID=$ClientId" `
            "AZURE_CLIENT_SECRET=$clientSecretPlainText" `
        --output none

    if ($LASTEXITCODE -ne 0) {
        throw "Azure Static Web Apps application settings update failed."
    }
}
finally {
    $clientSecretPlainText = $null

    Remove-Variable clientSecretPlainText `
        -ErrorAction SilentlyContinue
}

#
# Verify application settings
#

Write-Host ""
Write-Host "Verifying Azure Static Web Apps authentication settings..."

$appSettingsJson = az staticwebapp appsettings list `
    --name $staticWebAppName `
    --resource-group $resourceGroupName `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to verify the Azure Static Web Apps application settings."
}

$appSettings = $appSettingsJson | ConvertFrom-Json

if (-not $appSettings.properties) {
    throw "Azure Static Web Apps application settings could not be retrieved."
}

#
# Verify Client ID
#

$configuredClientId = $appSettings.properties.AZURE_CLIENT_ID

if ($configuredClientId -ne $ClientId) {
    throw @"
The configured Application Client ID does not match the expected value.

Expected Client ID : $ClientId
Actual Client ID   : $configuredClientId
"@
}

Write-Host "Application Client ID : Verified"

#
# Verify that the Client Secret setting exists
# without displaying its value
#

$clientSecretProperty =
    $appSettings.properties.PSObject.Properties["AZURE_CLIENT_SECRET"]

if (-not $clientSecretProperty) {
    throw "AZURE_CLIENT_SECRET was not found in the application settings."
}

Write-Host "Client Secret         : Verified"

#
# Result
#

Write-Host ""
Write-Host "========================================"
Write-Host "SWA Authentication Configured"
Write-Host "========================================"
Write-Host ""
Write-Host "Environment           : $Environment"
Write-Host "Static Web App        : $staticWebAppName"
Write-Host "Resource Group        : $resourceGroupName"
Write-Host "Hostname              : $($staticWebApp.defaultHostname)"
Write-Host "Application Client ID : $ClientId"
Write-Host "Client Secret         : Configured"
Write-Host ""
Write-Host "The Client Secret was not written to a file or displayed."