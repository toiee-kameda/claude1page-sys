# 作例: お知らせ

店主などの管理者がお知らせを書き、ワンページの「お知らせ」セクションに新しい順で表示する。

これは**一例**。項目・画面・API は、聞き取った要件に合わせて足したり削ったりする。

## よくある要件と、確認したいこと

- 書くのは誰か（1 人か数人か）→ 認証方式を決める
- 画像を付けるか → 付けるなら R2 を使う
- 下書き・公開予約は要るか → 要るなら `published_at` を未来の日時にできるようにする
- 何件表示するか（最新 5 件など）、古いものの一覧ページは要るか

## データの持ち方（例）

```sql
-- migrations/0001_create_announcements.sql
CREATE TABLE announcements (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  title        TEXT    NOT NULL,
  body         TEXT    NOT NULL,
  image_key    TEXT,                 -- R2 のキー（画像を使う場合だけ）
  published_at TEXT,                 -- UTC の ISO 8601。NULL は下書き
  created_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX idx_announcements_published_at ON announcements (published_at);
```

## API（例）

| メソッド | パス | 誰が | 内容 |
|---|---|---|---|
| GET | `/api/announcements?limit=5` | 誰でも | 公開済み（`published_at <= 現在`）を新しい順に。`limit` は上限（例: 50）を決めておく |
| GET | `/api/files/<キー>` | 誰でも | R2 の画像を返す |
| GET | `/api/admin/announcements` | 管理者 | 下書きも含めた一覧 |
| POST | `/api/admin/announcements` | 管理者 | 作成 |
| PUT | `/api/admin/announcements/<id>` | 管理者 | 更新（`updated_at` も更新） |
| DELETE | `/api/admin/announcements/<id>` | 管理者 | 削除（画像があれば R2 からも消す） |
| POST | `/api/admin/files` | 管理者 | 画像のアップロード。種類とサイズを確認し、キーを返す |

入力の確認例: タイトル 1〜100 文字、本文 1〜5000 文字、`published_at` は日時として読めること。

## 画面

- **公開ページ**（`public/index.html` のお知らせセクション）: 読み込み時に `fetch('/api/announcements?limit=5')` して並べる。日付は `Intl.DateTimeFormat('ja-JP', { timeZone: 'Asia/Tokyo', dateStyle: 'long' })` で表示。本文は `textContent` ＋ `white-space: pre-wrap`。0 件・読み込み失敗のときの表示も作る
- **管理画面**（`/admin`）: 一覧・新規作成・編集・削除・公開/下書きの切り替え。削除は確認ダイアログを出す。見た目は簡素でよいが、スマホでも操作できるようにする

## つまずきやすい点

- 公開ページは静的ファイルなので、お知らせを更新してもページの再デプロイは不要（表示のたびに API から取る）
- 一覧 API に `Cache-Control: public, max-age=60` 程度を付けると軽くなる。付けた場合、更新の反映に最大 1 分かかることを伝える
- 公開予約を使う場合、「現在」との比較は SQL 側で `published_at <= strftime('%Y-%m-%dT%H:%M:%SZ', 'now')` とする（保存形式をそろえておけば文字列比較で正しく並ぶ）
