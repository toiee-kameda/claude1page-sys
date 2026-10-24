---
name: worker-system-builder
description: Cloudflare Workers で、ワンページサイトに小さなシステム（お知らせ、予約、問い合わせフォーム、申込受付、ファイル置き場など）を付けるときに使います。D1・R2・KV、API、管理画面、データベース、フォームの保存、ログインが話題になったときに使います。ページの見た目だけの作成・編集には one-page-site-builder を使います。
---

非エンジニア向けに、ワンページサイトへ「小さなシステム」を安全に付けるためのスキル。

想定する規模: 管理者が数人、データが数千件程度まで。会員登録・決済・大規模な SNS のような仕組みは対象外（その場合は専用サービスを勧める）。

ページ（`public/index.html` など）の見た目は **`one-page-site-builder` スキル**に従う。このスキルは、その裏側（API・データ保存・管理画面）を担当する。

DB の項目や使う道具は、案件ごとに決める。このスキルが固定するのは、どの案件でも変わらない部分（構成・認証・秘密情報・確認手順）だけ。

## 作成前の確認（インタビュー）

新しくシステムを作るときは、作り始める前に確認する。依頼文から読み取れる項目は聞かない。

1. **誰が、何を登録・更新するか**（例: 店主がお知らせを書く / お客さんが予約を入れる）
2. **保存するものは何か**（文章・日時・人数・画像・添付ファイル など）
3. **個人情報を受け取るか**（名前・メール・電話番号。受け取るなら、いつ消すか）
4. **管理者は誰か**（自分だけ / 数人。ログインに使うメールアドレス）
5. **通知は要るか**（予約が入ったらメールで知らせる、など。要るなら外部サービスが必要になることを伝える）

聞き方は `one-page-site-builder` と同じ: 足りない項目だけを **1 回のメッセージにまとめて**聞き、各質問に**おすすめの答えを 1 つ添える**。「おまかせ」と言われたら、おすすめで作る。

作例として [references/announcements.md](references/announcements.md)（お知らせ）と [references/reservations.md](references/reservations.md)（予約）がある。近い依頼のときは読んでから設計する。そのまま写すのではなく、聞き取った要件に合わせて変える。

## 構成

```
public/            # ページ（静的ファイル）。データは fetch('/api/...') で取りに行く
src/index.ts       # Worker の入口。/api・/admin だけがここに来る
src/*.ts           # 処理が増えたら機能ごとに分ける（例: src/announcements.ts）
migrations/        # D1 のテーブル定義（マイグレーション）。番号順に適用される
wrangler.jsonc     # D1・R2 などの設定
```

- Worker を通るのは `wrangler.jsonc` の `run_worker_first` に書いたパスだけ（初期値は `/api`・`/api/*`・`/admin`・`/admin/*`）。ほかのパスを Worker で処理したいときは、ここに追加する
- **公開用の API** は `/api/...`、**管理者用の API** は `/api/admin/...`、**管理画面** は `/admin` に置く。管理用は必ず認証を通す（後述）
- 管理画面の HTML は `public/` に置かない（`/admin` へのリクエストは Worker が受けるので、Worker から返す。`src/admin.html` を `import` してもよい。wrangler は `*.html` を文字列として取り込める）
- ルーティングは、数本なら `if (url.pathname === ...)` の素の書き方でよい。10 本を超えそうなら Hono（`npm install hono`）を使ってよい。どちらにしたかを最初に一言伝える
- ページ側の JavaScript は素の `fetch` で書く。フレームワークやビルドは足さない

## 保存先の選び方

| 保存するもの | 使うもの | 例 |
|---|---|---|
| 一覧・検索・並べ替えをする記録 | **D1**（SQLite） | お知らせ、予約、問い合わせ |
| 画像・PDF などのファイル | **R2** | お知らせの画像、添付資料 |
| 設定値や一時的な小さなデータ | **KV** | 「受付停止中」フラグ、キャッシュ |

迷ったら D1。ファイルの中身を D1 に入れない（R2 に置いて、D1 にはキーだけ保存する）。

### D1 の使い方

1. 作成: `npx wrangler d1 create <名前>` を実行し、表示された設定を `wrangler.jsonc` の `d1_databases` に書く。binding 名は **`DB`** にそろえる（`package.json` の `db:migrate:*` が `DB` を前提にしている）。`migrations_dir` は `./migrations`
   - Cloudflare へのログイン（`npx wrangler login`）が必要。未ログインなら、ユーザーに実行してもらう
