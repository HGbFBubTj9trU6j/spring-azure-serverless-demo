# Step 6: GitHub Actions による CI/CD

Step 6 では、GitHub Actions を使用して Spring Boot バックエンドと React フロントエンドの CI/CD を自動化します。

このパイプラインは、Azure Container Apps と Azure Static Web Apps を対象として、アプリケーションのテスト、ビルド、デプロイ、およびデプロイ検証を自動化します。

GitHub Actions ワークフローは次のファイルで定義されています。

```text
.github/workflows/cicd.yml
```

---

## 目標

Step 6 の目標は次のとおりです。

- デプロイパイプラインを実行するたびに、バックエンドとフロントエンドの自動テストを実行する。
- Cloud Native Buildpacks を使用して、Spring Boot バックエンドを OCI イメージとしてビルドする。
- Azure の資格情報を長期間有効なシークレットとして保存せずに、GitHub Actions から Azure へ認証する。
- バックエンドの OCI イメージを Azure Container Registry にプッシュする。
- バックエンドを Azure Container Apps にデプロイする。
- デプロイ先固有の構成を使用して React フロントエンドをビルドする。
- フロントエンドを Azure Static Web Apps にデプロイする。
- 現在の Git コミットから作成された成果物が実際にデプロイされていることを検証する。
- ビルド、デプロイ、検証の処理を PowerShell スクリプトとして実装し、GitHub Actions 以外でも再利用できるようにする。

---

## パイプラインのトリガー

このプロジェクトは現在、1 人の開発者によって保守されています。

開発はローカルで行い、完了した変更をコミットして `main` に直接プッシュします。

このため、CI/CD ワークフローは `main` にプッシュされた場合にのみ実行されます。

```yaml
on:
  push:
    branches:
      - main
```

これにより、リポジトリでは次の運用規則を採用します。

```text
ローカル開発
        │
        ▼
コミット
        │
        ▼
main へプッシュ
        │
        ▼
GitHub Actions CI/CD
```

別のブランチにプッシュしても、アプリケーションはデプロイされません。

現在のプロジェクトの開発ワークフローでは、Pull Request の自動化は必要ありません。リポジトリが将来、ブランチとレビューに基づく開発モデルへ移行した場合に導入できます。

---

## パイプラインの概要

ワークフローには、互いに独立したバックエンドジョブとフロントエンドジョブがあります。

```text
main へのプッシュ
   │
   ├───────────────────────────────────┐
   │                                   │
   ▼                                   ▼
バックエンド                          フロントエンド
   │                                   │
   ├─ Maven テスト                     ├─ npm install
   │                                   │
   ├─ Buildpacks OCI ビルド            ├─ Vitest テスト
   │                                   │
   ├─ OIDC による Azure ログイン       ├─ OIDC による Azure ログイン
   │                                   │
   ├─ ACR ログイン                     ├─ 本番ビルド
   │                                   │
   ├─ OCI イメージのタグ付け           ├─ SWA デプロイ
   │                                   │
   ├─ ACR へのプッシュ                 └─ デプロイ検証
   │
   ├─ ACA デプロイ
   │
   └─ デプロイ検証
```

どちらのデプロイ経路でも、Git コミット SHA を変更不可能なデプロイ識別子として使用します。

---

# バックエンド CI/CD

## バックエンドテスト

バックエンドパイプラインでは、最初に Maven テストスイートを実行します。

```powershell
./mvnw clean test
```

バックエンドテストには、Step 5 で確立した認証と認可の動作が含まれます。

テストは、実際の Microsoft Entra テナントには依存しません。

バックエンドテストを外部テナントに結び付けずに Spring Security の issuer 構成を満たすため、テスト専用のテナント値を指定します。

---

## バックエンド OCI イメージのビルド

バックエンドは、Spring Boot Buildpacks を使用して OCI イメージとしてパッケージ化されます。

パイプラインでは、次の構成を使用します。

```text
Paketo Noble Java Tiny Builder
linux/amd64
```

OCI イメージは、最初に GitHub Actions ランナー上でローカルにビルドされます。

Git コミット SHA をイメージのバージョンとして使用します。

```text
spring-azure-serverless-demo/backend:<github-sha>
```

これにより、次の項目が直接関連付けられます。

```text
Git コミット
    ↓
OCI イメージ
```

Dockerfile は必要ありません。

---

## GitHub Actions から Azure への認証

GitHub Actions は、OpenID Connect フェデレーションを使用して Azure に認証します。

ワークフローでは次を使用します。

```text
azure/login
```

設定値は次のとおりです。

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

これらは GitHub Actions のシークレットとして保存します。

