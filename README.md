# Claude1page-sys

Claude Code を使って、シンプルで、モダンで、美しい、ワンページで完結するWebページに、**お知らせ・予約・問い合わせフォームなどの小さなシステム**を付けて公開するためのスターターキットです。Cloudflare Workers（D1・R2）で動かすように設計されています。

[claude1page](https://github.com/toiee-lab/claude1page)（静的なワンページを作って公開するだけのテンプレート）から派生しました。ページだけで十分なら、そちらの方がシンプルです。

データベースのテーブルや使う道具は案件ごとに Claude が設計します。このテンプレートが用意するのは、どの案件でも同じ部分（Worker の入口、ローカルでの確認、管理画面の守り方、秘密情報の扱い）と、そのための作り方の指示（スキル）です。

## 免責事項（Disclaimer）

本プロジェクトは非公式のコミュニティプロジェクトであり、Anthropic PBCとは一切関係がありません。Claude®はAnthropic PBCの登録商標です。

This is an unofficial, community-created project and is not affiliated with, endorsed by, or sponsored by Anthropic PBC. Claude® is a registered trademark of Anthropic PBC.

## 更新履歴

<!-- テンプレートの管理者へ: この更新履歴は、利用者のリポジトリで Claude Code がアップデートを取り込むときの手がかりになります。
     各項目には「何を変えたか」に加えて、既存のリポジトリでどう取り込めばよいか（例: wrangler.jsonc の既存の設定に ○○ を足す、スキルを置き換える）を書いてください。 -->

- 2026年10月24日:
  - [claude1page](https://github.com/toiee-lab/claude1page) をベースに新規作成
  - 小さなシステム（お知らせ・予約など）を載せられるよう、**Worker 付きの構成**に変更。ページは `public/` から静的に配信し、`/api/*` と `/admin/*` だけ `src/index.ts` で処理する（`wrangler.jsonc` の `run_worker_first`）
  - `package.json` を復活（`wrangler` を開発用に追加）。Worker のプログラムをローカルで動かし、D1・R2 を使うために必要なため、「外部依存ゼロ」の方針から変更した。最初に `npm install` が必要
  - プレビューを `npx serve public`（ポート 3000）から `wrangler dev`（ポート 8787）に変更。`/api/*` も本番と同じように動く
  - `/admin` は管理画面を認証付きで作るまで 404 を返す
  - D1・R2 の設定例を `wrangler.jsonc` にコメントで追加
  - `worker-system-builder` スキルを追加。要件の聞き取り、D1・R2 の使い方、管理画面の認証（Cloudflare Access / パスワード）、秘密情報、公開フォームの守り、個人情報、確認手順をまとめた。作例として「お知らせ」「シンプルな予約」を同梱（DB 定義は固定せず、一例として示す）
  - CLAUDE.md を「ワンページ＋小さなシステム」の前提に書き換え、セキュリティのルールを追加
  - アップデートスクリプト（`scripts/update.sh` / `update.ps1`）を廃止。このテンプレートから作るリポジトリは今の状態が出発点になるため、元の claude1page 向けの移行処理は不要になった。今後の更新は、README の「アップデート方法」にある指示を Claude Code に渡して取り込む（あなたが加えた変更と合わせる判断が必要なため）
  - `.gitignore` で `.dev.vars.example` を除外しないようにした
  - 公開手順を「PC から `npx wrangler deploy` で 1 回目の公開 → できた Worker に GitHub をつなぐ」順に変更。Cloudflare の画面で GitHub から始めると、エラーも出ずにビルドが止まることがあったため


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

### (2) PC から 1 回目の公開をする

**最初の公開は、GitHub からではなく PC から行います。** Cloudflare の画面で GitHub のリポジトリを読み込むところから始めると、エラーも出ずにビルドが止まってしまうことがあります。先に PC から公開して Worker を作っておき、あとから GitHub をつなぐと確実です。

1. Cloudflare にログインする（ブラウザが開くので、許可する）
   ```bash
   npx wrangler login
   ```
2. D1・R2 を使うシステムを付けている場合は、先に「(4) システムを付けたときに Cloudflare 側でやること」のうち、D1・R2 の作成とテーブルの反映を済ませる（データベースが無いまま公開すると失敗します）
3. 公開する
   ```bash
   npx wrangler deploy
   ```
4. 表示された `https://<公開名>.<アカウント名>.workers.dev` を開いて確認する

「Cloudflare に公開して」と Claude に頼めば、ここまでを案内しながら進めてくれます。

### (3) GitHub とつなぐ

1. GitHub にリポジトリを作り、push しておく
2. Cloudflare の **Workers & Pages** で、(2) で作られた Worker（公開名と同じ名前）を開く
3. **設定（Settings）> ビルド（Builds）> 接続（Connect）** を選び、GitHub のリポジトリを選ぶ（「アプリケーションを作成」から新しく作らない）
4. ビルドコマンドは空のまま、デプロイコマンドは `npx wrangler deploy` のままで保存する
5. 何かを push して、ビルドが成功することを確かめる
6. 必要に応じて、カスタムドメインなどを設定する

以後は GitHub に push するたびに自動で公開されます。

### (4) システムを付けたときに Cloudflare 側でやること

D1・R2・管理画面などを使うと、push だけでは済まない作業が出てきます。Claude が完了時に「Cloudflare 側でやること」として伝えるので、その通りに進めてください。主なものは次の通りです。

- **D1・R2 の作成**: `npx wrangler login` でログインしたあと、Claude の案内に従って作成する（初回だけ。作った ID は `wrangler.jsonc` に書いて push する）
- **テーブルの変更の反映**: `npm run db:migrate:remote`（テーブルを追加・変更したときに毎回。push だけでは本番に反映されません）
- **秘密情報の登録**: `npx wrangler secret put <名前>`、またはダッシュボードの「設定 > 変数とシークレット」
- **管理画面のログイン設定**: Cloudflare Access を使う場合は、Zero Trust の画面で `/admin` と `/api/admin` を守る設定をする

※ Worker 名と `wrangler.jsonc` の `name` が食い違った場合、Cloudflare が `name` を直す Pull Request を送ってきます。マージすれば揃います
※ Cloudflare でドメインを管理すれば、独自ドメインの設定がすごく簡単になります

## アップデート方法

このテンプレートから作ったリポジトリには、テンプレートの更新は自動では届きません（通知もありません）。

テンプレートは、Claude Code の新しい機能や Cloudflare の変更に合わせて更新することがあります。取り込むときは、**Claude Code に次の指示を貼り付けて頼んでください**。アップデート用のスクリプトはありません。システムを作ったあとのリポジトリでは、ファイルを置き換えるだけでは済まず、あなたが加えた変更と合わせる判断が必要になるためです。

```
テンプレート（https://github.com/toiee-kameda/claude1page-sys）の最新版を、このリポジトリに取り込んでください。

- テンプレートの main を、作業用の一時フォルダ（このリポジトリの外）に取得する
- このリポジトリの README の「更新履歴」で一番新しい日付を確認し、テンプレートの更新履歴のうち、それより後の項目を取り込む対象にする。対象が無ければ、そう伝えて終わる。README に更新履歴が残っていなければ、どの時点から取り込むか私に聞く
- 作業用のブランチを作る
- 取り込む前に、何をどう変えるかを一覧にして説明し、私の了承を得る
- CLAUDE.md・.claude/settings.json・.claude/ のスキル・.gitignore は、このリポジトリで加えた変更を残したまま、新しい内容を合わせる。置き換えると私の変更が消える場合は、先に知らせる
- wrangler.jsonc の公開名（name）と D1・R2 などの設定、src/・migrations/・public/・project-docs/ の中身は変えない（更新履歴にこれらへの追記の指示がある場合は、既存の設定に足す形で行い、説明に含める）
- README は、更新履歴とアップデート方法などテンプレート由来の部分をテンプレートに合わせる。私が書き足した部分は残す
- 取り込んだら npm install・npm run types・npm run check を実行し、プレビューで表示と /api の動作を確認する
- 終わったら、変わった点を一覧にして伝え、コミットしてよいか聞く
```

取り込みは作業用のブランチで行われるので、うまくいかなかったときは、そのブランチを捨てれば元に戻せます。

## ライセンス

[MIT License](LICENSE)
