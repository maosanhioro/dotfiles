#!/usr/bin/env bash
# dev-pick: いま見えているペインの内容から行を選び、shell ペインへ流し込む。
#
# エージェントの CLI（Claude Code / Codex / Copilot）は代替画面で動くため
# tmux 側にスクロールバックが積まれず、コピーモードで拾えるのは可視領域だけ。
# どのみち可視領域しか取れないなら、行の選択そのものを fzf に任せた方が速い。
#
# --url を付けると URL だけを候補にし、Enter でブラウザを開く（prefix + u）。
#
# 試用中の機能。やめるときは tmux.conf の該当ブロックと
# lib.sh の LINKS 行、このファイルを消して ~/.local/bin/dev-pick を rm する。
set -euo pipefail

TAB=$'\t'

die() {
  echo "dev-pick: $*" >&2
  exit 1
}

mode="lines"
if [ "${1:-}" = "--url" ]; then
  mode="url"
  shift
fi

# tmux のバージョンによっては display-popup の引数でフォーマットが展開されず、
# "#{pane_id}" という文字列がそのまま渡る。ID の形をしていなければ現在のペインに落とす
pane="${1:-}"
case "$pane" in
  %[0-9]*) ;;
  *) pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null)" ;;
esac
[ -n "$pane" ] || die "対象ペインを特定できません"

command -v fzf >/dev/null 2>&1 || die "fzf がありません（./scripts/install.sh で導入されます）"

# WSL は appendWindowsPath=false で explorer.exe が PATH に無いため絶対パスで呼ぶ。
# wslu（wslview）は 2025 年にアーカイブされたので使わない
open_url() {
  local url="$1"
  if [ -x /mnt/c/Windows/explorer.exe ]; then
    # explorer.exe は成功しても終了コード 1 を返すことがあるため結果を見ない
    /mnt/c/Windows/explorer.exe "$url" >/dev/null 2>&1 || true
    return 0
  fi
  command -v xdg-open >/dev/null 2>&1 || return 1
  # ポップアップが閉じると子プロセスも終わるため、setsid で切り離す
  setsid xdg-open "$url" >/dev/null 2>&1 </dev/null &
}

# URL モード。-J で端末の折り返しを繋いでから抜き出す（TUI が自前で改行した
# 長い URL は繋がらないため途中で切れることがある）。文末の句読点や閉じ括弧は落とす
if [ "$mode" = "url" ]; then
  urls="$(
    tmux capture-pane -p -J -t "$pane" |
      grep -oE "https?://[^][:space:]\"'<>(){}|^\`[]+" |
      sed -E 's/[.,;:!?]+$//' |
      awk '!seen[$0]++'
  )" || true
  [ -n "$urls" ] || die "ペインに URL が見当たりません"

  selected="$(
    printf '%s\n' "$urls" |
      fzf --no-sort --tac --expect=ctrl-y \
        --prompt='url> ' \
        --header='Enter: ブラウザで開く / Ctrl-Y: コピーのみ'
  )" || exit 0
  key="$(printf '%s\n' "$selected" | head -n1)"
  url="$(printf '%s\n' "$selected" | tail -n +2)"
  [ -n "$url" ] || exit 0

  if [ "$key" = "ctrl-y" ]; then
    printf '%s' "$url" | tmux load-buffer -w -b devpick -
    tmux display-message "dev-pick: URL をコピーしました"
    exit 0
  fi
  open_url "$url" || die "URL を開くコマンドがありません（xdg-open も explorer.exe も見つからない）"
  tmux display-message "dev-pick: 開きました ${url}"
  exit 0
fi

# 可視領域を候補行に整形する。前後の空白を落とし、空行と枠線だけの行を捨て、
# 同じ文字列は 1 つにまとめる（TUI が毎行描くステータス行で候補が埋まるのを防ぐ）
candidates="$(
  tmux capture-pane -p -t "$pane" |
    sed -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' |
    grep -vE '^$' |
    grep -vE '^[─━│┃╭╮╰╯├┤┌┐└┘]+$' |
    awk '!seen[$0]++'
)"
[ -n "$candidates" ] || die "ペインから取り出せる行がありません"

# --expect を付けると 1 行目に押されたキー名（Enter なら空行）が来る
selected="$(
  printf '%s\n' "$candidates" |
    fzf --no-sort --tac --multi --expect=ctrl-y \
      --prompt='pick> ' \
      --header='Enter: shell ペインへ入力（実行はしない） / Ctrl-Y: コピーのみ / Tab: 複数選択'
)" || exit 0 # ESC で抜けたときの 130 を正常終了として扱う

key="$(printf '%s\n' "$selected" | head -n1)"
text="$(printf '%s\n' "$selected" | tail -n +2)"
[ -n "$text" ] || exit 0

# -w は OSC 52 で端末へ渡す。clip.exe / wl-copy / xclip の分岐が要らないうえ、
# WSL 側は appendWindowsPath=false で clip.exe が PATH に無いため -w しか通らない
printf '%s' "$text" | tmux load-buffer -w -b devpick -

if [ "$key" = "ctrl-y" ]; then
  tmux display-message "dev-pick: クリップボードへコピーしました"
  exit 0
fi

session="$(tmux display-message -p -t "$pane" '#{session_name}')"
# shell ペインは dev build_session が @dev_agent を設定しない唯一のペイン。
# CLI が落ちてシェルに戻ったエージェントペインを掴まないよう、その条件も併せて見る。
# このシェル名リストは bin/dev の is_shell_command・tmux/dotbar-right.sh の
# 稼働判定と同じもの。変えるときは3箇所とも
shell_pane="$(
  tmux list-panes -s -t "=$session" \
    -F "#{pane_id}${TAB}#{@dev_agent}${TAB}#{pane_current_command}" |
    awk -F'\t' '$2 == "" && ($3 == "zsh" || $3 == "bash" || $3 == "sh" || $3 == "dash" || $3 == "fish") { print $1; exit }'
)"
if [ -z "$shell_pane" ]; then
  tmux display-message "dev-pick: shell ペインが無いためコピーのみ行いました"
  exit 0
fi

# 改行入りを send-keys で送ると行ごとに実行されてしまうため bracketed paste で渡す
# （dev send と同じ理由）。どちらの経路でも Enter は押さない＝実行するかは人が決める
if [ "${text//$'\n'/}" != "$text" ]; then
  tmux paste-buffer -p -b devpick -t "$shell_pane"
else
  tmux send-keys -t "$shell_pane" -l -- "$text"
fi
tmux select-pane -t "$shell_pane"
