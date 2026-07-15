#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook (Edit/Write/MultiEdit)。manager-pane（Claude Code）が
# 実装作業を直接行おうとしたとき、同一 dev セッションに player ペインが
# いるなら一度だけ差し戻し、AGENTS.md の委譲方針（delegate スキル参照）を
# 検討させる。委譲不要と判断してもう一度同じ操作を呼べば通す
# （無限ブロックで作業自体が止まるのを避けるワンショット設計）。
# マーカーは /tmp 配下に置く（再起動で自然に消える一時状態のため）。

input="$(cat)"

# tmux 外（hook 単体実行や dev セッション外での作業）は対象外
[ -n "${TMUX_PANE:-}" ] || exit 0

# このペインが manager-pane（Claude Code）でなければ対象外
agent="$(tmux show-options -p -qv -t "$TMUX_PANE" @dev_agent 2>/dev/null || true)"
[ "$agent" = "claude" ] || exit 0

# 同一セッションに player ペイン（codex/copilot）がいなければ委譲しようがない
session="$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}')"
has_player="$(tmux list-panes -s -t "=$session" -F '#{@dev_agent}' 2>/dev/null | grep -Ex 'codex|copilot' || true)"
[ -n "$has_player" ] || exit 0

tool_name="$(printf '%s' "$input" | jq -r '.tool_name')"
hash="$(printf '%s' "$input" | jq -r '.tool_input | tostring' | md5sum | cut -d' ' -f1)"
marker="/tmp/dev-guard-delegate.${session}.${hash}"

# 同じ呼び出しへの2回目は通す（1回の差し戻しで委譲を検討させれば十分。
# 毎回ブロックし続けるとマネージャーが自分で担うべき正当な作業まで進まなくなる）
if [ -f "$marker" ]; then
  rm -f "$marker"
  exit 0
fi
touch "$marker"

cat >&2 <<MSG
実装作業（${tool_name}）を検知しました。AGENTS.md の委譲方針に従い、
まず dev peek player でプレイヤーの状態を確認し、player-pane への委譲を
検討してください（delegate スキル参照）。委譲不要と判断した場合は、
この操作をもう一度実行すれば通ります。
MSG
exit 2
