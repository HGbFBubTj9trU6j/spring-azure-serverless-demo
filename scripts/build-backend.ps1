param(
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

$config = Import-PowerShellDataFile ".\config\$Environment.psd1"

$acrName = $config.AcrName
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

try {
    & .\mvnw.cmd clean spring-boot:build-image `
        "-Dspring-boot.build-image.imageName=$image" `
        "-Dbuild.version=$tag"

    if ($LASTEXITCODE -ne 0) {
        throw "Backend image build failed."
    }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Build completed."
Write-Host "Image: $image"