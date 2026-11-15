# 認証セットアップ

このドキュメントでは、`spring-azure-serverless-demo` の現在の Microsoft Entra ID 認証・認可構成を再現し、検証する方法について説明します。

現在の実装では、以下を使用します。

- 対話型ユーザーサインインには React と MSAL を使用します。
- フロントエンドにはシングルテナントの SPA App Registration を使用します。
- バックエンド API には別の App Registration を使用します。
- フロントエンドからバックエンドへの呼び出しには OAuth 2.0 アクセストークンを使用します。
- バックエンドのリソースサーバーとして Spring Security を使用します。
- API アクセスには委任された `access_as_user` スコープを使用します。
- 管理操作には `Fortune.Admin` アプリロールを使用します。
- Azure Static Web Apps は静的フロントエンドのホスティングにのみ使用します。

デプロイシーケンス全体については、以下を参照してください。

```text
docs/deployment.md
```

アーキテクチャと信頼境界の詳細については、以下を参照してください。

```text
docs/authentication.md
docs/architecture.md
```

---

## 概要

認証リソースとアプリケーションリソースは、異なる Microsoft Entra ID テナントコンテキストに存在する場合があります。

```text
Azure サブスクリプションテナント
  │
  ├── Azure Static Web Apps
  ├── Azure Container Apps
  ├── Azure Container Registry
  ├── Azure SQL Database
  └── ユーザー割り当てマネージド ID

認証テナント
  │
  ├── spring-azure-serverless-demo-client
  │     ├── SPA プラットフォーム構成
  │     ├── 運用環境およびローカルのリダイレクト URI
  │     └── 委任された access_as_user アクセス許可
  │
  └── spring-azure-serverless-demo-api
        ├── Application ID URI
        ├── 委任された access_as_user スコープ
        ├── Fortune.Admin アプリロール
        └── Service Principal
```

アプリケーションの認証フローは次のとおりです。

```text
ブラウザー
  │
  ▼
Azure Static Web Apps
  │  React アプリケーションを配信
  ▼
React / MSAL
  │  PKCE を使用した認可コードフロー
  ▼
Microsoft Entra ID
  │  API 用のアクセストークンを発行
  ▼
Spring Boot / Spring Security
  │  トークン、スコープ、ロールを検証
  ▼
保護された Fortune API 操作
```

このアーキテクチャでは、Azure Static Web Apps はユーザー認証を実行しません。コンパイル済みのフロントエンドとその静的構成をホストします。

React SPA はパブリッククライアントです。機密クライアント資格情報を使用または保存してはいけません。

---

## 認証セットアップフロー

セットアップシーケンスは次のとおりです。

```text
前提条件を確認
        │
        ▼
Azure サブスクリプションを選択し、Static Web Apps のホスト名を取得
        │
        ▼
認証テナントへ切り替え
        │
        ▼
41-deploy-identity.ps1 を実行
        │
        ├── バックエンド API の App Registration を作成または更新
        ├── access_as_user を構成
        ├── Fortune.Admin を構成
        ├── API の Service Principal を作成または確認
        ├── React SPA の App Registration を作成または更新
        ├── 運用環境およびローカルの SPA リダイレクト URI を構成
        └── クライアントから API への委任されたアクセス許可を構成
        │
        ▼
2 つの App Registration を確認
        │
        ▼
認証テナント構成を使用してバックエンドをデプロイ
        │
        ▼
フロントエンドをビルドしてデプロイ
        │
        ▼
サインイン、API アクセス、認可、サインアウトを確認
```

ID デプロイは、意図的にべき等になるよう設計されています。スクリプトは可能な場合に一致する App Registration を再利用し、その構成を想定される状態に収束させます。

---

## 前提条件

認証を構成する前に、以下を確認してください。

- Azure Static Web Apps がデプロイ済みであること。
- その運用環境のホスト名が利用できること。
- ユーザーが Azure サブスクリプションテナントへアクセスできること。
- ユーザーが認証テナント内のアプリケーション、Service Principal、スコープ、アクセス許可、アプリロールを管理できること。
- Azure CLI がインストールされ、認証済みであること。
- PowerShell が利用できること。
- リポジトリのスクリプトがローカルで利用できること。
- バックエンドとフロントエンドをビルドおよびデプロイできること。
- 必要に応じて、対象ユーザーが認証テナントに存在するか、招待されていること。
- テナントポリシーで必要な場合に、テナント管理者が同意を付与したり、アプリロールを割り当てたりできること。

