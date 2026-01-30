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

install_nvim_appimage() {
  echo "Installing Neovim (AppImage)..."
  apt_install curl libfuse2
  mkdir -p "$HOME/.local/bin"
  local tmp="/tmp/nvim.appimage"
  curl -fsSL -o "${tmp}" "https://github.com/neovim/neovim-releases/releases/latest/download/nvim-linux-x86_64.appimage"
  chmod +x "${tmp}"
  mv "${tmp}" "$HOME/.local/bin/nvim"
}

cleanup_apt_nvim() {
  # Remove PPA neovim if present to avoid old version taking precedence.
  if grep -Rqs "neovim-ppa/stable" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    echo "Removing neovim-ppa/stable..."
    sudo add-apt-repository -y -r ppa:neovim-ppa/stable || true
  fi
  sudo rm -f /etc/apt/sources.list.d/neovim-ppa-*.list 2>/dev/null || true
  if dpkg -s neovim >/dev/null 2>&1; then
    echo "Removing apt neovim..."
    sudo apt-get remove -y neovim
  fi
  sudo apt-get update
}

if ! command -v nvim >/dev/null 2>&1; then
  cleanup_apt_nvim
  install_nvim_appimage
else
  # Ensure minimum version (>=0.10) for modern plugins
  nvim_ver="$(nvim --version | head -n1 | awk '{print $2}' | sed 's/^v//')"
  case "${nvim_ver}" in
    0.0.*|0.1.*|0.2.*|0.3.*|0.4.*|0.5.*|0.6.*|0.7.*|0.8.*|0.9.*)
      cleanup_apt_nvim
      install_nvim_appimage
      ;;
  esac
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "Installing ripgrep..."
  apt_install ripgrep
fi

if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then
  echo "Installing fd-find..."
  apt_install fd-find
fi

if ! command -v pipx >/dev/null 2>&1; then
  echo "Installing pipx..."
  apt_install pipx
  pipx ensurepath
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
# ~/.bashrc エントリポイント（リンク）
############################################
echo "Linking ~/.bashrc"
ln -sfn "$REPO_DIR/bash/bashrc.common" "$HOME/.bashrc"

############################################
# ~/.tmux.conf エントリポイント（リンク）
############################################
echo "Linking ~/.tmux.conf"
ln -sfn "$REPO_DIR/tmux/tmux.common.conf" "$HOME/.tmux.conf"

############################################
# Neovim 設定の配置
############################################
echo "Linking Neovim config"
mkdir -p "$HOME/.config"
ln -sfn "$REPO_DIR/nvim" "$HOME/.config/nvim"

############################################
# 完了
############################################
echo
echo "Bootstrap complete."
echo "Next steps:"
echo "  source ~/.bashrc"
echo "  ta"