GitHub Actions の ID は、フェデレーション ID 資格情報を持つユーザー割り当てマネージド ID として実装されています。

これにより、長期間有効な Azure クライアントシークレットを GitHub に保存する必要がなくなります。

GitHub Actions が使用する ID は、Azure Container App に割り当てるランタイム ID とは別のものです。

それぞれの役割は次のとおりです。

```text
GitHub Actions のマネージド ID
    │
    ├─ OCI イメージを ACR にプッシュ
    └─ Azure Container Apps をデプロイ


Container App のマネージド ID
    │
    ├─ 実行時に OCI イメージをプル
    └─ Azure SQL Database にアクセス
```

これらの ID を分離することで、それぞれの役割とアクセス許可を限定できます。

---

## Azure Container Registry へのプッシュ

Azure への認証後、ワークフローは Azure Container Registry にログインします。

ローカルでビルドしたイメージに、次のタグを付けます。

```text
<acr-login-server>/backend:<github-sha>
```

その後、Azure Container Registry にプッシュします。

したがって、コミット SHA は次のすべてで一貫したデプロイ識別子となります。

```text
Git コミット
    ↓
ローカル OCI イメージ
    ↓
ACR OCI イメージ
    ↓
Azure Container Apps
```

---

## バックエンドのデプロイ

バックエンドは、次のスクリプトを使用してデプロイします。

```text
scripts/deploy-backend.ps1
```

このスクリプトは、GitHub Actions 内にデプロイロジックを重複して実装するのではなく、既存の Bicep インフラストラクチャ定義を呼び出します。

Azure Container App には、次のランタイム構成が渡されます。

```text
SPRING_PROFILES_ACTIVE
SPRING_DATASOURCE_URL
ENTRA_TENANT_ID
```

`SPRING_PROFILES_ACTIVE=database` を設定すると、Azure SQL を使用するデータアクセスが有効になります。

`SPRING_DATASOURCE_URL` は、Container App のユーザー割り当てマネージド ID を介した Azure SQL へのアクセスを構成します。

`ENTRA_TENANT_ID` は、バックエンド API のアクセストークンを検証するために Spring Security が使用する Microsoft Entra JWT issuer 構成を生成する際に必要です。

---

## バックエンドのデプロイ検証

Azure のデプロイコマンドが成功しただけでは、想定したアプリケーションイメージが実行されていることの証明にはなりません。

そのため Step 6 では、バックエンドのデプロイ後にデプロイ検証を実行します。

この検証では、デプロイ済みの Container App イメージを、期待する Git コミット SHA と照合します。

概念的には、次のようになります。

```text
期待値
github.sha
    │
    ▼
backend:<github.sha>


実際の値
Azure Container Apps
    │
    ▼
実行中のイメージタグ
```

期待するバージョンとデプロイ済みのバージョンが一致した場合にのみ、デプロイが検証済みとみなされます。

これにより、次の 2 つを区別できます。

```text
デプロイコマンドが成功した
```

次の状態とは異なります。

```text
この Git コミットからビルドした成果物が実際にデプロイされている
```

---

# フロントエンド CI/CD

## フロントエンドテスト

フロントエンドジョブでは、次のコマンドで依存関係をインストールします。

```powershell
npm ci
```

続いて、Vitest テストスイートを実行します。

```powershell
npm test -- --run
```

フロントエンドテストには、次の項目が含まれます。

- Fortune 取得の動作
- API エラー時の動作
- `Fortune.Admin` に基づく UI の表示
- Fortune Management の動作

これらのテストは、フロントエンドのビルドまたはデプロイの前に実行されます。

---

## フロントエンドの本番ビルド

本番用フロントエンドは、次のスクリプトでビルドします。

```text
scripts/build-frontend.ps1
```

このスクリプトは、デプロイ済みの Azure Container Apps バックエンドの FQDN を解決し、次の値を介して Vite に渡します。

```text
VITE_API_BASE_URL
```

GitHub Actions ワークフローは、Git コミット SHA を次のように渡します。

```text
-BuildVersion "${{ github.sha }}"
```

ビルドスクリプトは、次の値を介して React に渡します。

```text
VITE_BUILD_VERSION
```

同じ値は、Vite のビルド前に次のファイルにも書き込まれます。

```text
version.json
```

生成されたファイルは、次のパスでデプロイ出力に含まれます。

```text
frontend/dist/version.json
```

環境固有の生成データが作業ツリーに残らないように、`frontend/public` 配下の一時ソースファイルはビルド後に削除されます。

---

## ビルドのフェイルファスト動作

フロントエンドの本番ビルドは、デプロイ済みバックエンドのエンドポイントに依存します。