運用環境の Static Web Apps ホスト名を SPA リダイレクト URI として使用するため、通常は ID スクリプトを実行する前に Azure インフラストラクチャをデプロイしておく必要があります。

---

## 必要な情報

セットアップでは以下の値を使用します。

```text
認証テナント ID
Azure サブスクリプションテナント ID
Azure サブスクリプション ID
Azure Static Web Apps 名
Azure Static Web Apps のリソースグループ
Azure Static Web Apps の運用環境ホスト名
バックエンド API の App Registration 名
React SPA の App Registration 名
```

既定の App Registration 名は次のとおりです。

```text
spring-azure-serverless-demo-api
spring-azure-serverless-demo-client
```

環境固有でシークレットではない Azure リソース名は、以下から読み込まれます。

```text
config/dev.psd1
```

資格情報、トークン、その他のシークレット値を環境構成ファイルに配置しないでください。

---

## 必要な環境変数

### ENTRA_TENANT_ID

バックエンドのデプロイには以下が必要です。

```text
ENTRA_TENANT_ID
```

この値は、バックエンドがトークンを受け入れる Microsoft Entra ID テナントを識別します。これはシークレットではありません。

値を表示せずに、利用可能であることを確認します。

```powershell
if ($env:ENTRA_TENANT_ID) {
    Write-Host "ENTRA_TENANT_ID is configured."
}
else {
    Write-Host "ENTRA_TENANT_ID is not configured."
}
```

必要に応じて、現在の PowerShell セッションに設定します。

```powershell
$env:ENTRA_TENANT_ID = "<AUTHENTICATION_TENANT_ID>"
```

Windows のユーザー環境変数として保存するには、次を実行します。

```powershell
[System.Environment]::SetEnvironmentVariable(
    "ENTRA_TENANT_ID",
    "<AUTHENTICATION_TENANT_ID>",
    "User"
)
```

Windows のユーザー環境変数を設定した後、新しい PowerShell セッションを開きます。

### SWA_DEPLOYMENT_TOKEN

フロントエンドのデプロイには以下が必要です。

```text
SWA_DEPLOYMENT_TOKEN
```

これはデプロイ資格情報であり、ユーザー認証用の資格情報ではありません。シークレットとして取り扱い、コミットしないでください。

---

## Step 1: Azure サブスクリプションコンテキストを確認する

Azure サブスクリプションリソースを含むテナントにサインインします。

```powershell
az login `
  --tenant <AZURE_SUBSCRIPTION_TENANT_ID>
```

対象のサブスクリプションを選択します。

```powershell
az account set `
  --subscription <AZURE_SUBSCRIPTION_ID>
```

アクティブな Azure CLI コンテキストを確認します。

```powershell
az account show `
  --query "{tenantId:tenantId,subscriptionId:id,subscriptionName:name}" `
  --output table
```

以下を確認します。

- アクティブなテナントが Azure サブスクリプションテナントであること。
- 選択したサブスクリプションに、デプロイ済みの Static Web App が含まれていること。
- 想定されるリソースグループが利用可能であること。

---

## Step 2: Azure Static Web Apps のホスト名を取得する

運用環境のホスト名を取得します。

```powershell
$swaHostname = az staticwebapp show `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --query defaultHostname `
  --output tsv
```

結果を確認します。

```powershell
if (-not $swaHostname) {
    throw "The Azure Static Web Apps hostname could not be determined."
}

Write-Host "Static Web Apps hostname: $swaHostname"
```

値は URI スキームを含まないホスト名である必要があります。例:

```text
<STATIC_WEB_APP_HOSTNAME>
```

対応する運用環境の SPA リダイレクト URI は次のとおりです。

```text
https://<STATIC_WEB_APP_HOSTNAME>
```

開発環境の例と異なる場合は、選択した環境の実際の Static Web Apps 名とリソースグループを使用してください。

---

## Step 3: 認証テナントへ切り替える

認証テナントにサインインします。

```powershell
az login `
  --tenant <AUTHENTICATION_TENANT_ID> `
  --allow-no-subscriptions
```

アクティブなテナントを確認します。

```powershell
az account show `
  --query tenantId `
  --output tsv
```

