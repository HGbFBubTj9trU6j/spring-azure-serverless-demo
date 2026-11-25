# spring-azure-serverless-demo

Spring Boot Webアプリケーションを、Microsoft Azure上のサーバーレスアーキテクチャへ段階的に発展させるハンズオンプロジェクトです。

現在の実装では、以下を組み合わせています。

- ReactとVite
- Azure Static Web Apps
- Spring Boot
- Azure Container Apps
- Azure Container Registry
- Azure SQL Database
- Microsoft Entra ID認証
- MSALを使用したReactの認証とアクセストークン取得
- Spring Security OAuth 2.0 Resource Server
- ユーザー割り当てマネージドID
- BicepによるInfrastructure as Code
- Cloud Native Buildpacks

ReactフロントエンドはAzure Static Web Appsでホストされ、Azure Container Apps上で実行されるSpring Boot REST APIと通信します。

アプリケーションデータはAzure SQL Databaseに保存されます。デプロイされたバックエンドは、ユーザー割り当てマネージドIDを使用してデータベースにアクセスします。

> このリポジトリは、学習、実験、およびアーキテクチャ検証を目的としています。本番環境で使用する前に、すべての設定を確認してください。

---

## 現在の実装

現在、アプリケーションは以下をサポートしています。

- MSALを介したMicrosoft Entra IDによるReact認証
- MSALによるバックエンドAPIアクセストークンの取得
- Microsoft Entra IDアクセストークンによるバックエンドAPI認証
- Spring SecurityによるJWT検証
- `access_as_user`スコープを介した委任APIアクセス
- `Fortune.Admin`アプリロールによるロールベースのAPI認可
- ロールに基づくFortune管理UIの表示制御
- ランダムなFortuneの取得
- Azure SQLを使用したFortuneデータ
- リソースベースおよびデータベースベースのSpringプロファイル
- Fortuneの一覧表示
- Fortuneの作成
- Fortuneの削除
- ReactフロントエンドによるFortune管理
- マネージドIDを使用したAzure SQLアクセス
- 最小権限に基づくオブジェクトレベルのデータベース権限
- BicepによるAzureインフラストラクチャのデプロイ
- Cloud Native BuildpacksによるバックエンドOCIイメージの作成
- スクリプトによるビルド、デプロイ、検証
- GitHub ActionsによるCI/CD
- GitHub OIDCを使用したAzure認証
- バックエンドとフロントエンドの自動デプロイ検証

---

## ロードマップ

### 完了

- [x] Step 1: BicepによるAzureインフラストラクチャのプロビジョニング
- [x] Step 2: ReactフロントエンドとAzure Static Web Appsの統合
- [x] Step 3: Microsoft Entra ID認証
- [x] Step 4: データアクセス
  - [x] Step 4.1: Azure SQL Databaseインフラストラクチャ
  - [x] Step 4.2: Azure SQLを使用したFortuneデータアクセス
  - [x] Step 4.3: Fortune管理
- [x] Step 5: Microsoft Entra IDによる認証と認可
  - [x] MSALによるReact認証
  - [x] `access_as_user`を使用したバックエンドAPIアクセストークン
  - [x] Spring SecurityによるJWT認証
  - [x] `Fortune.Admin`アプリロールによる認可
  - [x] ロールに基づくFortune管理UI
- [x] Step 6: CI/CD
  - [x] バックエンドとフロントエンドの自動テスト
  - [x] バックエンドOCIイメージのビルドとACRへのプッシュ
  - [x] Azure Container Appsへのデプロイ
  - [x] Azure Static Web Appsへのデプロイ
  - [x] バックエンドとフロントエンドのデプロイ検証

Step 4の実装の詳細は、以下に記載されています。

```text
docs/step04-data-access.md
```

Step 5の実装の詳細は、以下に記載されています。

```text
docs/step05-entra-id-authentication-authorization.md
```

Step 6の実装の詳細は、以下に記載されています。

```text
docs/step06-cicd.md
docs/step06-cicd-ja.md
```

### 計画中

