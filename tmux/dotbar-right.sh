#!/usr/bin/env bash
# tmux-dotbar 右側: dev エージェント稼働状況 / 負荷 / メモリ / 時刻を
# starship プロンプトと同じ「角丸チップ」デザインで並べる。
# tmux.conf の @tmux-dotbar-status-right から #() で status-interval ごとに呼ばれる。
# グリフは編集事故・文字化けを防ぐため \u エスケープで定義する
# （すべて BMP 私用領域 = 全 Nerd Font 収録・幅は常に半角）
set -u

SESSION="${1:-}"
TAB=$'\t'

CAP_L=$'\ue0b6'   # 丸カプセル左端
CAP_R=$'\ue0b4'   # 丸カプセル右端
I_CPU=$'\uf2db'   # microchip
I_MEM=$'\uf1c0'   # database
I_CLOCK=$'\uf017' # clock
DOT=$'●'

BG0="#282c34"   # tmux/starship と共通の基調背景
FG_DARK="#282c34"
C_BLUE="#61afef"
C_PURPLE="#c678dd"
C_CYAN="#56b6c2"
C_GRAY="#3e4451"
C_FG_MUTED="#dcdfe4"
C_ON="#98c379"  # CLI 稼働中のドット色
C_OFF="#5c6370" # シェルに戻った（停止）のドット色

# 角丸チップを1個組み立てる: pill <bg> <fg> <内容(tmux書式込みでOK)>
pill() {
  local bg="$1" fg="$2" content="$3"
  printf '#[fg=%s,bg=default]%s#[fg=%s,bg=%s,bold] %s #[fg=%s,bg=default]%s#[default] ' \
    "$bg" "$CAP_L" "$fg" "$bg" "$content" "$bg" "$CAP_R"
}

out=""

# dev セッションなら claude / codex / agy ペインの稼働状態をドットで表示
# （@dev_agent は bin/dev が設定。CLI が終了してシェルに戻ったペインは灰色）
if [ -n "$SESSION" ]; then
  agents=""
  while IFS="$TAB" read -r agent cmd; do
    [ -n "$agent" ] || continue
    case "$cmd" in
      bash | zsh | sh | dash | fish) color="$C_OFF" ;;
      *) color="$C_ON" ;;
    esac
    agents="${agents}#[fg=${color}]${DOT}#[fg=${C_FG_MUTED}] ${agent}  "
  done < <(tmux list-panes -s -t "=$SESSION" -F "#{@dev_agent}${TAB}#{pane_current_command}" 2>/dev/null)
  agents="${agents%  }"
  if [ -n "$agents" ]; then
    out="$(pill "$C_GRAY" "$C_FG_MUTED" "$agents")"
  fi
fi

load="$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo '?')"
mem="$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {if (t>0) printf("%d%%",(t-a)*100/t); else print "?"}' /proc/meminfo 2>/dev/null)"
clock="$(date +%H:%M)"

out="${out}$(pill "$C_BLUE" "$FG_DARK" "${I_CPU} ${load}")"
out="${out}$(pill "$C_PURPLE" "$FG_DARK" "${I_MEM} ${mem}")"
out="${out}$(pill "$C_CYAN" "$FG_DARK" "${I_CLOCK} ${clock}")"

printf '%s' "${out% }"
