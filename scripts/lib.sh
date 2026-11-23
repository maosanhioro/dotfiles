# shellcheck disable=SC2034 # source される定義集なので、ここで使わない変数が大半
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

version_at_least() {
  # $1=現在 $2=要求。sort -V の最小値が要求と一致すれば満たしている
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
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
  "$HOME/.local/bin/dev-pick|tmux/pick.sh"
  "$HOME/.local/bin/tmux-pane-info|tmux/pane-info.sh"
  "$HOME/.claude/CLAUDE.md|agents/AGENTS.md"
  "$HOME/.claude/skills/delegate|agents/claude/skills/delegate"
  "$HOME/.claude/plugins-optional.md|agents/claude/plugins-optional.md"
  "$HOME/.codex/AGENTS.md|agents/AGENTS.md"
  "$HOME/.copilot/copilot-instructions.md|agents/AGENTS.md"
  "$HOME/.codex/hooks.json|agents/codex/hooks.json"
  "$HOME/.copilot/hooks/dev.json|agents/copilot/hooks/dev.json"
  "$HOME/.gemini/GEMINI.md|agents/AGENTS.md"
  # xremap は Ubuntu Desktop でだけ動く。WSL に張っても読まれないだけで害はないため分岐しない
  "$HOME/.config/xremap/config.yml|xremap/config.yml"
  "$HOME/.config/systemd/user/xremap.service|xremap/xremap.service"
)

# リンクではなくコピーで配置するもの（project trust 等のローカル状態を保持するため）
CODEX_CONFIG="$HOME/.codex/config.toml"
CODEX_CONFIG_TEMPLATE="$REPO_DIR/agents/codex/config.toml"

# Claude Code の hooks。settings.json は CLI が権限設定などを書き込むローカル状態の
# ため、リンクせず "hooks" キーだけを install がこのファイルの内容で置き換える
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CLAUDE_HOOKS_TEMPLATE="$REPO_DIR/agents/claude/hooks.json"
CLAUDE_PERMISSIONS_TEMPLATE="$REPO_DIR/agents/claude/permissions.json"
CLAUDE_PLUGINS_LIST="$REPO_DIR/agents/claude/plugins.txt"

# plugins.txt のプラグイン ID を1行ずつ出す（コメントと空行を除く）
claude_plugin_wanted() {
  [ -f "$CLAUDE_PLUGINS_LIST" ] || return 0
  sed -e 's/#.*//' -e 's/[[:space:]]//g' "$CLAUDE_PLUGINS_LIST" | grep -v '^$' || true
}

# user スコープで導入済みのプラグイン ID を1行ずつ出す。claude / jq が無ければ失敗を返す
claude_plugin_installed() {
  command -v claude >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1
  claude plugin list --json | jq -r '.[] | select(.scope == "user") | .id'
}

# tmux-dotbar（install が clone し、doctor が検出し、uninstall が削除する。TPM は使わない）
DOTBAR_DIR="$HOME/.config/tmux/plugins/tmux-dotbar"
DOTBAR_REPO="https://github.com/vaaleyard/tmux-dotbar.git"

# 旧構成の残骸（install が掃除し、doctor が検出する）
LEGACY_PATHS=(
  "$HOME/.local/bin/dotfiles"
  "$HOME/.local/bin/aidev"
  "$HOME/.local/bin/dev-monitor" # 旧ポーリング監視（dev report へ移行済み）
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

# プロジェクト AGENTS.md の固有ルール部分の見出し（dev init --force が各節を残すときの目印。旧形式は末尾に「（骨子）」が付く）
PROJECT_RULES_MARKER="# プロジェクト固有の AI エージェントルール"

GITIGNORE_HEADER="# AI agent files (managed by dev)"
GITIGNORE_HEADER_LEGACY="# AI agent files (managed by aidev)"
