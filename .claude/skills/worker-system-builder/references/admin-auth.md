# 管理画面の認証

## 目次

- 共通: 入口で 1 回だけ確認する（素の書き方 / Hono のミドルウェア）
- 方式 A: Cloudflare Access（おすすめ）— Cloudflare 側の設定、`wrangler.jsonc`、コード、`ctx.access` を使わない理由、確認
- 方式 B: パスワード（セッション）— しくみ、ユーザーにやってもらうこと、D1 とログイン回数制限の設定、コード、管理画面側の書き方、確認

`/admin`（管理画面）と `/api/admin/...`（管理者用 API）を守る方法。どちらの方式でも、**入口で 1 回だけ**確認する。

```ts
// src/index.ts の fetch の先頭付近
const isAdminPath =
  url.pathname === "/admin" || url.pathname.startsWith("/admin/") ||
  url.pathname === "/api/admin" || url.pathname.startsWith("/api/admin/");
if (isAdminPath) {
  const denied = await requireAdmin(request, env); // 方式 A か B のどちらか
  if (denied) return denied;
}
```

**Hono を使う場合**は、上の書き方ではなく Hono のミドルウェアで守る。Hono はルートを探す前にパスの `%xx` を戻す（`/api/%61dmin` を `/api/admin` として扱う）ため、生の `url.pathname` で判定するとすり抜けることがある。ルートと同じ仕組みで判定させる。

```ts
import type { MiddlewareHandler } from "hono";

const admin: MiddlewareHandler<{ Bindings: Env }> = async (c, next) => {
  const denied = await requireAdmin(c.req.raw, c.env);
  if (denied) return denied;
  await next();
};
app.use("/admin", admin);
app.use("/admin/*", admin);
app.use("/api/admin", admin);
app.use("/api/admin/*", admin);
```

どちらにするかは、ユーザーに次のように聞く（おすすめは A）:

> 管理画面のログイン方法を選んでください。おすすめは A です。
> A. Cloudflare Access — 登録したメールアドレスに届くコードでログイン。パスワード管理が不要（Cloudflare の画面で数分の設定が必要）
> B. パスワード — ログイン画面で 1 つの管理用パスワードを入力。設定は簡単だが、パスワードを安全に保管する必要がある（ログイン状態の保存に D1 を使う）

---

## 方式 A: Cloudflare Access（おすすめ）

### ユーザーに Cloudflare 側でやってもらうこと

1. Cloudflare ダッシュボードで **Zero Trust** を開く（初回はチーム名とプランの選択が必要。少人数なら Free プランを選べばよいが、支払い方法の登録を求められることがある）
2. **Access > Applications** で、新しいアプリケーションを **Self-hosted** で作る（画面の名前は変わることがある。「Self-hosted and private」など）
3. 守る場所（Application domain）を 2 つ登録する
   - `<公開名>.<アカウント名>.workers.dev` ＋ パス `admin`
   - `<公開名>.<アカウント名>.workers.dev` ＋ パス `api/admin`
   - 独自ドメインを使っているなら、そのドメインでも同じように登録する
4. ポリシーで、ログインを許可するメールアドレス（管理者）を指定する
5. 作ったアプリケーションの **Application Audience (AUD) Tag** と、**チームドメイン**（`https://<チーム名>.cloudflareaccess.com`）を控え、Claude に伝える

Worker 全体を守る「Enable Cloudflare Access」（Worker の設定画面のボタン）は使わない。公開ページまでログイン必須になってしまう。

### `wrangler.jsonc`

AUD とチームドメインは秘密ではないので `vars` に書く。

```jsonc
"vars": {
  "ACCESS_TEAM_DOMAIN": "https://<チーム名>.cloudflareaccess.com",
  "ACCESS_AUD": "<AUD タグ>"
}
```

### コード

`npm install jose` で JWT 検証のライブラリを入れる。

