#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"

usage() {
  cat <<'USAGE'
使い方: ./scripts/uninstall.sh [options]

dotfiles が張ったシンボリックリンクを削除します。
ローカル状態（~/.codex/config.toml, ~/.gitconfig.local, ~/.bashrc.local）は残します。

オプション:
  --dry-run     実行せずに内容だけ表示
  -h, --help    このヘルプを表示
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "不明なオプション: $arg"; usage; exit 1 ;;
  esac
done

remove_link() {
  local path="$1"
  if [ -L "$path" ]; then
    run rm "$path"
    echo "削除: $path"
  elif [ -e "$path" ]; then
    echo "スキップ（シンボリックリンクではない）: $path"
  fi
}

echo "== dotfiles アンインストール =="

for pair in "${LINKS[@]}"; do
  remove_link "${pair%%|*}"
done

for legacy in "${LEGACY_PATHS[@]}"; do
  remove_link "$legacy"
done

echo
echo "以下のローカル状態ファイルは残しています（不要なら手動で削除してください）:"
echo "  ~/.codex/config.toml"
echo "  ~/.gitconfig.local"
echo "  ~/.bashrc.local"
