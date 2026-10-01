$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "What-If Infrastructure"
Write-Host "========================================"

az deployment sub what-if `
  --location japaneast `
  --template-file .\infra\main.bicep `
  --parameters .\infra\dev.bicepparam
