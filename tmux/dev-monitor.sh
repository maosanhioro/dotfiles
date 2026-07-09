#!/usr/bin/env bash
# dev セッションの impl ペイン（Codex CLI / GitHub Copilot CLI）を監視し、
# AGENTS.md の規約（完了時 DEV_DONE / 続行不能時 DEV_BLOCKED: 理由 を単独行で出力）
# を検知したらデスクトップ通知を出し、dotbar-right.sh が読む @dev_status を
# 更新する（実行中=空 / 完了=done / 停止=blocked）。
# bin/dev の build_session が4本目のペインで起動する。
#
# 検知は「直近100行に DEV_DONE / DEV_BLOCKED: を含むか」の緩い一致にしている。
# TUI（入力欄・枠線・パディング）が最終行を埋めるため厳密な最終行一致は使えず、
# 枠線に囲まれて出力される可能性も考えて完全一致ではなく部分一致にしている。
# 重複通知は @dev_status で防ぐ（bin/dev の dev send が新タスク送信時にクリアする
# まで、一度 done/blocked になったペインは再走査しない）。
set -u

SESSION="${1:-}"
[ -n "$SESSION" ] || { echo "使い方: dev-monitor <session>" >&2; exit 1; }

TAB=$'\t'
INTERVAL=5
WINDOW=100

echo "監視中: ${SESSION} の impl ペイン（${INTERVAL}秒間隔、Ctrl+C で停止）"

while true; do
  while IFS="$TAB" read -r pane agent status; do
    [ -n "$pane" ] || continue
    case "$agent" in
      codex | copilot) ;;
      *) continue ;;
    esac
    [ -z "$status" ] || continue # 既に done/blocked を通知済みなら次の dev send までスキップ

    recent="$(tmux capture-pane -p -t "$pane" -S "-$WINDOW" 2>/dev/null)"

    if printf '%s\n' "$recent" | grep -q 'DEV_DONE'; then
      tmux set-option -p -t "$pane" @dev_status "done"
      echo "[$(date +%H:%M:%S)] ${agent}: 完了 (DEV_DONE)"
      command -v notify-send >/dev/null 2>&1 &&
        notify-send "dev: ${SESSION}" "${agent} が完了しました" 2>/dev/null
      continue
    fi

    blocked="$(printf '%s\n' "$recent" | grep -o 'DEV_BLOCKED:.*' | tail -n1)"
    if [ -n "$blocked" ]; then
      tmux set-option -p -t "$pane" @dev_status "blocked"
      echo "[$(date +%H:%M:%S)] ${agent}: 停止 (${blocked})"
      command -v notify-send >/dev/null 2>&1 &&
        notify-send -u critical "dev: ${SESSION}" "${agent} が停止しました: ${blocked#DEV_BLOCKED: }" 2>/dev/null
    fi
  done < <(tmux list-panes -s -t "=$SESSION" -F "#{pane_id}${TAB}#{@dev_agent}${TAB}#{@dev_status}" 2>/dev/null)

  sleep "$INTERVAL"
done
