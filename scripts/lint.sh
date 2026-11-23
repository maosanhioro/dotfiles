#!/usr/bin/env bash
# 渡されたファイルを種類ごとに検査する（シェル: 構文 + shellcheck、JSON: jq、TOML: tomllib）。
# テストも CI もないため、壊れたまま気づかない状態を減らすのが目的。
# 呼び出し元: .claude/hooks/lint-edited-file.sh（Claude の編集直後）、.githooks/pre-commit（誰の変更でもコミット時）
# 使い方: scripts/lint.sh FILE...   問題があれば内容を stderr に出して exit 1
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

# 種類を判定して出す: bash / zsh / json / toml / 空（対象外）
file_kind() {
  local file="$1" rel="${1#"$REPO_DIR"/}" first_line
  case "$rel" in
    zsh/zshrc) echo zsh; return ;;
    *.sh | bin/dev | bash/bashrc) echo bash; return ;;
    *.json) echo json; return ;;
    *.toml) echo toml; return ;;
  esac
  first_line="$(head -n 1 "$file")"
  case "$first_line" in
    '#!'*bash* | '#!'*/sh | '#!'*' sh') echo bash ;;
  esac
}

# 1ファイルを検査する。問題があれば stderr に書いて失敗を返す
lint_one() {
  local file="$1" rel="${1#"$REPO_DIR"/}" kind output
  kind="$(file_kind "$file")"
  case "$kind" in
    bash)
      if ! output="$(bash -n "$file" 2>&1)"; then
        printf '%s: bash 構文エラー（bash -n）\n%s\n' "$rel" "$output" >&2
        return 1
      fi
      # 未導入のマシンもあるので、無ければ構文チェックだけにする（doctor が未導入を知らせる）
      command -v shellcheck >/dev/null 2>&1 || return 0
      # common.sh は bash と zsh の両方から読まれるが、書き方は bash に揃えている
      if ! output="$(cd "$REPO_DIR" && shellcheck -S warning --shell=bash -x "$file" 2>&1)"; then
        printf '%s: shellcheck の警告\n%s\n' "$rel" "$output" >&2
        return 1
      fi
      ;;
    zsh)
      if ! output="$(zsh -n "$file" 2>&1)"; then
        printf '%s: zsh 構文エラー（zsh -n）\n%s\n' "$rel" "$output" >&2
        return 1
      fi
      ;;
    json)
      command -v jq >/dev/null 2>&1 || return 0
      if ! output="$(jq empty "$file" 2>&1)"; then
        printf '%s: JSON として読めません（jq）\n%s\n' "$rel" "$output" >&2
        return 1
      fi
      ;;
    toml)
      # tomllib は Python 3.11 以降。無ければ飛ばす
      python3 -I -c 'import tomllib' 2>/dev/null || return 0
      if ! output="$(python3 -I -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$file" 2>&1)"; then
        printf '%s: TOML として読めません（tomllib）\n%s\n' "$rel" "$(printf '%s\n' "$output" | tail -n 1)" >&2
        return 1
      fi
      ;;
  esac
}

failed=0
for file in "$@"; do
  [ -f "$file" ] || continue
  lint_one "$(readlink -f "$file")" || failed=1
done
exit "$failed"