2. テーブル定義: `npx wrangler d1 migrations create DB <内容>` でファイルを作り、SQL を書く。**一度適用したマイグレーションは書き換えず**、変更は新しいファイルで足す
3. ローカルに適用: `npm run db:migrate:local`
4. 型の更新: `npm run types`（`wrangler.jsonc` を変えたら毎回）

SQL のルール:

- 値は**必ず `prepare(...).bind(...)` で渡す**。文字列連結で SQL を組み立てない（SQL インジェクション対策）
- 日時は **UTC の ISO 8601 文字列**（`2026-10-24T05:00:00Z`）で保存し、表示するときに日本時間に直す。日付だけの項目（予約日など）は `2026-10-24` の形で保存する
- 一覧で絞り込む列にはインデックスを張る
- 「重複してはいけない」ものは、アプリのチェックだけに頼らず **`UNIQUE` 制約**で守る（予約の二重登録など）。制約違反は 409 で返し、利用者に分かる言葉で伝える
- 複数の書き込みをまとめて成功・失敗させたいときは `env.DB.batch([...])` を使う

### R2 の使い方

1. 作成: `npx wrangler r2 bucket create <名前>` を実行し、`wrangler.jsonc` の `r2_buckets` に書く（binding 名は `BUCKET`）
2. アップロードは管理者用 API（`/api/admin/...`）でだけ受け付ける。**種類（MIME）とサイズの上限**を決めてサーバ側で確認する（画像なら `image/jpeg`・`image/png`・`image/webp`、5MB まで など）
3. 保存するキーは `crypto.randomUUID()` などで作る。利用者が付けたファイル名をそのままキーにしない
4. 公開は Worker 経由（`/api/files/<キー>` で `env.BUCKET.get()` して返す）を基本にする。`Content-Type` と `Cache-Control` を付けて返す

## 管理画面の認証（必須）

**管理者用の API と管理画面は、認証なしで公開しない。** 「URL を知らなければ大丈夫」は認証ではない。

方式は 2 つ。くわしい手順とコードは [references/admin-auth.md](references/admin-auth.md) にある。

1. **Cloudflare Access（おすすめ）**: Cloudflare の画面で「`/admin` と `/api/admin` はこのメールアドレスの人だけ」と設定する。ログインは Cloudflare がやってくれるので、パスワードを管理しなくてよい。Worker 側では、Access が付ける署名（JWT）を必ず検証する
2. **パスワード方式（Access が使えないとき）**: 管理用パスワードを秘密情報（`ADMIN_PASSWORD`）として登録し、Basic 認証で確認する

注意:

- 静的ファイルを配信している Worker（このテンプレート）では、`ctx.access` は Worker に渡されない。Access を使っても、`ctx.access` ではなく **`Cf-Access-Jwt-Assertion` ヘッダーの JWT を検証する**
- 認証の確認は、管理用のルートごとに書かず、**`/admin`・`/api/admin`（とその下）のパスの入口で 1 回だけ**行う（付け忘れを防ぐ）。Hono を使うときはミドルウェアで行う（理由は `references/admin-auth.md`）
- `src/index.ts` の初期状態では `/admin` は 404 を返す。管理画面を作るときに、認証を入れてから置き換える

## 秘密情報

- パスワードや API キーは **`wrangler.jsonc` にもソースにも書かない**
- ローカル: `.dev.vars` に書く（`.gitignore` 済み）。必要な項目は `.dev.vars.example` に**値を空にして**書いておく
- 本番: ユーザーに `npx wrangler secret put <名前>` を実行してもらうか、Cloudflare ダッシュボードの「設定 > 変数とシークレット」で登録してもらう。値はチャットに貼ってもらわない
- 秘密でない設定値（Access のチームドメインなど）は `wrangler.jsonc` の `vars` に書いてよい

## 公開フォーム（予約・問い合わせなど）の守り

- 入力はサーバ側で必ず確認する（必須・文字数の上限・形式・日付の範囲）。ブラウザ側の確認は使いやすさのためで、守りにはならない
- スパム対策に **Cloudflare Turnstile** を付ける。`turnstile-spin` スキルが使える環境なら、それに従う。使えなければ、Turnstile の Siteverify をサーバ側で呼んで確認する（サイトキーは公開してよいが、シークレットキーは秘密情報）
- 書き込み系の API は `POST`（など）だけを受け付け、`Content-Type: application/json` 以外は 415 で断る
- 管理者用の書き込み API は、`Origin` ヘッダーが自分のサイトと一致するかも確認する（CSRF 対策）

