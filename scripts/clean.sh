#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"

usage() {
  cat <<'USAGE'
使い方: dev clean [options]

dev init が配置した AI 設定ファイルと .gitignore のエントリを削除します。
旧構成の残骸（CLAUDE.local.md, SKILL.md, CODEX.md, GEMINI.md,
.github/copilot-instructions.md）も対象です。

オプション:
  --dry-run   実行せずに内容だけ表示
  -h, --help  このヘルプを表示
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "不明なオプション: $arg"; usage; exit 1 ;;
  esac
done

DEST_DIR="$(pwd)"
GITIGNORE="$DEST_DIR/.gitignore"

remove_file() {
  local path="$1"
  if [ -e "$path" ] || [ -L "$path" ]; then
    run rm -f "$path"
    echo "削除: $path"
  fi
}

gitignore_remove() {
  local entry="$1"
  [ -f "$GITIGNORE" ] || return 0
  grep -qxF "$entry" "$GITIGNORE" || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] .gitignore から除去: %s\n' "$entry"
    return 0
  fi
  grep -vxF "$entry" "$GITIGNORE" >"$GITIGNORE.tmp" && mv "$GITIGNORE.tmp" "$GITIGNORE"
  echo ".gitignore から除去: $entry"
}

# 管理エントリがすべて消えたらヘッダーも除去し、空になればファイルごと削除
finalize_gitignore() {
  [ "$DRY_RUN" -eq 1 ] && return 0
  [ -f "$GITIGNORE" ] || return 0
  local entry
  for entry in "${PROJECT_FILES_CORE[@]}" "${PROJECT_FILES_LEGACY[@]}"; do
    grep -qxF "$entry" "$GITIGNORE" && return 0
  done
  grep -vxF "$GITIGNORE_HEADER" "$GITIGNORE" | grep -vxF "$GITIGNORE_HEADER_LEGACY" \
    >"$GITIGNORE.tmp" && mv "$GITIGNORE.tmp" "$GITIGNORE"
  if ! grep -q '[^[:space:]]' "$GITIGNORE"; then
    rm -f "$GITIGNORE"
    echo ".gitignore を削除（空になったため）"
  fi
}

for entry in "${PROJECT_FILES_CORE[@]}" "${PROJECT_FILES_LEGACY[@]}"; do
  remove_file "$DEST_DIR/$entry"
  gitignore_remove "$entry"
done
finalize_gitignore

echo ""
echo "完了: $DEST_DIR"
