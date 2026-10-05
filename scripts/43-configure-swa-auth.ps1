[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StaticWebAppName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

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
    --name $StaticWebAppName `
    --resource-group $ResourceGroupName `
    --query "{
        name:name,
        resourceGroup:resourceGroup,
        defaultHostname:defaultHostname
    }" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw @"
Azure Static Web App was not found in the active subscription.

Static Web App : $StaticWebAppName
Resource Group : $ResourceGroupName
Subscription   : $($account.subscriptionId)
"@
}

$staticWebApp = $staticWebAppJson | ConvertFrom-Json

if (-not $staticWebApp.name) {
    throw "The Azure Static Web App could not be retrieved."
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
        --name $StaticWebAppName `
        --resource-group $ResourceGroupName `
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
# Verify Client ID
#

Write-Host ""
Write-Host "Verifying Application Client ID..."

$configuredClientId = az staticwebapp appsettings list `
    --name $StaticWebAppName `
    --resource-group $ResourceGroupName `
    --query "properties.AZURE_CLIENT_ID" `
    --output tsv

if ($LASTEXITCODE -ne 0) {
    throw "Failed to verify the Azure Static Web Apps application settings."
}

if ($configuredClientId -ne $ClientId) {
    throw @"
The configured Application Client ID does not match the expected value.

Expected Client ID : $ClientId
Actual Client ID   : $configuredClientId
"@
}

#
# Verify that the Client Secret setting exists without retrieving its value
#

Write-Host "Verifying Client Secret setting..."

$settingNamesJson = az staticwebapp appsettings list `
    --name $StaticWebAppName `
    --resource-group $ResourceGroupName `
    --query "keys(properties)" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to verify the Client Secret setting."
}

$settingNames = @($settingNamesJson | ConvertFrom-Json)

if ("AZURE_CLIENT_SECRET" -notin $settingNames) {
    throw "AZURE_CLIENT_SECRET was not found in the application settings."
}

Write-Host ""
Write-Host "========================================"
Write-Host "SWA Authentication Configured"
Write-Host "========================================"
Write-Host ""
Write-Host "Static Web App        : $StaticWebAppName"
Write-Host "Resource Group        : $ResourceGroupName"
Write-Host "Application Client ID : $ClientId"
Write-Host "Client Secret         : Configured"
Write-Host ""
Write-Host "The Client Secret was not written to a file or displayed."