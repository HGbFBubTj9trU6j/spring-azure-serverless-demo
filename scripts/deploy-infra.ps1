$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "Deploy Infrastructure"
Write-Host "========================================"

az deployment sub create `
  --location japaneast `
  --template-file .\infra\main.bicep `
  --parameters .\infra\dev.bicepparam