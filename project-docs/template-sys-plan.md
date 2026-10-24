# テンプレート改良案：ワンページ ＋ 小規模システム（Cloudflare Workers）

元の claude1page（静的なワンページを作って公開するだけ）から派生し、
D1・R2 などを使った小さなシステム（お知らせ、シンプルな予約など）付きの Web ページを
作るためのテンプレートにする。

## 方針

- お知らせや予約の「完成品」は同梱しない。AI が要件に合わせて設計・実装するための**土台**と、**作り方のルール（スキル）**を用意する
- DB の項目や使う技術はその都度決める。どの用途でも同じ部分（Worker の入口、ローカル確認、デプロイ、管理画面の保護、秘密情報の扱い）は固定する

## 変更案

### 1. `wrangler.jsonc`：静的サイトのみ → Worker と静的ファイルの併用

- `main: "src/index.ts"` を追加し、`assets` に `binding: "ASSETS"` を付ける
- `run_worker_first: ["/api/*", "/admin/*"]`。ページはこれまで通り静的に配信し、プログラムを通すのは API と管理画面だけ
- `d1_databases` / `r2_buckets` は**コメントアウトした記入例**だけ置く。何を使うかは案件ごとに決める
- `observability` を有効にする

### 2. `package.json` を復活させる

- wrangler を devDependency に入れ、`dev` / `deploy` / `db:migrate:local` / `db:migrate:remote` を用意
- 元テンプレートの「外部依存ゼロ」を覆す理由（Worker のコードを動かすのに必要）を README に明記する

### 3. 最小の `src/index.ts`

- `/api/health` だけ返し、それ以外は `env.ASSETS.fetch()` に渡す
- ルーティングの道具（素の書き方か Hono など）は決めず、スキル側で選ばせる

### 4. ローカル確認の仕組みを変える

- `npx serve public` では `/api/*` が動かないので、`launch.json` を `wrangler dev`（ポート 8787）に変える
- `.claude/settings.json` に `npx wrangler dev` と `npx wrangler d1 migrations apply * --local` の実行許可を追加
- CLAUDE.md とスキルの「生成後の確認」を書き換え、API の応答とローカル DB への書き込みも確認するようにする

### 5. スキル

- `one-page-site-builder` は公開ページ用として残す（「管理画面・動的SPAには使わない」と書かれているため）
- 新しく `worker-system-builder`（仮）スキルを作る
  - 要件の聞き取り：誰が更新するか、保存するデータ、画像の有無、個人情報の有無
  - 保存先の選び方：D1・R2・KV
  - フォルダ構成：`src/` と `migrations/`、マイグレーション手順
  - 管理画面の認証：Cloudflare Access を標準、使えない場合はパスワード方式
  - 秘密情報：`.dev.vars` と `wrangler secret put`。Git には入れない
  - 公開フォームの迷惑投稿対策：Turnstile（`turnstile-spin` スキル）
  - 予約の二重登録防止：一意制約やトランザクション
  - 個人情報の保存期間と削除
- お知らせと予約は、スキル内の作例（`references/`）として置く。DB 定義は固定しない

### 6. デプロイ（Workers Builds）

- 標準のデプロイコマンドは D1 のマイグレーションを実行しないので、デプロイ前に `d1 migrations apply --remote` を流す `deploy` スクリプトを用意する
- 初回だけ必要な D1・R2 の作成と `database_id` の書き込みを README とスキルに書く
- wrangler が ID なしでリソースを自動作成できるかは未確認。Cloudflare のドキュメントで確かめてから採用を決める

### 7. CLAUDE.md・README・その他

- CLAUDE.md の前提を「ワンページ＋小さなシステム」に変える。ファイル構成に `src/` と `migrations/`、セキュリティのルール（秘密情報を Git に入れない、管理画面は必ず認証する）を書く
- `scripts/update.sh` / `update.ps1` の向き先を変える（今は `toiee-lab/claude1page` から上書きし、`package.json` も削除するため壊れる）
  - → 後に方針を変更: スクリプトは廃止し、README に Claude Code 向けのアップデート指示を載せる。利用者のリポジトリはこのテンプレートの今の状態が出発点で、旧 claude1page からの移行は不要。システムを作った後は、ファイルの置き換えではなく、利用者の変更と合わせる判断が必要なため
- README のクローン先 URL と説明文を書き換える
- `check-worker-name.sh` の除外条件にこのリポジトリを追加する（対応済み）

## 進め方

1. 1〜4（Worker が動く最小構成）— 済
2. 5（スキル）と 7（CLAUDE.md・README・update スクリプト）— 済
3. 6（デプロイ手順）— 未着手

## 実装中に分かったこと

- 静的ファイル（`assets`）を持つ Worker には `ctx.access` が渡されない。Cloudflare Access で管理画面を守る場合は、`Cf-Access-Jwt-Assertion` の JWT を Worker で検証する（`worker-system-builder/references/admin-auth.md`）
- Worker の設定画面の「Enable Cloudflare Access」は Worker 全体（公開ページも含む）を守ってしまう。`/admin` だけ守るには、Zero Trust で self-hosted アプリケーションをパス指定で作る
- wrangler には D1・R2 の自動作成（ID を書かずにデプロイすると作られる）があるが、ダッシュボード／GitHub 経由のデプロイでは ID がリポジトリに書き戻されない。マイグレーションのコマンドで DB を指定しにくくなるため、スキルでは `wrangler d1 create` で作って ID を書く方式にした。6 で改めて検討する
