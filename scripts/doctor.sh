#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  [OK] %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }
info() { printf '  [INFO] %s\n' "$*"; }

check_cmd() {
  local name="$1"
  local pretty="${2:-$1}"
  if command -v "$name" >/dev/null 2>&1; then
    ok "$pretty $(command -v "$name")"
  else
    warn "$pretty が見つかりません"
  fi
}

bold "Dotfiles 診断"

bold "コマンド"
check_cmd tmux
if command -v tmux >/dev/null 2>&1; then
  tmux_ver="$(tmux -V | sed 's/^tmux //; s/[a-z]$//')"
  if version_at_least "$tmux_ver" "3.1"; then
    ok "tmux バージョン $tmux_ver (>= 3.1)"
  else
    warn "tmux $tmux_ver は古すぎます（dev コマンドは 3.1 以上が必要）"
  fi
fi
check_cmd nvim
if command -v nvim >/dev/null 2>&1; then
  nvim_ver="$(nvim --version | head -n1 | awk '{print $2}' | sed 's/^v//')"
  if version_at_least "$nvim_ver" "0.11.0"; then
    ok "nvim バージョン $nvim_ver (>= 0.11)"
  else
    warn "nvim $nvim_ver は古すぎます（LazyVim は 0.11 以上が必要。./scripts/install.sh --force で更新）"
  fi
fi
check_cmd zsh
if command -v zsh >/dev/null 2>&1; then
  login_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [ "$login_shell" = "$(command -v zsh)" ]; then
    ok "ログインシェル zsh"
  else
    warn "ログインシェルが zsh ではありません: $login_shell（chsh -s $(command -v zsh)）"
  fi
fi
check_cmd starship
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  ok "zsh-autosuggestions"
else
  warn "zsh-autosuggestions が見つかりません（apt install zsh-autosuggestions）"
fi
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  ok "zsh-syntax-highlighting"
else
  warn "zsh-syntax-highlighting が見つかりません（apt install zsh-syntax-highlighting）"
fi
if [ -e "$DOTBAR_DIR/dotbar.tmux" ]; then
  ok "tmux-dotbar $DOTBAR_DIR"
else
  warn "tmux-dotbar が見つかりません（./scripts/install.sh で clone されます）"
fi
check_cmd rg ripgrep
if command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1; then
  ok "fd $(command -v fd || command -v fdfind)"
else
  warn "fd が見つかりません"
fi
check_cmd fzf
if command -v fzf >/dev/null 2>&1; then
  fzf_ver="$(fzf --version | awk '{print $1}')"
  if version_at_least "$fzf_ver" "0.45"; then
    ok "fzf バージョン $fzf_ver (>= 0.45)"
  else
    warn "fzf $fzf_ver は古すぎます（LazyVim ダッシュボードの Find File/Text が動きません。./scripts/install.sh --force で更新）"
  fi
fi
check_cmd bat
check_cmd eza
check_cmd pipx
check_cmd node "node (Mason の LSP サーバ実行に必要)"
check_cmd claude "Claude Code (claude)"
check_cmd codex "Codex CLI (codex)"
check_cmd copilot "GitHub Copilot CLI (copilot)"
player="${DEV_PLAYER:-codex}"
if command -v "$player" >/dev/null 2>&1; then
  ok "pane2 プレイヤー: $player（DEV_PLAYER で切替可）"
else
  warn "pane2 プレイヤー ${player} が見つかりません（DEV_PLAYER=codex か =copilot に切替、または該当 CLI を導入）"
fi

bold "リンク（対応表: scripts/lib.sh）"
for pair in "${LINKS[@]}"; do
  dest="${pair%%|*}"
  src="$REPO_DIR/${pair##*|}"
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    warn "$dest が見つかりません（./scripts/install.sh で作成されます）"
  elif [ ! -L "$dest" ]; then
    warn "$dest はシンボリックリンクではありません"
  elif [ "$(readlink -f "$dest" 2>/dev/null)" != "$(readlink -f "$src")" ]; then
    warn "$dest のリンク先が期待と異なります: $(readlink "$dest")（期待: $src）"
  else
    ok "$dest -> $src"
  fi
done

bold "ローカル状態ファイル"
if [ -L "$CODEX_CONFIG" ]; then
  warn "~/.codex/config.toml はシンボリックリンクです（project trust を保持するため通常ファイル推奨。install で移行されます）"
elif [ -f "$CODEX_CONFIG" ]; then
  ok "~/.codex/config.toml (regular file)"
  if grep -q 'project_doc_fallback_filenames' "$CODEX_CONFIG"; then
    warn "~/.codex/config.toml に project_doc_fallback_filenames が残っています（プロジェクト側は AGENTS.md 標準名に移行済みのため不要。手動で削除してください）"
  fi
else
  warn "~/.codex/config.toml が見つかりません"
fi
for f in "$HOME/.gitconfig.local" "$HOME/.bashrc.local" "$HOME/.zshrc.local"; do
  if [ -f "$f" ]; then
    ok "$f"
  else
    info "$f なし（install で雛形が作られます）"
  fi
done

bold "旧構成の残骸"
found_legacy=0
for legacy in "${LEGACY_PATHS[@]}"; do
  if [ -e "$legacy" ] || [ -L "$legacy" ]; then
    warn "$legacy が残っています（./scripts/install.sh で掃除されます）"
    found_legacy=1
  fi
done
[ "$found_legacy" -eq 0 ] && ok "残骸なし"

bold "メモ"
echo "  何か足りなければ: ./scripts/install.sh（または dev install）"
echo "  プロジェクトの AI 設定: dev init"