- [ ] Step 7: Spring Boot Actuator、BootUI、BootUI MCPを使用した、AI支援によるローカル診断を含むSpring Boot診断
- [ ] Step 8: HTTP、Spring Boot、Azure SQL間のトレースにOpenTelemetryとApache SkyWalkingを使用する可観測性
- [ ] Step 9: IDライフサイクル管理
- [ ] Step 10: 代替アーキテクチャとしてStatic Web AppsをBuildpacksベースのフロントエンドコンテナーに置き換え
- [ ] Step 11: Azure OpenAI、RAG、およびAI処理のOpenTelemetryトレースを使用したAI / RAG

今後のロードマップドキュメントには、以下の命名規則を使用します。

```text
docs/step07-spring-boot-diagnostics.md
docs/step08-observability.md
docs/step09-identity-lifecycle.md
docs/step10-frontend-container.md
docs/step11-ai-rag.md
```

---

## アーキテクチャ

```text
ブラウザー
  │
  ▼
Azure Static Web Apps
  │
  └── React + Vite
          │
          └── MSALクライアント: spring-azure-serverless-demo-client
                  │
                  │ access_as_user
                  │ バックエンドAPIアクセストークン
                  ▼
            spring-azure-serverless-demo-api
                  │
                  │ Authorization: Bearer <access-token>
                  ▼
          HTTPS / CORS
                  │
                  ▼
          Azure Container Apps
                  │
                  └── Spring Boot REST API
                        │
                        ├── Spring Security
                        │     ├── JWT検証
                        │     └── Fortune.Admin認可
                        │
                        │ ユーザー割り当てマネージドID
                        ▼
                  Azure SQL Database
                        │
                        └── dbo.fortunes
```

Azure Static Web Appsは、Reactフロントエンドを静的Webアプリケーションとしてホストします。

Reactは、Microsoft Entra IDへのサインインと、対象ユーザーがバックエンドAPIであるアクセストークンの取得にMSALを使用します。

ローカル環境とAzure環境の両方で同じMSALベースの認証フローを使用することで、環境固有の動作を減らし、検証を簡素化します。

Azure Container AppsはSpring Bootバックエンドをホストします。Spring Securityは、保護されたAPIリクエストがアプリケーションに到達する前に、Bearer JWTアクセストークンを独立して検証します。

`access_as_user`委任スコープは、サインインしたユーザーによるバックエンドAPIへのアクセスを表します。`Fortune.Admin`アプリロールは、バックエンドAPIアクセストークンの`roles`クレームに含まれ、管理API操作に必要です。

Azure SQL Databaseは、永続的なFortuneデータを提供します。

バックエンドは、アプリケーションにデータベースパスワードを保存せず、ユーザー割り当てマネージドIDを介してAzure SQLにアクセスします。

現在のシステム構成、コンポーネントの責務、IDの境界、およびデータアクセスプロファイルについては、以下を参照してください。

```text
docs/architecture.md
```

Step 5のIDおよび認可設計については、以下を参照してください。

```text
docs/step05-entra-id-authentication-authorization.md
```

---

## リポジトリ構成

```text
spring-azure-serverless-demo/
├── backend/
│   └── Spring Bootアプリケーション
│
├── frontend/
│   └── React + Viteアプリケーション
│
├── database/
│   └── Azure SQLスキーマ、シードデータ、セキュリティ構成
│
├── config/
│   └── 環境固有の非シークレット設定
│
├── infra/
│   └── Bicepで定義されたAzureインフラストラクチャ
│
├── scripts/
│   └── ビルド、デプロイ、構成、検証用スクリプト
│
├── docs/
│   └── ロードマップおよびリファレンスドキュメント
│
├── swa-cli.config.json
└── README.md
```

環境固有の非シークレット設定は、以下に保存されます。

```text
config/
```

既定の開発環境は、以下で定義されています。

```text
config/dev.psd1
```

シークレット値をこのファイルに保存しないでください。

---

## 前提条件

以下のツールが必要です。

- Azure CLI
- Bicep CLI
- Azure Container Apps CLI拡張機能
- Java 21
- Maven Wrapper
- Node.jsとnpm
- Docker互換のコンテナーランタイム
- Git
- PowerShell
- sqlcmd

ローカルのコンテナーランタイムを確認します。

```powershell
docker info
```

バックエンドにDockerfileは必要ありません。

バックエンドOCIイメージはSpring Boot Buildpacksで作成されます。Buildpacksのビルドをローカルで実行するため、Docker互換のランタイムは引き続き必要です。