ID デプロイスクリプトを実行する前に、結果が認証テナントと一致している必要があります。

認証テナントには、対象の Azure サブスクリプションが含まれていない場合があります。その場合、`--allow-no-subscriptions` オプションを使用すると、ディレクトリレベルの ID 操作を実行できます。

---

## Step 4: ID 構成を作成または更新する

リポジトリのルートから ID デプロイスクリプトを実行します。

```powershell
.\scripts\41-deploy-identity.ps1 `
  -StaticWebAppHostname $swaHostname
```

既定では、スクリプトは以下を管理します。

```text
spring-azure-serverless-demo-api
spring-azure-serverless-demo-client
```

バックエンド API の登録には以下が含まれます。

- Application ID URI。
- 委任されたアクセス許可スコープ `access_as_user`。
- `Fortune.Admin` アプリロール。
- 認証テナント内の Service Principal。

React SPA の登録には以下が含まれます。

- 運用環境のリダイレクト URI `https://<STATIC_WEB_APP_HOSTNAME>`。
- ローカル開発用のリダイレクト URI `http://localhost:5173`。
- API の `access_as_user` スコープに対する委任されたアクセス許可。

スクリプトの出力には、テナント ID、アプリケーション ID、オブジェクト ID、スコープ ID、ロール ID、Service Principal ID、リダイレクト URI が含まれます。これらの値は環境固有の構成データとして扱ってください。実際の識別子を、コミット対象のドキュメントにコピーしないでください。

### 表示名の任意指定

リポジトリのスクリプトが別の環境向けに表示名パラメーターをサポートしている場合は、スクリプトで定義されたパラメーター名を使用してください。API と SPA の登録を分離し、テナント内で一意の名前を使用してください。

Static Web Apps ホスト用に追加の登録を作成しないでください。現在のホストは OAuth の機密クライアントではありません。

---

## Step 5: バックエンド API の App Registration を確認する

API アプリケーションを取得します。

```powershell
$apiApp = az ad app list `
  --display-name "spring-azure-serverless-demo-api" `
  --query "[0]" `
  --output json | ConvertFrom-Json

if (-not $apiApp) {
    throw "The backend API App Registration was not found."
}
```

実際の値をリポジトリファイルに書き込まずに、その主要な構成を確認します。

```powershell
az ad app show `
  --id $apiApp.id `
  --query "{displayName:displayName,appId:appId,identifierUris:identifierUris,scopes:api.oauth2PermissionScopes[].{value:value,isEnabled:isEnabled},roles:appRoles[].{value:value,isEnabled:isEnabled}}" `
  --output json
```

以下を確認します。

- Application ID URI が存在すること。
- `access_as_user` スコープが存在し、有効であること。
- `Fortune.Admin` アプリロールが存在し、有効であること。
- ロールで許可されるメンバーの種類が、意図した割り当てモデルと一致していること。

### API の Service Principal を確認する

```powershell
az ad sp list `
  --filter "appId eq '$($apiApp.appId)'" `
  --query "[].{displayName:displayName,appId:appId,id:id}" `
  --output table
```

想定される Service Principal が 1 つだけ存在する必要があります。

Service Principal は、アクセス許可への同意とアプリロール割り当てに使用される、テナント内の表現です。API 登録の使用中は削除しないでください。

---

## Step 6: React SPA の App Registration を確認する

クライアントアプリケーションを取得します。

```powershell
$clientApp = az ad app list `
  --display-name "spring-azure-serverless-demo-client" `
  --query "[0]" `
  --output json | ConvertFrom-Json

if (-not $clientApp) {
    throw "The React SPA App Registration was not found."
}
```

SPA リダイレクト URI を確認します。

```powershell
az ad app show `
  --id $clientApp.id `
  --query "spa.redirectUris" `
  --output json
```

想定される値は次のとおりです。

```text
https://<STATIC_WEB_APP_HOSTNAME>
http://localhost:5173
```

リダイレクト URI は完全一致で比較されます。スキーム、ホスト名、ポート、パス、末尾のスラッシュを確認してください。

委任された API アクセス許可を確認します。

```powershell
az ad app show `
  --id $clientApp.id `
  --query "requiredResourceAccess" `
  --output json
```

クライアントがバックエンド API の `access_as_user` スコープを要求していることを確認します。アクセス許可エントリは、バックエンド API アプリケーションと、ID スクリプトによって生成されたスコープ ID を参照している必要があります。