## 表示するときの注意（XSS 対策）

- 利用者や管理者が入力した文字列をページに出すときは、**`textContent` で入れる**。`innerHTML` に入れない
- お知らせ本文で改行を出したいときは、CSS の `white-space: pre-wrap` を使う。HTML を書かせる機能は作らない（どうしても必要なら、許可するタグを絞るサニタイズを入れ、そのことをユーザーに伝える）

## 個人情報

- 集める項目は最小限にする（「あると便利」で増やさない）
- 公開用の API で個人情報を返さない（予約の空き状況 API は「何件埋まっているか」だけを返す、など）
- `console.log` に個人情報を出さない（`observability` で Cloudflare のログに残る）
- 保存期間を決め、消す方法（管理画面の削除ボタン、または期限切れの自動削除）を用意する。決めた内容をユーザーに伝える
- ページに、何のために何を集めるかを一文で書く（フォームの近くに）

## エラーの返し方

- API は JSON で返す: 成功は `{ ok: true, ... }`、失敗は `{ error: "利用者に見せてよい日本語" }` と適切なステータス（400 入力不備 / 401・403 認証 / 404 / 409 重複 / 415 / 500）
- 想定外のエラーは `try/catch` で受けて 500 を返し、詳細（スタックトレースや SQL）は利用者に返さない

## 本番への反映

- **まだ一度も公開していないリポジトリでは、GitHub 連携より先に PC から公開する。** Cloudflare の画面で GitHub のリポジトリを読み込むところから始めると、エラーも出ずにビルドが止まることがある。次の順に進める（README の「Cloudflare Workers での公開」と同じ）
  1. ユーザーに `npx wrangler login` を実行してもらう（ブラウザでの許可が必要）
  2. D1・R2 を使うなら作成し、ID を `wrangler.jsonc` に書く。`npm run db:migrate:remote` でテーブルを作る
  3. `npx wrangler deploy` で公開する（本番への公開なので、実行前にユーザーの了承を得る）
  4. 秘密情報があれば `npx wrangler secret put <名前>` で登録してもらう。Worker ができてから行う（値はチャットに貼ってもらわない）
  5. ダッシュボードで、できた Worker の「設定 > ビルド > 接続」から GitHub のリポジトリをつないでもらう。「アプリケーションを作成」から新しく作らない
- 公開済みなら、コードの反映は GitHub に push すると Workers Builds で行われる
- **D1 のテーブル変更は push だけでは本番に反映されない。** 新しいマイグレーションを作ったら、push の前に `npm run db:migrate:remote` を実行してもらう（Cloudflare へのログインが必要）。列を足すだけなどの古いコードと両立する変更にしておく。そのことを完了報告で必ず伝える
- 秘密情報（`ADMIN_PASSWORD` など）や Access の設定は、ユーザーが Cloudflare 側で行う必要がある。手順を短く伝える

## 生成後の確認

作って終わりにしない。**ユーザーに「動かして確認してください」と丸投げしない。**

1. `node_modules/` が無ければ `npm install`。D1 を使うなら `npm run db:migrate:local`
2. プレビューを起動する（`.claude/launch.json` の `Worker (wrangler dev)`）
3. 確認する:
   - 公開用 API を実際に呼び、期待した JSON が返るか（`curl http://localhost:8787/api/...`）
   - 書き込み API で登録 → 一覧 API に出てくるか。不正な入力が 400 になるか。重複が 409 になるか
   - **認証なしで `/admin` と `/api/admin/...` を呼ぶと 401/403 になるか**（必ず確認する）
   - 認証ありで管理操作ができるか（Access 方式のローカル確認方法は `references/admin-auth.md`）
   - ページを開き、データが表示されるか。コンソールエラー・ネットワークの 404/500 がないか
   - `npm run check`（TypeScript の型チェック）が通るか
4. 問題があれば直して、もう一度確認する
5. 完了報告では、**ユーザーが Cloudflare 側でやること**（D1/R2 の作成、本番マイグレーション、秘密情報の登録、Access の設定）を箇条書きで伝える