Azure Static Web Apps CLIは、フロントエンドのデプロイスクリプトによって`npx`経由で呼び出されます。

通常のデプロイフローでは、グローバルにインストールされた`swa`コマンドは必要ありません。

---

## 必要な環境変数

一部のビルドおよびデプロイ操作では、開発者が事前に用意する必要がある環境変数を使用します。

```text
ENTRA_TENANT_ID
SWA_DEPLOYMENT_TOKEN
```

`ENTRA_TENANT_ID`はAzure Container Appsのバックエンドに渡され、Spring SecurityがバックエンドAPIアクセストークンを検証するためのMicrosoft Entra JWT発行者を構成する際に使用されます。

`SWA_DEPLOYMENT_TOKEN`は、生成されたフロントエンドをAzure Static Web Appsにデプロイする際に使用されます。

値を出力せずに、環境変数が使用可能か確認します。

```powershell
if ($env:ENTRA_TENANT_ID) {
    Write-Host "ENTRA_TENANT_ID is configured."
}
else {
    Write-Host "ENTRA_TENANT_ID is not configured."
}

if ($env:SWA_DEPLOYMENT_TOKEN) {
    Write-Host "SWA_DEPLOYMENT_TOKEN is configured."
}
else {
    Write-Host "SWA_DEPLOYMENT_TOKEN is not configured."
}
```

以下のViteの値はフロントエンドのビルドプロセスによって生成され、通常は手動で用意する必要はありません。

```text
VITE_API_BASE_URL
VITE_BUILD_VERSION
```

シークレット値をリポジトリにコミットしないでください。

---

## はじめに

全体的なデプロイフローは以下のとおりです。

```text
前提条件とAzureコンテキストを確認
        │
        ▼
共有Azureインフラストラクチャをプロビジョニング
        │
        ▼
Azure SQLをデプロイして検証
        │
        ▼
バックエンドOCIイメージをビルド
        │
        ▼
バックエンドをAzure Container Appsにデプロイ
        │
        ▼
Microsoft Entra IDアプリ登録、APIスコープ、アプリロールを構成
        │
        ▼
Reactフロントエンドをビルド
        │
        ▼
フロントエンドをAzure Static Web Appsにデプロイ
        │
        ▼
サインイン、アクセストークンを使用したAPI呼び出し、ロールベースの認可を検証
```

主要なアプリケーションデプロイスクリプトは以下のとおりです。

```text
scripts/whatif-infra.ps1
scripts/deploy-infra.ps1
scripts/deploy-database.ps1
scripts/verify-database.ps1
scripts/build-backend.ps1
scripts/deploy-backend.ps1
scripts/build-frontend.ps1
scripts/deploy-frontend.ps1
scripts/verify-backend-deployment.ps1
scripts/verify-frontend-deployment.ps1
```

バックエンドAPIのアプリ登録では、`access_as_user`委任スコープを公開し、`Fortune.Admin`アプリロールも定義する必要があります。Reactクライアントのアプリ登録には、`access_as_user`への委任アクセス許可を付与する必要があります。現在の構成と検証手順については、Step 5のドキュメントを参照してください。

完全なデプロイ順序、前提条件、テナントの切り替え、ビルド設定、および検証コマンドについては、以下を参照してください。

```text
docs/deployment.md
```

---

## ローカル開発

Spring Bootバックエンドは通常、以下で実行されます。

```text
http://localhost:8080
```

React開発サーバーは通常、以下で実行されます。

```text
http://localhost:5173
```

`VITE_API_BASE_URL`が指定されていない場合、フロントエンドは以下をバックエンドAPIのベースURLとして使用します。

```text
http://localhost:8080
```

バックエンドは、次の2つのデータアクセスプロファイルをサポートします。

```text
resource
database
```

`resource`プロファイルは、アプリケーションにバンドルされたFortuneデータを読み取ります。

`database`プロファイルはAzure SQL Databaseを使用します。

フロントエンドの本番ビルドは、Viteプレビューサーバーを介してローカルでテストすることもできます。

```text
http://localhost:4173
```

バックエンドのCORS構成では、以下の両方のローカルフロントエンドオリジンが許可されています。

```text
http://localhost:5173
http://localhost:4173
```

保護されたAPIの呼び出しには、有効なバックエンドAPIアクセストークンが必要です。そのため、ローカルフロントエンド認証でも、ローカルオリジンに対するReact/MSALリダイレクトURIとバックエンドAPIアクセス許可の構成が必要です。

