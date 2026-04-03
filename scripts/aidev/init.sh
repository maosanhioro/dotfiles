#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
TEMPLATE_ROOT="$REPO_DIR/templates"

DRY_RUN=0
FORCE=0
TARGET="${1:-all}"

# 第1引数がオプションフラグの場合は TARGET を all にする
case "$TARGET" in
  --dry-run|--force|--help|-h) TARGET="all" ;;
  all|claude|codex|copilot|agents) shift || true ;;
  *)
    echo "不明なターゲット: $TARGET"
    echo "使い方: aidev init [claude|codex|copilot|agents] [--force] [--dry-run]"
    exit 1
    ;;
esac

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    --help|-h)
      cat <<'USAGE'
使い方: aidev init [target] [options]

ターゲット（省略時はすべて）:
  claude    CLAUDE.md をプロジェクトルートに配置
  codex     CODEX.md をプロジェクトルートに配置
  copilot   .github/copilot-instructions.md を配置
  agents    AGENTS.md を配置 + .gitignore に追記

オプション:
  --force     既存ファイルがあっても上書き
  --dry-run   実行せずに内容だけ表示
  -h, --help  このヘルプを表示
USAGE
      exit 0
      ;;
    *) echo "不明なオプション: $arg"; exit 1 ;;
  esac
done

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

DEST_DIR="$(pwd)"

place_file() {
  local src="$1"
  local dst="$2"

  if [ ! -f "$src" ]; then
    echo "テンプレートが見つかりません: $src"
    exit 1
  fi

  if [ -e "$dst" ] && [ "$FORCE" -ne 1 ]; then
    echo "スキップ（既存）: $dst  ※上書きは --force"
    return 0
  fi

  run mkdir -p "$(dirname "$dst")"
  run cp -f "$src" "$dst"
  echo "配置: $dst"
}

# .gitignore にべき等で追記
gitignore_add() {
  local entry="$1"
  local gitignore="$DEST_DIR/.gitignore"
  local header="# AI agent files (managed by aidev)"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] .gitignore に追記: %s\n' "$entry"
    return 0
  fi

  # エントリが既に存在する場合はスキップ（2>/dev/null でファイル未存在エラーを抑制）
  if grep -qxF "$entry" "$gitignore" 2>/dev/null; then
    return 0
  fi

  # ヘッダーが未記載の場合のみ1回だけ追加
  if ! grep -qxF "$header" "$gitignore" 2>/dev/null; then
    printf '\n%s\n' "$header" >> "$gitignore"
  fi

  printf '%s\n' "$entry" >> "$gitignore"
  echo ".gitignore に追記: $entry"
}

init_claude() {
  place_file "$TEMPLATE_ROOT/CLAUDE.md" "$DEST_DIR/CLAUDE.md"
  gitignore_add "CLAUDE.md"
}

init_codex() {
  place_file "$TEMPLATE_ROOT/CODEX.md" "$DEST_DIR/CODEX.md"
  gitignore_add "CODEX.md"
}

init_copilot() {
  place_file "$TEMPLATE_ROOT/copilot-instructions.md" "$DEST_DIR/.github/copilot-instructions.md"
  gitignore_add ".github/copilot-instructions.md"
}

init_agents() {
  place_file "$TEMPLATE_ROOT/AGENTS.md" "$DEST_DIR/AGENTS.md"
  gitignore_add "AGENTS.md"
}

case "$TARGET" in
  all)
    init_claude
    init_codex
    init_copilot
    init_agents
    ;;
  claude)  init_claude ;;
  codex)   init_codex ;;
  copilot) init_copilot ;;
  agents)  init_agents ;;
esac

echo ""
echo "完了: $DEST_DIR"
