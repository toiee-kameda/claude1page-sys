#!/bin/bash
# SessionStart フック: wrangler.jsonc の公開名が仮の "rename-me" のままなら Claude に知らせる
# 標準出力はセッション開始時のコンテキストとして Claude に渡される

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
[ -f wrangler.jsonc ] || exit 0

current=$(grep -E '^[[:space:]]*"name"[[:space:]]*:' wrangler.jsonc | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/')
[ "$current" = "rename-me" ] || exit 0

remote=$(git remote get-url origin 2>/dev/null)
# テンプレート本体では知らせない
case "$remote" in
  *toiee-lab/claude1page*) exit 0 ;;
esac

# リポジトリ名から公開名の候補を作る（英小文字・数字・ハイフン、63 文字以内）
repo=$(basename "${remote:-$(pwd)}" .git)
suggested=$(printf '%s' "$repo" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//' | cut -c1-63 | sed -E 's/-+$//')

echo "【公開名が未設定】wrangler.jsonc の name が仮の \"rename-me\" のままです。"
if [ -n "$suggested" ]; then
  echo "リポジトリ名から作った候補: \"$suggested\""
fi
echo "CLAUDE.md の「公開名（Worker 名）」の手順に従って、ユーザーに確認してから書き換えてください。"
exit 0