Step 4固有のローカル実行とデータアクセスの詳細は、以下に記載されています。

```text
docs/step04-data-access.md
```

---

## ビルドとデプロイ

バックエンドイメージはSpring Boot Buildpacksでビルドされます。

ビルドでは以下を使用します。

```text
Paketo Noble Java Tiny Builder
linux/amd64
```

変更可能な`latest`タグに依存する代わりに、バージョンが固定されたビルダーイメージを使用します。

フロントエンドのビルドは、デプロイされたAzure Container Appのエンドポイントを解決し、以下を介してViteに渡します。

```text
VITE_API_BASE_URL
```

フロントエンドのデプロイスクリプトは、以下を介してAzure Static Web Apps CLIを呼び出します。

```text
npx @azure/static-web-apps-cli
```

詳細なビルドおよびデプロイ手順は、以下で管理されています。

```text
docs/deployment.md
```

Microsoft Entra ID、MSAL、バックエンドのJWT検証、およびロール割り当ての詳細は、以下で管理されています。

```text
docs/step05-entra-id-authentication-authorization.md
```

---

## 認証

アプリケーションは、認証にMicrosoft Entra IDを使用します。

Reactアプリケーションは、ローカル環境とAzure環境の両方で、アプリケーションユーザーの認証メカニズムとしてMSALを使用します。

Azure Static Web Appsは静的フロントエンドのホスティングを提供しますが、独立したアプリケーション認証レイヤーは追加しません。

サインイン後、MSALはSpring BootバックエンドAPI用のアクセストークンを取得します。

認証リソースは、Azureサブスクリプションのリソースとは独立したライフサイクルを持つことができる認証テナントに属します。

### アプリ登録

現在のIDアーキテクチャでは、2つのアプリ登録に責務を分離しています。

- `spring-azure-serverless-demo-client`
  - React/MSALパブリッククライアントを表します。
  - Microsoft Entra IDでユーザーをサインインさせます。
  - バックエンドAPIの`access_as_user`委任アクセス許可を要求します。
- `spring-azure-serverless-demo-api`
  - Spring Bootリソースサーバーを表します。
  - `access_as_user`委任スコープを公開します。
  - `Fortune.Admin`アプリロールを定義します。

### バックエンドAPIアクセストークン

サインイン後、MSALはバックエンドAPI用のトークンを取得します。Reactは、APIリクエストでこのトークンをBearerトークンとして送信します。

```http
Authorization: Bearer <access-token>
```

バックエンドAPIアクセストークンとReactクライアントIDトークンの用途は異なります。APIトークンはバックエンドAPIのスコープとロールの情報源です。ユーザーがAPIの`Fortune.Admin`ロールを持っているかどうかをUIで判断するために、`account.idTokenClaims.roles`を使用してはいけません。

管理者ユーザーのバックエンドAPIアクセストークンには、次と同等のクレームが含まれます。

```json
{
  "scp": "access_as_user",
  "roles": [
    "Fortune.Admin"
  ]
}
```

管理者ではないユーザーのトークンには、`Fortune.Admin`なしで`access_as_user`が含まれる場合があります。

### Spring SecurityによるJWT認証

Spring BootアプリケーションはOAuth 2.0 Resource Serverとして動作します。Spring Securityは、エンドポイントの認可が評価される前に、Bearer JWTアクセストークンを独立して検証し、認証済みプリンシパルを確立します。

JWTの権限変換にはアクセストークンの`roles`値が含まれるため、バックエンドで`Fortune.Admin`アプリロールを適用できます。無効、期限切れ、欠落、発行者が不正、または対象ユーザーが不正なアクセストークンを、認証済みAPI呼び出しとして扱ってはいけません。

バックエンドAPIのトークンフローとStep 5の実装については、以下を参照してください。

```text
docs/step05-entra-id-authentication-authorization.md
```

### 認可より先に認証

認証と認可は、段階的に実装および検証します。

プロジェクトでは、まず以下を確立してテストします。

1. Microsoft Entra IDへのサインイン。
2. MSALによるバックエンドアクセストークンの取得。
3. Bearerトークンを使用したAPI呼び出し。
4. Spring SecurityによるJWT検証。
5. 一般APIへの認証済みアクセス。

