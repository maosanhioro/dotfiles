#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"

TEMPLATE_ROOT="$REPO_DIR/agents/templates"
FORCE=0

usage() {
  cat <<'USAGE'
使い方: dev init [options]

カレントプロジェクトに AI エージェント設定を配置します:
  AGENTS.md              プロジェクト固有ルールの骨子（共通ルールは各ツールのグローバル設定から読む）。
                         --force は説明部分だけを最新化し、書き込んだ各節は残す
  CLAUDE.md              AGENTS.md へのシンボリックリンク（Claude Code 用）
  AGENT_HANDOFF_LOG.md   エージェント間の引き継ぎログ（既存があれば --force でも保持）

すべて .gitignore に追記されます（個人設定のためコミットしない前提）。

オプション:
  --force     既存ファイルを最新化（AGENTS.md は各節を保持。AGENT_HANDOFF_LOG.md は記録なので対象外）
  --dry-run   実行せずに内容だけ表示
  -h, --help  このヘルプを表示
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "不明なオプション: $arg"; usage; exit 1 ;;
  esac
done

DEST_DIR="$(pwd)"

# 追記されていく記録ファイルを配置する。既存があれば --force でも上書きしない。
# 設定ファイルは正本から再生成できるが、引き継ぎログは作業の記録そのもので
# 失うと復元できないため、--force の意味（設定を最新化する）から意図的に外している
place_once() {
  local src="$1" dst="$2"
  if [ ! -f "$src" ]; then
    echo "テンプレートが見つかりません: $src"
    exit 1
  fi
  if [ -e "$dst" ]; then
    echo "保持（記録は上書きしない）: $dst"
    return 0
  fi
  run cp -f "$src" "$dst"
  echo "配置: $dst"
}

# 共通ルールは各ツールがグローバル設定（install が張るリンク）から読むため、
# プロジェクトの AGENTS.md には固有ルールだけを置く。--force は説明部分（最初の "## " より前）だけを
# 最新のテンプレートに差し替え、ユーザーが書いた各節は残す。旧形式（共通ルールを前に結合していたもの）も
# 固有ルールの見出しを目印に同じ処理で移行される
place_agents_md() {
  local template="$1" dst="$2"
  if [ ! -f "$template" ]; then
    echo "テンプレートが見つかりません: $template"
    exit 1
  fi

  if [ ! -e "$dst" ]; then
    run cp -f "$template" "$dst"
    echo "配置: $dst"
    return 0
  fi

  local marker_line
  marker_line="$(grep -n -m1 "^${PROJECT_RULES_MARKER}" "$dst" | cut -d: -f1 || true)"

  if [ "$FORCE" -ne 1 ]; then
    if [ -n "$marker_line" ] && [ "$marker_line" -gt 1 ]; then
      echo "スキップ（既存）: $dst  ※共通ルールを結合した旧形式。dev init --force で固有ルールだけに移行できる（各節は残る）"
    else
      echo "スキップ（既存）: $dst  ※説明部分の最新化は --force（各節は残る）"
    fi
    return 0
  fi

  # 目印が無いファイルは何が書かれているか分からないため、--force でも上書きしない
  if [ -z "$marker_line" ]; then
    echo "スキップ: $dst に「${PROJECT_RULES_MARKER}」の見出しが無いため上書きしません（中身を退避してから再実行してください）"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %s の説明部分を最新化し、%s 行目以降の各節を残す\n' "$dst" "$marker_line"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  {
    # テンプレートの説明部分（最初の "## " の手前まで）
    awk '/^## /{exit} {print}' "$template"
    # 既存ファイルの、目印の見出しより後ろにある最初の "## " から末尾まで
    awk -v start="$marker_line" 'NR > start && /^## /{found=1} found{print}' "$dst"
  } >"$tmp"
  # 既存側に "## " の節が1つも無ければ、テンプレートの各節をそのまま使う
  if ! grep -q '^## ' "$tmp"; then
    awk '/^## /{found=1} found{print}' "$template" >>"$tmp"
  fi
  mv "$tmp" "$dst"
  echo "更新: $dst（説明部分を最新化、各節は保持）"
}

place_link() {
  local target="$1" link="$2"
  if [ -e "$link" ] && [ ! -L "$link" ] && [ "$FORCE" -ne 1 ]; then
    echo "スキップ（既存の実ファイル）: $link  ※上書きは --force"
    return 0
  fi
  run ln -sfn "$target" "$link"
  echo "リンク: $link -> $target"
}

# .gitignore にべき等で追記
gitignore_add() {
  local entry="$1"
  local gitignore="$DEST_DIR/.gitignore"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] .gitignore に追記: %s\n' "$entry"
    return 0
  fi
  if grep -qxF "$entry" "$gitignore" 2>/dev/null; then
    return 0
  fi
  if ! grep -qxF "$GITIGNORE_HEADER" "$gitignore" 2>/dev/null; then
    printf '\n%s\n' "$GITIGNORE_HEADER" >>"$gitignore"
  fi
  printf '%s\n' "$entry" >>"$gitignore"
  echo ".gitignore に追記: $entry"
}

place_agents_md "$TEMPLATE_ROOT/AGENTS.md" "$DEST_DIR/AGENTS.md"
gitignore_add "AGENTS.md"

place_link "AGENTS.md" "$DEST_DIR/CLAUDE.md"
gitignore_add "CLAUDE.md"

place_once "$TEMPLATE_ROOT/AGENT_HANDOFF_LOG.md" "$DEST_DIR/AGENT_HANDOFF_LOG.md"
gitignore_add "AGENT_HANDOFF_LOG.md"

echo ""
echo "完了: $DEST_DIR（プロジェクト固有ルールは AGENTS.md を編集してください）"
