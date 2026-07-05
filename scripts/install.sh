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
echo "  source ~/.bashrc"
echo "  dev            # プロジェクトディレクトリで実行するとセッションが立ち上がる"
echo "  dev doctor     # 健全性チェック"
