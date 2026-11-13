$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "Infrastructure What-If"
Write-Host "========================================"

$entraAdminJson = az ad signed-in-user show `
    --query "{login:userPrincipalName,objectId:id}" `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to query the signed-in Microsoft Entra user."
}

$entraAdmin = $entraAdminJson | ConvertFrom-Json

if (-not $entraAdmin.login -or -not $entraAdmin.objectId) {
    throw "Failed to resolve the signed-in Microsoft Entra user."
}

$env:SQL_ENTRA_ADMIN_LOGIN = $entraAdmin.login
$env:SQL_ENTRA_ADMIN_OBJECT_ID = $entraAdmin.objectId

Write-Host ""
Write-Host "SQL Microsoft Entra administrator:"
Write-Host "  Login: $($entraAdmin.login)"
Write-Host "  Object ID: $($entraAdmin.objectId)"
Write-Host ""

$repositoryJson = gh repo view --json nameWithOwner

if ($LASTEXITCODE -ne 0) {
    throw "Failed to resolve the current GitHub repository."
}

$repository = $repositoryJson | ConvertFrom-Json

if (-not $repository.nameWithOwner) {
    throw "The current GitHub repository name could not be resolved."
}

$githubRepositoryJson = gh api "repos/$($repository.nameWithOwner)" `
    --jq '{owner: .owner.login, ownerId: .owner.id, repository: .name, repositoryId: .id}'

if ($LASTEXITCODE -ne 0) {
    throw "Failed to query the GitHub repository identity."
}

$githubRepository = $githubRepositoryJson | ConvertFrom-Json

if (
-not $githubRepository.owner -or
        -not $githubRepository.ownerId -or
        -not $githubRepository.repository -or
        -not $githubRepository.repositoryId
) {
    throw "Failed to resolve the immutable GitHub repository identity."
}

$githubSubject = "repo:$($githubRepository.owner)@$($githubRepository.ownerId)/$($githubRepository.repository)@$($githubRepository.repositoryId):ref:refs/heads/main"

$env:GITHUB_ACTIONS_SUBJECT = $githubSubject

Write-Host "GitHub Actions OIDC configuration:"
Write-Host "  Repository: $($repository.nameWithOwner)"
Write-Host "  Branch: main"
Write-Host "  Subject: $githubSubject"
Write-Host ""

az deployment sub what-if `
    --location japaneast `
    --template-file .\infra\main.bicep `
    --parameters .\infra\dev.bicepparam

if ($LASTEXITCODE -ne 0) {
    throw "Infrastructure what-if failed."
}
