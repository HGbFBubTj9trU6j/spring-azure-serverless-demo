# Step 6: GitHub ActionsによるCI/CD

Step 6では、GitHub Actionsを使用してSpring BootバックエンドとReactフロントエンドのCI/CDを自動化します。

このパイプラインでは、Azure Container AppsおよびAzure Static Web Appsに対するテスト、ビルド、デプロイ、デプロイ検証を自動化します。

GitHub Actions Workflowは以下に定義されています。

```text
.github/workflows/cicd.yml
```

---

## 目標

Step 6の目標は以下です。

- CI/CDパイプライン実行時にBackendとFrontendの自動テストを実行する。
- Cloud Native Buildpacksを使用してSpring Boot BackendのOCIイメージを作成する。
- 長期間有効なAzure資格情報をGitHubに保存せずにGitHub ActionsからAzureへ認証する。
- Backend OCIイメージをAzure Container RegistryへPushする。
- BackendをAzure Container Appsへデプロイする。
- React Frontendをデプロイ環境に応じた設定でBuildする。
- FrontendをAzure Static Web Appsへデプロイする。
- 現在のGitコミットから生成したArtifactが実際にデプロイされていることを確認する。
- Build、Deploy、Verificationの処理をPowerShellスクリプトとして実装し、GitHub Actions以外からも再利用可能にする。

---

## Pipeline Trigger

このプロジェクトは現在、一人で開発・管理しています。

ローカルで開発し、完成した変更を`main`へCommitしてPushする開発フローを使用しています。

そのため、CI/CD Workflowは`main`へのPush時のみ実行します。

```yaml
on:
  push:
    branches:
      - main
```

この構成により、リポジトリの運用ルールは以下になります。

```text
ローカル開発
    │
    ▼
Commit
    │
    ▼
mainへPush
    │
    ▼
GitHub Actions CI/CD
```

別ブランチへのPushではアプリケーションをデプロイしません。

現在の開発フローではPull Requestによる自動化は必要ありません。将来、ブランチとレビューを利用する開発モデルへ移行する場合には追加できます。

---

## Pipeline概要

WorkflowはBackendとFrontendの独立したJobで構成されています。

```text
main push
   │
   ├───────────────────────────────────┐
   │                                   │
   ▼                                   ▼
Backend                              Frontend
   │                                   │
   ├─ Maven Tests                      ├─ npm install
   │                                   │
   ├─ Buildpacks OCI Build             ├─ Vitest Tests
   │                                   │
   ├─ Azure Login with OIDC            ├─ Azure Login with OIDC
   │                                   │
   ├─ ACR Login                        ├─ Production Build
   │                                   │
   ├─ OCI Image Tag                    ├─ SWA Deploy
   │                                   │
   ├─ ACR Push                         └─ Deployment Verification
   │
   ├─ ACA Deploy
   │
   └─ Deployment Verification
```

BackendとFrontendの両方で、Git Commit SHAを変更されないデプロイ識別子として使用します。

---

# Backend CI/CD

## Backend Tests

Backend Pipelineでは最初にMaven Test Suiteを実行します。

```powershell
./mvnw clean test
```

Backend Testには、Step 5で実装した認証・認可の動作確認も含まれます。

Testは実際のMicrosoft Entra Tenantには依存しません。

Spring SecurityのIssuer設定に必要な値を満たすため、Test専用のTenant値を使用します。

---

## Backend OCI Image Build

BackendはSpring Boot Buildpacksを使用してOCIイメージとしてPackageします。

Pipelineでは以下を使用します。

```text
Paketo Noble Java Tiny Builder
linux/amd64
```

OCIイメージは最初にGitHub Actions Runner上でBuildされます。

Git Commit SHAをImage Versionとして使用します。

```text
spring-azure-serverless-demo/backend:<github-sha>
```

これにより、Git CommitとOCI Imageを直接対応付けられます。

```text
Git Commit
    ↓
OCI Image
```

Dockerfileは必要ありません。

---

## GitHub ActionsからAzureへの認証

GitHub ActionsからAzureへの認証にはOpenID Connect Federationを使用します。

Workflowでは以下を使用します。

```text
azure/login
```

以下の値をGitHub Actions Secretsとして設定します。

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

GitHub Actions Identityは、Federated Identity Credentialを設定したUser Assigned Managed Identityとして構成します。

