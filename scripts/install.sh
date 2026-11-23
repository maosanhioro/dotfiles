#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"

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
    -h | --help) usage; exit 0 ;;
    *) echo "不明なオプション: $arg"; usage; exit 1 ;;
  esac
done

SUDO="sudo"
if [ "$NO_SUDO" -eq 1 ]; then
  SUDO=""
fi

# 途中の sudo でパスワード入力に失敗して半端に止まらないよう、最初に一度だけ聞いておく
if [ "$NO_SUDO" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
  if ! sudo -v; then
    echo "sudo の認証に失敗しました。パスワードを入力できる端末から直接実行してください" >&2
    echo "（Claude Code の ! 経由では入力できません。sudo を使わないなら --no-sudo）" >&2
    exit 1
  fi
fi

echo "== dotfiles セットアップ =="
echo "repo: $REPO_DIR"

############################################
# パッケージ導入
############################################
apt_install() {
  run ${SUDO} apt-get update
  run ${SUDO} apt-get install -y "$@"
}

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
  run curl -fsSL -o "$tmp" "https://github.com/neovim/neovim-releases/releases/latest/download/nvim-linux-x86_64.appimage"
  run chmod +x "$tmp"
  run mv "$tmp" "$HOME/.local/bin/nvim"
}

cleanup_apt_nvim() {
  # PPA/apt の古い Neovim が AppImage より優先されるのを防ぐ
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

if [ "$FORCE" -eq 1 ] || ! command -v nvim >/dev/null 2>&1; then
  cleanup_apt_nvim
  install_nvim_appimage
else
  # LazyVim の要求バージョンを保証（>=0.11）
  nvim_ver="$(nvim --version | head -n1 | awk '{print $2}' | sed 's/^v//')"
  case "$nvim_ver" in
    0.0.* | 0.1.* | 0.2.* | 0.3.* | 0.4.* | 0.5.* | 0.6.* | 0.7.* | 0.8.* | 0.9.* | 0.10.*)
      cleanup_apt_nvim
      install_nvim_appimage
      ;;
  esac
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep をインストール中..."
  apt_install ripgrep
fi

# jq: Claude Code の hooks 設定（このスクリプト後半）と dev-guard-delegate.sh が使う
if ! command -v jq >/dev/null 2>&1; then
  echo "jq をインストール中..."
  apt_install jq
fi

# dotfiles 自身のシェルスクリプトを編集直後に shellcheck で検査する（.claude/hooks/check-shell.sh）
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck をインストール中..."
  apt_install shellcheck
fi

if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then
  echo "fd-find をインストール中..."
  apt_install fd-find
fi

install_fzf_binary() {
  echo "fzf（最新版）をインストール中..."
  command -v curl >/dev/null 2>&1 || apt_install curl
  run mkdir -p "$HOME/.local/bin"
  local tag tmp api_tmp
  api_tmp="$(mktemp)"
  curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest > "$api_tmp"
  tag="$(grep -m1 '"tag_name"' "$api_tmp" | sed -E 's/.*"v?([0-9.]+)".*/\1/')"
  rm -f "$api_tmp"
  [ -n "$tag" ] || { echo "fzf の最新バージョン取得に失敗しました。手動でインストールしてください"; return 1; }
  tmp="/tmp/fzf-${tag}.tar.gz"
  run curl -fsSL -o "$tmp" \
    "https://github.com/junegunn/fzf/releases/download/v${tag}/fzf-${tag}-linux_amd64.tar.gz"
  run tar -xzf "$tmp" -C "$HOME/.local/bin" fzf
  run chmod +x "$HOME/.local/bin/fzf"
  run rm -f "$tmp"
}

# apt の fzf は Debian/Ubuntu で更新が遅く、LazyVim ダッシュボードの fzf-lua が
# 要求する `transform` アクション（fzf >= 0.45 で追加）に届かないことがある
if dpkg -s fzf >/dev/null 2>&1; then
  echo "apt 版 fzf を削除中（新しいバイナリと重複させないため）..."
  run ${SUDO} apt-get remove -y fzf
fi

if [ "$FORCE" -eq 1 ] || ! command -v fzf >/dev/null 2>&1; then
  install_fzf_binary
else
  fzf_ver="$(fzf --version | awk '{print $1}')"
  if ! version_at_least "$fzf_ver" "0.45"; then
    install_fzf_binary
  fi
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
# zsh + プラグイン（apt 版を直接 source する。プラグインマネージャは使わない）
############################################
if ! command -v zsh >/dev/null 2>&1; then
  echo "zsh をインストール中..."
  apt_install zsh
fi

