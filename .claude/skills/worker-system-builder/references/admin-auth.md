# 管理画面の認証

## 目次

- 共通: 入口で 1 回だけ確認する（素の書き方 / Hono のミドルウェア）
- 方式 A: Cloudflare Access（おすすめ）— Cloudflare 側の設定、`wrangler.jsonc`、コード、`ctx.access` を使わない理由、確認
- 方式 B: パスワード（Basic 認証）— ユーザーにやってもらうこと、コード、確認

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
> B. パスワード — 1 つの管理用パスワードでログイン。設定は簡単だが、パスワードを安全に保管する必要がある

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

## 方式 B: パスワード（Basic 認証）

### ユーザーにやってもらうこと

1. 長いランダムなパスワードを作る（例: `openssl rand -base64 24`）。パスワードマネージャーに保存する
2. 本番に登録: `npx wrangler secret put ADMIN_PASSWORD`（または ダッシュボードの「設定 > 変数とシークレット」）
3. ローカル: `.dev.vars` に `ADMIN_PASSWORD=...` を書く（`.dev.vars.example` には `ADMIN_PASSWORD=` と空で書いておく）

パスワードはチャットに貼ってもらわない。

### コード

```ts
// src/auth.ts
// 認証できたら null、できなければ断るための Response を返す
export async function requireAdmin(request: Request, env: Env): Promise<Response | null> {
  const header = request.headers.get("Authorization") ?? "";
  const [scheme, encoded] = header.split(" ");
  if (scheme === "Basic" && encoded && env.ADMIN_PASSWORD) {
    try {
      const decoded = atob(encoded);
      const password = decoded.slice(decoded.indexOf(":") + 1);
      if (await safeEqual(password, env.ADMIN_PASSWORD)) return null;
    } catch {
      // 壊れたヘッダーは認証失敗として扱う
    }
  }
  return new Response("認証が必要です", {
    status: 401,
    headers: { "WWW-Authenticate": 'Basic realm="admin", charset="UTF-8"' },
  });
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
```

`ADMIN_PASSWORD` は `wrangler.jsonc` に書かないので、`npm run types` では型に入らない。`.dev.vars` に書いてから `npm run types` を実行すると型に入る。

### 確認

- `curl -i http://localhost:8787/api/admin/...` が 401 になること
- `curl -i -u admin:<.dev.vars のパスワード> http://localhost:8787/api/admin/...` が通ること
- 間違ったパスワードで 401 になること