これにより、長期間有効なAzure Client SecretをGitHubへ保存する必要がありません。

GitHub Actionsが使用するIdentityと、Azure Container AppがRuntimeで使用するIdentityは分離されています。

役割は以下です。

```text
GitHub Actions Managed Identity
    │
    ├─ OCI ImageをACRへPush
    └─ Azure Container AppsをDeploy


Container App Managed Identity
    │
    ├─ RuntimeでOCI ImageをPull
    └─ Azure SQL DatabaseへAccess
```

Identityごとに責務を分離することで、必要な権限を限定できます。

---

## Azure Container RegistryへのPush

Azure認証後、WorkflowはAzure Container RegistryへLoginします。

ローカルでBuildしたImageに以下のTagを付与します。

```text
<acr-login-server>/backend:<github-sha>
```

その後、Azure Container RegistryへPushします。

Git Commit SHAは以下のすべてで共通のDeployment IDとして維持されます。

```text
Git Commit
    ↓
Local OCI Image
    ↓
ACR OCI Image
    ↓
Azure Container Apps
```

---

## Backend Deployment

Backendは以下のScriptを使用してDeployします。

```text
scripts/deploy-backend.ps1
```

GitHub Actions内にDeployment Logicを重複して実装せず、既存のBicep Infrastructure DefinitionをScriptから利用します。

Azure Container Appには以下のRuntime Configurationを設定します。

```text
SPRING_PROFILES_ACTIVE
SPRING_DATASOURCE_URL
ENTRA_TENANT_ID
```

`SPRING_PROFILES_ACTIVE=database`によってAzure SQLを使用するData Accessを有効化します。

`SPRING_DATASOURCE_URL`では、Container AppのUser Assigned Managed Identityを使用してAzure SQLへAccessするよう設定します。

`ENTRA_TENANT_ID`は、Spring SecurityがBackend API Access Tokenを検証するためのMicrosoft Entra JWT Issuerを構成するために必要です。

---

## Backend Deployment Verification

Azure Deployment Commandが成功したことだけでは、期待したApplication Imageが実際に稼働していることの証明にはなりません。

そのため、Step 6ではBackend Deployment後にDeployment Verificationを実行します。

Verificationでは、Azure Container AppsにDeployされているImageと期待するGit Commit SHAを比較します。

概念的には以下です。

```text
Expected
github.sha
    │
    ▼
backend:<github.sha>


Actual
Azure Container Apps
    │
    ▼
Running Image Tag
```

Expected Versionと実際にDeployされたVersionが一致した場合のみ、Deploymentを検証済みとします。

これにより、

```text
Deployment Commandが成功した
```

ことと、

```text
今回のGit Commitから生成したArtifactが実際にDeployされている
```

ことを区別します。

---

# Frontend CI/CD

## Frontend Tests

Frontend Jobでは以下でDependencyをInstallします。

```powershell
npm ci
```

続いてVitest Test Suiteを実行します。

```powershell
npm test -- --run
```

Frontend Testには以下が含まれます。

- Fortune取得
- API Error処理
- `Fortune.Admin`によるUI表示制御
- Fortune Management

FrontendをBuild・Deployする前にこれらのTestを実行します。

---

## Frontend Production Build

Production Frontendは以下のScriptでBuildします。

```text
scripts/build-frontend.ps1
```

ScriptはDeploy済みAzure Container Apps BackendのFQDNを取得し、以下を通してViteへ渡します。

```text
VITE_API_BASE_URL
```

GitHub Actions WorkflowはGit Commit SHAを以下のParameterとして渡します。

```text
-BuildVersion "${{ github.sha }}"
```

Build Scriptはその値をReactへ以下で渡します。

```text
VITE_BUILD_VERSION
```

同じ値をVite Build前に以下にも出力します。

```text
version.json
```

生成したファイルは最終Deployment Outputへ以下として含まれます。

```text
frontend/dist/version.json
```

`frontend/public`配下の一時ファイルはBuild後に削除します。

これにより、Environment固有の生成ファイルをWorking Treeへ残しません。

---

## BuildのFail-Fast

Frontend Production Buildでは、Deploy済みBackend Endpointが必要です。

Azure Container AppのFQDNを取得できなかった場合に、不正なAPI URLを使用してBuildを続行してはいけません。

そのためBuild Scriptでは、

