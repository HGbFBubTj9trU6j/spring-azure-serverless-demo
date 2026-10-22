$ErrorActionPreference = "Stop"

$config = Import-PowerShellDataFile `
    -Path ".\config\dev.psd1"

$resourceGroup = $config.ResourceGroup
$sqlServer = $config.SqlServerName
$database = $config.SqlDatabaseName

Write-Host "========================================"
Write-Host "Verify Azure SQL Database"
Write-Host "========================================"

Write-Host ""
Write-Host "SQL logical server"
Write-Host "----------------------------------------"

az sql server show `
    --resource-group $resourceGroup `
    --name $sqlServer `
    --query "{Name:name,Location:location,Fqdn:fullyQualifiedDomainName,PublicNetworkAccess:publicNetworkAccess,MinimalTlsVersion:minimalTlsVersion}" `
    --output table

if ($LASTEXITCODE -ne 0) {
    throw "Failed to query the Azure SQL logical server."
}

Write-Host ""
Write-Host "Microsoft Entra administrator"
Write-Host "----------------------------------------"

az sql server ad-admin list `
    --resource-group $resourceGroup `
    --server $sqlServer `
    --output table

if ($LASTEXITCODE -ne 0) {
    throw "Failed to query the Microsoft Entra administrator."
}

Write-Host ""
Write-Host "Microsoft Entra-only authentication"
Write-Host "----------------------------------------"

az sql server ad-only-auth get `
    --resource-group $resourceGroup `
    --name $sqlServer `
    --output table

if ($LASTEXITCODE -ne 0) {
    throw "Failed to query Microsoft Entra-only authentication."
}

Write-Host ""
Write-Host "Azure SQL Database"
Write-Host "----------------------------------------"

az sql db show `
    --resource-group $resourceGroup `
    --server $sqlServer `
    --name $database `
    --query "{Name:name,Sku:sku.name,Tier:sku.tier,Family:sku.family,Capacity:sku.capacity,UseFreeLimit:useFreeLimit,FreeLimitBehavior:freeLimitExhaustionBehavior,AutoPauseDelay:autoPauseDelay,MinCapacity:minCapacity,MaxSizeBytes:maxSizeBytes,BackupRedundancy:requestedBackupStorageRedundancy,Collation:collation}" `
    --output table

if ($LASTEXITCODE -ne 0) {
    throw "Failed to query the Azure SQL database."
}

Write-Host ""
Write-Host "Firewall rules"
Write-Host "----------------------------------------"

az sql server firewall-rule list `
    --resource-group $resourceGroup `
    --server $sqlServer `
    --output table

if ($LASTEXITCODE -ne 0) {
    throw "Failed to query Azure SQL firewall rules."
}

Write-Host ""
Write-Host "========================================"
Write-Host "Azure SQL verification completed."
Write-Host "========================================"