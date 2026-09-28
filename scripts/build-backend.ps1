$ErrorActionPreference = "Stop"

$acrName = "springazureserverlessdemoacr"
$acrLoginServer = "$acrName.azurecr.io"

$tag = (git rev-parse --short HEAD).Trim()

$image = "$acrLoginServer/backend:$tag"

Write-Host "Building image: $image"

Push-Location backend

mvn spring-boot:build-image `
  "-Dspring-boot.build-image.imageName=$image"

Pop-Location