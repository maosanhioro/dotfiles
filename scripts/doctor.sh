#!/usr/bin/env bash
set -euo pipefail

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  [OK] %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }

bold "Dotfiles 診断"

check_cmd() {
  local name="$1"
  local pretty="${2:-$1}"
  if command -v "${name}" >/dev/null 2>&1; then
    ok "${pretty} $(command -v "${name}")"
  else
    warn "${pretty} が見つかりません"
  fi
}

check_link() {
  local path="$1"
  if [ -L "${path}" ]; then
    ok "${path} -> $(readlink "${path}")"
  elif [ -e "${path}" ]; then
    warn "${path} は存在しますがシンボリックリンクではありません"
  else
    warn "${path} が見つかりません"
  fi
}

bold "コマンド"
check_cmd tmux
check_cmd nvim
check_cmd rg ripgrep
check_cmd fd
check_cmd fzf
check_cmd bat
check_cmd eza
check_cmd pipx
check_cmd claude
check_cmd codex

bold "リンク"
check_link "${HOME}/.gitconfig"
check_link "${HOME}/.bashrc"
check_link "${HOME}/.tmux.conf"
check_link "${HOME}/.config/nvim"

bold "メモ"
echo "  何か足りなければ: ./scripts/install.sh"
