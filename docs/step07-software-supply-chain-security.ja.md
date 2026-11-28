# Step 7: Software Supply Chain Security / DevSecOps

Step 6では、アプリケーションを継続的にビルド、デプロイできるようにしました。Step 7では、生成されたBackend成果物そのものの内容を把握し、同じ成果物を後から再評価できる独立した経路を追加します。

目的は、単に2つのセキュリティツールを実行することではありません。次の追跡可能なループを確立することです。

```text
Git Commit
    ↓
Azure Container Registry上のbackend:<Git SHA>
    ↓
TagをOCI Digestへ解決
    ↓
Syftによる棚卸しとSBOM生成
    ↓
Grypeによる脆弱性評価
    ↓
アクセス制御された非公開レポート
    ↓
修正、再ビルド、再スキャン
```

このStepでは、以下を扱います。

- `pom.xml`だけではなく、Buildpacksで生成したOCI Imageを調査する
- Syft JSONとSPDX JSON形式のSBOMを生成する
- SBOMをGrypeで評価する
- 既存のAzure Container Registry（ACR）Imageを再ビルドせずにスキャンする
- スキャン前に変更可能なTagを不変のOCI Digestへ解決する
- デプロイとセキュリティ評価を分離する
- 詳細レポートをPrivate Azure Blob Storageへ保存する
- GitHub Actions SummaryにはSeverity件数だけを表示する
- ローカルスクリプトでACR Imageを調査し、保存済みレポートを取得する
- Java RuntimeとMaven管理依存関係の実例を題材に、修正を再スキャンで検証する

> [!IMPORTANT]
> Scannerの検出結果は調査の根拠であり、それだけで悪用可能性が確定するわけではありません。Release判断の前に、検出Package、Match Type、修正版Version、Runtime Architecture、Application Exposure、代替統制を確認してください。

## 目標

Step 7を完了すると、デプロイされたBackend成果物について、次の質問に答えられるようになります。

1. どのGit Commitから生成されたか。
2. どの不変のOCI Manifestをスキャンしたか。
3. Application、Runtime、OS、Buildpack由来のどのPackageが含まれるか。
4. スキャン時点で、どの既知脆弱性がそれらのPackageに一致したか。
5. 詳細レポートはどこに保存され、誰が読み書きできるか。
6. 修正後の成果物に、実際に修正版が含まれているか。

## なぜOCI Imageを評価境界にするのか

Mavenの依存関係Treeは、Applicationが宣言したJava依存関係を表します。しかし、デプロイするImage全体を表すものではありません。最終的なOCI Imageには、Builderと参加Buildpackが提供するJava Runtime、OS Package、証明書、Launch設定、Spring Boot Layerも含まれます。

関係する主なPaketo Buildpackは次のとおりです。

