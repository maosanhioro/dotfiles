#!/usr/bin/env bash
# PostToolUse（Edit|Write）: Claude が編集したファイルを scripts/lint.sh で検査する。
# 編集の直後に気づけるようにするのが目的（コミット時の検査は .githooks/pre-commit が受け持つ）。
# exit 2 で stderr の内容が Claude に返る（編集は取り消されない）。
set -euo pipefail

file="$(jq -r '.tool_input.file_path // empty')"
[ -n "$file" ] && [ -f "$file" ] || exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$file" in
  "$project_dir"/*) ;;
  *) exit 0 ;;
esac

"$project_dir/scripts/lint.sh" "$file" || exit 2