```text
az containerapp show exit code
```

を確認するとともに、取得したFQDNが空でないことを確認します。

Backend Endpointを取得できなかった場合、Buildはその時点で失敗します。

これにより、例えば、

```text
VITE_API_BASE_URL=https://
```

のような不完全な設定でFrontend Buildが成功扱いになることを防止します。

---

## Azure Static Web Apps Deployment

Production Frontendは以下でDeployします。

```text
scripts/deploy-frontend.ps1
```

DeploymentではGitHub Actions Secretとして保存した以下を使用します。

```text
SWA_DEPLOYMENT_TOKEN
```

Azure Static Web Appsは静的Hosting Layerとして使用します。

Application User AuthenticationはAzure Static Web Appsの追加認証レイヤーではなく、React/MSALによって実行します。

これによりLocal DevelopmentとAzure DeploymentでAuthentication Flowを統一しています。

```text
Local

React
  │
  ▼
MSAL
  │
  ▼
Microsoft Entra ID
  │
  ▼
Backend API Access Token
  │
  ▼
Spring Boot


Azure

Azure Static Web Apps
  │
  ▼
React
  │
  ▼
MSAL
  │
  ▼
Microsoft Entra ID
  │
  ▼
Backend API Access Token
  │
  ▼
Spring Boot
```

---

## Frontend Deployment Verification

Static Web Apps Deployment Commandが成功しただけでは、新しくBuildしたFrontendが既に配信されていることは証明できません。

そのためStep 6ではFrontend Deployment Verificationを追加しています。

Production Buildでは以下を公開します。

```text
/version.json
```

内容は以下です。

```json
{
  "version": "<github-sha>"
}
```

Deployment後、CI/CD PipelineはAzure Static Web Appsからこのファイルを取得します。

Verificationでは以下を比較します。

```text
Expected Version
    │
    └─ github.sha

Actual Version
    │
    └─ SWA /version.json
```

両方のVersionが一致した場合のみDeploymentを成功とします。

Verification Scriptは以下です。

```text
scripts/verify-frontend-deployment.ps1
```

Deployment Command完了から新しいStatic Contentが配信されるまで短い時間差が発生する可能性があるため、ScriptではRetryを行います。

Verificationは成功・失敗の両方を検証しました。

```text
Expected == Actual
→ Verification Success
```

```text
Expected != Actual
→ Retry
→ Verification Failure
```

VerificationはHTTPで直接実行するため、現在のAzure CLI TenantやSubscription Contextには依存しません。

---

# Deployment VerificationとE2E Verification

Step 6では、Deployment VerificationとEnd-to-End Scenario Verificationを明確に区別します。

## Deployment Verification

Deployment Verificationが確認するのは、

> このGit Commitから生成したArtifactが実際にDeployされたか

です。

Backend：

```text
github.sha
==
Deployed OCI Image Tag
```

Frontend：

```text
github.sha
==
Deployed /version.json
```

これらはGitHub Actionsで自動化しています。

## End-to-End Verification

E2E Verificationが確認するのは、

> DeployされたSystemを使って、Userが目的とするApplication Scenarioを完了できるか

です。

Step 5で定義したUser Scenarioを使用して、Deploy後のApplicationを手動で再検証しました。

確認したFlowは以下です。

1. Deploy済みReact Applicationを開く。
2. MSALを使用してMicrosoft Entra IDへSign inする。
3. Sign in済み状態を確認する。
4. Fortuneを取得する。
5. Fortune Management UIが`Fortune.Admin`にのみ表示されることを確認する。
6. `Fortune.Admin` Userとして既存Fortuneを一覧表示する。
7. Fortuneを追加する。
8. 追加したFortuneが一覧に表示されることを確認する。
9. Fortuneを削除する。
10. 削除したFortuneが一覧から消えることを確認する。
11. `Fortune.Admin`を持たないUserが管理操作を実行できないことを確認する。
12. Sign outする。

Microsoft Entra ID Interactive Authenticationは現在GitHub Actionsでは自動化していません。

このScenarioを自動化すると、Test User Lifecycle、MFA、Conditional Access、Credential Managementなど、CI/CDとは異なる論点が追加されます。

そのためStep 6では、Deployment VerificationまでをCI/CDとして自動化し、Application全体のE2E Scenarioは独立したManual Quality Checkとして扱います。

