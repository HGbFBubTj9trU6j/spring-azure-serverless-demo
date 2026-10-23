$ErrorActionPreference = "Stop"

$config = Import-PowerShellDataFile `
    -Path ".\config\dev.psd1"

$sqlServerFqdn = "$($config.SqlServerName).database.windows.net"
$database = $config.SqlDatabaseName
$managedIdentityName = $config.IdentityName

Write-Host "========================================"
Write-Host "Deploy Database"
Write-Host "========================================"

Write-Host ""
Write-Host "Server:   $sqlServerFqdn"
Write-Host "Database: $database"
Write-Host ""

Write-Host "Applying database schema..."
sqlcmd `
    -S $sqlServerFqdn `
    -d $database `
    -G `
    -i .\database\schema.sql

if ($LASTEXITCODE -ne 0) {
    throw "Failed to apply database schema."
}

Write-Host ""
Write-Host "Loading initial data..."
sqlcmd `
    -S $sqlServerFqdn `
    -d $database `
    -G `
    -i .\database\data.sql

if ($LASTEXITCODE -ne 0) {
    throw "Failed to load initial data."
}

Write-Host ""
Write-Host "Configuring database security..."
sqlcmd `
    -S $sqlServerFqdn `
    -d $database `
    -G `
    -v ManagedIdentityName="$managedIdentityName" `
    -i .\database\security.sql

if ($LASTEXITCODE -ne 0) {
    throw "Failed to configure database security."
}

Write-Host ""
Write-Host "========================================"
Write-Host "Database deployment completed."
Write-Host "========================================"
