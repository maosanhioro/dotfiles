# install.sh / uninstall.sh / doctor.sh / init.sh / clean.sh の共有定義。
# リンク対応表をここに一元化することで、3スクリプト間の食い違い
# （installが張るのにuninstallが外さない等）を構造的に防ぐ。

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

DRY_RUN="${DRY_RUN:-0}"

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

# リンク対応表: "リンク先(HOME側)|実体(リポジトリ相対)"
LINKS=(
  "$HOME/.bashrc|bash/bashrc"
  "$HOME/.zshrc|zsh/zshrc"
  "$HOME/.config/starship.toml|zsh/starship.toml"
  "$HOME/.gitconfig|git/gitconfig"
  "$HOME/.tmux.conf|tmux/tmux.conf"
  "$HOME/.tmux.wsl.conf|tmux/tmux.wsl.conf"
  "$HOME/.tmux.ubuntu.conf|tmux/tmux.ubuntu.conf"
  "$HOME/.config/nvim|nvim"
  "$HOME/.local/bin/dev|bin/dev"
  "$HOME/.local/bin/dotbar-right|tmux/dotbar-right.sh"
  "$HOME/.claude/CLAUDE.md|agents/AGENTS.md"
  "$HOME/.claude/skills/delegate|agents/claude/skills/delegate"
  "$HOME/.codex/AGENTS.md|agents/AGENTS.md"
  "$HOME/.gemini/GEMINI.md|agents/AGENTS.md"
)

# リンクではなくコピーで配置するもの（project trust 等のローカル状態を保持するため）
CODEX_CONFIG="$HOME/.codex/config.toml"
CODEX_CONFIG_TEMPLATE="$REPO_DIR/agents/codex/config.toml"

# tmux-dotbar（install が clone し、doctor が検出し、uninstall が削除する。TPM は使わない）
DOTBAR_DIR="$HOME/.config/tmux/plugins/tmux-dotbar"
DOTBAR_REPO="https://github.com/vaaleyard/tmux-dotbar.git"

# 旧構成の残骸（install が掃除し、doctor が検出する）
LEGACY_PATHS=(
  "$HOME/.local/bin/dotfiles"
  "$HOME/.local/bin/aidev"
  "$HOME/.agents/skills/dev"
  "$HOME/.vscode-server/data/User/instructions/personal-dev-rules.instructions.md"
)

# dev init がプロジェクトに配置するファイル（clean はこの集合+レガシーを除去する）
PROJECT_FILES_CORE=(
  "AGENTS.md"
  "CLAUDE.md"
  "AGENT_HANDOFF_LOG.md"
)
PROJECT_FILES_LEGACY=(
  "CLAUDE.local.md"
  "SKILL.md"
  "CODEX.md"
  "GEMINI.md"
  ".github/copilot-instructions.md"
  ".antigravity.md"
)

GITIGNORE_HEADER="# AI agent files (managed by dev)"
GITIGNORE_HEADER_LEGACY="# AI agent files (managed by aidev)"