この基準が機能し、テストでカバーされた後にのみ、ロールベースの認可を追加します。

1. `Fortune.Admin`アプリロールの定義と割り当て。
2. `/api/admin/**`に対するバックエンド認可。
3. ロールを持たない認証済みユーザーに対する`403 Forbidden`の検証。
4. ロールに基づくFortune管理UIの表示制御。

この分離により、実装およびトラブルシューティング中に、認証エラーと認可エラーが混在することを防ぎます。

---

## 認可

認証では、リクエストに有効なバックエンドAPIアクセストークンが含まれているかどうかを判断します。その後、認可によって、認証済みユーザーが実行できる操作を決定します。

現在の認可モデルは以下のとおりです。

| 操作 | `Fortune.Admin`を持たない認証済みユーザー | `Fortune.Admin`を持つユーザー |
|---|---:|---:|
| Fortuneを取得 | 許可 | 許可 |
| Fortune管理を表示 | 非表示 | 表示 |
| 管理対象のFortuneを一覧表示 | 禁止 | 許可 |
| Fortuneを追加 | 禁止 | 許可 |
| Fortuneを削除 | 禁止 | 許可 |

Spring Securityでは、以下に対して`Fortune.Admin`が必要です。

```text
/api/admin/**
```

バックエンドがセキュリティ境界です。`Fortune.Admin`を持たない認証済みユーザーが管理エンドポイントを呼び出すと、`403 Forbidden`が返されます。

ReactフロントエンドはバックエンドAPIアクセストークンを取得し、その`roles`クレームを読み取ります。Fortune管理は、トークンに`Fortune.Admin`が含まれている場合にのみ表示されます。

フロントエンドでのトークン解析はユーザーエクスペリエンスの制御にのみ使用されます。トークンの署名は検証されないため、セキュリティ境界として使用してはいけません。管理UIを非表示にしても、バックエンドでの認可の代わりにはなりません。

---
## データアクセス

Azure SQL Databaseには永続的なFortuneデータが保存されます。

デプロイされたバックエンドは、ユーザー割り当てマネージドIDを介してAzure SQLにアクセスします。

現在、アプリケーションは`dbo.fortunes`に対して、マネージドIDに以下のオブジェクトレベルの権限を付与します。

```text
SELECT
INSERT
DELETE
```

現在のFortune機能では、広範な固定データベースロールへのメンバーシップは必要ありません。

アプリケーションは以下を提供します。

```text
GET    /api/fortune                  認証済みユーザー

GET    /api/admin/fortunes           Fortune.Admin
POST   /api/admin/fortunes           Fortune.Admin
DELETE /api/admin/fortunes/{id}      Fortune.Admin
```

Azure SQLインフラストラクチャ、Springプロファイル、リポジトリ設計、データベース権限、Fortune管理、およびStep 4の検証の詳細については、以下を参照してください。

```text
docs/step04-data-access.md
```

---

## テストと検証

このプロジェクトでは、検証の目的を区別しています。

### 自動テスト

バックエンドとフロントエンドの自動テストは、デプロイ済みの完全なユーザーフローを必要とせずに、アプリケーションとコンポーネントの動作を検証します。

Step 5のセキュリティテストは以下を対象としています。

- Fortune管理のGET、POST、DELETEエンドポイントに対するバックエンドセキュリティテスト。
- 未認証の管理リクエストの拒否。
- `Fortune.Admin`を持たない認証済みユーザーに対する`403 Forbidden`。
- `Fortune.Admin`が存在する場合の管理リクエストの成功。
- ReactクライアントIDトークンではなく、テスト用バックエンドAPIアクセストークンからUI認可を導出するフロントエンドテスト。
- アクセストークンに`Fortune.Admin`が含まれる場合のFortune管理の表示。
- トークン取得完了後、ロールが存在しない場合のFortune管理の非表示。
- 既存のFortune取得における成功時とエラー時の動作。

フロントエンドのテストスイートには、4つの`App.test.tsx`テストと2つの`FortuneManagement.test.tsx`テストが含まれています。完了した検証では、以下の結果が報告されています。

```text
npm test       6 tests passed
npm run build  succeeded
```

本番ビルドでは、500 kBを超えるチャンクに対する、処理を妨げないバンドルサイズの警告が出力されました。この警告は、認証および認可の動作とは別のものです。