Azure Container App の FQDN を解決できない場合、無効な API URL のままビルドを続行してはいけません。

そのため、ビルドスクリプトは次を明示的に確認します。

```text
az containerapp show の終了コード
```

さらに、返された FQDN が空でないことを確認します。

バックエンドのエンドポイントを解決できない場合、ビルドは直ちに終了します。

これにより、次のようなビルドが誤って成功とみなされることを防ぎます。

```text
VITE_API_BASE_URL=https://
```

---

## Azure Static Web Apps へのデプロイ

本番用フロントエンドは、次のスクリプトでデプロイします。

```text
scripts/deploy-frontend.ps1
```

デプロイでは、次の値を使用します。

```text
SWA_DEPLOYMENT_TOKEN
```

これは GitHub Actions のシークレットとして保存します。

Azure Static Web Apps は、静的ホスティングレイヤーとして使用します。

アプリケーションユーザーの認証は、Azure Static Web Apps に追加の認証レイヤーを設けるのではなく、React/MSAL によって実行します。

これにより、ローカル開発環境とデプロイ済みアプリケーションで認証フローの一貫性を保ちます。

```text
ローカル

React
  │
  ▼
MSAL
  │
  ▼
Microsoft Entra ID
  │
  ▼
バックエンド API アクセストークン
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
バックエンド API アクセストークン
  │
  ▼
Spring Boot
```

---

## フロントエンドのデプロイ検証

Static Web Apps のデプロイコマンドが成功しただけでは、新しくビルドしたフロントエンドがすでに配信されていることの証明にはなりません。

そのため Step 6 では、フロントエンドのデプロイ検証を追加します。

本番ビルドでは、次のファイルを公開します。

```text
/version.json
```

内容は次のとおりです。

```json
{
  "version": "<github-sha>"
}
```

デプロイ後、CI/CD パイプラインは Azure Static Web Apps からこのファイルを取得します。

検証では、次の値を比較します。

```text
期待するバージョン
    │
    └─ github.sha

実際のバージョン
    │
    └─ SWA /version.json
```

両方のバージョンが一致した場合にのみ、デプロイが成功したとみなされます。

検証スクリプトは次のとおりです。

```text
scripts/verify-frontend-deployment.ps1
```

デプロイコマンドの完了から新しい静的コンテンツが利用可能になるまでに短い遅延が生じる場合があるため、このスクリプトは再試行します。

検証では、次の両方のケースをテストしました。

```text
期待値 == 実際の値
→ 検証成功
```

および、次のケースです。

```text
期待値 != 実際の値
→ 再試行
→ 検証失敗
```

この検証は HTTP を直接使用し、現在の Azure CLI テナントまたはサブスクリプションには依存しません。

---

# デプロイ検証と E2E 検証の違い

Step 6 では、デプロイ検証とエンドツーエンドのシナリオ検証を意図的に区別します。

## デプロイ検証

デプロイ検証では、次の問いに答えます。

> この Git コミットから作成した成果物が実際にデプロイされたか。

バックエンド:

```text
github.sha
==
デプロイ済みの OCI イメージタグ
```

フロントエンド:

```text
github.sha
==
デプロイ済みの /version.json
```

これらの確認は GitHub Actions によって自動化されています。

## エンドツーエンド検証

E2E 検証では、次の問いに答えます。

> ユーザーは、デプロイ済みシステムを通じて想定したアプリケーションシナリオを完了できるか。

デプロイ済みアプリケーションは、Step 5 のユーザーシナリオを使用して手動で再検証しました。

検証したフローは次のとおりです。

1. デプロイ済みの React アプリケーションを開く。
2. MSAL を使用して Microsoft Entra ID にサインインする。
3. サインイン済みの状態を確認する。
4. Fortune を取得する。
5. ロールに基づく Fortune Management UI の表示を確認する。
6. `Fortune.Admin` ユーザーとして Fortune レコードを一覧表示する。
7. Fortune を追加する。
8. Fortune が一覧に表示されることを確認する。
9. Fortune を削除する。
10. Fortune が一覧から消えることを確認する。
11. `Fortune.Admin` を持たないユーザーが管理操作を実行できないことを確認する。
12. サインアウトする。

対話型の Microsoft Entra 認証は、現在 GitHub Actions では自動化していません。

このシナリオを自動化すると、テストユーザーのライフサイクル、MFA、条件付きアクセス、資格情報の取り扱いなど、追加の考慮事項が生じます。

そのため Step 6 では、自動 CI/CD はデプロイ検証までとし、アプリケーション全体の E2E シナリオは独立した手動品質チェックとして残します。

---

# GitHub Actions のシークレット

CI/CD ワークフローには、次の GitHub Actions シークレットが必要です。

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

