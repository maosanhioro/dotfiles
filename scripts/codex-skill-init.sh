#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_ROOT="$REPO_DIR/codex/skills-templates"

DRY_RUN=0
FORCE=0
TEMPLATE_NAME=""
DEST_DIR=""
OUTPUT_NAME="SKILL.md"

usage() {
  cat <<'USAGE'
使い方: ./scripts/codex-skill-init.sh [options]

オプション:
  --template <project|subproject>  使うテンプレート
  --project                         project テンプレートを使う
  --subproject                      subproject テンプレートを使う
  --dest <dir>                      配置先ディレクトリ（必須）
  --output <file>                   出力ファイル名（既定: SKILL.md）
  --force                           既存ファイルがあっても上書き
  --dry-run                         実行せずに内容だけ表示
  -h, --help                        このヘルプを表示

例:
  ./scripts/codex-skill-init.sh --project --dest /path/to/repo
  ./scripts/codex-skill-init.sh --subproject --dest ./apps/foo --output SKILL.md
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --project) TEMPLATE_NAME="project"; shift ;;
    --subproject) TEMPLATE_NAME="subproject"; shift ;;
    --template)
      TEMPLATE_NAME="${2:-}"; shift 2 ;;
    --dest)
      DEST_DIR="${2:-}"; shift 2 ;;
    --output)
      OUTPUT_NAME="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "不明なオプション: $1"; usage; exit 1 ;;
  esac
done

if [ -z "$TEMPLATE_NAME" ]; then
  echo "テンプレートを指定してください: --project / --subproject / --template"
  usage
  exit 1
fi

if [ -z "$DEST_DIR" ]; then
  echo "配置先ディレクトリを指定してください: --dest"
  usage
  exit 1
fi

case "$TEMPLATE_NAME" in
  project|subproject)
    TEMPLATE_PATH="$TEMPLATE_ROOT/$TEMPLATE_NAME/SKILL.md"
    ;;
  *)
    echo "テンプレート指定が不正です: $TEMPLATE_NAME"
    usage
    exit 1
    ;;
esac

if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "テンプレートが見つかりません: $TEMPLATE_PATH"
  exit 1
fi

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

run mkdir -p "$DEST_DIR"

TARGET_PATH="$DEST_DIR/$OUTPUT_NAME"
if [ -e "$TARGET_PATH" ] && [ "$FORCE" -ne 1 ]; then
  echo "既存ファイルがあります: $TARGET_PATH"
  echo "上書きする場合は --force を指定してください"
  exit 1
fi

run cp -f "$TEMPLATE_PATH" "$TARGET_PATH"

echo "配置しました: $TARGET_PATH"