### デプロイ検証

CI/CDデプロイ検証では、現在のGitコミットからビルドされた成果物が、実際にデプロイされた成果物であることを確認します。

バックエンドの検証では、GitコミットSHAと、Azure Container AppsにデプロイされたOCIイメージタグを比較します。

フロントエンドの検証では、GitコミットSHAと、以下を介して公開されたバージョンを比較します。

```text
/version.json
```

これらの確認はGitHub Actionsによって自動化されており、アプリケーションのE2Eシナリオ検証とは異なります。

Step 6のCI/CDおよびデプロイ検証の詳細は、以下に記載されています。

```text
docs/step06-cicd.md
docs/step06-cicd-ja.md
```

### ローカル機能検証

ローカル機能検証では、開発中のフロントエンドとバックエンドの動作を確認します。

完了したロールベースUIの確認では、バックエンドAPIアクセストークンに`Fortune.Admin`が含まれるユーザーにはFortune管理が表示され、このロールを持たないユーザーには表示されないことを確認しました。

### デプロイ済みバックエンドの機能検証

Azure Container Appsに対する直接のAPI検証では、デプロイ済みバックエンド、トークン検証、認可、およびAzure SQLアクセスが正しく動作することを確認します。

Fortune管理のGET、POST、DELETEなどの個別API操作は、デプロイ済みバックエンドの機能検証として扱います。

これらは、アプリケーション全体のE2E検証としては扱いません。

### エンドツーエンドのシナリオ検証

E2E検証はユーザーシナリオに基づきます。

Fortune管理では、Azure Static Web Appsがユーザーのエントリポイントです。

検証済みのシナリオには、以下が含まれます。

1. デプロイ済みアプリケーションにサインインする。
2. バックエンドAPIアクセストークンを取得する。
3. 認証済みAPIを介してFortuneを取得する。
4. `Fortune.Admin`を持つ場合にのみFortune管理が表示されることを確認する。
5. 管理者として既存のFortuneレコードを表示する。
6. React UIからFortuneを追加する。
7. Fortuneが管理一覧に表示されることを確認する。
8. 更新されたFortuneデータでアプリケーションを使用する。
9. 追加したFortuneを削除する。
10. Fortuneが管理一覧から消えることを確認する。

この検証の目的は、デプロイ済みアプリケーションを介してユーザーが意図したワークフローが成功し、フロントエンドの表示制御とバックエンドの認可が一致していることを確認することです。

Step 4のデータアクセステストおよび検証の詳細は、以下に記載されています。

```text
docs/step04-data-access.md
```

Step 5の認証および認可テストの詳細は、以下に記載されています。

```text
docs/step05-entra-id-authentication-authorization.md
```

---

## ドキュメント

ドキュメントは、ロードマップドキュメントと横断的なリファレンスドキュメントに分かれています。

### ロードマップドキュメント

ロードマップドキュメントでは、プロジェクトの特定のStepで導入された実装と判断事項について説明します。

現在利用可能なドキュメントは以下のとおりです。

```text
docs/step04-data-access.md
docs/step05-entra-id-authentication-authorization.md
docs/step06-cicd.md
docs/step06-cicd-ja.md
```

今後のロードマップドキュメントも同じ命名規則に従います。

```text
docs/step07-spring-boot-diagnostics.md
docs/step08-observability.md
docs/step09-identity-lifecycle.md
docs/step10-frontend-container.md
docs/step11-ai-rag.md
```

### リファレンスドキュメント

現在のアーキテクチャ:

```text
docs/architecture.md
```

デプロイと環境設定:

```text
docs/deployment.md
```

Azure Static Web Appsの認証アーキテクチャと境界:

```text
docs/authentication.md
```

認証のプロビジョニングと構成:

```text
docs/authentication-setup.md
```

Microsoft Entra ID、React/MSAL、バックエンドアクセストークン、Spring SecurityによるJWT認証、およびロールベースの認可:

```text
docs/step05-entra-id-authentication-authorization.md
```

GitHub ActionsによるCI/CDとデプロイ検証:

```text
docs/step06-cicd.md
docs/step06-cicd-ja.md
```

既知の問題、診断、解決策:

```text
docs/troubleshooting.md
```

---

## セキュリティに関する注意事項

