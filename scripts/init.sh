#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"

TEMPLATE_ROOT="$REPO_DIR/agents/templates"
FORCE=0

usage() {
  cat <<'USAGE'
使い方: dev init [options]

カレントプロジェクトに AI エージェント設定を配置します:
  AGENTS.md              正本 agents/AGENTS.md の全文 + プロジェクト固有骨子を結合して生成
                         （Codex/Copilot 等プロジェクト直下しか読まないエージェントのため）
  CLAUDE.md              AGENTS.md へのシンボリックリンク（Claude Code 用）
  AGENT_HANDOFF_LOG.md   エージェント間の引き継ぎログ

すべて .gitignore に追記されます（個人設定のためコミットしない前提）。

オプション:
  --force     既存ファイルがあっても上書き
  --dry-run   実行せずに内容だけ表示
  -h, --help  このヘルプを表示
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "不明なオプション: $arg"; usage; exit 1 ;;
  esac
done

DEST_DIR="$(pwd)"

place_file() {
  local src="$1" dst="$2"
  if [ ! -f "$src" ]; then
    echo "テンプレートが見つかりません: $src"
    exit 1
  fi
  if [ -e "$dst" ] && [ "$FORCE" -ne 1 ]; then
    echo "スキップ（既存）: $dst  ※上書きは --force"
    return 0
  fi
  run cp -f "$src" "$dst"
  echo "配置: $dst"
}

place_agents_md() {
  local master="$1" template="$2" dst="$3"
  if [ ! -f "$master" ]; then
    echo "正本が見つかりません: $master"
    exit 1
  fi
  if [ ! -f "$template" ]; then
    echo "テンプレートが見つかりません: $template"
    exit 1
  fi
  if [ -e "$dst" ] && [ "$FORCE" -ne 1 ]; then
    echo "スキップ（既存）: $dst  ※上書きは --force"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %s の全文 + %s を結合して書き込み: %s\n' "$master" "$template" "$dst"
    return 0
  fi
  {
    cat "$master"
    printf '\n\n---\n\n'
    cat "$template"
  } >"$dst"
  echo "配置: $dst"
}

place_link() {
  local target="$1" link="$2"
  if [ -e "$link" ] && [ ! -L "$link" ] && [ "$FORCE" -ne 1 ]; then
    echo "スキップ（既存の実ファイル）: $link  ※上書きは --force"
    return 0
  fi
  run ln -sfn "$target" "$link"
  echo "リンク: $link -> $target"
}

# .gitignore にべき等で追記
gitignore_add() {
  local entry="$1"
  local gitignore="$DEST_DIR/.gitignore"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] .gitignore に追記: %s\n' "$entry"
    return 0
  fi
  if grep -qxF "$entry" "$gitignore" 2>/dev/null; then
    return 0
  fi
  if ! grep -qxF "$GITIGNORE_HEADER" "$gitignore" 2>/dev/null; then
    printf '\n%s\n' "$GITIGNORE_HEADER" >>"$gitignore"
  fi
  printf '%s\n' "$entry" >>"$gitignore"
  echo ".gitignore に追記: $entry"
}

place_agents_md "$REPO_DIR/agents/AGENTS.md" "$TEMPLATE_ROOT/AGENTS.md" "$DEST_DIR/AGENTS.md"
gitignore_add "AGENTS.md"

place_link "AGENTS.md" "$DEST_DIR/CLAUDE.md"
gitignore_add "CLAUDE.md"

place_file "$TEMPLATE_ROOT/AGENT_HANDOFF_LOG.md" "$DEST_DIR/AGENT_HANDOFF_LOG.md"
gitignore_add "AGENT_HANDOFF_LOG.md"

echo ""
echo "完了: $DEST_DIR（プロジェクト固有ルールは AGENTS.md を編集してください）"