```ts
// src/auth.ts
import { createRemoteJWKSet, jwtVerify } from "jose";

let jwks: ReturnType<typeof createRemoteJWKSet> | undefined;

// 認証できたら null、できなければ断るための Response を返す
export async function requireAdmin(request: Request, env: Env): Promise<Response | null> {
  const url = new URL(request.url);

  // ローカル（wrangler dev）では Access を通らないので、確認を省く
  // 本番の workers.dev や独自ドメインに localhost というホスト名で届くことはない
  if (url.hostname === "localhost" || url.hostname === "127.0.0.1") return null;

  const token = request.headers.get("cf-access-jwt-assertion");
  if (!token || !env.ACCESS_TEAM_DOMAIN || !env.ACCESS_AUD) {
    return new Response("Forbidden", { status: 403 });
  }

  jwks ??= createRemoteJWKSet(new URL(`${env.ACCESS_TEAM_DOMAIN}/cdn-cgi/access/certs`));
  try {
    await jwtVerify(token, jwks, { issuer: env.ACCESS_TEAM_DOMAIN, audience: env.ACCESS_AUD });
    return null;
  } catch {
    return new Response("Forbidden", { status: 403 });
  }
}
```

ログイン中の人のメールアドレスが必要なら、`jwtVerify` の戻り値の `payload.email` を使う。

### なぜ `ctx.access` を使わないのか

Cloudflare のドキュメントには `ctx.access.getIdentity()` を使う簡単な方法が載っているが、**静的ファイル（`assets`）を持つ Worker には `ctx.access` が渡されない**。このテンプレートは `public/` を配信しているので該当する。JWT を自分で検証する。

### 確認

- ローカル: `/admin` が開けること（localhost では確認を省くため）
- ローカルで「拒否される」ことも確かめたいときは、一時的に localhost の行をコメントアウトし、`curl http://localhost:8787/api/admin/...` が 403 になるのを見てから戻す
- 本番: ログインしていないブラウザ（シークレットウィンドウ）で `/admin` を開くと、Cloudflare のログイン画面が出ること。`curl https://<公開名>.<アカウント名>.workers.dev/api/admin/...` がログイン画面へのリダイレクト（302）か 403 になること

---

## 方式 B: パスワード（セッション）

### しくみ

1. `/admin/login` のログイン画面でパスワードを入力する
2. 合っていれば、Worker がランダムな鍵（トークン）を作り、ハッシュにして D1 の `admin_sessions` に有効期限つきで保存する。鍵そのものは Cookie でブラウザに渡す
3. 以後のリクエストは、Cookie の鍵のハッシュが D1 にあり、期限内かどうかで確認する
4. ログアウトすると D1 の行を消すので、その鍵はすぐ使えなくなる

D1 に保存するのは、ログアウトや強制ログアウトをすぐ効かせるため。KV は反映に時間がかかることがあるので、セッションには使わない。D1 にはハッシュだけを入れるので、D1 の中身が漏れても、それでログインはできない。

Cookie は `HttpOnly`（JavaScript から読めない）、`Secure`（HTTPS のみ。ローカルの http では付けない）、`SameSite=Strict`（他サイトからのリクエストには付かない）にする。`/admin` と `/api/admin` の両方で使うので `Path=/` にする。`SameSite=Strict` のため、メールなど他サイトのリンクから `/admin` を開くと、ログイン中でもログイン画面が出る。

### ユーザーにやってもらうこと

1. **必ず**長いランダムなパスワードを作る（例: `openssl rand -base64 24`）。自分で考えた短いパスワードは使わない（下の回数制限だけでは守れない）。パスワードマネージャーに保存する
2. 本番に登録: `npx wrangler secret put ADMIN_PASSWORD`（または ダッシュボードの「設定 > 変数とシークレット」）
3. ローカル: `.dev.vars` に `ADMIN_PASSWORD=...` を書く（`.dev.vars.example` には `ADMIN_PASSWORD=` と空で書いておく）

