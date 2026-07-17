#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook (Edit/Write/MultiEdit)。manager-pane（Claude Code）が
# プロジェクト配下のコードへ直接実装を始めようとしたとき、同一 dev セッションに
# 稼働中の player ペイン（codex/copilot）がいるなら差し戻し、AGENTS.md の
# 委譲方針（delegate スキル参照）を検討させる。
#
# - 差し戻しは Claude Code の会話（session_id）につき1回だけ。以後の実装作業は
#   すべて通す（毎回ブロックすると正当な作業まで止まるため）
# - 対象はプロジェクト（@dev_path）配下のコードファイルのみ。*.md と
#   プロジェクト外（scratchpad 等）は計画・メモ書きなので素通しする
# - プレイヤーの状態（dev status 相当）をメッセージに同梱し、差し戻し後に
#   マネージャーが dev peek で確認しに行く往復を省く
# - マーカーは /tmp 配下に置く（再起動で自然に消える一時状態のため）

input="$(cat)"

# tmux 外（hook 単体実行や dev セッション外での作業）は対象外
[ -n "${TMUX_PANE:-}" ] || exit 0

# このペインが manager-pane（Claude Code）でなければ対象外
agent="$(tmux show-options -p -qv -t "$TMUX_PANE" @dev_agent 2>/dev/null || true)"
[ "$agent" = "claude" ] || exit 0

# この会話で案内済みなら通す（共通経路なので早めに判定して安く抜ける）
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"
[ -n "$session_id" ] || exit 0
marker="/tmp/dev-guard-delegate.conv.${session_id}"
[ ! -e "$marker" ] || exit 0

# プロジェクト配下のコードファイルだけを実装作業とみなす
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
project_root="$(tmux display-message -p -t "$TMUX_PANE" '#{@dev_path}')"
{ [ -n "$file_path" ] && [ -n "$project_root" ]; } || exit 0
case "$file_path" in
  *.md) exit 0 ;;
  "$project_root"/*) ;;
  *) exit 0 ;;
esac

# 同一セッションに player ペインがいなければ委譲しようがない
session="$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}')"
player_pane="$(tmux list-panes -s -t "=$session" -F "#{pane_id}	#{@dev_agent}" 2>/dev/null |
  awk -F'\t' '$2 == "codex" || $2 == "copilot" { print $1; exit }')"
[ -n "$player_pane" ] || exit 0

# プレイヤーの CLI が終了してシェルに戻っているなら委譲できないので素通し
# （このシェル名リストは bin/dev の is_shell_command と対で、変えるときは両方）
current="$(tmux display-message -p -t "$player_pane" '#{pane_current_command}')"
case "$current" in
  bash | zsh | sh | dash | fish) exit 0 ;;
esac

# 委譲判断の材料としてプレイヤーの状態を同梱する（dev status player 相当）
state="$(tmux show-options -p -qv -t "$player_pane" @dev_status 2>/dev/null || true)"
reason="$(tmux show-options -p -qv -t "$player_pane" @dev_reason 2>/dev/null || true)"
case "$state" in
  done) player_state="done（前タスク完了・待機中）" ;;
  blocked) player_state="blocked${reason:+: $reason}（前タスクで停止報告あり）" ;;
  *) player_state="running（CLI 稼働中・報告なし。前タスク作業中の可能性があれば dev peek player で確認）" ;;
esac

tool_name="$(printf '%s' "$input" | jq -r '.tool_name')"
touch "$marker"

cat >&2 <<MSG
実装作業（${tool_name}: ${file_path}）を検知しました。AGENTS.md の委譲方針に
従い、player-pane への委譲を検討してください（delegate スキル参照）。
プレイヤーの状態: ${player_state}
この案内はこの会話につき一度だけです。委譲不要と判断した場合は、同じ操作を
もう一度実行してください。以後の実装作業はブロックされません。
MSG
exit 2
