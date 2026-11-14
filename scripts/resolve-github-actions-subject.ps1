$ErrorActionPreference = "Stop"

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

Write-Output $githubSubject
