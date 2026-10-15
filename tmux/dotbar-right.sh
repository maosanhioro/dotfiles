#!/usr/bin/env bash
# tmux-dotbar 右側: dev エージェント稼働状況 / 負荷 / メモリ / 時刻。
# 背景色で塗ったカプセル記号（旧デザイン）は GNOME Terminal(VTE) で上端が欠けて
# 描画される既知の不具合があったため廃止し、前景色のテキスト＋アイコンと
# 通常の罫線文字（│）区切りだけで表現する（starship.toml と揃えた方針）。
# tmux.conf の @tmux-dotbar-status-right から #() で status-interval ごとに呼ばれる。
set -u

SESSION="${1:-}"
TAB=$'\t'

I_CPU=$''   # microchip
I_MEM=$''   # database
I_CLOCK=$'' # clock
DOT=$'●'
SEP='│'

C_BLUE="#61afef"
C_PURPLE="#c678dd"
C_CYAN="#56b6c2"
C_MUTED="#5c6370"
C_FG="#dcdfe4"
C_ON="#98c379"     # CLI 稼働中のドット色
C_OFF="#5c6370"    # シェルに戻った（停止）のドット色
C_DONE="#e5c07b"   # dev-monitor が DEV_DONE を検知（レビュー待ち）
C_BLOCKED="#e06c75" # dev-monitor が DEV_BLOCKED を検知（要対応）
C_WAITING="#d19a66" # hook: 承認・回答待ち（人が対応しないと進まない）
IDLE_DOT=$'○'       # hook: ターン終了・入力待ち（色は稼働中と同じで中抜き）

seg() {
  local color="$1" content="$2"
  printf '#[fg=%s,bold]%s#[default]' "$color" "$content"
}

sep() {
  printf ' #[fg=%s]%s#[default] ' "$C_MUTED" "$SEP"
}

out=""

# dev セッションなら各ペイン（claude / プレイヤー）の稼働状態をドットで表示
# （@dev_agent は bin/dev が設定。@dev_status はプレイヤーが dev report で設定する）
# 色の優先順位: blocked（要対応）は CLI がクラッシュ/終了してシェルに戻っていても
# 赤を維持する。done はタスク単位の状態なので CLI 終了（灰）に譲る。
# @dev_agent 未設定のペインは -f フィルタで最初から除外する
# （bash の read は IFS=タブでも先頭が空フィールドだと詰めてしまうため、
#   シェル側で agent=="" を弾くのではなく tmux 側で事前に絞る）
if [ -n "$SESSION" ]; then
  agents=""
  # @dev_attention は各 CLI の hooks が bin/dev hook 経由で設定する（未導入なら常に空）。
  # 優先順位: blocked > シェルに戻った > waiting（承認待ち）> done > idle > 稼働中
  # タブは IFS の空白扱いで連続すると1つに詰められ、空の status の位置に attention が
  # ずれて入る。そのため status / attention には s: / a: を前置して空にしない
  while IFS="$TAB" read -r agent cmd status attention; do
    status="${status#s:}"
    attention="${attention#a:}"
    dot="$DOT"
    if [ "$status" = "blocked" ]; then
      color="$C_BLOCKED"
    else
      # このシェル名リストは bin/dev の is_shell_command・tmux/pick.sh の
      # shell ペイン同定と同じもの。変えるときは3箇所とも
      case "$cmd" in
        bash | zsh | sh | dash | fish) color="$C_OFF" ;;
        *)
          if [ "$attention" = "waiting" ]; then
            color="$C_WAITING"
          elif [ "$status" = "done" ]; then
            color="$C_DONE"
          else
            color="$C_ON"
            [ "$attention" = "idle" ] && dot="$IDLE_DOT"
          fi
          ;;
      esac
    fi
    agents="${agents}#[fg=${color}]${dot}#[fg=${C_FG}] ${agent}  "
  done < <(tmux list-panes -s -t "=$SESSION" -f "#{@dev_agent}" -F "#{@dev_agent}${TAB}#{pane_current_command}${TAB}s:#{@dev_status}${TAB}a:#{@dev_attention}" 2>/dev/null)
  agents="${agents%  }"
  [ -n "$agents" ] && out="${agents}$(sep)"
fi

load="$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo '?')"
mem="$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {if (t>0) printf("%d%%",(t-a)*100/t); else print "?"}' /proc/meminfo 2>/dev/null)"
clock="$(date +%H:%M)"

out="${out}$(seg "$C_BLUE" "${I_CPU} ${load}")$(sep)"
out="${out}$(seg "$C_PURPLE" "${I_MEM} ${mem}")$(sep)"
out="${out}$(seg "$C_CYAN" "${I_CLOCK} ${clock}")"

printf '%s ' "${out}"
