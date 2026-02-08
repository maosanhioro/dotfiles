#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="$HOME/dotfiles"

DRY_RUN=0
FORCE=0
NO_SUDO=0

usage() {
  cat <<'USAGE'
使い方: ./scripts/install.sh [options]

オプション:
  --dry-run     実行せずに内容だけ表示
  --force       既存があっても再インストール/再リンク
  --no-sudo     sudo を使わない（特殊環境向け）
  -h, --help    このヘルプを表示
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    --no-sudo) NO_SUDO=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "不明なオプション: $arg"; usage; exit 1 ;;
  esac
done

run() {
  if [ "${DRY_RUN}" -eq 1 ]; then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

SUDO="sudo"
if [ "${NO_SUDO}" -eq 1 ]; then
  SUDO=""
fi

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

echo "== dotfiles セットアップ =="
echo "repo: $REPO_DIR"

############################################
# パッケージ管理
############################################
apt_install() {
  run ${SUDO} apt-get update
  run ${SUDO} apt-get install -y "$@"
}

############################################
# 必須ツール確認 / インストール
############################################
echo "依存関係を確認中..."

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux をインストール中..."
  apt_install tmux
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git をインストール中..."
  apt_install git
fi

install_nvim_appimage() {
  echo "Neovim（AppImage）をインストール中..."
  apt_install curl libfuse2
  run mkdir -p "$HOME/.local/bin"
  local tmp="/tmp/nvim.appimage"
  run curl -fsSL -o "${tmp}" "https://github.com/neovim/neovim-releases/releases/latest/download/nvim-linux-x86_64.appimage"
  run chmod +x "${tmp}"
  run mv "${tmp}" "$HOME/.local/bin/nvim"
}

cleanup_apt_nvim() {
  # Remove PPA neovim if present to avoid old version taking precedence.
  if grep -Rqs "neovim-ppa/stable" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    echo "neovim-ppa/stable を削除中..."
    run ${SUDO} add-apt-repository -y -r ppa:neovim-ppa/stable || true
  fi
  run ${SUDO} rm -f /etc/apt/sources.list.d/neovim-ppa-*.list 2>/dev/null || true
  if dpkg -s neovim >/dev/null 2>&1; then
    echo "apt の Neovim を削除中..."
    run ${SUDO} apt-get remove -y neovim
  fi
  run ${SUDO} apt-get update
}

if [ "${FORCE}" -eq 1 ]; then
  cleanup_apt_nvim
  install_nvim_appimage
elif ! command -v nvim >/dev/null 2>&1; then
  cleanup_apt_nvim
  install_nvim_appimage
else
  # 近代的なプラグイン向けに最小バージョンを保証（>=0.10）
  nvim_ver="$(nvim --version | head -n1 | awk '{print $2}' | sed 's/^v//')"
  case "${nvim_ver}" in
    0.0.*|0.1.*|0.2.*|0.3.*|0.4.*|0.5.*|0.6.*|0.7.*|0.8.*|0.9.*)
      cleanup_apt_nvim
      install_nvim_appimage
      ;;
  esac
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep をインストール中..."
  apt_install ripgrep
fi

if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then
  echo "fd-find をインストール中..."
  apt_install fd-find
fi

if ! command -v fzf >/dev/null 2>&1; then
  echo "fzf をインストール中..."
  apt_install fzf
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "unzip をインストール中..."
  apt_install unzip
fi

if ! command -v bat >/dev/null 2>&1; then
  if command -v batcat >/dev/null 2>&1; then
    echo "bat -> batcat のリンクを作成中..."
    run mkdir -p "$HOME/.local/bin"
    run ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"
  else
    echo "bat をインストール中..."
    apt_install bat || apt_install batcat
    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
      run mkdir -p "$HOME/.local/bin"
      run ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"
    fi
  fi
fi

if ! command -v eza >/dev/null 2>&1; then
  echo "eza をインストール中..."
  apt_install eza || true
fi

if ! command -v pipx >/dev/null 2>&1; then
  echo "pipx をインストール中..."
  apt_install pipx
  run pipx ensurepath
fi

############################################
# Ubuntu Desktop 側クリップボード
############################################
if ! is_wsl; then
  if command -v wl-copy >/dev/null 2>&1; then
    echo "wl-copy を検出（Wayland）"
  elif command -v xclip >/dev/null 2>&1; then
    echo "xclip を検出（X11）"
  else
    echo "クリップボードツールをインストール中..."
    # Wayland 優先
    apt_install wl-clipboard || apt_install xclip
  fi
fi

############################################
# ~/.bashrc エントリポイント（リンク）
############################################
echo "~/.bashrc をリンク中"
run ln -sfn "$REPO_DIR/bash/bashrc.common" "$HOME/.bashrc"

############################################
# ~/.tmux.conf エントリポイント（リンク）
############################################
echo "~/.tmux.conf をリンク中"
run ln -sfn "$REPO_DIR/tmux/tmux.common.conf" "$HOME/.tmux.conf"

############################################
# Neovim 設定の配置
############################################
echo "Neovim 設定をリンク中"
run mkdir -p "$HOME/.config"
run ln -sfn "$REPO_DIR/nvim" "$HOME/.config/nvim"

############################################
# Codex CLI Skills（汎用）
############################################
echo "Codex CLI Skills（汎用）をリンク中"
run mkdir -p "$HOME/.agents/skills"
run ln -sfn "$REPO_DIR/codex/skills/dev" "$HOME/.agents/skills/dev"

############################################
# 完了
############################################
echo
echo "セットアップ完了。"
echo "次の手順:"
echo "  source ~/.bashrc"
echo "  ta"