パスワードはチャットに貼ってもらわない。

パスワードが漏れたかもしれないときは、新しいパスワードを登録してから、全員をログアウトさせる（パスワードを変えるだけでは、ログイン済みのセッションは消えない）。

```bash
npx wrangler d1 execute DB --remote --command "DELETE FROM admin_sessions"
```

### D1 とログイン回数制限の設定

D1 が無ければ、SKILL.md の「D1 の使い方」に沿って作る。`npx wrangler d1 migrations create DB create_admin_sessions` でファイルを作り、次の SQL を書く。

```sql
CREATE TABLE admin_sessions (
  token_hash TEXT PRIMARY KEY,
  expires_at TEXT NOT NULL
);
```

大量のログイン試行を抑えるため、`wrangler.jsonc` に回数制限を足す（同じ IP アドレスごとに、1 分に 5 回を目安にする）。`namespace_id` は、同じ Cloudflare アカウントの中で Worker ごとに違う数字にする。この制限は概算で、データセンターごとに数えるので、本番では設定した回数を大きく超えてから効くことがある（テストでは、連続した試行が 30 回を超えたあたりで初めて 429 が出て、その後も一部の試行が通った）。守りの中心は長いパスワードで、回数制限はその補助と考える。厳密な制限が要るなら Durable Objects が必要になる。

```jsonc
"ratelimits": [
  { "name": "LOGIN_LIMIT", "namespace_id": "1001", "simple": { "limit": 5, "period": 60 } }
]
```

`npm run db:migrate:local` のあと、`npm run types` を実行する。`ADMIN_PASSWORD` は `wrangler.jsonc` に書かないので、`.dev.vars` に書いてから `npm run types` を実行すると型に入る。

### コード

