// Worker の入口
// wrangler.jsonc の run_worker_first に一致したリクエスト（/api/*・/admin/*）だけがここに来る
// それ以外のページや画像は public/ から直接配信される

export default {
  async fetch(request, env): Promise<Response> {
    const url = new URL(request.url);

    // 動作確認用。システムを作るときは、ここに API を追加していく
    if (url.pathname === "/api/health") {
      return Response.json({ ok: true });
    }

    if (url.pathname === "/api" || url.pathname.startsWith("/api/")) {
      return Response.json({ error: "Not Found" }, { status: 404 });
    }

    // 管理画面はまだ無い。作るときは、必ず認証を付けてからここで処理する
    // （認証前に public/ のファイルを返さないよう、今は 404 にしておく）
    if (url.pathname === "/admin" || url.pathname.startsWith("/admin/")) {
      return new Response("Not Found", { status: 404 });
    }

    return env.ASSETS.fetch(request);
  },
} satisfies ExportedHandler<Env>;
