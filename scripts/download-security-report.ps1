param(
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ImageTag
)

$ErrorActionPreference = "Stop"

$config = Import-PowerShellDataFile ".\config\dev.psd1"

$storageAccountName = $config.SecurityReportStorageAccountName
$containerName = $config.SecurityReportContainerName

Write-Host "========================================"
Write-Host "Download Security Report"
Write-Host "========================================"
Write-Host "Storage account: $storageAccountName"
Write-Host "Container:       $containerName"
Write-Host ""

if ([string]::IsNullOrWhiteSpace($ImageTag)) {
    Write-Host "Finding latest security report..."

    $metadataBlobs = az storage blob list `
        --account-name $storageAccountName `
        --container-name $containerName `
        --auth-mode login `
        --query "[?ends_with(name, '/scan-metadata.json')].{Name:name,LastModified:properties.lastModified}" `
        --output json |
            ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list security reports."
    }

    if (-not $metadataBlobs -or $metadataBlobs.Count -eq 0) {
        throw "No security reports were found."
    }

    $latest = $metadataBlobs |
            Sort-Object {
                [DateTimeOffset]$_.LastModified
            } -Descending |
            Select-Object -First 1

    if ($latest.Name -notmatch '^backend/([0-9a-f]{40})/scan-metadata\.json$') {
        throw "Unexpected security report path: $($latest.Name)"
    }

    $ImageTag = $Matches[1]

    Write-Host "Latest report found."
}

$prefix = "backend/$ImageTag"
$destination = ".\security-reports\$ImageTag"

Write-Host "Image tag:       $ImageTag"
Write-Host "Destination:     $destination"
Write-Host ""

New-Item `
    -ItemType Directory `
    -Force `
    -Path $destination |
        Out-Null

$reports = @(
    "sbom.syft.json",
    "sbom.spdx.json",
    "grype-report.json",
    "scan-metadata.json"
)

foreach ($report in $reports) {
    Write-Host "Downloading $report..."

    az storage blob download `
        --account-name $storageAccountName `
        --container-name $containerName `
        --name "$prefix/$report" `
        --file "$destination\$report" `
        --auth-mode login `
        --overwrite `
        --output none

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to download $report."
    }
}

Write-Host ""
Write-Host "Security reports downloaded successfully."
Write-Host "Location: $destination"