| Buildpack | Build時の役割 |
|---|---|
| [CA Certificates](https://github.com/paketo-buildpacks/ca-certificates) | 必要に応じて信頼するCA証明書を提供します。 |
| [BellSoft Liberica](https://github.com/paketo-buildpacks/bellsoft-liberica) | Applicationが使用するJDKまたはJREを提供します。 |
| [Syft](https://github.com/paketo-buildpacks/syft) | Buildpacks Lifecycleで使用するSoftware Inventory MetadataのためのSyft統合を提供します。 |
| [Executable JAR](https://github.com/paketo-buildpacks/executable-jar) | Executable JAR Applicationを検出し、Launch Processを構成します。 |
| [Spring Boot](https://github.com/paketo-buildpacks/spring-boot) | Spring Boot依存関係MetadataとApplication Layerを提供します。 |

Image作成時に参加するSyft Buildpackと、このStepで使用するStandalone Syft CLIは、関連しますが別のものです。

- BuildpackはCloud Native Buildpacks Lifecycleの一部として実行されます。
- Standalone CLIは、完成したOCI ImageをBuildの外側から調査します。

ここでは、ACRに保存され、実際にデプロイできる成果物を評価するため、外部からのスキャンを検証境界とします。

## Architectureと責務の境界

CI/CDとSecurity Scanは、意図的に責務を分離します。

```text
.github/workflows/cicd.yml
    ├── Application Test
    ├── backend:<Git SHA>をBuild
    ├── ImageをACRへPush
    ├── Azure Container AppsへDeploy
    └── Deployment Verification

.github/workflows/security-scan.yml
    ├── 既存の40文字Git SHAを受け取る
    ├── backend:<Git SHA>をOCI Digestへ解決
    ├── SyftでDigestをスキャン
    ├── 生成したSBOMをGrypeで評価
    ├── Scan Metadataを生成
    ├── 詳細レポートをPrivate Blob StorageへUpload
    └── Severity件数をGitHub Actions Summaryへ出力
```

Security ScanではApplicationを**再ビルドしません**。再ビルドすると、Builderの内容、Buildpack依存関係、Vulnerability Database、Upstream Packageの変化によって、別の成果物が生成される可能性があります。ACRにある既存成果物をスキャンすることで、Step 6で確立した成果物の同一性を維持します。

## 成果物の同一性: Git SHA、Tag、Digest

Step 6では、Backend Imageへ完全なGit Commit SHAを付けます。

```text
<acr-login-server>/backend:<40-character Git SHA>
```

TagはSource Controlとの対応が分かりやすい一方、OCI Tagは移動できます。そのためStep 7では、スキャン前にTagをManifest Digestへ解決します。

```text
backend:<Git SHA>
    ↓
sha256:<OCI Manifest Digest>
    ↓
<acr-login-server>/backend@sha256:<OCI Manifest Digest>
```

SyftはDigestを含むReferenceをスキャンします。Scan MetadataにはSource Tagと解決済みDigestの両方を記録し、Gitとの追跡関係を残しながら、結果を不変のImage Contentへ結び付けます。

## 前提条件

### Tool

次のToolをInstallし、Versionを確認します。

- PowerShell 7以降
- Azure CLI
- Syft
- Grype
- Git

```powershell
pwsh --version
az version
syft version
grype version
git --version
```

検証したToolchainでは[Syft 1.57.1](https://github.com/anchore/syft/releases/tag/v1.57.1)が参照されました。Tool VersionもScan Metadataの一部として扱い、計画的に更新してください。同じImageでも、ScannerやVulnerability Databaseが更新されると結果が変わる場合があります。

### AzureへのSign-inとSubscription

Project ResourceへアクセスできるIDでSign-inします。

```powershell
az login
az account show -o table
```

複数のSubscriptionを利用できる場合は、ScanまたはReport Downloadの前に対象Subscriptionを選択します。

```powershell
az account set --subscription "<subscription-id-or-name>"
```

### Project設定

環境固有の非Secret値は`config/dev.psd1`から読み込みます。Step 7では、次の設定を使用します。

```powershell
@{
    AcrName                           = "<acr-name>"
    BackendBuilderImage              = "<builder-image>@sha256:<digest>"
    SecurityReportStorageAccountName = "<storage-account-name>"
    SecurityReportContainerName      = "security-reports"
}
```

Access Token、Storage Account Key、その他のCredentialをこのFileへ保存しないでください。

### 必要なAccess権

Least Privilege Modelは次のとおりです。

| Principal | Resource Scope | Role / Permission | 目的 |
|---|---|---|---|
| GitHub Actions用User Assigned Managed Identity | ACR | Read / Pull Access | Backend ImageのDigest解決とスキャン。 |
| GitHub Actions用User Assigned Managed Identity | `security-reports` Blob Container | `Storage Blob Data Contributor` | 4つの詳細Report FileをUpload。 |
| 人間のReviewer | ACR | Read / Pull Access | ローカルACR Scanを実行。 |
| 人間のReviewer | `security-reports` Blob Container | `Storage Blob Data Reader` | 保存済みReportをDownload。 |

より広いAccessが不要な場合は、Blob Data RoleをStorage AccountやSubscriptionではなくContainer Scopeで割り当てます。

## 7.1 ローカルのBuildpacks Imageを調査

最初に、ローカルで作成したImageの内容を可視化します。

```powershell
.\mvnw.cmd spring-boot:build-image
```

生成されたImageが`backend:0.0.1-SNAPSHOT`の場合は、Package一覧を表示します。

```powershell
syft "docker:backend:0.0.1-SNAPSHOT"
```

Projectで使用する2形式を生成します。

```powershell
New-Item -ItemType Directory -Force -Path ".\security-reports\local" | Out-Null

syft "docker:backend:0.0.1-SNAPSHOT" `
  -o "syft-json=.\security-reports\local\sbom.syft.json" `
  -o "spdx-json=.\security-reports\local\sbom.spdx.json"
```

Syft JSONはGrypeへの機械処理用Inputとして使用し、SPDX JSONは相互運用可能なSBOM表現として保持します。

```powershell
grype "sbom:.\security-reports\local\sbom.syft.json" `
  -o json `
  --file ".\security-reports\local\grype-report.json"
```

`security-reports/`はGit管理外のままにしてください。SBOMやVulnerability Reportには、Package名、Version、File Path、未修正Componentなどの情報が含まれる場合があります。

## 7.2 ACR Imageをローカルでスキャン

Repositoryには、繰り返し可能なローカル調査用の`scripts/scan-backend-image.ps1`が含まれています。

### 最新のBackend Tagをスキャン

```powershell
.\scripts\scan-backend-image.ps1
```

ScriptはRegistry Metadataに基づいて最新のACR `backend` Tagを選択し、Digestへ解決してから、その不変Referenceをスキャンします。

### 特定のCI/CD成果物をスキャン

```powershell
.\scripts\scan-backend-image.ps1 `
  -ImageTag "<40-character Git SHA>"
```

SHAはImage Tagとして使用する前に、`^[0-9a-f]{40}$`で検証されます。

### 認証経路

このScriptでは、`docker pull`も実行中のDocker daemonも必要ありません。現在のAzure CLI Sessionから短期ACR Tokenを取得します。

```text
az loginで認証したID
    ↓
az acr login --expose-token
    ↓
短期ACR Access Token
    ↓
Syft registry Source
    ↓
Digestで指定したPrivate ACR Image
```

`az acr login --expose-token`は、Docker ClientへCredentialを保存する代わりにTokenを返します。その後、SyftがRegistryを直接読み取ります。

学習とTroubleshooting用に、同等のManual Commandを示します。通常運用ではScriptを使用してください。ScriptはDigest解決、認証用環境変数の復元、全Report生成、Metadata記録も行います。

```powershell
$config = Import-PowerShellDataFile ".\config\dev.psd1"
$acrName = $config.AcrName
$acrLoginServer = "$acrName.azurecr.io"
$imageTag = "<40-character Git SHA>"

$acrToken = az acr login `
  --name $acrName `
  --expose-token `
  --query accessToken `
  -o tsv

$env:SYFT_REGISTRY_AUTH_USERNAME = "00000000-0000-0000-0000-000000000000"
$env:SYFT_REGISTRY_AUTH_PASSWORD = $acrToken

$image = "$acrLoginServer/backend:$imageTag"
syft "registry:$image"
```

取得したTokenはCredentialとして扱います。Logへ出力したり、Repositoryへ保存したりしないでください。

### ローカル出力

Scriptは次のFileを生成します。

```text
security-reports/
└── <Git SHA>/
    ├── sbom.syft.json
    ├── sbom.spdx.json
    ├── grype-report.json
    └── scan-metadata.json
```

ConsoleにはSeverity Summaryを表示しますが、ローカル結果をBlob StorageへUploadしません。共有Reportを生成、保存する正式な経路はGitHub Actions Workflowです。

## 7.3 生成されるReportを理解する

### `sbom.syft.json`

Syft固有のJSON表現であり、詳細なPackage情報とRelationshipを含みます。このProjectではGrypeへのInputとして使用します。

### `sbom.spdx.json`

SPDX JSON表現は、SPDX Standardを利用するToolやProcessとの相互運用に使用できます。後から別Imageを対象に変換するのではなく、Syft JSONと同じScanで生成して保持します。

### `grype-report.json`

Grype JSON Reportには、Artifact、Vulnerability ID、Severity、修正情報、Match Detail、Scanner Metadataが含まれます。検出結果は次の点を踏まえて解釈します。

- `Critical`、`High`、`Medium`、`Low`、`Negligible`、`Unknown`は、優先順位付けのSignalです。
- Exact Direct MatchやExact Indirect Matchは、一般に広いCPE Matchより強いPackage Evidenceを持ちます。
- Fix Versionが空でも、安全であることを意味しません。
- 同じVulnerabilityが、複数のAdvisoryやPackage Relationshipを通じて現れる場合があります。
- Scanner VersionとDatabase Versionは結果へ影響します。

### `scan-metadata.json`

Metadata Fileは、Reportと実行Contextを結び付けます。少なくとも次を含めます。

- Git SHA / Image Tag
- Tag付きImage Reference
- Digest付きの解決済みImage Reference
- OCI Digest
- UTCのScan Timestamp
- Syft Version
- Grype Version
- Workflowが使用したReport SchemaまたはFile名

`scan-metadata.json`を暗号学的署名として扱わないでください。これはTraceability Metadataです。Image SigningとAttestationは将来の統制です。

## 7.4 Security Scan Workflow

独立したWorkflowは次のFileで定義します。

```text
.github/workflows/security-scan.yml
```

`workflow_dispatch`で手動実行し、完全なGit SHAを指定します。想定する処理順序は次のとおりです。

1. 40文字の小文字16進数SHAを検証する。
2. Repositoryの設定とWorkflow CodeをCheckoutする。
3. GitHub OIDCとUser Assigned Managed IdentityでAzureへ認証する。
4. `config/dev.psd1`から`AcrName`、Storage Account名、Container名を読み取る。
5. `backend:<SHA>`をOCI Digestへ解決する。
6. 短期ACR Tokenを取得し、Digest付きImageをSyftでスキャンする。
7. Syft JSONとSPDX JSON形式のSBOMを生成する。
8. Syft JSON SBOMをGrypeで評価する。
9. `scan-metadata.json`を生成する。
10. GitHub Actions Job Summary用にSeverity件数を集計する。
11. Microsoft Entra認証を使用して、4つの詳細FileをPrivate Blob StorageへUploadする。

正常終了したRunでは、次の対応関係を保持します。

```text
Git SHA
  = ACR Tag
  → OCI Digest
  → SBOM
  → Grype Report
  → Scan Metadata
  → Private Report Prefix
```

### なぜ手動起動にするのか

最初の実装では`workflow_dispatch`を使用し、Operatorが既存成果物を選択して、Deployment経路を変更せずに調査できるようにします。これによりStep 7を、棚卸し、Traceability、Report保護、修正検証へ集中させます。

将来は、Continuous Vulnerability Re-evaluationのためにScheduleを追加できます。Application Codeが変わらなくても、新しいVulnerabilityが公開されることがあるため、定期的な再スキャンには意味があります。

## 7.5 Private Report Storage

詳細Reportは、成果物ごとのPrefixへUploadします。

```text
security-reports/
└── backend/
    └── <Git SHA>/
        ├── sbom.syft.json
        ├── sbom.spdx.json
        ├── grype-report.json
        └── scan-metadata.json
```

Storage Designでは、次のControlを適用します。

- Blob Container AccessをPrivateにする
- Anonymous Public Accessを無効にする
- Shared Key Authorizationを無効にする
- HTTPSを必須にする
- TLS 1.2以降を必須にする
- GitHub ActionsはMicrosoft Entra IDとContainer ScopeのRBACで書き込む
- ReviewerはMicrosoft Entra IDとContainer ScopeのRBACで読み取る

Azure CLIのData Operationでは、次を明示します。

```text
--auth-mode login
```

`--auth-mode login`を省略すると、Azure CLIがAccount Key Authorizationを試みる場合があります。ScriptとWorkflowでは、意図したID経路を明示します。

## 7.6 GitHub Actions Summaryの情報公開境界

GitHub Actions Summaryには、次のような集計件数だけを表示します。

| Severity | 件数 |
|---|---:|
| Critical | 0 |
| High | 2 |
| Medium | 8 |
| Low | 4 |
| Negligible | 1 |
| Unknown | 0 |

Summaryへ次の情報を出力してはいけません。

- Package名、Executable名
- Install済みPackage Version
- CVE Description
- 修正版Version
- File Path
- 完全なSBOM
- 完全なGrype Report

これは情報公開の境界であり、完全なAuthorization Controlではありません。Workflow Runの閲覧可否はRepository Permissionにも依存し、詳細Reportは引き続きAzure RBACで保護します。

最初の実装では、結果を表示してもRelease Gateにはしません。`Critical > 0`なら常にFailとするようなRuleは、Match Quality、Exploitability、Accepted Risk、Exception、Remediation SLAを定義してから導入します。

## 7.7 保存済みReportをDownload

`scripts/download-security-report.ps1`を使用して、Sign-in済みAzure IDでReportを取得します。

### 最新の完了済みReportを取得

```powershell
.\scripts\download-security-report.ps1
```

`-ImageTag`を省略すると、Scriptは`backend/*/scan-metadata.json` Blobを一覧し、Blobの`lastModified`時刻が最新の完了済みReportを選択します。現在のGit `HEAD`に対するScanが完了済みであるとは仮定しません。

### 特定のReportを取得

```powershell
.\scripts\download-security-report.ps1 `
  -ImageTag "<40-character Git SHA>"
```

4つのFileは次の場所へDownloadされます。

```text
security-reports/<Git SHA>/
```

Scriptは`az storage blob` Commandで`--auth-mode login`を使用します。Storage Account Keyを取得、使用しません。

## 7.8 ローカルでReport Dataを確認

PowerShellでJSONを整形表示します。

```powershell
Get-Content ".\security-reports\<Git SHA>\grype-report.json" -Raw |
  ConvertFrom-Json |
  ConvertTo-Json -Depth 100
```

Severityの分布を表示します。

```powershell
$report = Get-Content ".\security-reports\<Git SHA>\grype-report.json" -Raw |
  ConvertFrom-Json

$report.matches |
  Group-Object { $_.vulnerability.severity } |
  Sort-Object Name |
  Select-Object Name, Count |
  Format-Table -AutoSize
```

CriticalとHighの検出結果、および利用可能なFixを表示します。

```powershell
$report.matches |
  Where-Object { $_.vulnerability.severity -in @("Critical", "High") } |
  Select-Object `
    @{Name="Package"; Expression={$_.artifact.name}},
    @{Name="Installed"; Expression={$_.artifact.version}},
    @{Name="Vulnerability"; Expression={$_.vulnerability.id}},
    @{Name="Severity"; Expression={$_.vulnerability.severity}},
    @{Name="FixedIn"; Expression={$_.vulnerability.fix.versions -join ", "}} |
  Format-Table -AutoSize
```

False PositiveまたはRelease Blockerと判断する前に、完全なJSONでMatch Detailを確認してください。

## 7.9 検証済み修正事例: Java4Shell

このProjectでは、Java4Shellと呼ばれる`CVE-2026-114938`を対象に、検出、原因追跡、修正、再検証の一連の流れを実行しました。

### 最初の観測

Syftによって、完成したBackend ImageにOpenJDK `21.0.12`が含まれることを確認しました。Grypeは、このRuntimeに`CVE-2026-114938`を一致させました。

重要なのはCVEだけではなく、影響を受けるComponentのProvenanceです。

```text
pom.xml
    └── PackageされるJREを選択していない

Spring Boot Buildpacks
    ↓
Paketo Builder
    ↓
BellSoft Liberica Buildpack
    ↓
最終OCI Image内のLiberica JRE
```

問題はRuntimeにあるため、Application Dependencyを変更するだけでは、Package済みJREを修正できません。

### 修正

修正版BellSoft Liberica依存関係を含むBuilderへ更新し、`config/dev.psd1`でDigestを固定しました。

```powershell
BackendBuilderImage = "paketobuildpacks/builder-noble-java-tiny@sha256:<verified-digest>"
```

ローカルBuildとGitHub Actionsは同じ値を使用するため、DeveloperとCIで異なるBuilderを知らないうちに選択することを防げます。

再ビルドしたImageには、次の公開Archiveに対応するBellSoft Liberica JRE `21.0.13.1+5`が含まれていました。

```text
bellsoft-jre21.0.13.1+5-linux-amd64.tar.gz
```

[BellSoft Liberica Release Artifact](https://github.com/bell-sw/Liberica/releases/download/21.0.13.1+5/bellsoft-jre21.0.13.1+5-linux-amd64.tar.gz)および[CVE-2026-114938に関するBellSoft Guidance](https://bell-sw.com/blog/addressing-java4shell-in-liberica-jdk/)も参照してください。

### 検証

修正後のApplicationを再ビルドし、新しいGit SHA TagでPushし、新しいDigestへ解決して再スキャンしました。対象CVEは再検出されませんでした。

```text
OpenJDK 21.0.12
    ↓
CVE-2026-114938を検出
    ↓
RuntimeをBellSoft Liberica BuildpackとPaketo Builderまで追跡
    ↓
Builderを更新し、Digestで固定
    ↓
BellSoft Liberica JRE 21.0.13.1+5
    ↓
再ビルド、再スキャン
    ↓
CVE-2026-114938は非検出
```

この検証では、異なる2つの性質を確認しています。

1. **Remediation** — 再ビルドしたImageに修正版Runtimeが含まれる。
2. **Provenance** — RuntimeはMaven依存関係だけではなく、BuilderとBuildpackのSupply Chainから提供される。

非検出という結果は、検証に使用したImage、Scanner、Vulnerability Databaseに対するものです。他の脆弱性が存在しないことを証明するものではありません。

## 7.10 検証済み修正事例: NettyのMaven依存関係

このProjectでは、Applicationが直接宣言していないAzure SDK経由のNetty脆弱性についても、検出、依存経路の特定、修正、再検証のLoopを実行しました。

### 最初の観測と依存経路の特定

GrypeによるBuildpacks生成OCI Imageの検査で、影響を受けるNetty Componentが検出されました。対象範囲には4.2.19.Finalが含まれ、4.2.20.Finalが修正版として示されていました。検出対象には`netty-handler`だけでなくQUIC Classesも含まれていたため、1つのNetty Moduleだけを更新する方法では不十分です。

Mavenで依存経路を確認しました。

```powershell
.\mvnw.cmd dependency:tree "-Dincludes=io.netty"
```

PowerShellでは、`-Dincludes=io.netty`全体を引用符で囲みます。引用符がない場合、Mavenへ`.netty`が別の引数として渡され、`Unknown lifecycle phase ".netty"`となることがあります。

確認した依存経路は次のとおりです。

```text
com.azure:azure-identity:1.18.7
  └── com.azure:azure-core-http-netty:1.16.8
      └── io.netty:*:4.2.19.Final
```

これにより、NettyはApplicationの直接依存ではなく、`azure-identity`の推移的依存関係であることを確認しました。

### 管理Versionの特定

`pom.xml`を変更する前に、Effective POMを生成して管理Versionを確認しました。

```powershell
.\mvnw.cmd help:effective-pom > effective-pom.xml
Select-String -Path .\effective-pom.xml -Pattern "netty.version"
```

Effective POMには次の値が含まれていました。

```xml
<netty.version>4.2.19.Final</netty.version>
```

`effective-pom.xml`は調査のために生成したFileであり、Commit対象にはしません。

### 修正

`pom.xml`の既存Propertyを上書きしました。

```xml
<properties>
    <!-- その他の管理Versionは省略 -->
    <netty.version>4.2.20.Final</netty.version>
</properties>
```

`netty-handler`への直接依存や、追加のNetty BOMは導入していません。既存Propertyを使用することで、現在の依存関係管理境界を維持し、関連ModuleのVersionをそろえました。

### 検証

依存関係Treeを再確認し、対象および関連Moduleが一貫して4.2.20.Finalへ解決されたことを確認しました。

```text
io.netty:netty-handler:4.2.20.Final
io.netty:netty-codec-classes-quic:4.2.20.Final
io.netty:netty-codec-http3:4.2.20.Final
io.netty:netty-common:4.2.20.Final
```

`netty-tcnative-boringssl-static`は別のVersion体系を使用しており、管理された依存関係Setにより2.0.84.Finalから2.0.85.Finalへ更新されました。

その後、BuildpacksでBackend OCI Imageを再ビルドし、Grypeで再検査しました。再ビルドしたImageでは、今回対象としていたNettyの検出結果が表示されなくなりました。Mavenは依存関係Graphを確認し、最後のGrype Scanは配布対象OCI成果物の内容を確認します。

```text
OCI ImageでGrypeが検出
    ↓
azure-identity → azure-core-http-netty → Nettyを特定
    ↓
Effective POMでnetty.versionを確認
    ↓
4.2.19.Final → 4.2.20.Finalへ更新
    ↓
dependency:treeでModuleの整合性を確認
    ↓
BuildpacksでOCI Imageを再ビルド
    ↓
Grypeで再スキャン
    ↓
対象Netty脆弱性は非検出
```

### 異なる対応が必要な検出結果

同じScanから、次の3種類の対応を確認できました。

- **修正して再検証する:** Nettyは互換性のある修正版を取得できたため、更新してImageを再スキャンしました。
- **記録して再評価する:** `tomcat-embed-core` 11.0.29には修正版11.0.30が示されましたが、調査時点ではMaven Centralからまだ取得できませんでした。検出結果を消す目的で存在しないVersionは宣言しません。
- **ProvenanceとMatch品質を確認する:** OpenSSLはBinary検出とUbuntu Package検出の両方に現れました。Upstream Version文字列だけでBackport修正が存在しないと判断せず、Ubuntu Package VersionとAdvisoryを確認します。

この事例は、Scannerの1行に表示されたPackageだけを更新する危険性も示します。関連Moduleが影響Versionに残るか、SupportされないVersion混在状態を作る可能性があります。

## 7.11 Builderの固定と更新

BuilderをDigestで固定するとBuildの再現性が高まりますが、固定したDigestは自動更新されません。Builderを保守対象の依存関係として扱います。

1. 更新候補のBuilderを特定する。
2. Builderと関係するBuildpackのRelease情報を確認する。
3. 新しいBuilder Digestを解決、記録する。
4. `config/dev.psd1`の`BackendBuilderImage`を更新する。
5. BackendをローカルBuildする。
6. 生成したImageをSyftで確認する。
7. SBOMをGrypeでスキャンする。
8. 設定変更をCommitする。
9. CI/CDでGit SHA Tag付き成果物をBuild、Deployする。
10. 独立したSecurity Scanで、そのACR成果物を評価する。

Security Updateを自動取得するためだけに、Digest固定を変更可能な`latest` Tagへ戻さないでください。管理された更新と再検証によって、Securityと再現性の両方を維持します。

## 7.12 ACR成果物のLifecycle

開発を続けると、Git SHA Tagが蓄積します。ACRは課金対象ですが、OCI Layerは共有される場合があるため、Tag数はそのままStorage使用量にはなりません。

成果物を削除する前に、次を確認します。

- Azure Container Appsで現在Deploy中のImageを特定する
- Releaseに対応する成果物を保持する
- 修正事例や進行中の調査に必要な成果物を保持する
- 対応するImageがなくなった後もReportを保持するか決める
- `az acr show-usage`でACR使用量を確認する

Demo環境では、次のようなPolicyから開始できます。

```text
保持: 現在Deploy中のImage
保持: Releaseに対応するImage
保持: 調査、Case Studyに必要なImage
保持: 定義した期間または件数の最近の開発Image
削除候補: Releaseに対応しない古いImage
削除候補: 確認後のローカル *-dirty Tag
```

必ず最初に候補を一覧し、明示的に確認した条件で削除します。期間ベースのRuleでも、現在Deploy中、Release済み、調査中のImageを削除してはいけません。

## 7.13 失敗時の対応とTroubleshooting

### `manifest unknown`またはImage Not Found

- 完全なGit SHAが`backend` RepositoryのTagとして存在することを確認します。
- `az acr repository show-tags`でTagを一覧します。
- `config/dev.psd1`が正しいACRとSubscriptionを指していることを確認します。

### ACR Authorization Failure

- `az account show`を実行し、TenantとSubscriptionを確認します。
- ReviewerまたはManaged IdentityにRegistryのRead / Pull Accessがあることを確認します。
- Exposed ACR Tokenは短期のため、新しいTokenを取得します。
- 通常のScanでACR Admin Accountへ切り替えないでください。

### Syftが認証できない

- Syftを実行するProcessで、2つのRegistry認証環境変数が設定されていることを確認します。
- Digest付きImage Referenceが正しいLogin Serverを使用していることを確認します。
- Scan後に一時的な環境変数を削除または元の値へ戻します。
- Token値を出力しないでください。

### Grype Database Updateに失敗する

- 設定されたGrype Database SourceへのNetwork Accessを確認します。
- Database StatusとScanner Versionを記録します。
- Databaseが古い、または利用できないScanを、現在のClean Resultとして提示しないでください。

### Blob UploadまたはDownloadが拒否される

- `--auth-mode login`が指定されていることを確認します。
- PrincipalにAzure管理Plane Roleだけではなく、必要なBlob Data Roleがあることを確認します。
- Role Assignment Scopeが対象の`security-reports` Containerであることを確認します。
- 新しいRole AssignmentではRBAC反映時間を考慮します。

### Report Setが不完全

4つのFileがすべて存在する場合だけ、Reportを完了と扱います。Download Scriptは最新の完了済みReportを探索するときに`scan-metadata.json`を使用し、一部だけUploadされたPrefixを正常結果として選択しないようにします。

## 7.14 検証Checklist

成果物についてStep 7を完了と判断する前に、次を確認します。

- [ ] Source Git SHAが分かっている。
- [ ] `backend:<Git SHA>`が対象ACRに存在する。
- [ ] Scan前にTagをOCI Digestへ解決した。
- [ ] SyftがDigest付きReferenceをスキャンした。
- [ ] `sbom.syft.json`を生成した。
- [ ] `sbom.spdx.json`を生成した。
- [ ] Syft SBOMから`grype-report.json`を生成した。
- [ ] `scan-metadata.json`へTag、Digest、Timestamp、Tool Versionを記録した。
- [ ] GitHub Actions SummaryにはSeverity件数だけが含まれる。
- [ ] 4つの詳細FileをPrivate Blob PrefixへUploadした。
- [ ] WriterとReaderのRoleをReport Container Scopeへ限定した。
- [ ] Shared KeyとAnonymous Accessを使用していない。
- [ ] ローカル`security-reports/`をGit管理外にしている。
- [ ] 修正を、再ビルドしたACR成果物のScanで検証した。

## 今後の発展

次の改善は有用ですが、Step 7の完了境界には含めません。

1. **定期再スキャン** — 変更していないImageを新しいVulnerability Databaseで再評価する。
2. **Retention自動化** — Deploy中とRelease成果物を保護しながら、対象となる古いImageとReportを削除する。
3. **ExceptionとRisk Workflow** — Accepted Risk、False Positiveの根拠、Owner、有効期限を記録する。
4. **Release Policy** — 生のSeverity件数ではなく、Review済みPolicyから`PASS`、`REVIEW`、`FAIL`を決定する。
5. **Image SigningとVerification** — OCI成果物へ暗号学的なIdentityを追加する。
6. **ProvenanceとAttestation** — 検証可能なBuildおよびSBOM Attestationを公開する。
7. **追加のSBOM形式** — Consumerが必要とする場合にだけCycloneDXなどを追加する。

Release Gateは、Match Confidenceの扱い、Exploitability Context、Remediation SLA、Exception Owner、緊急Override Processを定義してから導入してください。

## 関連File

```text
.github/workflows/cicd.yml
.github/workflows/security-scan.yml
config/dev.psd1
scripts/scan-backend-image.ps1
scripts/download-security-report.ps1
docs/step06-cicd.md
docs/step06-cicd.ja.md
docs/step07-software-supply-chain-security.md
docs/step07-software-supply-chain-security.ja.md
```

## 参考資料

- [Paketo Buildpack for CA Certificates](https://github.com/paketo-buildpacks/ca-certificates)
- [Paketo Buildpack for BellSoft Liberica](https://github.com/paketo-buildpacks/bellsoft-liberica)
- [Paketo Buildpack for Syft](https://github.com/paketo-buildpacks/syft)
- [Paketo Buildpack for Executable JARs](https://github.com/paketo-buildpacks/executable-jar)
- [Paketo Buildpack for Spring Boot](https://github.com/paketo-buildpacks/spring-boot)
- [Syft 1.57.1 Release](https://github.com/anchore/syft/releases/tag/v1.57.1)
- [Syft Private Registry Authentication](https://github.com/anchore/syft/wiki/Private-Registry-Authentication)
- [Grype Getting Started](https://oss.anchore.com/docs/guides/vulnerability/getting-started/)
- [Understanding Grype Results](https://oss.anchore.com/docs/guides/vulnerability/interpreting-results/)
- [Working with Grype JSON](https://oss.anchore.com/docs/guides/vulnerability/json/)
- [Azure Container Registry Authentication](https://learn.microsoft.com/azure/container-registry/container-registry-authentication)
- [Azure CLIによるBlob Data Operationの認証](https://learn.microsoft.com/azure/storage/blobs/authorize-data-operations-cli)
- [GitHub Actions Secure Use Reference](https://docs.github.com/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions)
- [Java4Shell / CVE-2026-114938に関するBellSoft Guidance](https://bell-sw.com/blog/addressing-java4shell-in-liberica-jdk/)
