#!/usr/bin/env bash
# ペイン上端（pane-border-format）に出す作業ディレクトリと git ブランチ。
# tmux.conf の pane-border-format から #() で status-interval ごとに、ペインごとに呼ばれる。
# 大きなリポジトリで git status が遅いとステータス描画が待たされるため timeout で打ち切る
# （打ち切られたら変更ありの印を出さないだけで、ブランチ名は出す）。
set -u

DIR="${1:-}"
[ -d "$DIR" ] || exit 0

I_FOLDER=$'\uf07b' # nf-fa-folder
I_BRANCH=$'\ue0a0' # powerline branch
C_PATH="#56b6c2"
C_BRANCH="#c678dd"
C_DIRTY="#e5c07b"
MAX_PATH_LEN=40

short_path() {
  local path="$1"
  case "$path" in
    "$HOME") path="~" ;;
    "$HOME"/*) path="~/${path#"$HOME"/}" ;;
  esac
  if [ "${#path}" -gt "$MAX_PATH_LEN" ]; then
    # 末尾の2階層だけ残す
    path="…/$(basename "$(dirname "$path")")/$(basename "$path")"
  fi
  printf '%s' "$path"
}

printf '#[fg=%s]%s %s' "$C_PATH" "$I_FOLDER" "$(short_path "$DIR")"

branch="$(git -C "$DIR" symbolic-ref --short -q HEAD 2>/dev/null ||
  git -C "$DIR" rev-parse --short -q HEAD 2>/dev/null)"
[ -n "$branch" ] || exit 0

dirty=""
if [ -n "$(timeout 1 git -C "$DIR" status --porcelain --ignore-submodules 2>/dev/null | head -1)" ]; then
  dirty="#[fg=${C_DIRTY}]*"
fi
printf '  #[fg=%s]%s %s%s' "$C_BRANCH" "$I_BRANCH" "$branch" "$dirty"