```ts
// src/auth.ts
const COOKIE_NAME = "admin_session";
const SESSION_SECONDS = 7 * 24 * 60 * 60; // ログインの有効期間（7 日）

// 認証できたら null、できなければ断るための Response を返す
export async function requireAdmin(request: Request, env: Env): Promise<Response | null> {
  const url = new URL(request.url);

  // ログイン画面とログイン API だけは、ログインなしで通す
  // 完全一致で比べる（%xx を含む別の書き方は、ここを通らず確認に進むので安全側に倒れる）
  if (
    (url.pathname === "/admin/login" && request.method === "GET") ||
    (url.pathname === "/api/admin/login" && request.method === "POST")
  ) {
    return null;
  }

  // 書き込みは、自分のサイトから送られたものだけを受け付ける（CSRF 対策）
  if (request.method !== "GET" && request.method !== "HEAD" && !isSameOrigin(request)) {
    return Response.json({ error: "このサイト以外からの操作はできません" }, { status: 403 });
  }

  if (await hasValidSession(request, env)) return null;

  if (url.pathname === "/api/admin" || url.pathname.startsWith("/api/admin/")) {
    return Response.json({ error: "ログインが必要です" }, { status: 401 });
  }
  return new Response(null, {
    status: 302,
    headers: { Location: "/admin/login", "Cache-Control": "no-store" },
  });
}

// GET /admin/login
export function loginPage(): Response {
  return new Response(LOGIN_HTML, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "Content-Security-Policy": "frame-ancestors 'none'",
    },
  });
}

// POST /api/admin/login
export async function login(request: Request, env: Env): Promise<Response> {
  if (!isSameOrigin(request)) {
    return Response.json({ error: "このサイト以外からの操作はできません" }, { status: 403 });
  }
  if (!(request.headers.get("Content-Type") ?? "").startsWith("application/json")) {
    return Response.json({ error: "送信形式が正しくありません" }, { status: 415 });
  }

  const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const { success } = await env.LOGIN_LIMIT.limit({ key: ip });
  if (!success) {
    return Response.json({ error: "しばらく待ってから、もう一度お試しください" }, { status: 429 });
  }

  const body = (await request.json().catch(() => null)) as { password?: unknown } | null;
  const password = body?.password;
  if (
    typeof password !== "string" ||
    !env.ADMIN_PASSWORD ||
    !(await safeEqual(password, env.ADMIN_PASSWORD))
  ) {
    return Response.json({ error: "パスワードが違います" }, { status: 401 });
  }

  // ログインのたびに新しい鍵を作る。期限切れの行はここで片付ける
  const now = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_SECONDS * 1000).toISOString();
  const token = [...crypto.getRandomValues(new Uint8Array(32))]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  await env.DB.batch([
    env.DB.prepare("DELETE FROM admin_sessions WHERE expires_at <= ?").bind(now.toISOString()),
    env.DB.prepare("INSERT INTO admin_sessions (token_hash, expires_at) VALUES (?, ?)").bind(
      await sha256Hex(token),
      expiresAt,
    ),
  ]);

  return Response.json(
    { ok: true },
    {
      headers: {
        "Set-Cookie": sessionCookie(request, token, SESSION_SECONDS),
        "Cache-Control": "no-store",
      },
    },
  );
}

// POST /api/admin/logout（requireAdmin を通ったあとに呼ぶ）
export async function logout(request: Request, env: Env): Promise<Response> {
  const token = readSessionToken(request);
  if (token) {
    await env.DB.prepare("DELETE FROM admin_sessions WHERE token_hash = ?")
      .bind(await sha256Hex(token))
      .run();
  }
  return Response.json(
    { ok: true },
    { headers: { "Set-Cookie": sessionCookie(request, "", 0), "Cache-Control": "no-store" } },
  );
}

async function hasValidSession(request: Request, env: Env): Promise<boolean> {
  const token = readSessionToken(request);
  if (!token) return false;
  const row = await env.DB.prepare(
    "SELECT 1 FROM admin_sessions WHERE token_hash = ? AND expires_at > ?",
  )
    .bind(await sha256Hex(token), new Date().toISOString())
    .first();
  return row !== null;
}

function readSessionToken(request: Request): string | null {
  for (const part of (request.headers.get("Cookie") ?? "").split(";")) {
    const [name, value] = part.trim().split("=");
    if (name === COOKIE_NAME && value) return value;
  }
  return null;
}

function sessionCookie(request: Request, value: string, maxAge: number): string {
  const secure = new URL(request.url).protocol === "https:" ? "; Secure" : "";
  return `${COOKIE_NAME}=${value}; Path=/; Max-Age=${maxAge}; HttpOnly; SameSite=Strict${secure}`;
}

function isSameOrigin(request: Request): boolean {
  return request.headers.get("Origin") === new URL(request.url).origin;
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// 比較にかかる時間からパスワードを推測されないよう、ハッシュ同士を一定時間で比べる
async function safeEqual(a: string, b: string): Promise<boolean> {
  const enc = new TextEncoder();
  const [ha, hb] = await Promise.all([
    crypto.subtle.digest("SHA-256", enc.encode(a)),
    crypto.subtle.digest("SHA-256", enc.encode(b)),
  ]);
  return crypto.subtle.timingSafeEqual(ha, hb);
}

const LOGIN_HTML = `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>管理画面ログイン</title>
<style>
  body { font-family: system-ui, sans-serif; max-width: 22rem; margin: 15vh auto; padding: 0 1rem; }
  input, button { width: 100%; box-sizing: border-box; padding: .75rem; font-size: 1rem; margin-top: .5rem; }
  #error { color: #b91c1c; min-height: 1.5rem; }
</style>
</head>
<body>
<h1>管理画面ログイン</h1>
<form id="form">
  <label for="password">パスワード</label>
  <input id="password" type="password" autocomplete="current-password" required autofocus>
  <button type="submit">ログイン</button>
