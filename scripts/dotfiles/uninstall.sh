#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"

DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h)
      cat <<'USAGE'
使い方: dotfiles uninstall [options]

dotfiles が張ったシンボリックリンクをすべて外します。
実ファイル（dotfiles リポジトリ内）は削除しません。
dotfiles install で即座に元に戻せます。

オプション:
  --dry-run   実行せずに対象リンクを表示
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

remove_link() {
  local path="$1"
  if [ -L "$path" ]; then
    run rm "$path"
    echo "削除: $path"
  elif [ -e "$path" ]; then
    echo "スキップ（シンボリックリンクではない）: $path"
  else
    echo "スキップ（存在しない）: $path"
  fi
}

echo "== dotfiles リンクを解除 =="

# dotfiles 本体
remove_link "$HOME/.gitconfig"
remove_link "$HOME/.bashrc"
remove_link "$HOME/.tmux.conf"
remove_link "$HOME/.config/nvim"

# AI グローバル設定
remove_link "$HOME/.agents/skills/dev"
remove_link "$HOME/.claude/CLAUDE.md"
remove_link "$HOME/.vscode-server/data/User/instructions/personal-dev-rules.instructions.md"

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  echo "（dry-run）上記リンクを削除します。実行するには --dry-run を外してください。"
else
  echo "完了。dotfiles install で元に戻せます。"
fi
