# spring-azure-serverless-demo

Spring Boot Web アプリケーションを Microsoft Azure 上のサーバーレスアーキテクチャへ段階的に発展させる、ハンズオンプロジェクトです。

現在の実装では、以下を組み合わせています。

- React と Vite
- Azure Static Web Apps
- Spring Boot
- Azure Container Apps
- Azure Container Registry
- Azure SQL Database
- Microsoft Entra ID 認証
- MSAL を使用した React の認証とアクセストークンの取得
- Spring Security OAuth 2.0 Resource Server
- ユーザー割り当てマネージド ID
- Bicep による Infrastructure as Code
- Cloud Native Buildpacks

React フロントエンドは Azure Static Web Apps でホストされ、Azure Container Apps 上で稼働する Spring Boot REST API と通信します。

アプリケーションデータは Azure SQL Database に保存されます。デプロイされたバックエンドは、ユーザー割り当てマネージド ID を使用してデータベースにアクセスします。

> このリポジトリは、学習、実験、アーキテクチャ検証を目的としています。本番環境で使用する前に、すべての設定を確認してください。

---

## 現在の実装

現在、アプリケーションは以下をサポートしています。

- Azure Static Web Apps を介した Microsoft Entra ID 認証
- MSAL を使用した React の認証とバックエンド API 用アクセストークンの取得
- React フロントエンドへの認証済みアクセス
- Microsoft Entra ID アクセストークンによるバックエンド API 認証
- Spring Security による JWT 検証
- `access_as_user` スコープを介した委任 API アクセス
- `Fortune.Admin` アプリロールによるロールベースの API 認可
- ロールに基づく Fortune 管理 UI の表示制御
- ランダムな Fortune の取得
- Azure SQL に保存された Fortune データ
- リソースベースおよびデータベースベースの Spring プロファイル
- Fortune の一覧表示
- Fortune の作成
- Fortune の削除
- React フロントエンドを介した Fortune 管理
- マネージド ID による Azure SQL アクセス
- 最小権限かつオブジェクトレベルのデータベース権限
- Bicep による Azure インフラストラクチャのデプロイ
- Cloud Native Buildpacks によるバックエンド OCI イメージの作成
- スクリプトによるビルド、デプロイ、検証

---

## ロードマップ

### 完了

- [x] Step 1: Bicep による Azure インフラストラクチャのプロビジョニング
- [x] Step 2: React フロントエンドと Azure Static Web Apps の統合
- [x] Step 3: Microsoft Entra ID 認証
- [x] Step 4: データアクセス
  - [x] Step 4.1: Azure SQL Database インフラストラクチャ
  - [x] Step 4.2: Azure SQL を使用した Fortune データアクセス
  - [x] Step 4.3: Fortune 管理
- [x] Step 5: Microsoft Entra ID の認証と認可
  - [x] MSAL による React の認証
  - [x] `access_as_user` を使用したバックエンド API 用アクセストークン
  - [x] Spring Security JWT 認証
  - [x] `Fortune.Admin` アプリロールによる認可
  - [x] ロールベースの Fortune 管理 UI

Step 4 の実装詳細は、以下に記載されています。

```text
docs/step04-data-access.md
```

Step 5 の実装詳細は、以下に記載されています。

```text
docs/step05-entra-id-authentication-authorization.md
```

### 計画中

- [ ] Step 6: CI/CD
- [ ] Step 7: Spring Boot Diagnostics（Spring Boot Actuator、BootUI、BootUI MCP を使用した AI 支援によるローカル診断）
- [ ] Step 8: Observability（OpenTelemetry と Apache SkyWalking による HTTP、Spring Boot、Azure SQL を横断するトレーシング）
- [ ] Step 9: ID ライフサイクル管理
- [ ] Step 10: 代替アーキテクチャとして、Static Web Apps を Buildpacks ベースのフロントエンドコンテナーに置き換える
- [ ] Step 11: AI / RAG（Azure OpenAI、RAG、AI 処理の OpenTelemetry トレーシング）

