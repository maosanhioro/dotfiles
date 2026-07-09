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

seg() {
  local color="$1" content="$2"
  printf '#[fg=%s,bold]%s#[default]' "$color" "$content"
}

sep() {
  printf ' #[fg=%s]%s#[default] ' "$C_MUTED" "$SEP"
}

out=""

# dev セッションなら各ペイン（claude / 実装エージェント / nvim）の稼働状態をドットで表示
# （@dev_agent は bin/dev が設定。@dev_status は dev-monitor が DEV_DONE/DEV_BLOCKED
# 検知時に設定する。CLI が終了してシェルに戻ったペインは灰色が最優先）
# monitor ペインは @dev_agent 未設定なので -f フィルタで最初から除外する
# （bash の read は IFS=タブでも先頭が空フィールドだと詰めてしまうため、
#   シェル側で agent=="" を弾くのではなく tmux 側で事前に絞る）
if [ -n "$SESSION" ]; then
  agents=""
  while IFS="$TAB" read -r agent cmd status; do
    case "$cmd" in
      bash | zsh | sh | dash | fish) color="$C_OFF" ;;
      *)
        case "$status" in
          blocked) color="$C_BLOCKED" ;;
          done) color="$C_DONE" ;;
          *) color="$C_ON" ;;
        esac
        ;;
    esac
    agents="${agents}#[fg=${color}]${DOT}#[fg=${C_FG}] ${agent}  "
  done < <(tmux list-panes -s -t "=$SESSION" -f "#{@dev_agent}" -F "#{@dev_agent}${TAB}#{pane_current_command}${TAB}#{@dev_status}" 2>/dev/null)
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
