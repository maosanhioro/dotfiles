#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
AGENT_TEMPLATE_ROOT="$REPO_DIR/copilot/agents-templates"
SKILL_TEMPLATE_ROOT="$REPO_DIR/copilot/skills-templates"

DRY_RUN=0
FORCE=0
DEST_DIR=""
AGENTS_ONLY=0
SKILLS_ONLY=0

usage() {
  cat <<'USAGE'
使い方: ./scripts/copilot-team-init.sh [options]

オプション:
  --dest <dir>     配置先リポジトリ（必須）
  --agents-only    .github/agents のみ配置
  --skills-only    .github/skills のみ配置
  --force          既存ファイルがあっても上書き
  --dry-run        実行せずに内容だけ表示
  -h, --help       このヘルプを表示

例:
  ./scripts/copilot-team-init.sh --dest /path/to/repo
  ./scripts/copilot-team-init.sh --dest . --agents-only
  ./scripts/copilot-team-init.sh --dest ../my-app --skills-only --force
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dest)
      DEST_DIR="${2:-}"
      shift 2
      ;;
    --agents-only)
      AGENTS_ONLY=1
      shift
      ;;
    --skills-only)
      SKILLS_ONLY=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "不明なオプション: $1"
      usage
      exit 1
      ;;
  esac
done

if [ -z "$DEST_DIR" ]; then
  echo "配置先ディレクトリを指定してください: --dest"
  usage
  exit 1
fi

if [ "$AGENTS_ONLY" -eq 1 ] && [ "$SKILLS_ONLY" -eq 1 ]; then
  echo "--agents-only と --skills-only は同時に指定できません"
  exit 1
fi

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

copy_file() {
  local src="$1"
  local dst="$2"

  if [ -e "$dst" ] && [ "$FORCE" -ne 1 ]; then
    echo "既存ファイルがあります: $dst"
    echo "上書きする場合は --force を指定してください"
    exit 1
  fi

  run mkdir -p "$(dirname "$dst")"
  run cp -f "$src" "$dst"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "配置予定: $dst"
  else
    echo "配置しました: $dst"
  fi
}

copy_agents() {
  local target_root="$DEST_DIR/.github/agents"
  local src

  for src in "$AGENT_TEMPLATE_ROOT"/*.md; do
    [ -f "$src" ] || continue
    copy_file "$src" "$target_root/$(basename "$src")"
  done
}

copy_skills() {
  local target_root="$DEST_DIR/.github/skills"
  local src_dir

  for src_dir in "$SKILL_TEMPLATE_ROOT"/*; do
    [ -d "$src_dir" ] || continue
    copy_file "$src_dir/SKILL.md" "$target_root/$(basename "$src_dir")/SKILL.md"
  done
}

if [ "$SKILLS_ONLY" -ne 1 ]; then
  copy_agents
fi

if [ "$AGENTS_ONLY" -ne 1 ]; then
  copy_skills
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Copilot team agent テンプレートの配置予定を表示しました: $DEST_DIR/.github"
else
  echo "Copilot team agent テンプレートを配置しました: $DEST_DIR/.github"
fi