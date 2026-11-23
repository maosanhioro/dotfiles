#!/usr/bin/env bash
# PostToolUse（Edit|Write）: Claude が編集したシェルスクリプトの構文と静的解析を確かめる。
# テストも CI もないリポジトリなので、壊れたことに編集の直後に気づけるようにする。
# exit 2 で stderr の内容が Claude に返る（編集は取り消されない）。
set -euo pipefail

file="$(jq -r '.tool_input.file_path // empty')"
[ -n "$file" ] && [ -f "$file" ] || exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$file" in
  "$project_dir"/*) ;;
  *) exit 0 ;;
esac

rel="${file#"$project_dir"/}"
first_line="$(head -n 1 "$file")"

shell_kind=""
case "$rel" in
  zsh/zshrc) shell_kind="zsh" ;;
  *.sh | bin/dev | bash/bashrc) shell_kind="bash" ;;
  *)
    case "$first_line" in
      '#!'*bash* | '#!'*/sh | '#!'*' sh') shell_kind="bash" ;;
    esac
    ;;
esac
[ -n "$shell_kind" ] || exit 0

if [ "$shell_kind" = "zsh" ]; then
  if ! zsh_errors="$(zsh -n "$file" 2>&1)"; then
    printf 'check-shell: %s の zsh 構文エラー（zsh -n）\n%s\n' "$rel" "$zsh_errors" >&2
    exit 2
  fi
  exit 0
fi

if ! bash_errors="$(bash -n "$file" 2>&1)"; then
  printf 'check-shell: %s の bash 構文エラー（bash -n）\n%s\n' "$rel" "$bash_errors" >&2
  exit 2
fi

# shellcheck は未導入のマシンもある。無ければ構文チェックだけで済ませる（doctor が未導入を知らせる）
command -v shellcheck >/dev/null 2>&1 || exit 0

# common.sh は bash と zsh の両方から読まれるが、書き方は bash に揃えている
if ! sc_output="$(shellcheck -S warning --shell=bash -x "$file" 2>&1)"; then
  printf 'check-shell: %s に shellcheck の警告があります\n%s\n' "$rel" "$sc_output" >&2
  exit 2
fi