それぞれの役割は意図的に分けられています。

| シークレット | 用途 |
|---|---|
| `AZURE_CLIENT_ID` | GitHub Actions のフェデレーション済み Azure ID |
| `AZURE_TENANT_ID` | GitHub OIDC ログインで使用する Azure テナント |
| `AZURE_SUBSCRIPTION_ID` | デプロイ済みインフラストラクチャを含む Azure サブスクリプション |
| `ENTRA_TENANT_ID` | Spring Security の JWT issuer 検証で使用する Microsoft Entra テナント |
| `VITE_ENTRA_TENANT_ID` | React/MSAL で使用する Microsoft Entra テナント |
| `VITE_ENTRA_CLIENT_ID` | React/MSAL のパブリッククライアントアプリケーション ID |
| `VITE_API_SCOPE` | バックエンド API の委任されたスコープ |
| `SWA_DEPLOYMENT_TOKEN` | Azure Static Web Apps のデプロイ |

認証テナントは、Azure サブスクリプションのテナントと異なる場合があります。

この区別は、現在のプロジェクトアーキテクチャにおいて重要です。

---

# CI/CD の失敗時の動作

前提となる処理が失敗した場合、パイプラインは不完全な成果物をデプロイまたは受け入れるのではなく、失敗するように設計されています。

次のようなケースが該当します。

- バックエンドテストが失敗した。
- フロントエンドテストが失敗した。
- OCI イメージのビルドが失敗した。
- Azure へのログインが失敗した。
- ACR へのプッシュが失敗した。
- バックエンドのデプロイが失敗した。
- バックエンドのデプロイ済みイメージの検証が失敗した。
- フロントエンドのビルド中に、バックエンド Container App の FQDN を解決できなかった。
- フロントエンドの本番ビルドが失敗した。
- Static Web Apps のデプロイが失敗した。
- フロントエンドのデプロイ済みバージョンの検証が失敗した。

このフェイルファスト動作により、不完全なデプロイが GitHub Actions の成功結果に隠れてしまうことを防ぎます。

---

# 実施した検証

Step 6 は、自動パイプラインの実行とデプロイ済みアプリケーションの検証の両方によって確認しました。

完了した確認項目は次のとおりです。

## GitHub Actions

```text
バックエンドテスト                           PASS
バックエンド OCI ビルド                      PASS
Azure OIDC ログイン                          PASS
ACR へのプッシュ                             PASS
Azure Container Apps へのデプロイ             PASS
バックエンドのデプロイ検証                    PASS

フロントエンドテスト                          PASS
フロントエンドの本番ビルド                    PASS
Azure Static Web Apps へのデプロイ             PASS
フロントエンドのデプロイ検証                  PASS
```

## デプロイ済みアプリケーション

```text
フロントエンドバージョン == GitHub SHA        PASS
サインイン                                    PASS
サインアウト                                  PASS
Fortune の取得                                PASS
ロールに基づく UI の表示                      PASS
Fortune の一覧表示                            PASS
Fortune の作成                                PASS
Fortune の削除                                PASS
バックエンドの認可                            PASS
```

デプロイ済みフロントエンドのバージョンが、GitHub Actions で処理した Git コミット SHA と一致することを確認しました。

---

# 結果

Step 6 により、`main` ブランチへのプッシュから検証済みの Azure デプロイまでを網羅する CI/CD 経路が確立されます。

```text
ローカル開発
        │
        ▼
コミット
        │
        ▼
main へプッシュ
        │
        ▼
GitHub Actions CI/CD
        │
        ├──────────── バックエンド ────────────┐
        │                                     │
        │ テスト                              │
        │   ↓                                 │
        │ OCI ビルド                          │
        │   ↓                                 │
        │ ACR へのプッシュ                    │
        │   ↓                                 │
        │ ACA デプロイ                        │
        │   ↓                                 │
        │ デプロイ検証                        │
        │                                     │
        └──────────── フロントエンド ──────────┤
                                              │
          テスト                              │
            ↓                                 │
          本番ビルド                          │
            ↓                                 │
          SWA デプロイ                        │
            ↓                                 │
          デプロイ検証                        │
                                              ▼
                                      検証済み Azure デプロイ
```

このパイプラインは、デプロイコマンドが成功したことだけでなく、現在の Git コミットに対応する成果物が実際にデプロイされていることも検証します。

ユーザーシナリオ全体の E2E 検証は、独立した品質チェックとして残します。

---

## 関連ドキュメント

```text
README.md
docs/architecture.md
docs/deployment.md
docs/step04-data-access.md
docs/step05-entra-id-authentication-authorization.md
docs/troubleshooting.md
```
