# 作例: シンプルな予約

お客さんが空いている枠を選んで予約し、管理者が予約一覧を確認・取り消しできる。

これは**一例**。枠の決め方（時間枠・日付単位・人数制）は店や催しによって大きく違うので、必ず聞き取ってから設計する。

## 必ず確認したいこと

- **枠の単位**: 30 分ごと / 1 日 1 組 / 1 回の定員○名 など
- **枠の作り方**: 管理者が 1 つずつ登録する / 曜日と時間のルールから自動で作る（ルール方式は複雑になるので、まず「管理者が登録」を勧める）
- **受け取る項目**: 名前・連絡先（メールか電話か）・人数・メモ。最小限にする
- **取り消し**: お客さん自身が取り消せるか（できるなら、予約時に取り消し用のコードを発行する）/ 管理者だけか
- **締め切り**: 前日まで、○時間前まで など
- **通知**: 予約が入ったら管理者にメール、お客さんに確認メール → 外部のメール送信サービス（Resend など）が必要になる。最初は「管理画面で確認する」で始めることを勧める
- **個人情報の保存期間**: 来店日から○日後に消す など

## データの持ち方（例: 管理者が枠を登録し、枠ごとに定員がある）

```sql
-- migrations/0001_create_reservations.sql
CREATE TABLE slots (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  starts_at  TEXT    NOT NULL UNIQUE,   -- UTC の ISO 8601
  capacity   INTEGER NOT NULL CHECK (capacity > 0),
  is_open    INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE reservations (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  slot_id      INTEGER NOT NULL REFERENCES slots (id),
  seat_no      INTEGER NOT NULL,        -- 1〜capacity。定員を超えないための番号
  name         TEXT    NOT NULL,
  email        TEXT    NOT NULL,
  party_size   INTEGER NOT NULL DEFAULT 1,
  note         TEXT,
  cancel_token TEXT    NOT NULL UNIQUE, -- お客さんが取り消すとき用（crypto.randomUUID()）
  created_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  UNIQUE (slot_id, seat_no)             -- 同じ枠の同じ番号は 1 つだけ ＝ 定員超えを DB が防ぐ
);
CREATE INDEX idx_reservations_slot_id ON reservations (slot_id);
```

### 定員を超えさせない方法

「件数を数えて、空いていたら INSERT」を 2 つの SQL で書くと、同時に 2 人が予約したときに定員を超える。**1 つの INSERT の中で空き番号を決め、`UNIQUE (slot_id, seat_no)` で守る。**

```ts
const result = await env.DB.prepare(
  `INSERT INTO reservations (slot_id, seat_no, name, email, party_size, note, cancel_token)
   SELECT s.id,
          (SELECT COALESCE(MAX(r.seat_no), 0) + 1 FROM reservations r WHERE r.slot_id = s.id),
          ?2, ?3, ?4, ?5, ?6
   FROM slots s
   WHERE s.id = ?1 AND s.is_open = 1
     AND (SELECT COUNT(*) FROM reservations r WHERE r.slot_id = s.id) < s.capacity`
)
  .bind(slotId, name, email, partySize, note, crypto.randomUUID())
  .run()
  .catch((e) => (String(e).includes("UNIQUE") ? null : Promise.reject(e)));

if (!result || result.meta.changes === 0) {
  return Response.json({ error: "この枠は満席になりました。別の枠をお選びください。" }, { status: 409 });
}
```

- 取り消しで番号に空きができても、`MAX + 1` は次の番号を使うので、定員の判定は `COUNT(*) < capacity` で行う（上の SQL の通り）
- 「1 枠 1 組」なら `capacity = 1` にすればよい
- 人数（`party_size`）の合計で定員を見る場合は、`COUNT(*)` を `SUM(party_size)` に変え、同時予約の確認を必ず行う

## API（例）

| メソッド | パス | 誰が | 内容 |
|---|---|---|---|
| GET | `/api/slots?from=2026-11-01&to=2026-11-30` | 誰でも | 枠と**残り数だけ**を返す（予約者の情報は返さない） |
| POST | `/api/reservations` | 誰でも | 予約。Turnstile を確認する。成功したら取り消し用の URL を返す |
| POST | `/api/reservations/cancel` | 誰でも | `cancel_token` で取り消し |
| GET | `/api/admin/reservations?from=...&to=...` | 管理者 | 予約一覧（個人情報を含む） |
| POST | `/api/admin/slots` | 管理者 | 枠の作成 |
| PUT | `/api/admin/slots/<id>` | 管理者 | 受付停止・定員変更 |
| DELETE | `/api/admin/reservations/<id>` | 管理者 | 予約の取り消し |

入力の確認例: 名前 1〜50 文字、メールは `@` を含む 254 文字以内、人数 1〜上限、メモ 500 文字以内、枠が締め切り前であること（サーバの現在時刻で判定）。

## 画面

- **公開ページ**: 日付を選ぶ → 空いている枠を表示 → フォーム入力 → 確認 → 完了（取り消し用 URL を表示）。満席（409）のときは枠を選び直せるようにする
- **管理画面**: 日別の予約一覧、枠の追加・受付停止、予約の取り消し。CSV で書き出せると喜ばれることが多い（個人情報なので、扱いに注意するよう伝える）

## つまずきやすい点

- 日時は UTC で保存し、表示と入力は日本時間で行う。「11 月 1 日の枠」を探すときは、日本時間の 0:00〜24:00 を UTC に直して検索する
- 取り消し用 URL は推測できない値（`crypto.randomUUID()`）にする。連番の ID を使わない
- 古い予約の個人情報を消す処理は、Cron トリガー（`wrangler.jsonc` の `triggers.crons` と `scheduled` ハンドラ）で毎日動かせる。作った場合はユーザーに伝える