if [ ! -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  echo "zsh-autosuggestions をインストール中..."
  apt_install zsh-autosuggestions
fi

if [ ! -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  echo "zsh-syntax-highlighting をインストール中..."
  apt_install zsh-syntax-highlighting
fi

############################################
# starship（apt に無いため公式インストーラで ~/.local/bin へ。nvim AppImage と同じ方式）
############################################
if [ "$FORCE" -eq 1 ] || ! command -v starship >/dev/null 2>&1; then
  echo "starship をインストール中..."
  command -v curl >/dev/null 2>&1 || apt_install curl
  run mkdir -p "$HOME/.local/bin"
  run sh -c "curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b '$HOME/.local/bin'"
fi

############################################
# tmux-dotbar（ステータスバーテーマ。TPM は使わず直接 clone）
############################################
if [ ! -d "$DOTBAR_DIR" ]; then
  echo "tmux-dotbar を配置中..."
  run mkdir -p "$(dirname "$DOTBAR_DIR")"
  run git clone --depth 1 "$DOTBAR_REPO" "$DOTBAR_DIR"
elif [ "$FORCE" -eq 1 ]; then
  echo "tmux-dotbar を更新中..."
  run git -C "$DOTBAR_DIR" pull --ff-only
fi

# Ubuntu Desktop 側クリップボード
if ! is_wsl; then
  if command -v wl-copy >/dev/null 2>&1; then
    echo "wl-copy を検出（Wayland）"
  elif command -v xclip >/dev/null 2>&1; then
    echo "xclip を検出（X11）"
  else
    echo "クリップボードツールをインストール中..."
    apt_install wl-clipboard || apt_install xclip
  fi
fi

# デスクトップ通知（dev report と dev hook が使う。WSL は notify-send を入れず、
# bin/dev が Windows の powershell.exe でトースト通知を出す。無くても
# dev report 自体は dotbar の色変更だけで動く）
if ! is_wsl; then
  if command -v notify-send >/dev/null 2>&1; then
    echo "notify-send を検出"
  else
    echo "notify-send をインストール中..."
    apt_install libnotify-bin
  fi
fi

############################################
# ~/.gitconfig（既存実ファイルは .gitconfig.local へ退避）
############################################
if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ] && [ ! -f "$HOME/.gitconfig.local" ]; then
  echo "既存の ~/.gitconfig を ~/.gitconfig.local に退避"
  run mv "$HOME/.gitconfig" "$HOME/.gitconfig.local"
fi

############################################
# シンボリックリンク（対応表は scripts/lib.sh）
############################################
echo "シンボリックリンクを作成中..."
for pair in "${LINKS[@]}"; do
  dest="${pair%%|*}"
  src="$REPO_DIR/${pair##*|}"
  run mkdir -p "$(dirname "$dest")"
  run ln -sfn "$src" "$dest"
  echo "  $dest -> $src"
done

############################################
# 雛形生成（既存があれば触らない）
############################################
if [ ! -f "$HOME/.gitconfig.local" ]; then
  echo "~/.gitconfig.local を作成中（user.name / user.email を設定してください）"
  run tee "$HOME/.gitconfig.local" >/dev/null <<'LOCALCONF'
# マシン固有の Git 設定
[user]
  name =
  email =
LOCALCONF
fi

if [ ! -f "$HOME/.bashrc.local" ]; then
  echo "~/.bashrc.local を作成中（マシン固有のシェル設定はここへ）"
  run tee "$HOME/.bashrc.local" >/dev/null <<'LOCALRC'
# マシン固有のシェル設定（Git 管理外）
# 例: gcloud SDK の読み込み、仕事用の環境変数、追加 PATH など
LOCALRC
fi

if [ ! -f "$HOME/.zshrc.local" ]; then
  echo "~/.zshrc.local を作成中（マシン固有のシェル設定はここへ）"
  run tee "$HOME/.zshrc.local" >/dev/null <<'LOCALRC'
# マシン固有のシェル設定（Git 管理外）
# 例: gcloud SDK の読み込み、仕事用の環境変数、追加 PATH など
# bash から移行した場合は ~/.bashrc.local から必要なものをコピーする
LOCALRC
fi

############################################
# ログインシェルを zsh へ
############################################
zsh_path="$(command -v zsh || true)"
login_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [ -n "$zsh_path" ] && [ "$login_shell" != "$zsh_path" ]; then
  echo "ログインシェルを zsh に変更中（パスワードを求められる場合があります）..."
  run chsh -s "$zsh_path" ||
    echo "  chsh に失敗しました。手動で実行してください: chsh -s $zsh_path"
fi

############################################
# ~/.codex/config.toml（リンクではなくコピー。project trust をローカル保持するため）
############################################
if [ -L "$CODEX_CONFIG" ]; then
  echo "~/.codex/config.toml を実ファイルへ移行中（ローカル状態を保持するため）"
  run rm "$CODEX_CONFIG"
  run install -m 600 "$CODEX_CONFIG_TEMPLATE" "$CODEX_CONFIG"
elif [ -f "$CODEX_CONFIG" ]; then
  echo "~/.codex/config.toml は既存のローカル実ファイルを保持"
elif [ -e "$CODEX_CONFIG" ]; then
  echo "~/.codex/config.toml は通常ファイルではないためスキップ"
else
  echo "~/.codex/config.toml をテンプレートから作成"
  run mkdir -p "$(dirname "$CODEX_CONFIG")"
  run install -m 600 "$CODEX_CONFIG_TEMPLATE" "$CODEX_CONFIG"
fi

# 既存の実ファイルにはテンプレートの後から足した設定が入らないため、ここで補う。
# alternate_screen: 出力を tmux のスクロールバックに残す（2026-10 追加）
if [ -f "$CODEX_CONFIG" ] && ! grep -qE '^[[:space:]]*alternate_screen[[:space:]]*=' "$CODEX_CONFIG"; then
  echo "~/.codex/config.toml に [tui] alternate_screen を追加"
  if grep -qxF '[tui]' "$CODEX_CONFIG"; then
    # [tui] を 2 回書くと Codex が起動時にエラーになるため、既存の表の直下に足す
    run sed -i '/^\[tui\]$/a alternate_screen = "never"' "$CODEX_CONFIG"
  elif [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] ~/.codex/config.toml の末尾に [tui] を追記"
  else
    printf '\n[tui]\nalternate_screen = "never"\n' >>"$CODEX_CONFIG"
  fi
fi

############################################
# WSL interop（Linux から Windows の exe を起動する仕組み）の保護
############################################
# WSL の全ディストリは1つのカーネルを共有しており、binfmt_misc の登録も共有になる。
# systemd が動くディストリが起動すると systemd-binfmt が登録を全消去して /etc/binfmt.d
# の分だけ登録し直すため、WSLInterop が消えて全ディストリで cmd.exe・powershell.exe が
# 「実行形式エラー」になる（通知・スクショ貼り付け・下の Windows Terminal 設定が全滅する）。
# /etc/binfmt.d に WSLInterop を置けば systemd-binfmt が登録し直す側に回る
WSL_INTEROP_REGISTER="/proc/sys/fs/binfmt_misc/register"
WSL_INTEROP_ENTRY=":WSLInterop:M::MZ::/init:PF"
WSL_INTEROP_CONF="/etc/binfmt.d/WSLInterop.conf"
if is_wsl && [ "$NO_SUDO" -eq 0 ]; then
  if [ "$(cat "$WSL_INTEROP_CONF" 2>/dev/null)" != "$WSL_INTEROP_ENTRY" ]; then
    echo "WSL interop を systemd-binfmt から守る設定を追加: $WSL_INTEROP_CONF"
    run ${SUDO} mkdir -p "$(dirname "$WSL_INTEROP_CONF")"
    if [ "$DRY_RUN" -eq 0 ]; then
      echo "$WSL_INTEROP_ENTRY" | ${SUDO} tee "$WSL_INTEROP_CONF" >/dev/null
    fi
  fi
  # すでに消されている場合はこの場で登録し直す（wsl --shutdown でも戻る）
  if [ ! -e /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    echo "WSL interop が無効になっているため登録し直します"
    if [ "$DRY_RUN" -eq 0 ]; then
      echo "$WSL_INTEROP_ENTRY" | ${SUDO} tee "$WSL_INTEROP_REGISTER" >/dev/null ||
        echo "  登録に失敗しました。PowerShell で wsl --shutdown してから開き直してください"
    fi
  fi
fi

############################################
# Windows Terminal の設定（WSL のみ。Windows 側のファイルを /mnt/c 経由で編集）
############################################
# タブ名をセッション名にする設定と Shift+Enter の改行。中身は scripts/wt-settings.py
if is_wsl; then
  win_cmd="/mnt/c/Windows/System32/cmd.exe"
  local_appdata=""
  if [ -x "$win_cmd" ]; then
    # cmd.exe は WSL の作業ディレクトリが Linux 側だと警告を出すため /mnt/c から呼ぶ
    local_appdata="$(cd /mnt/c && "$win_cmd" /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')"
  fi
  if [ -z "$local_appdata" ]; then
    echo "Windows の LOCALAPPDATA が取れないため Windows Terminal の設定をスキップ（cmd.exe が起動できない。WSL interop を確認）"
  else
    wt_found=0
    for wt_package in Microsoft.WindowsTerminal_8wekyb3d8bbwe Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe; do
      wt_settings="$(wslpath -u "$local_appdata")/Packages/${wt_package}/LocalState/settings.json"
      [ -f "$wt_settings" ] || continue
      wt_found=1
      echo "Windows Terminal（${wt_package%%_*}）の設定を確認中..."
      if [ "$DRY_RUN" -eq 1 ]; then
        python3 "$REPO_DIR/scripts/wt-settings.py" --dry-run "$wt_settings"
      else
        python3 "$REPO_DIR/scripts/wt-settings.py" "$wt_settings"
      fi
    done
    [ "$wt_found" -eq 1 ] || echo "Windows Terminal の settings.json が見つからないためスキップ（一度起動すると作られる）"
  fi
fi

############################################
# ~/.claude/settings.json の hooks と permissions.allow（他のキーは触らない）
############################################
# hooks は dotfiles を正とし、丸ごと置き換える（手で足した hook は消える。
# 足したいときは agents/claude/hooks.json に書く）。
# __DOTFILES__ はこのリポジトリの場所に置き換える（clone 先がマシンで違ってもよいように）
# permissions.allow は手で足したルールや「常に許可」で増えたルールを残したいので、
# 丸ごと置き換えずに agents/claude/permissions.json の allow を足し、remove を消すだけにする。
# remove は起動時に警告が出る旧い書き方（Edit(*) 等）を各マシンから消すためのもの
if ! command -v jq >/dev/null 2>&1; then
  echo "jq が無いため Claude Code の hooks / permissions 設定をスキップ"
elif [ -f "$CLAUDE_SETTINGS" ] && ! jq empty "$CLAUDE_SETTINGS" 2>/dev/null; then
  echo "~/.claude/settings.json が JSON として読めないため hooks / permissions 設定をスキップ"
else
  echo "~/.claude/settings.json の hooks と permissions.allow を設定中..."
  claude_settings_tmp="$(mktemp)"
  { cat "$CLAUDE_SETTINGS" 2>/dev/null || echo '{}'; } |
    jq --arg repo "$REPO_DIR" \
      --slurpfile hooks "$CLAUDE_HOOKS_TEMPLATE" \
      --slurpfile perms "$CLAUDE_PERMISSIONS_TEMPLATE" \
      '.hooks = ($hooks[0] | walk(if type == "string" then gsub("__DOTFILES__"; $repo) else . end))
       | .permissions.allow = ((.permissions.allow // []) - $perms[0].remove - $perms[0].allow) + $perms[0].allow' \
      >"$claude_settings_tmp"
  run mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
  run mv "$claude_settings_tmp" "$CLAUDE_SETTINGS"
  rm -f "$claude_settings_tmp"
fi

############################################
# Claude Code プラグイン（一覧: agents/claude/plugins.txt）
############################################
# 未導入のものだけ入れる。一覧から消したものを外すのは破壊的なので自動ではやらず、doctor で知らせる。
# 1件失敗しても他の設定まで止めないよう、警告を出して続ける
if ! installed_plugins="$(claude_plugin_installed)"; then
  echo "claude / jq が無いか、プラグイン一覧の取得に失敗したため Claude Code プラグインの導入をスキップ"
else
  echo "Claude Code プラグインを確認中..."
  while IFS= read -r plugin_id; do
    if grep -qxF "$plugin_id" <<<"$installed_plugins"; then
      echo "  導入済み: $plugin_id"
      continue
    fi
    echo "  導入: $plugin_id"
    run claude plugin install "$plugin_id" --scope user ||
      echo "  [WARN] $plugin_id の導入に失敗しました（手動: claude plugin install $plugin_id --scope user）"
  done < <(claude_plugin_wanted)
fi

############################################
# 旧構成の残骸を掃除（1回限りの移行用）
############################################
for legacy in "${LEGACY_PATHS[@]}"; do
  if [ -L "$legacy" ]; then
    run rm "$legacy"
    echo "旧リンクを削除: $legacy"
  fi
done

############################################
# 完了
############################################
echo
echo "セットアップ完了。"
echo "次の手順:"
echo "  exec zsh       # 新しいシェルへ切り替え（次回ログインからは自動で zsh）"
echo "  dev            # プロジェクトディレクトリで実行するとセッションが立ち上がる"
echo "  dev doctor     # 健全性チェック"
echo
echo "アイコン表示には Nerd Font のインストールと端末フォント設定が必要（README のフォント節を参照）。"
if is_wsl; then
  echo
  echo "【WSL】改行キーを Ubuntu Desktop と揃える（Alt+Enter に統一）:"
  echo "  Windows Terminal の設定 → 操作 → 'Alt+Enter'（全画面切り替え）のバインドを削除"
  echo "  （GNOME Terminal は Ctrl+Enter を Enter と区別できないため Alt+Enter に寄せる）"
fi
