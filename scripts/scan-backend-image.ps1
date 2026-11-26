param(
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ImageTag
)

$ErrorActionPreference = "Stop"

$config = Import-PowerShellDataFile ".\config\dev.psd1"

$acrName = $config.AcrName
$acrLoginServer = "$acrName.azurecr.io"

Write-Host "========================================"
Write-Host "Scan Backend OCI Image"
Write-Host "========================================"
Write-Host "ACR: $acrName"
Write-Host ""

if ([string]::IsNullOrWhiteSpace($ImageTag)) {
    Write-Host "Finding latest backend image tag..."

    $ImageTag = az acr repository show-tags `
        --name $acrName `
        --repository backend `
        --orderby time_desc `
        --top 1 `
        --output tsv

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ImageTag)) {
        throw "Failed to resolve the latest backend image tag."
    }

    Write-Host "Latest image tag found."
}

$imageDigest = az acr repository show `
    --name $acrName `
    --image "backend:$ImageTag" `
    --query digest `
    --output tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($imageDigest)) {
    throw "Failed to resolve the backend image digest."
}

$imageReference = "$acrLoginServer/backend@$imageDigest"
$destination = ".\security-reports\$ImageTag"

Write-Host "Image tag:    $ImageTag"
Write-Host "Image digest: $imageDigest"
Write-Host "Destination:  $destination"
Write-Host ""

$acrToken = az acr login `
    --name $acrName `
    --expose-token `
    --query accessToken `
    --output tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($acrToken)) {
    throw "Failed to get the ACR access token."
}

$previousSyftUsername = $env:SYFT_REGISTRY_AUTH_USERNAME
$previousSyftPassword = $env:SYFT_REGISTRY_AUTH_PASSWORD

try {
    $env:SYFT_REGISTRY_AUTH_USERNAME =
    "00000000-0000-0000-0000-000000000000"
    $env:SYFT_REGISTRY_AUTH_PASSWORD = $acrToken

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $destination |
            Out-Null

    Write-Host "Generating Syft SBOM..."

    syft "registry:$imageReference" `
        -o "syft-json=$destination\sbom.syft.json" `
        -o "spdx-json=$destination\sbom.spdx.json"

    if ($LASTEXITCODE -ne 0) {
        throw "Syft scan failed."
    }

    Write-Host "Scanning SBOM with Grype..."

    grype "sbom:$destination\sbom.syft.json" `
        -o json `
        --file "$destination\grype-report.json"

    if ($LASTEXITCODE -ne 0) {
        throw "Grype scan failed."
    }

    $metadata = [ordered]@{
        imageTag    = $ImageTag
        image       = "$acrLoginServer/backend:$ImageTag"
        imageDigest = $imageDigest
        scannedAt   = (Get-Date).ToUniversalTime().ToString("o")
    }

    $metadata |
            ConvertTo-Json |
            Set-Content `
            -Path "$destination\scan-metadata.json" `
            -Encoding utf8

    $report = Get-Content "$destination\grype-report.json" -Raw |
            ConvertFrom-Json

    Write-Host ""
    Write-Host "Vulnerability summary:"
    Write-Host ""

    $report.matches |
            Group-Object { $_.vulnerability.severity } |
            Sort-Object Count -Descending |
            Select-Object Name, Count |
            Format-Table -AutoSize

    Write-Host "Security scan completed."
    Write-Host "Location: $destination"
}
finally {
    $env:SYFT_REGISTRY_AUTH_USERNAME = $previousSyftUsername
    $env:SYFT_REGISTRY_AUTH_PASSWORD = $previousSyftPassword
}