### 同意

テナントポリシーによっては、委任されたアクセス許可にユーザーまたは管理者の同意を付与する必要があります。

同意は認可チェックの代わりにはなりません。バックエンドでは引き続きトークンを検証し、保護された各操作に対して想定されるスコープとロールを要求する必要があります。

---

## Step 7: アプリロール割り当てを構成する

管理用 Fortune 操作を必要とするユーザーまたはグループにのみ、`Fortune.Admin` を割り当ててください。

アプリロールの割り当ては、テナントの管理操作です。Microsoft Entra ID または承認済みの管理プロセスで割り当てを確認してください。

割り当てを変更した後は、次を実行します。

1. アプリケーションからサインアウトします。
2. 必要に応じて、既存のブラウザーセッションを終了します。
3. 再度サインインして、新しいトークンを取得します。
4. 新しいトークンに、想定されるロールクレームが含まれていることを確認します。

古いキャッシュ済みトークンに、新しく割り当てたロールが自動的に追加されることはありません。

認証を成功させるという理由だけで、`Fortune.Admin` を付与しないでください。認証、委任された API アクセス、管理者認可はそれぞれ独立した制御です。

---

## Step 8: Azure サブスクリプションテナントへ戻る

Azure サブスクリプションテナントにサインインします。

```powershell
az login `
  --tenant <AZURE_SUBSCRIPTION_TENANT_ID>
```

対象のサブスクリプションを選択します。

```powershell
az account set `
  --subscription <AZURE_SUBSCRIPTION_ID>
```

アクティブなコンテキストを確認します。

```powershell
az account show `
  --query "{tenantId:tenantId,subscriptionId:id,subscriptionName:name}" `
  --output table
```

アクティブなテナントとサブスクリプションが対象アプリケーション環境を示すまで、続行しないでください。

---

## Step 9: バックエンドの認証構成をデプロイする

バックエンドのデプロイ前に `ENTRA_TENANT_ID` を確認します。

```powershell
if (-not $env:ENTRA_TENANT_ID) {
    throw "ENTRA_TENANT_ID is not configured."
}
```

リポジトリのデプロイ手順を使用して、バックエンドをデプロイします。

```powershell
.\scripts\deploy-backend.ps1
```

バックエンドのデプロイでは、認証テナント構成が Azure Container App に渡されます。

デプロイ後、バックエンドが正常に起動し、Spring Security が OAuth 2.0 リソースサーバーとして構成されていることを確認します。

バックエンドでは少なくとも以下を検証する必要があります。

- トークン署名。
- 発行者とテナント。
- バックエンド API 用のトークン対象者。
- トークンの有効期間。
- 委任された API アクセス用の `access_as_user` スコープ。
- 管理操作用の `Fortune.Admin` ロール。

バックエンドの認可をフロントエンドに依存しないでください。フロントエンドの制御は使いやすさを向上させますが、セキュリティ境界ではありません。

---

## Step 10: フロントエンドをビルドする

現在の環境構成を使用してフロントエンドをビルドします。

```powershell
.\scripts\build-frontend.ps1
```

ビルドスクリプトはフロントエンド API エンドポイントとビルドメタデータを準備し、Vite の運用ビルドを実行します。

生成されたファイルは以下に書き込まれます。

```text
frontend/dist
```

生成された `dist` ディレクトリをコミットしないでください。

Static Web Apps の構成は、Azure Static Web Apps がホスティング専用であることと整合している必要があります。MSAL の前段に 2 つ目のユーザー認証フローを導入してはいけません。

---

## Step 11: Static Web Apps のデプロイトークンを構成する

Azure サブスクリプションテナントにサインインした状態で、デプロイトークンを取得します。

```powershell
$token = az staticwebapp secrets list `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --query properties.apiKey `
  --output tsv
```

Windows のユーザー環境変数として保存します。

```powershell
[System.Environment]::SetEnvironmentVariable(
    "SWA_DEPLOYMENT_TOKEN",
    $token,
    "User"
)
```

新しい PowerShell セッションを開き、値を表示せずに変数が利用可能であることを確認します。

```powershell
if ($env:SWA_DEPLOYMENT_TOKEN) {
    Write-Host "SWA_DEPLOYMENT_TOKEN is configured."
}
else {
    Write-Host "SWA_DEPLOYMENT_TOKEN is not configured."
}
```

