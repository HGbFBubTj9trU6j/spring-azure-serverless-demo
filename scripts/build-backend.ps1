$ErrorActionPreference = "Stop"

$acrName = "springazureserverlessdemoacr"
$acrLoginServer = "$acrName.azurecr.io"

$dirty = git status --porcelain

if ($dirty) {
    $tag = "$(git rev-parse --short HEAD)-dirty"
}
else {
    $tag = git rev-parse --short HEAD
}

$image = "$acrLoginServer/backend:$tag"

Write-Host "Building image: $image"

Push-Location backend

& .\mvnw.cmd clean spring-boot:build-image `
  "-Dspring-boot.build-image.imageName=$image" `
  "-Dbuild.version=$tag"

Pop-Location