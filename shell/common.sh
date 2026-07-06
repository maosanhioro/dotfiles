# bash / zsh 共通設定（エイリアス・関数・環境変数）
# bash/bashrc と zsh/zshrc の両方から source される。
# ここに書くものは両シェルで動く構文に限る（shopt / setopt は各 rc へ）。

# ローカル bin（AppImage / starship / 手動インストール）
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# lesspipe
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

############################################
# 便利系
############################################
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -alF --group-directories-first --icons=auto'
  alias la='eza -a --group-directories-first --icons=auto'
  alias l='eza -F --group-directories-first --icons=auto'
else
  alias ll='ls -alF'
  alias la='ls -A'
  alias l='ls -CF'
fi
alias ..='cd ..'
alias ...='cd ../..'
alias cls='clear'

# 環境別（WSL / Ubuntu Desktop）
if grep -qi microsoft /proc/version 2>/dev/null; then
  alias open='explorer.exe .'
else
  alias open='xdg-open .'
fi

# エディタ
if command -v nvim >/dev/null 2>&1; then
  export EDITOR="nvim"
  export VISUAL="nvim"
fi

# ツール系ヘルパー
path() { printf '%s\n' "${PATH}" | tr ':' '\n'; }
mkcd() { mkdir -p "$1" && cd "$1"; }
extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;;
      *.tar.gz) tar xzf "$1" ;;
      *.tar.xz) tar xJf "$1" ;;
      *.tar) tar xf "$1" ;;
      *.bz2) bunzip2 "$1" ;;
      *.gz) gunzip "$1" ;;
      *.xz) unxz "$1" ;;
      *.zip) unzip "$1" ;;
      *) echo "extract: unsupported file: $1" ;;
    esac
  else
    echo "extract: file not found: $1"
  fi
}

# Git ヘルパー
alias g='git'
alias gst='git status -sb'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gl='git log --oneline --graph --decorate'
alias gpl='git pull --ff-only'
alias gps='git push'
alias gpf='git push --force-with-lease'
alias gaa='git add -A'
alias gcm='git commit -m'
cproj() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
  cd "${root}" || return 1
}

# fzf ヘルパー（任意）
if command -v fzf >/dev/null 2>&1; then
  ff() {
    local file
    file="$(fzf --height=40% --reverse --border --preview 'bat --style=numbers --color=always {} 2>/dev/null || sed -n "1,200p" {}')" || return
    [ -n "${file}" ] && ${EDITOR:-nvim} "${file}"
  }
  fcd() {
    local dir
    if command -v fd >/dev/null 2>&1; then
      dir="$(fd --type d --hidden --exclude .git 2>/dev/null | fzf --height=40% --reverse --border)" || return
    else
      dir="$(find . -type d -name .git -prune -o -type d -print 2>/dev/null | fzf --height=40% --reverse --border)" || return
    fi
    [ -n "${dir}" ] && cd "${dir}"
  }
fi

############################################
# NVM（即時ロード：遅延なし）
############################################
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
fi
# bash_completion は bash 専用（zsh は compinit が担当）
if [ -n "${BASH_VERSION:-}" ] && [ -s "$NVM_DIR/bash_completion" ]; then
  . "$NVM_DIR/bash_completion"
fi