デプロイトークンをリポジトリに保存しないでください。

---

## Step 12: フロントエンドをデプロイする

生成されたフロントエンドをデプロイします。

```powershell
.\scripts\deploy-frontend.ps1
```

スクリプトは以下をデプロイします。

```text
frontend/dist
```

デプロイ先は Azure Static Web Apps の運用環境です。

デプロイトークンはデプロイだけを認可します。MSAL では使用されず、バックエンド API に提示されることもありません。

---

## Step 13: 運用環境を確認する

Azure Static Web Apps の環境を一覧表示します。

```powershell
az staticwebapp environment list `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --output table
```

運用環境は次の値で表されます。

```text
default
```

認証をテストする前に、運用環境の準備が完了していることを確認します。

アプリケーション URL を取得して表示します。

```powershell
$swaHostname = az staticwebapp show `
  --name spring-azure-serverless-demo-dev-swa `
  --resource-group spring-azure-serverless-demo-rg `
  --query defaultHostname `
  --output tsv

Write-Host "https://$swaHostname"
```

---

## Step 14: サインインとトークン取得を確認する

古いセッションに依存しないように、新しい InPrivate またはシークレットブラウザーウィンドウを使用します。

1. デプロイ済みの React アプリケーションを開きます。
2. サインイン前にアプリケーションが読み込まれることを確認します。
3. **サインイン** を選択します。
4. MSAL が想定される Microsoft Entra ID テナントにリダイレクトすることを確認します。
5. 登録済みユーザーでサインインします。
6. 構成済みの SPA リダイレクト URI で、ブラウザーが React アプリケーションに戻ることを確認します。
7. サインイン済みの状態が表示されることを確認します。
8. Fortune API リクエストを実行します。
9. MSAL がバックエンド API スコープ用のアクセストークンを取得することを確認します。
10. バックエンドがトークンを受け入れることを確認します。

実際のアクセストークンを、ドキュメント、課題管理システム、チャット、スクリーンショット、テストフィクスチャに貼り付けないでください。

診断のためにトークンを調べる必要がある場合は、承認済みのローカルツールで必要なクレームだけを確認し、その後トークンを破棄してください。

想定されるクレームの分類には、以下が含まれます。

- 発行者とテナント。
- 対象者。
- サブジェクトまたはオブジェクト識別子。
- 委任されたスコープ。
- 割り当てられている場合はアプリロール。
- 発行時刻と有効期限。

---

## Step 15: 認可シナリオを確認する

### 委任された API アクセスを持つユーザー

想定される結果:

```text
access_as_user が存在する場合、読み取り専用または通常の保護された操作が成功します。
```

委任されたスコープがないリクエストを、フロントエンドだけでなくバックエンドも拒否することを確認します。

### Fortune.Admin を持つユーザー

想定される結果:

```text
管理用の Fortune 操作が成功します。
```

以下を確認します。

- 管理用 UI コントロールが適切に表示されること。
- Fortune 一覧操作が成功すること。
- Fortune の作成が成功すること。
- Fortune の削除が成功すること。
- バックエンドが独立してロールを適用すること。

### Fortune.Admin を持たないユーザー

想定される結果:

```text
通常の許可された操作はアプリケーションポリシーに従いますが、管理操作は拒否されます。
```

管理用ボタンを非表示にするだけでは不十分です。ロールを持たない直接の API 呼び出しも拒否する必要があります。

### 未登録または許可されていないユーザー

想定される結果:

```text
テナントおよびアプリケーションポリシーに従って、サインインまたは API アクセスが拒否されます。
```

アクセスが、メールドメインの一致だけではなく、テナントへの登録、同意、トークンの有効性、スコープ、ロールに基づくことを確認します。

---

## Step 16: サインアウトを確認する

React アプリケーションから完全にサインアウトします。

サインアウト後:

1. アプリケーションが MSAL のアカウントとトークンの状態をクリアする必要があります。
2. 以前のアプリケーションセッションで、保護された API 呼び出しが成功し続けてはいけません。
3. その後に保護された操作を行う際は、再度認証が必要です。
4. 再度サインインすると、新しいトークンが取得される必要があります。

ブラウザーのシングルサインオンによって、資格情報の入力を求められずに Microsoft Entra ID が同じアカウントを再度認証する場合があります。この動作は、アプリケーションからのサインアウトが失敗したことを意味するものではありません。

---

## Azure 環境の再構築

Azure サブスクリプションリソースと認証リソースは、それぞれ独立したライフサイクルを持ちます。

Azure 環境を再構築する場合:

1. 新しい Static Web App をデプロイします。
2. 運用環境のホスト名を取得します。
3. 認証テナントへ切り替えます。
4. 新しいホスト名を指定して `41-deploy-identity.ps1` を実行します。
5. バックエンド API と React SPA の登録を確認します。
6. 委任されたアクセス許可への同意を確認または付与します。
7. アプリロールの割り当てを確認します。
8. Azure サブスクリプションテナントへ戻ります。
9. 正しい `ENTRA_TENANT_ID` を使用してバックエンドをデプロイします。
10. フロントエンドをビルドしてデプロイします。
11. サインイン、API、認可、サインアウトの検証を繰り返します。

スクリプトは可能な場合に、既存の App Registration を再利用します。

環境を置き換える場合は、対応するフロントエンドが使用されなくなるまで、古い SPA リダイレクト URI を削除しないでください。どのデプロイ、カスタムドメイン、テスト環境からも依存されていないことを確認してください。

---

## 構成更新シナリオ

### 認証テナントが変更された場合

認証テナントが変更された場合:

1. 新しい `ENTRA_TENANT_ID` を設定します。
2. 十分なディレクトリ権限を持つアカウントで、新しいテナントにサインインします。
3. そのテナントで 2 つの App Registration を作成または選択します。
4. API スコープ、アプリロール、Service Principal、SPA リダイレクト URI、委任されたアクセス許可を構成します。
5. 新しいテナントで同意を付与し、ロールを割り当てます。
6. バックエンドを再デプロイします。
7. MSAL 構成が変更された場合は、フロントエンドを再ビルドして再デプロイします。
8. 発行者、対象者、スコープ、ロールクレームを確認します。
9. エンドツーエンドテストをすべて実施します。

オブジェクトと同意は、テナント間で自動的に移動しません。

### Static Web Apps のホスト名が変更された場合

運用環境のホスト名が変更された場合:

1. 新しいホスト名を取得します。
2. 新しいホスト名を指定して `41-deploy-identity.ps1` を実行します。
3. 新しい SPA リダイレクト URI を確認します。
4. フロントエンドを再ビルドしてデプロイします。
5. ログインとリダイレクトの動作を確認します。
6. 古い環境を廃止した後にのみ、古いリダイレクト URI を削除します。

### API アプリケーションが変更された場合

バックエンド API の登録が変更された場合:

1. 新しい Application ID URI を確認します。
2. `access_as_user` スコープとその識別子を確認します。
3. `Fortune.Admin` ロールとその識別子を確認します。
4. React SPA の委任されたアクセス許可を更新します。
5. 必要に応じて同意を付与します。
6. API 識別子に依存するバックエンドとフロントエンドの構成を更新します。
7. 両方のアプリケーションコンポーネントを再デプロイします。
8. 新しいトークンを取得し、認可テストを再度実施します。

### SPA アプリケーションが変更された場合

React SPA の登録が変更された場合:

1. 運用環境およびローカルのリダイレクト URI を確認します。
2. バックエンド API に対する委任されたアクセス許可を確認します。
3. フロントエンドの MSAL クライアント構成を更新します。
4. フロントエンドを再ビルドして再デプロイします。
5. 古いブラウザー状態をクリアし、新しいトークンを取得します。
6. サインインと API のテストを繰り返します。

### Fortune.Admin の割り当てが変更された場合

アプリロールの割り当てだけが変更された場合:

1. バックエンド API の Service Principal に対する割り当てを確認します。
2. サインアウトします。
3. キャッシュ済みトークンを破棄します。
4. 再度サインインします。
5. 新しいトークンにロールが存在すること、または存在しなくなったことを確認します。
6. UI と直接の API 動作の両方を確認します。

---

## 認証の完了基準

以下を満たした場合、認証と認可のセットアップは完了です。

- バックエンド API の App Registration が存在すること。
- その Application ID URI が構成されていること。
- 委任された `access_as_user` スコープが存在し、有効であること。
- `Fortune.Admin` アプリロールが存在し、有効であること。
- バックエンド API の Service Principal が存在すること。
- React SPA の App Registration が存在すること。
- 運用環境およびローカルの SPA リダイレクト URI が構成されていること。
- SPA が API の委任されたスコープを要求すること。
- 必要な同意が付与されていること。
- 必要なアプリロール割り当てが存在すること。
- バックエンドがリソースサーバーとしてアクセストークンを検証すること。
- 許可されたユーザーが MSAL を通じてサインインできること。
- `access_as_user` を含むトークンで保護された API を呼び出せること。
- 有効なトークンのないリクエストが拒否されること。
- 必要なスコープのないリクエストが拒否されること。
- `Fortune.Admin` を持たない管理リクエストが拒否されること。
- `Fortune.Admin` を持つ管理リクエストが成功すること。
- Fortune の一覧、作成、削除の動作が認可ポリシーと一致すること。
- サインアウトが成功すること。
- トークンやデプロイ資格情報がリポジトリにコミットされていないこと。

---

## 現在のセキュリティ境界

現在のセキュリティ境界はバックエンド API です。

```text
React / MSAL
  │
  │ ****** トークン
  ▼