</form>
<p id="error" role="alert"></p>
<script>
  const error = document.getElementById("error");
  document.getElementById("form").addEventListener("submit", async (event) => {
    event.preventDefault();
    error.textContent = "";
    try {
      const res = await fetch("/api/admin/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ password: document.getElementById("password").value }),
      });
      if (res.ok) {
        location.href = "/admin";
        return;
      }
      error.textContent = (await res.json()).error;
    } catch {
      error.textContent = "通信に失敗しました。もう一度お試しください";
    }
  });
</script>
</body>
</html>`;
```

`src/index.ts` では、入口の確認（このファイルの先頭）のあとにルートを足す。`/admin` の 404 より前に書く。

```ts
import { login, loginPage, logout, requireAdmin } from "./auth";

// 入口の確認（isAdminPath と requireAdmin）のあとで
if (url.pathname === "/admin/login" && request.method === "GET") return loginPage();
if (url.pathname === "/api/admin/login" && request.method === "POST") return login(request, env);
if (url.pathname === "/api/admin/logout" && request.method === "POST") return logout(request, env);
```

Hono を使う場合は、先頭のミドルウェアをそのまま使い、その**あと**に同じ処理をルートとして登録する（Hono は登録した順に動くので、ルートを先に書くと確認を通らない）。

```ts
app.get("/admin/login", () => loginPage());
app.post("/api/admin/login", (c) => login(c.req.raw, c.env));
app.post("/api/admin/logout", (c) => logout(c.req.raw, c.env));
```

### 管理画面側の書き方

- 管理画面（`/admin`）と管理者用 API の応答には `Cache-Control: no-store` を付ける（個人情報がブラウザなどに残らないようにする）
- 管理画面の `fetch` では、401 が返ったらログイン画面へ移す。ログアウトボタンは `POST` で呼ぶ

```js
const res = await fetch("/api/admin/announcements");
if (res.status === 401) location.href = "/admin/login";

// ログアウト
await fetch("/api/admin/logout", { method: "POST" });
location.href = "/admin/login";
```

### 確認

パスワードをコマンドに直接書かないよう、`.dev.vars` から読み込んで順に実行する。Cookie はリポジトリの外（一時ファイル）に保存し、終わったら消す。

```bash
B=http://localhost:8787
PW=$(sed -n 's/^ADMIN_PASSWORD=//p' .dev.vars)
JAR=$(mktemp)

# ログインなし: API は 401、管理画面は /admin/login への 302、ログイン画面は 200
curl -i "$B/api/admin/..."
curl -i "$B/admin"
curl -i "$B/admin/login"

# 間違ったパスワード: 401 で、Set-Cookie が付かない
curl -i -X POST "$B/api/admin/login" -H "Origin: $B" -H "Content-Type: application/json" -d '{"password":"wrong"}'

# 他のサイトから: 403
curl -i -X POST "$B/api/admin/login" -H "Origin: https://example.com" -H "Content-Type: application/json" -d "{\"password\":\"$PW\"}"

# 正しいパスワード: 200 で Set-Cookie が付き、そのあと API が通る
curl -si -c "$JAR" -X POST "$B/api/admin/login" -H "Origin: $B" -H "Content-Type: application/json" -d "{\"password\":\"$PW\"}" | grep -E "^HTTP"
curl -i -b "$JAR" "$B/api/admin/..."

# ログアウト: 200 のあと、同じ Cookie の API が 401 になる
curl -i -b "$JAR" -X POST "$B/api/admin/logout" -H "Origin: $B"
curl -i -b "$JAR" "$B/api/admin/..."

rm -f "$JAR"
```

- ローカル（`wrangler dev`）で、間違ったパスワードを 1 分に 6 回送ると、6 回目までに 429 が出ること。本番では 429 が出るまでの回数が大きく増えるので、6 回で出なくても不具合ではない
- ブラウザで `/admin` を開くとログイン画面に移り、ログインすると `/admin` に戻り、ログアウトするとログイン画面に戻ること
