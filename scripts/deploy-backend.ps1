$ErrorActionPreference = "Stop"

$acrName = "springazureserverlessdemoacr"
$acrLoginServer = "$acrName.azurecr.io"

$resourceGroup = "spring-azure-serverless-demo-rg"
$containerApp = "spring-azure-serverless-dev-ca"

$tag = (git rev-parse --short HEAD).Trim()

$image = "$acrLoginServer/backend:$tag"

Write-Host "Image Tag : $tag"
Write-Host "Image     : $image"

Push-Location backend

mvn spring-boot:build-image `
  "-Dspring-boot.build-image.imageName=$image"

Pop-Location

az acr login `
  --name $acrName

docker push $image

az containerapp update `
  --name $containerApp `
  --resource-group $resourceGroup `
  --image $image

Write-Host ""
Write-Host "Deployment completed."
Write-Host "Image: $image"