今後のロードマップドキュメントでは、以下の命名パターンを使用します。

```text
docs/step06-cicd.md
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
  ├── React + Vite
  │     │
  │     ├── SWA サインイン: spring-azure-serverless-demo-auth
  │     │
  │     └── MSAL クライアント: spring-azure-serverless-demo-client
  │             │
  │             │ access_as_user
  │             │ バックエンド API 用アクセストークン
  │             ▼
  │       spring-azure-serverless-demo-api
  │             │
  │             │ Authorization: ******
  │             ▼
  └────────── HTTPS / CORS ──────────► Azure Container Apps
                                        │
                                        └── Spring Boot REST API
                                              │
                                              ├── Spring Security
                                              │     ├── JWT 検証
                                              │     └── Fortune.Admin 認可
                                              │
                                              │ ユーザー割り当てマネージド ID
                                              ▼
                                        Azure SQL Database
                                              │
                                              └── dbo.fortunes
```

Azure Static Web Apps は、認証済みフロントエンドのエントリーポイントを提供します。React は MSAL も使用し、バックエンド API を対象（audience）とするアクセストークンを取得します。

Azure Container Apps は Spring Boot バックエンドをホストします。Spring Security は、保護された API リクエストがアプリケーションに到達する前に、Bearer JWT アクセストークンを独立して検証します。

`access_as_user` 委任スコープは、サインインしたユーザーによるバックエンド API へのアクセスを表します。`Fortune.Admin` アプリロールは、バックエンド API 用アクセストークンの `roles` クレームに格納され、管理 API の操作に必要です。

Azure SQL Database は永続的な Fortune データを提供します。

バックエンドは、アプリケーションにデータベースパスワードを保存することなく、ユーザー割り当てマネージド ID を介して Azure SQL にアクセスします。

現在のシステム構造、コンポーネントの責務、ID の境界、データアクセスプロファイルについては、以下を参照してください。

```text
docs/architecture.md
```

Step 5 の ID と認可の設計については、以下を参照してください。

```text
docs/step05-entra-id-authentication-authorization.md
```

---

## リポジトリ構成

```text
spring-azure-serverless-demo/
├── backend/
│   └── Spring Boot アプリケーション
│
├── frontend/
│   └── React + Vite アプリケーション
│
├── database/
│   └── Azure SQL のスキーマ、シードデータ、セキュリティ構成
│
├── config/
│   └── 環境固有の非機密構成
│
├── infra/
│   └── Bicep で定義された Azure インフラストラクチャ
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

環境固有の非機密設定は、以下に保存されます。

```text
config/
```

既定の開発環境は、以下で定義されています。

```text
config/dev.psd1
```

このファイルに機密値を保存しないでください。

---

## 前提条件

以下のツールが必要です。

- Azure CLI
- Bicep CLI
- Azure Container Apps CLI 拡張機能
- Java 21
- Maven Wrapper
- Node.js と npm
- Docker 互換のコンテナーランタイム
- Git
- PowerShell
- sqlcmd

ローカルのコンテナーランタイムを確認します。

```powershell
docker info
```

バックエンドに Dockerfile は必要ありません。

バックエンド OCI イメージは Spring Boot Buildpacks で作成されます。Buildpacks によるビルドをローカルで実行するには、Docker 互換のランタイムが引き続き必要です。

Azure Static Web Apps CLI は、フロントエンドのデプロイスクリプトから `npx` を介して呼び出されます。

通常のデプロイフローでは、グローバルにインストールされた `swa` コマンドは必要ありません。

---

## 必要な環境変数

一部のビルドおよびデプロイ操作には、開発者が準備する必要のある環境変数があります。

```text
ENTRA_TENANT_ID
SWA_DEPLOYMENT_TOKEN
```

`ENTRA_TENANT_ID` は、Azure Static Web Apps の認証構成を生成するときに使用されます。

`SWA_DEPLOYMENT_TOKEN` は、生成されたフロントエンドを Azure Static Web Apps にデプロイするときに使用されます。

値を表示せずに、それらが設定されていることを確認します。

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

以下の Vite の値はフロントエンドのビルドプロセスで生成され、通常は手動で準備する必要はありません。

```text
VITE_API_BASE_URL
VITE_BUILD_VERSION
```

機密値をリポジトリにコミットしないでください。

---

## はじめに

全体的なデプロイフローは以下のとおりです。

```text
前提条件と Azure コンテキストを確認
        │
        ▼
