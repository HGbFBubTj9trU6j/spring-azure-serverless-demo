param(
    [Parameter(Mandatory = $true)]
    [string]$ExpectedVersion,

    [Parameter(Mandatory = $true)]
    [string]$FrontendBaseUrl,

    [int]$MaxAttempts = 12,

    [int]$RetryIntervalSeconds = 5
)

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "Verify Frontend Deployment"
Write-Host "========================================"

$versionUrl = "$($FrontendBaseUrl.TrimEnd('/'))/version.json"

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {

    Write-Host "Verification attempt $attempt/$MaxAttempts"

    try {
        $response = Invoke-RestMethod `
            -Uri $versionUrl `
            -Method Get `
            -Headers @{
            "Cache-Control" = "no-cache"
        }

        $actualVersion = $response.version

        Write-Host "Expected Version: $ExpectedVersion"
        Write-Host "Actual Version  : $actualVersion"

        if ($actualVersion -eq $ExpectedVersion) {
            Write-Host ""
            Write-Host "Frontend deployment verification succeeded."
            exit 0
        }
    }
    catch {
        Write-Host "Frontend version is not available yet."
    }

    if ($attempt -lt $MaxAttempts) {
        Start-Sleep -Seconds $RetryIntervalSeconds
    }
}

throw "Frontend deployment verification failed. Expected version '$ExpectedVersion' was not deployed."
