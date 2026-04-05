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

check_file_or_link() {
  local path="$1"
  if [ -L "${path}" ]; then
    ok "${path} -> $(readlink "${path}")"
  elif [ -f "${path}" ]; then
    ok "${path} (regular file)"
  else
    warn "${path} が見つかりません"
  fi
}

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
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
check_file_or_link "${HOME}/.vscode-server/data/User/instructions/personal-dev-rules.instructions.md"

if is_wsl && command -v cmd.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
  win_user_profile_win="$(cmd.exe /C "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')"
  win_user_profile_wsl="$(wslpath "$win_user_profile_win" 2>/dev/null || true)"

  if [ -n "$win_user_profile_wsl" ] && [ -d "$win_user_profile_wsl" ]; then
    bold "WSL から見た Windows 側"
    check_file_or_link "$win_user_profile_wsl/AppData/Roaming/Code/User/instructions/personal-dev-rules.instructions.md"
    check_file_or_link "$win_user_profile_wsl/AppData/Roaming/Code - Insiders/User/instructions/personal-dev-rules.instructions.md"
  fi
fi

bold "メモ"
echo "  何か足りなければ: dotfiles install"
echo "  AI環境のセットアップ: aidev init"
echo "  Windows 側 VS Code 反映: powershell -ExecutionPolicy Bypass -File scripts/dotfiles/install-windows.ps1"