共有 Azure インフラストラクチャをプロビジョニング
        │
        ▼
Azure SQL をデプロイして検証
        │
        ▼
バックエンド OCI イメージをビルド
        │
        ▼
バックエンドを Azure Container Apps にデプロイ
        │
        ▼
Microsoft Entra ID のアプリ登録、API スコープ、アプリロールを構成
        │
        ▼
React フロントエンドをビルド
        │
        ▼
フロントエンドを Azure Static Web Apps にデプロイ
        │
        ▼
Azure Static Web Apps の認証を構成
        │
        ▼
サインイン、アクセストークンを使用した API 呼び出し、ロールベース認可を検証
```

主なアプリケーションデプロイスクリプトは以下のとおりです。

```text
scripts/whatif-infra.ps1
scripts/deploy-infra.ps1
scripts/deploy-database.ps1
scripts/verify-database.ps1
scripts/build-backend.ps1
scripts/deploy-backend.ps1
scripts/build-frontend.ps1
scripts/deploy-frontend.ps1
```

Azure Static Web Apps の認証設定では、以下を使用します。

```text
scripts/41-deploy-identity.ps1
scripts/42-create-client-secret.ps1
scripts/43-configure-swa-auth.ps1
```

バックエンド API のアプリ登録では、`access_as_user` 委任スコープを公開し、`Fortune.Admin` アプリロールも定義する必要があります。React クライアントのアプリ登録には、`access_as_user` への委任アクセス許可を付与する必要があります。現在の構成と検証手順については、Step 5 のドキュメントを参照してください。

完全なデプロイ順序、前提条件、テナントの切り替え、ビルド設定、検証コマンドについては、以下を参照してください。

```text
docs/deployment.md
```

---

## ローカル開発

Spring Boot バックエンドは通常、以下で実行されます。

```text
http://localhost:8080
```

React 開発サーバーは通常、以下で実行されます。

```text
http://localhost:5173
```

`VITE_API_BASE_URL` が指定されていない場合、フロントエンドは以下を使用します。

```text
http://localhost:8080
```

これをバックエンド API のベース URL として使用します。

バックエンドは、以下の 2 つのデータアクセスプロファイルをサポートしています。

```text
resource
database
```

`resource` プロファイルは、アプリケーションに同梱された Fortune データを読み取ります。

`database` プロファイルは Azure SQL Database を使用します。

フロントエンドの本番ビルドは、Vite プレビューサーバーを介してローカルでもテストできます。

```text
http://localhost:4173
```

バックエンドの CORS 構成では、以下の両方のローカルフロントエンドオリジンが許可されています。

```text
http://localhost:5173
http://localhost:4173
```

保護された API の呼び出しには、有効なバックエンド API 用アクセストークンが必要です。そのためローカルのフロントエンド認証でも、ローカルオリジンに対して React/MSAL のリダイレクト URI とバックエンド API のアクセス許可を構成する必要があります。

Step 4 固有のローカル実行とデータアクセスの詳細は、以下に記載されています。

```text
docs/step04-data-access.md
```

---

## ビルドとデプロイ

バックエンドイメージは Spring Boot Buildpacks でビルドされます。

ビルドでは以下を使用します。

```text
Paketo Noble Java Tiny Builder
linux/amd64
```

可変の `latest` タグに依存する代わりに、バージョン固定のビルダーイメージを使用します。

フロントエンドビルドは、デプロイ済み Azure Container App のエンドポイントを解決し、以下を介して Vite に渡します。

```text
VITE_API_BASE_URL
```

フロントエンドのデプロイスクリプトは、以下を介して Azure Static Web Apps CLI を呼び出します。

```text
npx @azure/static-web-apps-cli
```

ビルドとデプロイの詳細な手順は、以下で管理されています。

```text
docs/deployment.md
```

Microsoft Entra ID、MSAL、バックエンドの JWT 検証、ロール割り当ての詳細は、以下で管理されています。

```text
docs/step05-entra-id-authentication-authorization.md
```

---

## 認証

アプリケーションは、認証に Microsoft Entra ID を使用します。

Azure Static Web Apps は引き続き認証済みフロントエンドのエントリーポイントとして機能し、React アプリケーションも MSAL を使用してユーザーをサインインさせ、Spring Boot バックエンド API 用のアクセストークンを取得します。

認証リソースは、Azure サブスクリプションのリソースとは独立したライフサイクルを持つことができる認証テナントに属します。

### アプリ登録

ID アーキテクチャでは、3 つのアプリ登録に責務を分離しています。

- `spring-azure-serverless-demo-auth`
  - Azure Static Web Apps の認証を提供します。
- `spring-azure-serverless-demo-client`
  - React/MSAL パブリッククライアントを表します。
  - バックエンド API の `access_as_user` 委任アクセス許可を要求します。
- `spring-azure-serverless-demo-api`
  - Spring Boot リソースサーバーを表します。
  - `access_as_user` 委任スコープを公開します。
  - `Fortune.Admin` アプリロールを定義します。

### バックエンド API 用アクセストークン

サインイン後、MSAL はバックエンド API 用のトークンを取得します。React は API リクエストで、そのトークンを Bearer トークンとして送信します。

```http
Authorization: ******
```

バックエンド API 用アクセストークンと React クライアントの ID トークンには、それぞれ異なる目的があります。API トークンは、バックエンド API のスコープとロールの参照元です。ユーザーが API の `Fortune.Admin` ロールを持つかどうかを判断するために、UI で `account.idTokenClaims.roles` を使用してはいけません。

管理者ユーザーのバックエンド API 用アクセストークンには、次と同等のクレームが含まれます。

```json
{
  "scp": "access_as_user",
  "roles": [
    "Fortune.Admin"
  ]
}
```

管理者ではないユーザーのトークンには、`Fortune.Admin` がなくても `access_as_user` が含まれる場合があります。

### Spring Security JWT 認証

Spring Boot アプリケーションは、OAuth 2.0 Resource Server として動作します。Spring Security は Bearer JWT アクセストークンを独立して検証し、エンドポイントの認可が評価される前に認証済みプリンシパルを確立します。

JWT の Authority 変換にはアクセストークンの `roles` 値が含まれるため、バックエンドは `Fortune.Admin` アプリロールを強制できます。無効、期限切れ、欠落、不正な発行元、または対象（audience）が誤っているアクセストークンを、認証済みの API 呼び出しとして扱ってはいけません。

既存の Azure Static Web Apps 認証アーキテクチャとプロビジョニング手順については、以下を参照してください。

```text
docs/authentication.md
docs/authentication-setup.md
```

バックエンド API のトークンフローと Step 5 の実装については、以下を参照してください。

```text
docs/step05-entra-id-authentication-authorization.md
```

### 認可の前に認証を実装する

認証と認可は段階的に実装および検証します。

このプロジェクトでは、まず次の項目を確立してテストします。

1. Microsoft Entra ID へのサインイン。
2. MSAL によるバックエンド用アクセストークンの取得。
3. Bearer トークンを使用した API 呼び出し。
4. Spring Security による JWT 検証。
5. 一般 API への認証済みアクセス。

この基盤が動作し、テストでカバーされた後にのみ、ロールベースの認可を追加します。

1. `Fortune.Admin` アプリロールの定義と割り当て。
2. `/api/admin/**` に対するバックエンド認可。
3. ロールを持たない認証済みユーザーに対する `403 Forbidden` の検証。
4. ロールに基づく Fortune 管理 UI の表示制御。

この分離により、実装時とトラブルシューティング時に、認証の失敗と認可の失敗が混在することを防ぎます。

---

## 認可

認証は、リクエストに有効なバックエンド API 用アクセストークンが含まれているかどうかを判断します。認可はその後、認証されたユーザーが何を実行できるかを決定します。

現在の認可モデルは以下のとおりです。

| 操作 | `Fortune.Admin` を持たない認証済みユーザー | `Fortune.Admin` を持つユーザー |
|---|---:|---:|
| Fortune を取得 | 許可 | 許可 |
| Fortune 管理を表示 | 非表示 | 表示 |
| 管理対象 Fortune の一覧を表示 | 禁止 | 許可 |
| Fortune を追加 | 禁止 | 許可 |
| Fortune を削除 | 禁止 | 許可 |

Spring Security は、以下に対して `Fortune.Admin` を要求します。

```text
/api/admin/**
```

バックエンドがセキュリティ境界です。`Fortune.Admin` を持たない認証済みユーザーが管理エンドポイントを呼び出すと、`403 Forbidden` が返されます。

React フロントエンドはバックエンド API 用アクセストークンを取得し、その `roles` クレームを読み取ります。トークンに `Fortune.Admin` が含まれる場合にのみ、Fortune 管理をレンダリングします。

フロントエンドでのトークン解析はユーザーエクスペリエンスの制御だけを目的とし、トークンの署名は検証しないため、セキュリティ境界として使用してはいけません。管理 UI を非表示にすることは、バックエンドの認可に代わるものではありません。

---
## データアクセス

Azure SQL Database は永続的な Fortune データを保存します。

デプロイされたバックエンドは、ユーザー割り当てマネージド ID を介して Azure SQL にアクセスします。

現在、アプリケーションは `dbo.fortunes` に対して、以下のオブジェクトレベル権限をマネージド ID に付与します。

```text
SELECT
INSERT
DELETE
```

現在の Fortune 機能では、広範な固定データベースロールのメンバーシップは必要ありません。

アプリケーションは以下を提供します。

```text
GET    /api/fortune                  認証済みユーザー

GET    /api/admin/fortunes           Fortune.Admin
POST   /api/admin/fortunes           Fortune.Admin
DELETE /api/admin/fortunes/{id}      Fortune.Admin
```

Azure SQL インフラストラクチャ、Spring プロファイル、リポジトリ設計、データベース権限、Fortune 管理、Step 4 の検証の詳細については、以下を参照してください。

```text
docs/step04-data-access.md
```

---

## テストと検証

このプロジェクトでは、検証の目的を区別しています。

### 自動テスト

バックエンドとフロントエンドの自動テストは、デプロイ済みの完全なユーザーフローを必要とせずに、アプリケーションとコンポーネントの動作を検証します。

Step 5 のセキュリティテスト範囲には、以下が含まれます。

- Fortune 管理の GET、POST、DELETE エンドポイントに対するバックエンドセキュリティテスト。
- 未認証の管理リクエストの拒否。
- `Fortune.Admin` を持たない認証済みユーザーに対する `403 Forbidden`。
- `Fortune.Admin` が存在する場合の管理リクエストの成功。
- React クライアントの ID トークンではなく、テスト用バックエンド API アクセストークンから UI の認可を導出するフロントエンドテスト。
- アクセストークンに `Fortune.Admin` が含まれる場合に Fortune 管理が表示されること。
- トークン取得の完了後、ロールがない場合に Fortune 管理が表示されないこと。
- 既存の Fortune 取得における成功時とエラー時の動作。

フロントエンドのテストスイートには、4 件の `App.test.tsx` テストと 2 件の `FortuneManagement.test.tsx` テストが含まれています。完了した検証では、以下の結果が報告されました。

```text
npm test       6 tests passed
npm run build  succeeded
```

本番ビルドでは、500 kB を超えるチャンクに関するブロックされないバンドルサイズ警告が出力されました。この警告は、認証および認可の動作とは別のものです。

### ローカル機能検証

ローカル機能検証では、開発中のフロントエンドとバックエンドの動作を確認します。

完了したロールベース UI の確認では、バックエンド API 用アクセストークンに `Fortune.Admin` が含まれるユーザーには Fortune 管理が表示され、そのロールを持たないユーザーには表示されないことを確認しました。

### デプロイ済みバックエンドの機能検証

Azure Container Apps に対する直接的な API 検証では、デプロイ済みバックエンド、トークン検証、認可、Azure SQL アクセスが正しく動作することを確認します。

Fortune 管理の GET、POST、DELETE などの個別 API 操作は、デプロイ済みバックエンドの機能検証として扱います。

これらは、アプリケーション全体の E2E 検証としては扱いません。

### エンドツーエンドのシナリオ検証

E2E 検証は、ユーザーシナリオに基づいています。

Fortune 管理では、Azure Static Web Apps がユーザーのエントリーポイントです。

検証済みのシナリオには、以下が含まれます。

1. デプロイ済みアプリケーションにサインインする。
2. バックエンド API 用アクセストークンを取得する。
3. 認証済み API を介して Fortune を取得する。
4. `Fortune.Admin` の場合にのみ Fortune 管理が表示されることを確認する。
5. 管理者として既存の Fortune レコードを表示する。
6. React UI から Fortune を追加する。
7. Fortune が管理一覧に表示されることを確認する。
8. 更新された Fortune データを使用してアプリケーションを操作する。
9. 追加した Fortune を削除する。
10. Fortune が管理一覧から消えることを確認する。

この検証の目的は、デプロイ済みアプリケーションを介してユーザーが意図したワークフローが成功し、フロントエンドの表示制御がバックエンドの認可と一致することを確認することです。

Step 4 のデータアクセステストと検証の詳細は、以下に記載されています。

```text
docs/step04-data-access.md
```

Step 5 の認証と認可に関するテストの詳細は、以下に記載されています。

```text
docs/step05-entra-id-authentication-authorization.md
```

---

## ドキュメント

ドキュメントは、ロードマップドキュメントと横断的なリファレンスドキュメントに分かれています。

### ロードマップドキュメント

ロードマップドキュメントでは、プロジェクトの各 Step で導入された実装と意思決定について説明します。

現在利用できるドキュメントは以下のとおりです。

```text
docs/step04-data-access.md
docs/step05-entra-id-authentication-authorization.md
```

今後のロードマップドキュメントも、同じ命名規則に従います。

```text
docs/step06-cicd.md
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

Azure Static Web Apps の認証アーキテクチャと境界:

```text
docs/authentication.md
```

認証のプロビジョニングと構成:

```text
docs/authentication-setup.md
```

Microsoft Entra ID、React/MSAL、バックエンド用アクセストークン、Spring Security JWT 認証、ロールベース認可:

```text
docs/step05-entra-id-authentication-authorization.md
```

既知の問題、診断、解決策:

```text
docs/troubleshooting.md
```

---

## セキュリティに関する注意事項

認証と認可は、複数のレイヤーで適用されます。

Azure Static Web Apps は、認証済みフロントエンドのエントリーポイントを提供します。

React アプリケーションは MSAL を使用して、`access_as_user` 委任スコープを含むバックエンド API 用アクセストークンを取得します。API リクエストは、`Authorization: Bearer` ヘッダーでトークンを送信します。

Spring Boot バックエンドは、Spring Security を介して Bearer JWT アクセストークンを独立して検証します。

以下にある管理エンドポイントには、

```text
/api/admin/**
```

`Fortune.Admin` アプリロールが必要です。

React フロントエンドは `Fortune.Admin` を持たないユーザーに対して Fortune 管理を非表示にしますが、フロントエンドの表示制御はセキュリティ境界ではありません。バックエンドは、ロールを持たない認証済みユーザーによる管理リクエストを、`403 Forbidden` で独立して拒否します。

フロントエンドは、React クライアントの ID トークンではなく、バックエンド API 用アクセストークンからロールを読み取ります。フロントエンドでのクレームのデコードでは署名検証を行わず、表示制御のみに使用します。

バックエンドは、Azure SQL へのアクセスにユーザー割り当てマネージド ID を使用し、アプリケーションソースにデータベースパスワードを保存しません。

データベース ID は、最小権限かつオブジェクトレベルの権限モデルに従います。

以下をコミットしないでください。

- クライアントシークレット
- Azure Static Web Apps のデプロイトークン
- アクセストークン
- リフレッシュトークン
- ID トークン
- 実際の `/.auth/me` レスポンス
- 実在するユーザー ID 情報
- Azure 資格情報
- SQL 資格情報
- 秘密証明書または秘密鍵
- 環境固有の値を含む生成ファイル
- 資格情報を含むローカル環境ファイル

適切な機密情報の保存場所には、以下があります。

- Azure Static Web Apps のアプリケーション設定
- GitHub Actions シークレット
- Azure Key Vault
- ローカルユーザーの環境変数

認証固有のセキュリティ境界については、以下を参照してください。

```text
docs/authentication.md
docs/step05-entra-id-authentication-authorization.md
```

---

## トラブルシューティング

既知の問題、診断手順、検証済みの解決策は、以下に記載されています。

```text
docs/troubleshooting.md
```

以下のトピックが含まれます。

- Azure CLI のテナントおよびサブスクリプションコンテキスト
- Bicep の診断
- Azure SQL 認証
- マネージド ID のデータベース権限
- コンテナーランタイムの接続性
- Buildpacks のアーキテクチャ不一致
- Azure Container Apps のログ取得
- Vite のビルド時環境変数
- Vite プレビューの CORS
- Azure Static Web Apps CLI の呼び出し
- Vitest のワーカープール動作
- 認証およびリダイレクトの失敗
- MSAL アカウントおよびサイレントトークン取得の失敗
- バックエンド API トークンの対象（audience）、発行者、有効期限、署名に関する失敗
- `access_as_user` スコープまたは `Fortune.Admin` ロールクレームの欠落
- `401 Unauthorized` の認証失敗と `403 Forbidden` の認可失敗の区別
- ID トークンとバックエンド API 用アクセストークンのクレーム選択

---

## 次のステップ

### Step 6: CI/CD

次の Step では、CI/CD 自動化を導入します。

以下の自動化を目標とします。

- 認証および認可テストを含むバックエンドテスト
- アクセストークンベースのロール表示テストを含むフロントエンドテスト
- バックエンド OCI イメージの作成
- インフラストラクチャのデプロイ
- データベースデプロイの検証
- バックエンドのデプロイ
- フロントエンドのビルドとデプロイ
- デプロイの検証

以降のロードマップには、以下が含まれます。

- Step 7: Spring Boot Diagnostics（Spring Boot Actuator、BootUI、BootUI MCP を使用した AI 支援によるローカル診断）
- Step 8: Observability（OpenTelemetry と Apache SkyWalking による HTTP、Spring Boot、Azure SQL を横断するトレーシング）
- Step 9: ユーザーの招待とオンボーディング、セルフサービスサインアップ、アクセスレビューを含む ID ライフサイクル管理
- Step 10: Azure Static Web Apps を Azure Container Apps に置き換える代替アーキテクチャとしての Buildpacks ベースのフロントエンドコンテナー化
- Step 11: AI / RAG（Azure OpenAI、RAG、AI 処理の OpenTelemetry トレーシング）

---

## ライセンス

ライセンスはまだ宣言されていません。

ライセンスが追加されるまでは、標準的な著作権規則が適用されます。

再利用やコントリビューションを想定している場合は、公開または外部からのコントリビューションを受け入れる前に、適切なオープンソースライセンスを追加してください。