---

# GitHub Actions Secrets

CI/CD Workflowでは以下のGitHub Actions Secretsを使用します。

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID

ENTRA_TENANT_ID

VITE_ENTRA_TENANT_ID
VITE_ENTRA_CLIENT_ID
VITE_API_SCOPE

SWA_DEPLOYMENT_TOKEN
```

それぞれの責務は異なります。

| Secret | 用途 |
|---|---|
| `AZURE_CLIENT_ID` | GitHub Actionsが使用するFederated Azure Identity |
| `AZURE_TENANT_ID` | GitHub OIDC Loginで使用するAzure Tenant |
| `AZURE_SUBSCRIPTION_ID` | Deployment対象Azure Subscription |
| `ENTRA_TENANT_ID` | Spring Security JWT Issuer Validationで使用するMicrosoft Entra Tenant |
| `VITE_ENTRA_TENANT_ID` | React/MSALで使用するMicrosoft Entra Tenant |
| `VITE_ENTRA_CLIENT_ID` | React/MSAL Public Client Application ID |
| `VITE_API_SCOPE` | Backend API Delegated Scope |
| `SWA_DEPLOYMENT_TOKEN` | Azure Static Web Apps Deployment |

Authentication TenantとAzure Subscription Tenantは異なる場合があります。

現在のProject Architectureでは、この区別が重要です。

---

# CI/CD Failure Behavior

Pipelineは前提となる処理が失敗した場合に、不完全なArtifactをDeployしたり成功扱いにしたりせず、失敗するよう設計します。

例えば以下です。

- Backend Test Failure
- Frontend Test Failure
- OCI Image Build Failure
- Azure Login Failure
- ACR Push Failure
- Backend Deployment Failure
- Backend Deployed Image Verification Failure
- Frontend Build時にBackend Container App FQDNを取得できない
- Frontend Production Build Failure
- Static Web Apps Deployment Failure
- Frontend Deployed Version Verification Failure

Fail-Fastによって、不完全なDeploymentをGitHub Actionsの成功として扱うことを防止します。

---

# 実施したVerification

Step 6は、自動Pipeline実行とDeploy済みApplicationの双方で確認しました。

## GitHub Actions

```text
Backend Tests                         PASS
Backend OCI Build                     PASS
Azure OIDC Login                      PASS
ACR Push                              PASS
Azure Container Apps Deployment       PASS
Backend Deployment Verification       PASS

Frontend Tests                        PASS
Frontend Production Build             PASS
Azure Static Web Apps Deployment      PASS
Frontend Deployment Verification      PASS
```

## Deploy済みApplication

```text
Frontend Version == GitHub SHA         PASS
Sign in                               PASS
Sign out                              PASS
Fortune Retrieval                     PASS
Role-based UI Visibility              PASS
Fortune List                          PASS
Fortune Creation                      PASS
Fortune Deletion                      PASS
Backend Authorization                 PASS
```

DeployされたFrontend Versionが、GitHub Actionsで処理したGit Commit SHAと一致することも確認しました。

---

# 結果

Step 6によって、`main`へのPushから検証済みAzure Deploymentまでの一連のCI/CDが成立しました。

```text
ローカル開発
    │
    ▼
Commit
    │
    ▼
mainへPush
    │
    ▼
GitHub Actions CI/CD
    │
    ├──────────── Backend ────────────┐
    │                                 │
    │ Test                            │
    │   ↓                             │
    │ OCI Build                       │
    │   ↓                             │
    │ ACR Push                        │
    │   ↓                             │
    │ ACA Deploy                      │
    │   ↓                             │
    │ Deployment Verification         │
    │                                 │
    └──────────── Frontend ───────────┤
                                      │
      Test                            │
        ↓                             │
      Production Build                │
        ↓                             │
      SWA Deploy                      │
        ↓                             │
      Deployment Verification         │
                                      ▼
                              Verified Azure Deployment
```

PipelineではDeployment Commandが成功したことだけでなく、現在のGit Commitに対応するArtifactが実際にDeployされていることまで検証します。

User Scenario全体のE2E Verificationは、独立したQuality Checkとして扱います。

---

## 関連Document

```text
README.md
docs/architecture.md
docs/deployment.md
docs/step04-data-access.md
docs/step05-entra-id-authentication-authorization.md
docs/troubleshooting.md
```
