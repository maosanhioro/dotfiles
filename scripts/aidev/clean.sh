#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
TARGET="${1:-all}"

case "$TARGET" in
  --dry-run|--force|--help|-h) TARGET="all" ;;
  all|claude|codex|copilot|agents) shift || true ;;
  *)
    echo "不明なターゲット: $TARGET"
    echo "使い方: aidev clean [claude|codex|copilot|agents] [--dry-run]"
    exit 1
    ;;
esac

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h)
      cat <<'USAGE'
使い方: aidev clean [target] [options]

ターゲット（省略時はすべて）:
  claude    CLAUDE.md を削除 + .gitignore から除去
  codex     CODEX.md を削除 + .gitignore から除去
  copilot   .github/copilot-instructions.md を削除
  agents    AGENTS.md を削除 + .gitignore から除去

オプション:
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

remove_file() {
  local path="$1"
  if [ -e "$path" ]; then
    run rm -f "$path"
    echo "削除: $path"
  else
    echo "スキップ（存在しない）: $path"
  fi
}

# .gitignore からエントリを除去
gitignore_remove() {
  local entry="$1"
  local gitignore="$DEST_DIR/.gitignore"

  if [ ! -f "$gitignore" ]; then
    return 0
  fi

  if ! grep -qxF "$entry" "$gitignore"; then
    return 0  # 記載なし
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] .gitignore から除去: %s\n' "$entry"
    return 0
  fi

  # エントリとその直前のコメント行（aidev管理コメント）を除去
  grep -vxF "$entry" "$gitignore" | \
    awk '/^# AI agent files \(managed by aidev\)$/{
      # 次の行がすべて消えた場合、このコメントも消す
      getline next_line
      if (next_line != "") print next_line
      next
    } {print}' > "$gitignore.tmp" && mv "$gitignore.tmp" "$gitignore"

  echo ".gitignore から除去: $entry"
}

clean_claude() {
  remove_file "$DEST_DIR/CLAUDE.md"
  gitignore_remove "CLAUDE.md"
}

clean_codex() {
  remove_file "$DEST_DIR/CODEX.md"
  gitignore_remove "CODEX.md"
}

clean_copilot() {
  remove_file "$DEST_DIR/.github/copilot-instructions.md"
}

clean_agents() {
  remove_file "$DEST_DIR/AGENTS.md"
  gitignore_remove "AGENTS.md"
}

case "$TARGET" in
  all)
    clean_claude
    clean_codex
    clean_copilot
    clean_agents
    ;;
  claude)  clean_claude ;;
  codex)   clean_codex ;;
  copilot) clean_copilot ;;
  agents)  clean_agents ;;
esac

echo ""
echo "完了: $DEST_DIR"