Spring Security リソースサーバー
  ├── 署名検証
  ├── 発行者とテナントの検証
  ├── 対象者の検証
  ├── access_as_user の適用
  └── Fortune.Admin の適用
```

Azure Static Web Apps はフロントエンドをホストします。バックエンドのトークン検証の代わりにはなりません。

フロントエンドのルートガード、無効化されたコントロール、非表示のボタンは、ユーザー体験のための機能です。強制力のある API 認可を提供するものではありません。

CORS は API を呼び出せるブラウザーオリジンを制限しますが、呼び出し元を認証するものではなく、OAuth 2.0 トークン検証の代わりにもなりません。

マネージド ID を使用した Azure SQL アクセスは、エンドユーザー認証とは別のものです。バックエンドのデータベース ID は、サインインしたユーザーを表すものではありません。

---

## トラブルシューティング

### MSAL のリダイレクトが失敗する

以下を確認します。

- ブラウザーが想定されるフロントエンド URL を使用していること。
- SPA 登録に、リダイレクト URI として正確なフロントエンドオリジンが含まれていること。
- リダイレクト URI が SPA プラットフォーム構成に含まれていること。
- アクティブなテナントが、意図した認証テナントであること。
- フロントエンドが、想定されるテナントとクライアントアプリケーションを使用していること。
- リダイレクト URI に、想定外のパスや末尾のスラッシュがないこと。

想定される運用環境の形式:

```text
https://<STATIC_WEB_APP_HOSTNAME>
```

想定されるローカル環境の形式:

```text
http://localhost:5173
```

### 同意またはスコープのエラー

以下を確認します。

- バックエンド API が `access_as_user` を公開していること。
- SPA の委任されたアクセス許可が、正しい API アプリケーションを参照していること。
- アクセス許可が現在のスコープ ID を参照していること。
- 必要に応じて、ユーザーまたは管理者の同意が付与されていること。
- 要求するスコープ文字列が、バックエンド API の Application ID URI を使用していること。
- 構成変更後に新しいトークンが取得されていること。

### 401 Unauthorized

通常、401 応答はリクエストが正常に認証されなかったことを意味します。

以下を確認します。

- アクセストークンが ****** として付与されていること。
- トークンの有効期限が切れていないこと。
- トークン署名が有効であること。
- 発行者とテナントが `ENTRA_TENANT_ID` と一致すること。
- 対象者がバックエンド API を示していること。
- バックエンドが意図した Entra 構成を使用していること。
- デプロイ済みのバックエンドが、現在の環境設定を受け取っていること。

トークン検証を弱めることで 401 を診断しないでください。

### 403 Forbidden

通常、403 応答は呼び出し元が認証済みではあるものの、必要な認可を持たないことを意味します。

以下を確認します。

- 委任された API アクセス用の `access_as_user` がトークンに含まれていること。
- 管理エンドポイントが、意図した場所でのみ `Fortune.Admin` を要求すること。
- ユーザーまたはグループにアプリロールが割り当てられていること。
- 新しく取得したトークンにロールが含まれていること。
- Spring Security がスコープとロールのクレームを、想定される権限にマッピングしていること。

403 を解消するという理由だけで、保護されたエンドポイントをすべての呼び出し元に許可するよう変更しないでください。

### 割り当て後に Fortune.Admin が含まれない

1. バックエンド API の Service Principal に対する割り当てを確認します。
2. アプリケーションからサインアウトします。
3. プライベートブラウザーウィンドウを閉じるか、MSAL キャッシュをクリアします。
4. 再度サインインします。
5. 必要なトークンクレームだけをローカルで確認します。
6. バックエンドがマッピングされた権限を認識していることを確認します。

ロールの割り当ては、新しく発行されるトークンに反映されます。すでにキャッシュされているトークンには反映されません。

### 間違ったテナントがアクティブになっている

Azure CLI コンテキストを確認します。

```powershell
az account show `
  --query "{tenantId:tenantId,subscriptionId:id,subscriptionName:name}" `
  --output table
