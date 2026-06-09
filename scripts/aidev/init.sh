#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
TEMPLATE_ROOT="$REPO_DIR/templates"
CODEX_TEMPLATE_ROOT="$REPO_DIR/codex/skills-templates"

DRY_RUN=0
FORCE=0
TARGET="${1:-all}"

# 第1引数がターゲット名またはプリセット名なら消費し、オプションフラグなら TARGET を all のまま残す
# （例: `aidev init --force` → TARGET=all, `aidev init claude --force` → TARGET=claude）
case "$TARGET" in
  --dry-run|--force|--help|-h) TARGET="all" ;;         # オプションのみ → TARGET=all で残す
  all|claude|codex|copilot|agents|antigravity|--personal|--work) shift || true ;;  # ターゲット/プリセット → 消費
  *)
    echo "不明なターゲット: $TARGET"
    echo "使い方: aidev init [claude|codex|copilot|agents|antigravity|--personal|--work] [--force] [--dry-run]"
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
  claude        CLAUDE.md をプロジェクトルートに配置
  codex         SKILL.md をプロジェクトルートに配置
  copilot       .github/copilot-instructions.md を配置
  agents        AGENT_HANDOFF_LOG.md を配置 + .gitignore に追記
  antigravity   .antigravity.md をプロジェクトルートに配置

プリセット:
  --personal  個人開発用（Codex CLI + Claude Code + Antigravity）: codex + claude + antigravity + agents
  --work      会社用（Copilot + Claude Code）: copilot + claude + agents

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
  gitignore_add "CLAUDE.local.md"
}

init_antigravity() {
  place_file "$TEMPLATE_ROOT/antigravity.md" "$DEST_DIR/.antigravity.md"
  gitignore_add ".antigravity.md"
}

init_codex() {
  place_file "$CODEX_TEMPLATE_ROOT/project/SKILL.md" "$DEST_DIR/SKILL.md"
  gitignore_add "SKILL.md"
}

init_copilot() {
  place_file "$TEMPLATE_ROOT/copilot-instructions.md" "$DEST_DIR/.github/copilot-instructions.md"
  gitignore_add ".github/copilot-instructions.md"
}

init_agents() {
  place_file "$TEMPLATE_ROOT/AGENT_HANDOFF_LOG.md" "$DEST_DIR/AGENT_HANDOFF_LOG.md"
  gitignore_add "AGENT_HANDOFF_LOG.md"
}

case "$TARGET" in
  all)
    init_claude
    init_codex
    init_copilot
    init_antigravity
    init_agents
    ;;
  claude)       init_claude ;;
  codex)        init_codex ;;
  copilot)      init_copilot ;;
  agents)       init_agents ;;
  antigravity)  init_antigravity ;;
  --personal)
    echo "プリセット: personal（Codex CLI + Claude Code + Antigravity）"
    init_codex
    init_claude
    init_antigravity
    init_agents
    ;;
  --work)
    echo "プリセット: work（Copilot + Claude Code）"
    init_copilot
    init_claude
    init_agents
    ;;
esac

echo ""
echo "完了: $DEST_DIR"
