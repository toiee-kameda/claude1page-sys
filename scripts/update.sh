#!/bin/bash
# claude1page-sys アップデートスクリプト
# Usage: curl -fsSL https://raw.githubusercontent.com/toiee-kameda/claude1page-sys/main/scripts/update.sh | bash
set -e

BASE_URL="https://raw.githubusercontent.com/toiee-kameda/claude1page-sys/main"

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  claude1page-sys アップデート${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# カレントディレクトリに CLAUDE.md があるか確認
if [ ! -f "CLAUDE.md" ]; then
    echo -e "${RED}エラー: CLAUDE.md が見つかりません。${NC}"
    echo "claude1page-sys プロジェクトのルートディレクトリで実行してください。"
    exit 1
fi

# --- 古いファイルの削除 ---
echo -e "${YELLOW}古いファイルを削除中...${NC}"

# 元の claude1page の v1 構成で存在していたファイル
rm -rf scripts/install_pkgs.sh
rm -rf dev-tools/
rm -f .claude/agents/unsplash-image-finder.md
# Node.js 版から Shell 版への移行で不要になったファイル
rm -f .claude/skills/unsplash-image-finder/unsplash-search.js
# one-page-site-builder references を SKILL.md に統合
rm -rf .claude/skills/one-page-site-builder/references
# package.json は Worker を動かすのに必要なので削除しない（元の claude1page とは違う）

echo "  done"

# --- ディレクトリ作成 ---
echo -e "${YELLOW}ディレクトリを準備中...${NC}"
mkdir -p .claude/skills/unsplash-image-finder
mkdir -p .claude/skills/unsplash-image-finder/references
mkdir -p .claude/skills/one-page-site-builder
mkdir -p .claude/skills/worker-system-builder/references
mkdir -p .claude/hooks
mkdir -p scripts
mkdir -p src
mkdir -p .vscode
echo "  done"

# --- 最新ファイルのダウンロード ---
echo -e "${YELLOW}最新ファイルをダウンロード中...${NC}"

download() {
    local dest="$1"
    local url="${BASE_URL}/${dest}"
    if curl -fsSL -o "$dest" "$url"; then
        echo "  ✓ $dest"
    else
        echo -e "  ${RED}✗ $dest (ダウンロード失敗)${NC}"
    fi
}

download "CLAUDE.md"
download ".claude/settings.json"
download ".claude/launch.json"
download ".rgignore"
download ".env.local.example"
download ".gitignore"
download ".claude/skills/unsplash-image-finder/SKILL.md"
download ".claude/skills/unsplash-image-finder/_load-env.sh"
download ".claude/skills/unsplash-image-finder/unsplash-search.sh"
download ".claude/skills/unsplash-image-finder/unsplash-health-check.sh"
download ".claude/skills/unsplash-image-finder/unsplash-track.sh"
download ".claude/skills/unsplash-image-finder/references/setup.md"
download ".claude/skills/one-page-site-builder/SKILL.md"
download ".claude/skills/one-page-site-builder/brand-icon.sh"
download ".claude/skills/worker-system-builder/SKILL.md"
download ".claude/skills/worker-system-builder/references/admin-auth.md"
download ".claude/skills/worker-system-builder/references/announcements.md"
download ".claude/skills/worker-system-builder/references/reservations.md"
download ".claude/hooks/check-worker-name.sh"
download "scripts/update.sh"
download "scripts/update.ps1"
download "README.md"
download "LICENSE"
download ".vscode/settings.json"

# 自分で書き換えるファイルは、まだ無い場合だけ追加する（上書きしない）
#   wrangler.jsonc: 公開名・D1/R2 の設定
#   package.json: 追加したライブラリ
#   src/index.ts: 自分のシステムのコード
for f in wrangler.jsonc package.json tsconfig.json src/index.ts; do
    if [ ! -f "$f" ]; then
        download "$f"
    fi
done

# 実行権限を付与
chmod +x scripts/update.sh 2>/dev/null || true
chmod +x .claude/skills/one-page-site-builder/brand-icon.sh 2>/dev/null || true
chmod +x .claude/hooks/check-worker-name.sh 2>/dev/null || true
chmod +x .claude/skills/unsplash-image-finder/_load-env.sh 2>/dev/null || true
chmod +x .claude/skills/unsplash-image-finder/unsplash-search.sh 2>/dev/null || true
chmod +x .claude/skills/unsplash-image-finder/unsplash-health-check.sh 2>/dev/null || true
chmod +x .claude/skills/unsplash-image-finder/unsplash-track.sh 2>/dev/null || true

# --- 完了 ---
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ アップデート完了！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  注意: 以下のファイルは最新版で上書きされます${NC}"
echo "    CLAUDE.md"
echo "    README.md"
echo "    .claude/settings.json"
echo "    .claude/launch.json"
echo "    .gitignore"
echo "    .vscode/settings.json"
echo "  これらをカスタマイズしていた場合は、git diff で変更を確認し、"
echo "  必要に応じてご自身の変更を再反映してください。"
echo ""
echo "  wrangler.jsonc・package.json・tsconfig.json・src/ は上書きしていません。"
echo ""
echo -e "${YELLOW}次に実行してください:${NC}"
echo "    npm install"
echo "    npm run types"
echo ""
