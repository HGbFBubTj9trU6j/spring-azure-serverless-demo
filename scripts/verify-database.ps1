$ErrorActionPreference = "Stop"

$config = Import-PowerShellDataFile `
    -Path ".\config\dev.psd1"

$sqlServerFqdn = "$($config.SqlServerName).database.windows.net"
$database = $config.SqlDatabaseName
$managedIdentityName = $config.IdentityName

Write-Host "========================================"
Write-Host "Verify Database"
Write-Host "========================================"

Write-Host ""
Write-Host "Database connection"
Write-Host "----------------------------------------"

sqlcmd `
    -S $sqlServerFqdn `
    -d $database `
    -G `
    -Q "SELECT CAST(DB_NAME() AS varchar(32)) AS database_name, CAST(DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS varchar(32)) AS collation;"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to connect to the database."
}

Write-Host ""
Write-Host "Fortunes table"
Write-Host "----------------------------------------"

sqlcmd `
    -S $sqlServerFqdn `
    -d $database `
    -G `
    -Q "SELECT CAST(COLUMN_NAME AS varchar(32)) AS column_name, CAST(DATA_TYPE AS varchar(32)) AS data_type, CHARACTER_MAXIMUM_LENGTH AS max_length, CAST(IS_NULLABLE AS varchar(8)) AS nullable, CAST(COLLATION_NAME AS varchar(32)) AS collation FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'fortunes' ORDER BY ORDINAL_POSITION;"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to verify the fortunes table."
}

Write-Host ""
Write-Host "Managed Identity database principal"
Write-Host "----------------------------------------"

sqlcmd `
    -S $sqlServerFqdn `
    -d $database `
    -G `
    -Q "SELECT CAST(name AS varchar(64)) AS name, CAST(type_desc AS varchar(32)) AS type FROM sys.database_principals WHERE name = '$managedIdentityName';"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to verify the Managed Identity database principal."
}

Write-Host ""
Write-Host "Managed Identity database roles"
Write-Host "----------------------------------------"

sqlcmd `
    -S $sqlServerFqdn `
    -d $database `
    -G `
    -Q "SELECT CAST(r.name AS varchar(32)) AS role_name, CAST(m.name AS varchar(64)) AS member_name FROM sys.database_role_members rm JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id WHERE m.name = '$managedIdentityName';"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to verify the Managed Identity database roles."
}

Write-Host ""
Write-Host "========================================"
Write-Host "Database verification completed."
Write-Host "========================================"
