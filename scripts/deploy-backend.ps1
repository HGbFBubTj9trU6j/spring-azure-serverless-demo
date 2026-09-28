$ErrorActionPreference = "Stop"

$acrName = "springazureserverlessdemoacr"
$acrLoginServer = "$acrName.azurecr.io"

$resourceGroup = "spring-azure-serverless-demo-rg"
$containerApp = "spring-azure-serverless-dev-ca"

$dirty = git status --porcelain

if ($dirty) {
    $tag = "$(git rev-parse --short HEAD)-dirty"
}
else {
    $tag = git rev-parse --short HEAD
}

$image = "$acrLoginServer/backend:$tag"

Write-Host "Deploying image: $image"

az acr login `
  --name $acrName

docker push $image

az containerapp update `
  --name $containerApp `
  --resource-group $resourceGroup `
  --image $image

az containerapp show `
  --name $containerApp `
  --resource-group $resourceGroup `
  --query properties.template.containers[0].image `
  -o tsv

Write-Host ""
Write-Host "Deployment completed."
Write-Host "Image: $image"