```

コマンドを再実行する前に、現在の手順で必要なテナントへ切り替えてください。

### App Registration が重複している

ID スクリプトから、同じ表示名を持つアプリケーションが複数あると報告された場合:

1. セットアップを停止します。
2. オブジェクト ID とアプリケーション ID を使用して、意図したアプリケーションを特定します。
3. 各オブジェクトを参照しているデプロイとアクセス許可を確認します。
4. 明示的な管理プロセスを通じて、古い重複を名前変更または削除します。
5. 表示名が一意になった後にのみ、スクリプトを再実行します。

名前が重複しているように見えるという理由だけで、アプリケーションを削除しないでください。

### フロントエンドは動作するが API 呼び出しが失敗する

トークンのパス全体を確認します。

```text
React/MSAL の構成
  → 要求された API スコープ
  → 発行されたトークンの対象者とスコープ
  → Authorization ヘッダー
  → バックエンドでの発行者と対象者の検証
  → エンドポイントの認可規則
```

対話型サインインの成功は、SPA がユーザーを認証できることだけを示します。SPA がバックエンド API 用の有効なトークンを取得したことを示すものではありません。

### 静的フロントエンドが読み込まれない

ID 構成を変更する前に、ホスティングまたはデプロイの問題として扱ってください。

以下を確認します。

- フロントエンドのビルドが成功したこと。
- `frontend/dist` に想定されるアセットが含まれていること。
- デプロイ先が運用環境であること。
- `SWA_DEPLOYMENT_TOKEN` が現在有効であること。
- Static Web Apps のルーティングが React のエントリポイントを配信すること。

追加の診断については、以下を参照してください。

```text
docs/troubleshooting.md
```

---

## セキュリティ要件

以下を絶対にコミットしないでください。

- Azure Static Web Apps のデプロイトークン。
- アクセストークン。
- 更新トークン。
- ID トークン。
- 実際のユーザークレームや個人情報。
- 秘密証明書または秘密鍵。
- 資格情報を含むローカル環境ファイル。
- 意図しない環境固有データを含む、生成済みフロントエンドファイル。

以下にトークンまたは ID の値を含めないでください。

- Git のコミットメッセージ。
- Pull Request の説明。
- スクリーンショット。
- テストフィクスチャ。
- Markdown の例。
- 共有するターミナルトランスクリプト。
- 可能な限り、コマンド履歴。

React SPA はパブリッククライアントであり、PKCE を使用した認可コードフローを使用する必要があります。フロントエンドコード、Vite 変数、静的アセット、Static Web Apps の設定に機密資格情報を追加しないでください。

デプロイと自動化の資格情報は、以下のような承認済みの場所にのみ保存してください。

- GitHub Actions のシークレット。
- Azure Key Vault。
- 開発専用ワークフロー向けのローカルユーザー環境変数。
- デプロイプロセスでサポートされる場合はマネージド ID。

以下には最小権限を使用してください。

- ディレクトリアプリケーションの管理。
- API への同意。
- アプリロールの割り当て。
- Azure デプロイアクセス。
- データベースアクセス。

---

## 関連ドキュメント

認証アーキテクチャと信頼境界:

```text
docs/authentication.md
```

現在のアプリケーションアーキテクチャ:

```text
docs/architecture.md
```

デプロイシーケンス:

```text
docs/deployment.md
```

トラブルシューティング:

```text
docs/troubleshooting.md
```

認証実装の履歴:

```text
docs/step03-authentication.md
```

テストと検証の定義:

```text
docs/testing.md
```
