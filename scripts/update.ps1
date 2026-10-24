# claude1page-sys アップデートスクリプト (Windows PowerShell)
# Usage: irm https://raw.githubusercontent.com/toiee-kameda/claude1page-sys/main/scripts/update.ps1 | iex
$ErrorActionPreference = "Stop"

$BASE_URL = "https://raw.githubusercontent.com/toiee-kameda/claude1page-sys/main"

Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "  claude1page-sys アップデート" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# カレントディレクトリに CLAUDE.md があるか確認
if (-not (Test-Path "CLAUDE.md")) {
    Write-Host "エラー: CLAUDE.md が見つかりません。" -ForegroundColor Red
    Write-Host "claude1page-sys プロジェクトのルートディレクトリで実行してください。"
    exit 1
}

# --- 古いファイルの削除 ---
Write-Host "古いファイルを削除中..." -ForegroundColor Yellow

# package.json は Worker を動かすのに必要なので削除しない（元の claude1page とは違う）
$oldFiles = @(
    "scripts\install_pkgs.sh",
    ".claude\agents\unsplash-image-finder.md",
    ".claude\skills\unsplash-image-finder\unsplash-search.js"
)
$oldDirs = @(
    ".claude\skills\one-page-site-builder\references"
)
foreach ($f in $oldFiles) {
    if (Test-Path $f) { Remove-Item $f -Force }
}
if (Test-Path "dev-tools") { Remove-Item "dev-tools" -Recurse -Force }
foreach ($d in $oldDirs) {
    if (Test-Path $d) { Remove-Item $d -Recurse -Force }
}

Write-Host "  done"

# --- ディレクトリ作成 ---
Write-Host "ディレクトリを準備中..." -ForegroundColor Yellow

$dirs = @(".claude\skills\unsplash-image-finder", ".claude\skills\unsplash-image-finder\references", ".claude\skills\one-page-site-builder", ".claude\skills\worker-system-builder\references", ".claude\hooks", "scripts", "src", ".vscode")
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

Write-Host "  done"

# --- 最新ファイルのダウンロード ---
Write-Host "最新ファイルをダウンロード中..." -ForegroundColor Yellow

function Download-File {
    param([string]$RelPath)
    $url = "$BASE_URL/$($RelPath -replace '\\','/')"
    $dest = $RelPath
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        Write-Host "  ✓ $RelPath" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ $RelPath (ダウンロード失敗)" -ForegroundColor Red
    }
}

$files = @(
    "CLAUDE.md",
    ".claude\settings.json",
    ".claude\launch.json",
    ".rgignore",
    ".env.local.example",
    ".gitignore",
    ".claude\skills\unsplash-image-finder\SKILL.md",
    ".claude\skills\unsplash-image-finder\_load-env.sh",
    ".claude\skills\unsplash-image-finder\unsplash-search.sh",
    ".claude\skills\unsplash-image-finder\unsplash-health-check.sh",
    ".claude\skills\unsplash-image-finder\unsplash-track.sh",
    ".claude\skills\unsplash-image-finder\references\setup.md",
    ".claude\skills\one-page-site-builder\SKILL.md",
    ".claude\skills\one-page-site-builder\brand-icon.sh",
    ".claude\skills\worker-system-builder\SKILL.md",
    ".claude\skills\worker-system-builder\references\admin-auth.md",
    ".claude\skills\worker-system-builder\references\announcements.md",
    ".claude\skills\worker-system-builder\references\reservations.md",
    ".claude\hooks\check-worker-name.sh",
    "scripts\update.sh",
    "scripts\update.ps1",
    "README.md",
    "LICENSE",
    ".vscode\settings.json"
)

foreach ($file in $files) {
    Download-File -RelPath $file
}

# 自分で書き換えるファイルは、まだ無い場合だけ追加する（上書きしない）
#   wrangler.jsonc: 公開名・D1/R2 の設定
#   package.json: 追加したライブラリ
#   src\index.ts: 自分のシステムのコード
foreach ($file in @("wrangler.jsonc", "package.json", "tsconfig.json", "src\index.ts")) {
    if (-not (Test-Path $file)) {
        Download-File -RelPath $file
    }
}

# --- 完了 ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ✅ アップデート完了！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  注意: 以下のファイルは最新版で上書きされます" -ForegroundColor Yellow
Write-Host "    CLAUDE.md"
Write-Host "    README.md"
Write-Host "    .claude\settings.json"
Write-Host "    .claude\launch.json"
Write-Host "    .gitignore"
Write-Host "    .vscode\settings.json"
Write-Host "  これらをカスタマイズしていた場合は、git diff で変更を確認し、"
Write-Host "  必要に応じてご自身の変更を再反映してください。"
Write-Host ""
Write-Host "  wrangler.jsonc・package.json・tsconfig.json・src\ は上書きしていません。"
Write-Host ""
Write-Host "次に実行してください:" -ForegroundColor Yellow
Write-Host "    npm install"
Write-Host "    npm run types"
Write-Host ""
