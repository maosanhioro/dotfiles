#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="$HOME/dotfiles"

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

echo "== dotfiles bootstrap =="
echo "repo: $REPO_DIR"

############################################
# パッケージ管理
############################################
apt_install() {
  sudo apt-get update
  sudo apt-get install -y "$@"
}

############################################
# 必須ツール確認 / インストール
############################################
echo "Checking dependencies..."

if ! command -v tmux >/dev/null 2>&1; then
  echo "Installing tmux..."
  apt_install tmux
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Installing git..."
  apt_install git
fi

############################################
# Ubuntu Desktop 側クリップボード
############################################
if ! is_wsl; then
  if command -v wl-copy >/dev/null 2>&1; then
    echo "wl-copy found (Wayland)"
  elif command -v xclip >/dev/null 2>&1; then
    echo "xclip found (X11)"
  else
    echo "Installing clipboard tool..."
    # Wayland 優先
    apt_install wl-clipboard || apt_install xclip
  fi
fi

############################################
# ~/.bashrc エントリポイント生成
############################################
echo "Writing ~/.bashrc"

cat > "$HOME/.bashrc" <<'EOF'
# dotfiles managed entrypoint

. "$HOME/dotfiles/bash/bashrc.common"

if grep -qi microsoft /proc/version 2>/dev/null; then
  . "$HOME/dotfiles/bash/bashrc.wsl"
else
  . "$HOME/dotfiles/bash/bashrc.ubuntu"
fi
EOF

############################################
# ~/.tmux.conf エントリポイント生成
############################################
echo "Writing ~/.tmux.conf"

cat > "$HOME/.tmux.conf" <<'EOF'
# dotfiles managed entrypoint

source-file ~/dotfiles/tmux/tmux.common.conf

if-shell 'grep -qi microsoft /proc/version 2>/dev/null' \
  'source-file ~/dotfiles/tmux/tmux.wsl.conf' \
  'source-file ~/dotfiles/tmux/tmux.ubuntu.conf'
EOF

############################################
# 完了
############################################
echo
echo "Bootstrap complete."
echo "Next steps:"
echo "  source ~/.bashrc"
echo "  ta"

