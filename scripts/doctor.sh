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

version_at_least() {
  # $1=現在 $2=要求。sort -V の最小値が要求と一致すれば満たしている
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
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
check_cmd rg ripgrep
check_cmd fd
check_cmd fzf
check_cmd bat
check_cmd eza
check_cmd pipx
check_cmd node "node (Mason の LSP サーバ実行に必要)"
check_cmd claude "Claude Code (claude)"
check_cmd codex "Codex CLI (codex)"
if command -v agy >/dev/null 2>&1; then
  ok "Antigravity CLI (agy) $(command -v agy)"
else
  info "Antigravity CLI (agy) なし — dev のペイン3は nvim になります"
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
for f in "$HOME/.gitconfig.local" "$HOME/.bashrc.local"; do
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
