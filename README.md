# GHAS & Defender for Cloud 統合デモアプリ

> **注意**: このリポジトリは [build25-woodgrove/mdc-customer-playbook](https://github.com/build25-woodgrove/mdc-customer-playbook) をベースに変更を加えたものです。

GitHub Advanced Security (GHAS) と Microsoft Defender for Cloud (MDC) の統合を検証するためのデモ用 Node.js (Express) アプリケーションです。**セキュリティスキャン機能の動作確認を目的として、意図的に複数の脆弱性が含まれています。本番環境には絶対にデプロイしないでください。**

## ソリューション概要

- **アプリケーション**: Express ベースの Web API（Node.js 18）
- **インフラ**: Azure Container Apps + Azure Container Registry（Bicep による IaC）
- **デプロイ**: Phase 1 スクリプト（インフラ構築）→ GitHub Actions（コンテナビルド & プッシュ）

### プロジェクト構成

```
├── server.js               # Express アプリケーション (エントリポイント)
├── index.js                # ヘルスチェック用プロセス
├── utils.js                # ユーティリティ (脆弱性を含む)
├── utils_location.js       # DOM 操作ユーティリティ (脆弱性を含む)
├── routes/
│   └── hello.js            # /hello ルート (脆弱性を含む)
├── Dockerfile              # コンテナイメージ定義
├── package.json
└── infra/
    ├── deploy-phase1.sh    # Phase 1 デプロイスクリプト
    ├── main.bicep          # Bicep テンプレート (サブスクリプションスコープ)
    ├── main.parameters.json
    └── modules/
        ├── acr.bicep           # Azure Container Registry
        └── containerapp.bicep  # Azure Container Apps
```

### API エンドポイント

| パス | メソッド | 説明 |
|------|----------|------|
| `/` | GET | トップページ (リンク一覧) |
| `/api?name=<name>` | GET | 名前を返す API |
| `/api/health` | GET | ヘルスチェック |
| `/api/calculate` | POST | 式を受け取り HTML を返す |
| `/hello?name=<name>` | GET | 挨拶メッセージ |

---

## 意図的に含まれている脆弱性

以下の脆弱性は、GHAS の Code Scanning (CodeQL) や Defender for Cloud による検出を検証する目的で意図的に組み込まれています。

### 1. SQL インジェクション (`utils.js`)

- **`sanitizeSqlInput()`**: シングルクォートの置換のみ行い、他の SQL インジェクションベクターを処理していません。
- **`buildQuery()`**: ユーザー入力を直接文字列結合して SQL クエリを構築しています。パラメータ化クエリが使われていません。

```js
// 不十分なサニタイズ
return input.replace(/'/g, "''");

// 文字列結合による SQL 構築
return `SELECT * FROM ${table} WHERE ${column} = '${sanitizeSqlInput(filter)}'`;
```

### 2. クロスサイトスクリプティング (XSS) — Stored/Reflected (`utils.js` → `server.js`)

- **`createHtmlContent()`**: ユーザー入力をエスケープせずにそのまま HTML に埋め込んでいます。
- **`/api/calculate` エンドポイント**: POST ボディの `expression` をそのまま HTML レスポンスとして返すため、任意の JavaScript が実行可能です。

```js
// ユーザー入力がそのまま HTML に出力される
return `<div class="user-content">${userContent}</div>`;
```

### 3. Reflected XSS (`routes/hello.js`, `server.js`)

- `/hello?name=<script>alert(1)</script>` や `/api?name=<script>alert(1)</script>` のように、クエリパラメータ `name` がエスケープなしで HTML レスポンスに埋め込まれます。

```js
router.get('/hello', (req, res) => res.send(`Hello word, ${req.query.name}!`));
app.get('/api', (req, res) => res.send(`API, ${req.query.name}!`));
```

### 4. DOM ベース XSS (`utils_location.js`)

- **`logWindowLocation()`**: `document.write(window.location)` によって、URL 内の悪意あるスクリプトがそのまま DOM に書き込まれます。

```js
document.write(window.location);
```

### 5. コンテナセキュリティの問題 (`Dockerfile`)

- **root ユーザーで実行**: `USER` 命令が指定されておらず、コンテナが root 権限で動作します。

---

## セットアップ

### ローカル実行

```bash
npm install
npm start        # http://localhost:3000
```

### Azure へのデプロイ

```bash
# 1. Azure にログイン
az login

# 2. Phase 1: インフラストラクチャのデプロイ (RG + ACR + Container Apps)
cd infra
bash deploy-phase1.sh

# 3. GitHub Actions でコンテナイメージをビルド & プッシュ
```

## ライセンス

このリポジトリはデモ・教育目的で提供されています。
