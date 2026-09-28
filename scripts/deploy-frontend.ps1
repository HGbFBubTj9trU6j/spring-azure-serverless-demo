Push-Location frontend

swa deploy `
  ./dist `
  --env production `
  --deployment-token $env:SWA_DEPLOYMENT_TOKEN `
  --verbose

Pop-Location