# Claude1page-sys

Claude Code を使って、シンプルで、モダンで、美しい、ワンページで完結するWebページに、**お知らせ・予約・問い合わせフォームなどの小さなシステム**を付けて公開するためのスターターキットです。Cloudflare Workers（D1・R2）で動かすように設計されています。

[claude1page](https://github.com/toiee-lab/claude1page)（静的なワンページを作って公開するだけのテンプレート）から派生しました。ページだけで十分なら、そちらの方がシンプルです。

データベースのテーブルや使う道具は案件ごとに Claude が設計します。このテンプレートが用意するのは、どの案件でも同じ部分（Worker の入口、ローカルでの確認、管理画面の守り方、秘密情報の扱い）と、そのための作り方の指示（スキル）です。

## 免責事項（Disclaimer）

本プロジェクトは非公式のコミュニティプロジェクトであり、Anthropic PBCとは一切関係がありません。Claude®はAnthropic PBCの登録商標です。

This is an unofficial, community-created project and is not affiliated with, endorsed by, or sponsored by Anthropic PBC. Claude® is a registered trademark of Anthropic PBC.

## 更新履歴

- 2026年10月24日:
  - 小さなシステム（お知らせ・予約など）を載せられるよう、**Worker 付きの構成**に変更。ページは `public/` から静的に配信し、`/api/*` と `/admin/*` だけ `src/index.ts` で処理する（`wrangler.jsonc` の `run_worker_first`）
  - `package.json` を復活（`wrangler` を開発用に追加）。Worker のプログラムをローカルで動かし、D1・R2 を使うために必要なため、「外部依存ゼロ」の方針から変更した。最初に `npm install` が必要
  - プレビューを `npx serve public`（ポート 3000）から `wrangler dev`（ポート 8787）に変更。`/api/*` も本番と同じように動く
  - `/admin` は管理画面を認証付きで作るまで 404 を返す
  - D1・R2 の設定例を `wrangler.jsonc` にコメントで追加
  - `worker-system-builder` スキルを追加。要件の聞き取り、D1・R2 の使い方、管理画面の認証（Cloudflare Access / パスワード）、秘密情報、公開フォームの守り、個人情報、確認手順をまとめた。作例として「お知らせ」「シンプルな予約」を同梱（DB 定義は固定せず、一例として示す）
  - CLAUDE.md を「ワンページ＋小さなシステム」の前提に書き換え、セキュリティのルールを追加
  - アップデートスクリプトの取得元をこのリポジトリ（`toiee-kameda/claude1page-sys`）に変更。`package.json` を削除しないようにし、`wrangler.jsonc`・`package.json`・`tsconfig.json`・`src/index.ts` は**まだ無い場合だけ**追加する
  - `.gitignore` で `.dev.vars.example` を除外しないようにした

- 2026年10月19日:
  - 公開先を Cloudflare Pages から **Cloudflare Workers**（静的アセット）に変更。`wrangler.jsonc` を追加し、`public/` をそのまま公開する設定にした
  - 公開名（Worker 名）は `wrangler.jsonc` の `name` で決まる。仮の `rename-me` のままだと、Claude Code が起動時にリポジトリ名へ合わせるよう提案する（`.claude/hooks/check-worker-name.sh`）
  - `.gitignore` に `.wrangler/` と `.dev.vars*` を追加
  - アップデートスクリプトは `wrangler.jsonc` を**まだ無い場合だけ**追加する（設定済みの公開名を上書きしない）

- 2026年 9月28日:
  - CLAUDE.md から「ローカルでの表示確認」セクションを削除。`.claude/launch.json`・`.vscode/settings.json`・README に同じ情報があり、毎セッション読み込まれる CLAUDE.md に置く必要がないため（人向けの説明は README の「ローカルでの表示確認」に残っています）

- 2026年 9月17日:
  - `one-page-site-builder` スキルの Lucide v1 改名表を修正。表にあった `face-smiling` / `text-align-left` は v1.32.0 に存在せず描画されない名前だった（実機確認）。旧名がエイリアスとして残っていることが分かったため、表を撤去し「旧名のまま使ってよい」旨に置き換え
  - `one-page-site-builder` スキルに「作成前の確認（インタビュー）」を追加。新規作成時に対象読者・ゴール・印象が不明なら、おすすめ案を 1 つ添えて 1 回にまとめて確認する
  - `.claude/settings.json` に `npx serve public` の実行許可を追加（ターミナル版 Claude Code で「生成後の確認」を行う際に許可プロンプトで止まらないように）
  - CLAUDE.md の技術スタック列挙を廃止し、スキル参照に一本化（Simple Icons 移行時に CLAUDE.md 側が更新漏れしていたため）

- 2026年 8月19日:
  - `update.sh` / `update.ps1` が削除済みの `package.json` / `package-lock.json` を取得しようとして毎回ダウンロード失敗していた問題を修正
  - アップデート対象に `LICENSE` と `.vscode/settings.json` を追加。上書きされるファイルを完了メッセージに明記
  - 3つの Unsplash スクリプトに重複していた `.env.local` の読み込み処理を `_load-env.sh` に集約。Windows で作成した `.env.local`（CRLF 改行）やクォート付きの記述でも API キーが正しく読めるように修正
  - `one-page-site-builder` スキルを見直し: 「最低8セクション」の数値ノルマを撤廃（水増し防止）、ナビ仕様を「意図＋必須要件」に整理、全ライブラリの CDN タグと記述位置を明記、**生成後にプレビューで自己確認する手順を追加**
  - `unsplash-image-finder` スキルの description を日本語化し、既定値と同じで無意味だった `user-invocable: true` を削除
  - README のファイル構成図を実態に合わせ、ローカル表示確認とライセンスの記載を追加
  - Lucide をメジャーバージョン **v1.32.0** に更新
  - ブランドロゴ（SNSアイコン等）は **Simple Icons** から取得する方式に変更。Lucide 公式のガイド（[Brand Logo Statement](https://lucide.dev/brand-logo-statement)）に従った対応
  - `brand-icon.sh` を追加。Simple Icons の SVG を `fill="currentColor"` 付きで取り出し、HTML に直接貼れる形で出力する（元データには `fill` が無く、そのまま貼ると黒一色になるため）
  - v1 で名称が変わった Lucide アイコンの対応表を `one-page-site-builder` スキルに追記

- 2026年 4月13日:
  - `one-page-site-builder` スキルの `references/` 配下4ファイル（tech-stack・navigation-spec・content-structure・image-optimization）を `SKILL.md` に統合・集約
  - スキルファイルの構成をシンプル化し、参照ファイルなしで完結するように刷新
  - アップデートスクリプト（`update.sh` / `update.ps1`）で古い `references/` を削除するよう対応

- 2026年 4月10日:
  - `unsplash-image-finder` の画像検索スクリプトを Node.js (`unsplash-search.js`) からシェルスクリプト (`unsplash-search.sh` / `unsplash-health-check.sh` / `unsplash-track.sh`) に完全移行
  - Node.js・npm・undici が不要になり、セットアップがシンプル化
  - プロキシ対応をシェルスクリプト内の `curl` オプションで実装。Claude Code クラウド環境でも `npm install` なしで動作
  - `references/setup.md` を追加（Unsplash API キーの設定方法をスキル内に集約）
  - アップデートスクリプト（`update.sh` / `update.ps1`）を新しいスクリプト構成に対応

- 2026年 4月 9日:
  - `SessionStart` フックを追加。クラウド環境（`$CLAUDE_CODE_REMOTE = "true"`）でのみ `npm install` を自動実行するよう設定
  - `node install` 不要にしていたが、Claude Codeクラウド環境では、プロキシを使う必要があるため、 `undici` を使い対応するように変更
  - ただし `unsplash-search.js` の `undici` を動的インポートに変更し、`npm install` 不要でも動作するよう改善
  - `package.json` に `"type": "module"` を追加し、Node.js の警告を解消
  - アップデートスクリプト（`update.sh` / `update.ps1`）で `package.json` / `package-lock.json` を削除せず、最新版をダウンロードするよう変更
- 2026年 4月 7日:
  - `one-page-site-builder` スキルを追加（ワンページサイトの技術スタック・HTML 構造・ナビ仕様・画像最適化方針を集約）
  - CLAUDE.md を整理し、詳細仕様はスキル側に委譲するシンプルな構成に刷新
- 2026年 3月10日:
  - 外部依存（Node.js パッケージ）を完全撤廃。`package.json`, `scripts/install_pkgs.sh` を削除
  - `unsplash-search.js` を `.claude/skills/unsplash-image-finder/` に統合（外部依存ゼロで動作）
  - アップデート方式をワンライナーに刷新（`scripts/update.sh` / `update.ps1`）
- 2026年 2月24日:
  - Claude Code Desktop のプレビュー機能で利用できるように、 launch.json を追加
- 2026年 2月6日:
  - 講座のURLを、cwm.toiee.jp にドメインを変更したこと伴う修正（ダミー画像のリンク先）
  - CLAUDE.md の冗長性の修正
- 2026年 1月19日:
  - Unsplash画像検索を Sub Agent ではなく、Skillに移行（これにより、コンテキストの消費を抑え、動作も軽快になる）
- 2025年 12月26日:
  - .gitignore に、`.playwright-mcp` 一時フォルダを追加し、リポジトリから除外されるようにした
- 2025年 12月23日:
  - TailwindCSS v4.1 の設定をより確実に行われるように、CLAUDE.md を修正
  - ナビゲーションがより確実に実装されやすいように技術仕様、デザインについての方針を明確に記述(CLAUDE.md)
- 2025年 11月26日:
  - Claude Code on the Web (Sandbox)では、Unsplashの画像検索ができない問題を解決（Proxyを使うように修正）
  - 画像検索のフォールバックが、フォールバックになっていない（エラーする画像URL）ので、独自で用意したダミー画像URLを指定するようにした（ https://cwm.toiee.jp/images/dummy.jpg )
- 2025年 11月 5日:
  - scripts/install_pkg.sh をローカルでは実行しない（Claude Code on the Webでは実行）ように設定
  - scripts/install_pkg.sh に実行権限を与えるように初期設定のガイドを修正
- 2025年 10月 27日:
  - `.rgignore` を使って、prompt.md などを検索対象除外から除外（これで、Claude Code で @ で指定できるようになった）
  - README.md を Cloudflareの説明などに変更（Unsplashの設定も推奨に設定、環境変数対応についても記載など）

**アップデート方法は、末尾をご覧ください**

## 必要なサービスと準備

- **Claude Code の事前インストール** （Claude Code on the Web でも動作します）
- **Visual Studio Code**
  - **おすすめの拡張機能**
  	- Claude Code
    - Live Server
    - Prettier - Code formatter
- [Github.com](https://github.com/)
- Gitのインストールと設定
- **Node.js**（Worker を動かす `wrangler` に必要。macOS なら `mise use -g node@lts` などでインストール）
- [Cloudflare](https://www.cloudflare.com/ja-jp/)
- [Unsplash開発者登録](https://unsplash.com/oauth/applications)

### Unsplash API キーの設定（環境変数に設定）

**APIキーの取得方法：**
1. [Unsplash Developers](https://unsplash.com/developers) にアクセス
2. "Register as a developer" でアカウント登録
3. "New Application" で新しいアプリケーションを作成
4. Access Key を取得

環境変数に設定する場合は、以下のようなコマンド（here-is-your-keyを書き換えた上で）を実行します。

macOSの場合
```zsh
echo 'export UNSPLASH_ACCESS_KEY=here-is-your-key' >> ~/.zshrc && source ~/.zshrc
```

Windowsの場合（PowerShellで実行）
```powershell
if (!(Test-Path $PROFILE)) { New-Item -Path $PROFILE -ItemType File -Force }; Add-Content -Path $PROFILE -Value '$env:UNSPLASH_ACCESS_KEY="here-is-your-key"'; . $PROFILE
```

あるいは、APIキー設定用のファイルを作成し、中身を編集してください。見ればわかります。

```bash
cp .env.local.example .env.local
```

## 準備

1. **リポジトリからクローン**
      
   フォルダを作る
   ```bash
   mkdir project-name
   ```
   フォルダに移動
   ```bash
   cd project-name
   ```
   
   フォルダ内でリポジトリをクローン（展開する）
   ```bash
   git clone https://github.com/toiee-kameda/claude1page-sys.git .
   ```

2. **リポジトリの初期化**
   ```bash
   rm -rf .git
   git init
   ```

3. **Worker を動かす道具（wrangler）を入れる**
   ```bash
   npm install
   ```

4. **Unsplashで画像が検索できるかテストする**
   以下のコマンドでテストしてください。

   ```bash
   bash .claude/skills/unsplash-image-finder/unsplash-health-check.sh
   ```

以上で完了です。

> **Claude Code on the Web（クラウドサンドボックス環境）でも動作します。**
> 画像検索のシェルスクリプトはプロキシ環境を自動検出し、`curl` 経由で Unsplash API にアクセスします。Worker の確認には `npm install` が必要です（Claude が必要に応じて実行します）。

## ポイント

- **プロンプトファイルの活用**
  - `prompt.md` や `prompt2.md` などのファイルを作って、プロンプトを書いてコピペすると便利です（gitに保存されません）
  - あるいは、 prompt.md にプロンプトを書き込み、保存し、 `@prompt.md` で呼び出しても良いです

- **コンテンツの管理**
  - `project-docs` ディレクトリに、コンテキストコンテンツなどを保管して、呼び出すと便利です

- **画像の自動取得**
  - Unsplash APIを設定すると、Claude Codeが自動で高品質な画像を検索・取得します
  - 手動で画像を探す手間が省けて、作業効率が大幅に向上します
  - 取得される画像は最適化済み（WebP形式、適切なサイズ）で、ページの読み込み速度も向上します

## プロンプト例

```
Webページを作成してください。

- ここにありったけ、情報を書いてください
- どんなデザインが良いのか？
- もし、カラーが決まっているなら指定する
- 誰向けのものなのか？
- あなたが伝えたいこと、あなたの強み、特徴など
- お店の名前や、プロダクトについての説明など
- 難しく考えず、たくさん書いて、あとはClaudeに任せましょう
```

## ファイル構成

```
claude1page/
├── public/             # 公開用ディレクトリ（成果物はここに作られる）
│   └── assets/         # CSS、JS、画像、フォントなどの静的ファイル
├── project-docs/       # プロジェクト関連ドキュメント
├── scripts/            # アップデートスクリプト
│   ├── update.sh       # macOS/Linux用
│   └── update.ps1      # Windows用
├── .claude/
│   ├── settings.json   # Claude Code設定（権限の許可リスト）
│   ├── launch.json     # プレビュー用サーバー設定（wrangler dev、ポート8787）
│   ├── hooks/
│   │   └── check-worker-name.sh  # 公開名が未設定なら知らせるフック
│   └── skills/         # スキル定義
│       ├── one-page-site-builder/
│       │   └── SKILL.md                  # ワンページサイト生成スキル（技術仕様・ナビ仕様・生成後の確認）
│       ├── worker-system-builder/
│       │   ├── SKILL.md                  # システム作成スキル（D1・R2・認証・秘密情報・確認手順）
│       │   └── references/               # 管理画面の認証、作例（お知らせ・予約）
│       └── unsplash-image-finder/
│           ├── SKILL.md                  # 画像検索スキル
│           ├── _load-env.sh              # APIキー読み込みの共通処理
│           ├── unsplash-search.sh        # 画像検索スクリプト
│           ├── unsplash-health-check.sh  # 動作確認スクリプト
│           ├── unsplash-track.sh         # ダウンロード記録スクリプト
│           └── references/setup.md       # APIキー設定ガイド
├── .vscode/
│   └── settings.json   # VS Code Live Server 設定（ポート5500）
├── src/
│   └── index.ts        # Worker の入口（/api/* と /admin/* を処理）
├── wrangler.jsonc      # Cloudflare Workers の設定（公開名・公開フォルダ・D1/R2）
├── package.json        # wrangler と実行コマンド（npm run dev など）
├── tsconfig.json       # TypeScript の設定
├── worker-configuration.d.ts  # wrangler types が生成する型定義（手で編集しない）
├── CLAUDE.md           # Claude Code用の指示書
├── .env.local.example  # API設定テンプレート
├── LICENSE             # MIT License
└── README.md           # このファイル
```

## ローカルでの表示確認

最初に一度だけ `npm install` を実行してください（Worker を動かす `wrangler` が入ります）。

作ったページをブラウザで確認する方法は2つあります。

- **Claude Code のプレビュー機能**: `.claude/launch.json` の `Worker (wrangler dev)` を使います（`npx wrangler dev`、http://localhost:8787 ）。ページに加えて `/api/*` などのシステム部分も本番と同じように動きます。Claude 自身がここでページを開いて、コンソールエラーや画像のリンク切れを自分で確認します
- **VS Code の Live Server 拡張**: `.vscode/settings.json` で `public` をルートに設定済みです（http://localhost:5500 ）。見た目の確認だけならこちらでも構いませんが、`/api/*` は動きません

## Cloudflare Workers での公開

### (1) 公開名を決める

公開 URL は `https://<公開名>.<アカウント名>.workers.dev` になります。公開名は **GitHub のリポジトリ名と同じ** にするのがおすすめです。

- テンプレートからリポジトリを作るときに、英小文字・数字・ハイフンだけの名前を付けておく（例: `kameda-cafe`）
- `wrangler.jsonc` の `"name": "rename-me"` を、その名前に書き換える。Claude Code を起動すると「公開名が未設定です」と提案してくれるので、了承すれば書き換えてくれます
- 独自ドメインを使う場合も、公開名は管理用の名前として残ります

### (2) Cloudflare に接続する

1. Cloudflare にログイン
2. コンピューティングとAI > Workers & Pages を選択
3. アプリケーションを作成 > 「リポジトリをインポート」（Git リポジトリに接続）を選び、GitHub のリポジトリを選ぶ
4. プロジェクト名（Worker 名）を、`wrangler.jsonc` の `name` と同じにする
5. ビルドコマンドは空のまま、デプロイコマンドは `npx wrangler deploy` のままでデプロイ
6. その後、必要に応じて、カスタムドメインなどを設定する

以後は GitHub に push するたびに自動で公開されます。

### (3) システムを付けたときに Cloudflare 側でやること

D1・R2・管理画面などを使うと、push だけでは済まない作業が出てきます。Claude が完了時に「Cloudflare 側でやること」として伝えるので、その通りに進めてください。主なものは次の通りです。

- **D1・R2 の作成**: `npx wrangler login` でログインしたあと、Claude の案内に従って作成する（初回だけ）
- **テーブルの変更の反映**: `npm run db:migrate:remote`（テーブルを追加・変更したときに毎回。push だけでは本番に反映されません）
- **秘密情報の登録**: `npx wrangler secret put <名前>`、またはダッシュボードの「設定 > 変数とシークレット」
- **管理画面のログイン設定**: Cloudflare Access を使う場合は、Zero Trust の画面で `/admin` と `/api/admin` を守る設定をする

※ Worker 名と `wrangler.jsonc` の `name` が食い違った場合、Cloudflare が `name` を直す Pull Request を送ってきます。マージすれば揃います
※ Cloudflare でドメインを管理すれば、独自ドメインの設定がすごく簡単になります

## アップデート方法

このテンプレートリポジトリから作成した新しいリポジトリには、自動でアップデートはされません（通知も）。

時々、Claude Code の新しい機能に対応させるために、アップデートを行うことがあります。手順は、以下の通りです。

### (1) アップデートスクリプトを実行

プロジェクトのルートディレクトリで、以下のワンライナーを実行してください。

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/toiee-kameda/claude1page-sys/main/scripts/update.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/toiee-kameda/claude1page-sys/main/scripts/update.ps1 | iex
```

### (2) 変更点をチェック

ソースコード管理などで、変更されたファイルをチェックしてください。もし、あなたが意図的に変更したものを上書きしているなら、以前のものと今のものを比較しながら、調整してください。

アップデートで上書きされるのは以下のファイルです。カスタマイズしている場合は、ご自身の変更を再反映してください。

- `CLAUDE.md`
- `README.md`
- `.claude/settings.json`
- `.claude/launch.json`
- `.gitignore`
- `.vscode/settings.json`
- スキル（`.claude/skills/` 配下）

`wrangler.jsonc`・`package.json`・`tsconfig.json`・`src/` は上書きされません（まだ無い場合だけ追加されます）。アップデート後に `npm install` と `npm run types` を実行してください。

## ライセンス

[MIT License](LICENSE)
