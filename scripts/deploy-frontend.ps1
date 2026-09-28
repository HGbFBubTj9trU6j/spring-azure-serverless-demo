Push-Location frontend

swa deploy `
  ./dist `
  --deployment-token $env:SWA_DEPLOYMENT_TOKEN

Pop-Location