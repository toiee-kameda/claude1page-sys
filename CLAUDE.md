# （ここにプロジェクト名を書いてください）

## プロジェクト概要

- 非エンジニア、非デザイナーが、AI Agent (Claude Code) を使って Web サイトを構築する
- 構築する Web サイトは「ワンページ完結」とする。1 ページに必要な情報をまとめて提供する
- ブログなどは、別のサービス（Substack や note.com など）を利用することを前提とする
- デプロイ先は **Cloudflare Workers**（静的アセット ＋ Worker。GitHub 連携の Workers Builds で公開）
- ページは `public/` から静的に配信し、`/api/*` と `/admin/*` だけを Worker（`src/index.ts`）で処理する

## ファイル構成

- `project-docs/` : Web ページの内容や、その他作成に必要なドキュメントを格納
- `public/` : 公開するディレクトリ（`wrangler.jsonc` の `assets.directory`）。ここに成果物を入れる
- `public/assets/` : 画像、CSS、JavaScript などの生成物の置き場
- `src/index.ts` : Worker の入口。API や管理画面の処理を書く
- `wrangler.jsonc` : Workers の設定。`name` が公開名（Worker 名）。D1・R2 などを使うときもここに書く
- `worker-configuration.d.ts` : `wrangler types` が生成する型定義。`wrangler.jsonc` を変えたら `npm run types` で作り直す（手で編集しない）

# 作成のためのルール

## 保存先

- ファイルは必ず **UTF-8** で保存（日本語の文字化け防止）
- 成果物は `public/` ディレクトリに保存
- 特に指示がなければ `public/index.html` で作成
- 指示があれば、その指示に合わせて `public/` 配下に保存
- 画像・CSS・JavaScript を生成した場合は `public/assets/` 配下の所定フォルダに保存

## あなたの仕事

- **Web ページの作成**: ユーザーの指示・意図を理解して作成する。コンテンツも創造的に作って欲しいと判断したら創造性を発揮する。詳細指定があればそれに従う
- **Web ページの編集**: 編集箇所と依頼を理解して編集する
- **Web ページのチェック**: 文法エラー、不要な記述、大きすぎる画像などがあれば改善方法をアドバイスする

作成・編集したあとは、**必ずプレビューで表示を確認してから完了とする**（`.claude/launch.json` の `Worker (wrangler dev)` を起動し、コンソールエラー・404・レイアウト崩れを確認する。API を作った・変えたときは、その応答も実際に呼んで確認する）。`node_modules/` が無ければ先に `npm install` を実行する。手順は `one-page-site-builder` スキルの「生成後の確認」にある。ユーザーに確認を丸投げしない。

## 公開名（Worker 名）

`wrangler.jsonc` の `name` は公開 URL（`https://<name>.<アカウント名>.workers.dev`）の先頭になる。原則として **GitHub リポジトリ名 ＝ Worker 名** で揃える。

- `name` が仮の `"rename-me"` のままだと SessionStart フックが知らせてくる。そのときは、最初の返答で 1 回だけ「公開名をリポジトリ名の候補に変えるか」を確認し、了承されたら `name` を書き換える（断られたら、そのセッションでは繰り返さない）
- 使える文字は英小文字・数字・ハイフンのみ、63 文字以内
- 名前を変えると workers.dev の URL も変わる。すでに Cloudflare で公開済みなら、ダッシュボードの Worker 名と同じにする（違うと、Cloudflare が `name` を直す PR を送ってくる）

## ワンページ Web サイトの生成方法

ワンページサイトの作成・編集を行う際は、必ず **`one-page-site-builder` スキル**を使用すること。
技術スタック（使用ライブラリと CDN タグ）、HTML 構造、固定ナビゲーション仕様、セクション構成、画像方針、生成前の確認、生成後の確認は、すべてこのスキルに集約されている。ここには重複して書かない。

画像が必要な場合は **`unsplash-image-finder` スキル**を使って Unsplash から取得する。