認証と認可は複数のレイヤーで適用されます。

Azure Static Web AppsはReactフロントエンドをホストします。

アプリケーションユーザーの認証は、Microsoft Entra IDを使用したReact/MSALによって実行されます。

Reactアプリケーションは、`access_as_user`委任スコープを含むバックエンドAPIアクセストークンを取得します。APIリクエストは、このトークンを`Authorization: Bearer`ヘッダーで送信します。

Spring Bootバックエンドは、Spring Securityを介してBearer JWTアクセストークンを独立して検証します。

以下の管理エンドポイントには、

```text
/api/admin/**
```

`Fortune.Admin`アプリロールが必要です。

Reactフロントエンドは、`Fortune.Admin`を持たないユーザーに対してFortune管理を非表示にしますが、フロントエンドの表示制御はセキュリティ境界ではありません。バックエンドは、このロールを持たない認証済みユーザーからの管理リクエストを独立して拒否し、`403 Forbidden`を返します。

フロントエンドは、ReactクライアントIDトークンではなく、バックエンドAPIアクセストークンからロールを読み取ります。フロントエンドでのクレームのデコードでは署名を検証せず、表示の制御にのみ使用します。

バックエンドはAzure SQLへのアクセスにユーザー割り当てマネージドIDを使用し、アプリケーションのソースにデータベースパスワードを保存しません。

データベースIDは、最小権限に基づくオブジェクトレベルのアクセス許可モデルに従います。

以下をコミットしないでください。

- クライアントシークレット
- Azure Static Web Appsのデプロイトークン
- アクセストークン
- リフレッシュトークン
- IDトークン
- 実在するユーザーのID情報
- Azure資格情報
- SQL資格情報
- 秘密証明書または秘密鍵
- 環境固有の値を含む生成ファイル
- 資格情報を含むローカル環境ファイル

シークレットの保存に適した場所には、以下があります。

- GitHub Actions secrets
- Azure Key Vault
- ローカルユーザーの環境変数

認証固有のセキュリティ境界については、以下を参照してください。

```text
docs/step05-entra-id-authentication-authorization.md
```

---

## トラブルシューティング

既知の問題、診断手順、および検証済みの解決策は、以下に記載されています。

```text
docs/troubleshooting.md
```

トピックには以下が含まれます。

- Azure CLIのテナントおよびサブスクリプションコンテキスト
- Bicepの診断
- Azure SQL認証
- マネージドIDのデータベース権限
- コンテナーランタイムの接続
- Buildpacksのアーキテクチャ不一致
- Azure Container Appsのログ取得
- Viteのビルド時環境変数
- ViteプレビューのCORS
- Azure Static Web Apps CLIの呼び出し
- Vitestワーカープールの動作
- 認証およびリダイレクトの失敗
- MSALアカウントおよびサイレントトークン取得の失敗
- バックエンドAPIトークンの対象ユーザー、発行者、有効期限、署名の失敗
- `access_as_user`スコープまたは`Fortune.Admin`ロールクレームの欠落
- `401 Unauthorized`認証エラーと`403 Forbidden`認可エラーの区別
- IDトークンとバックエンドAPIアクセストークンのクレーム選択

---

## 次のStep

### Step 7: Spring Boot診断

次のStepでは、Spring Boot Actuator、BootUI、BootUI MCPを使用したローカル診断機能を導入します。これには、MCPクライアントを使用したAI支援による調査が含まれます。

その後のロードマップには、以下が含まれます。

- Step 8: HTTP、Spring Boot、Azure SQL間のトレースにOpenTelemetryとApache SkyWalkingを使用する可観測性
- Step 9: ユーザーの招待とオンボーディング、セルフサービスサインアップ、アクセスレビューを含むIDライフサイクル管理
- Step 10: Azure Static Web AppsをAzure Container Appsに置き換える代替アーキテクチャとしての、Buildpacksベースのフロントエンドコンテナー化
- Step 11: Azure OpenAI、RAG、およびAI処理のOpenTelemetryトレースを使用したAI / RAG

---

## ライセンス

ライセンスはまだ宣言されていません。

ライセンスが追加されるまでは、標準の著作権規則が適用されます。

再利用やコントリビューションを想定する場合は、公開または外部からのコントリビューションを受け付ける前に、適切なオープンソースライセンスを追加してください。
