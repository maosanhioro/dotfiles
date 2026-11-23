# プロジェクトごとに入れる Claude Code 拡張の候補

全環境共通のもの（`agents/claude/plugins.txt`、install が入れる）とは別に、**必要なプロジェクトにだけ**入れる候補。
判定の根拠は 2026-11-23 の二段検証（Instagram リール由来の拡張55件。実物を clone してフック試行・strace 計測）。

Claude への指示（agents/AGENTS.md から参照される）:
作業が下の「使う場面」に当てはまったら、該当する候補の導入を一言提案する。**承認なしに入れない。**
既に入っているか、ユーザーが見送ると言ったものは繰り返し提案しない。

既定の入れ方は `--scope local`（`<project>/.claude/settings.local.json`、git 管理外）。
チームで共有したいプロジェクトだけ `--scope project`（`.claude/settings.json`、コミット対象）にする。

| 候補 | 使う場面 | 入れ方 | 注意 |
|---|---|---|---|
| frontend-design（Anthropic 公式） | Web の画面・LP・ダッシュボードなど UI を作り始めたとき | `claude plugin install frontend-design@anthropic-plugin-directory --scope local` | プロンプトのみ。フック・スクリプトなし |
| Stop Slop（hardikpandya/stop-slop） | README・記事・ドキュメントなど人が読む文章が主な成果物のとき | 下の「Stop Slop の入れ方」 | マーケットプレイスに無い単体スキル。Markdown のみ |
| Playwright MCP（Microsoft 公式） | ブラウザでの動作確認・E2E・スクリーンショットが要るとき | 下の「Playwright MCP の入れ方」 | 組み込みディレクトリの `playwright` プラグインは `@latest`・非 isolated なので使わない |
| Trail of Bits の監査系（differential-review、insecure-defaults、supply-chain-risk-auditor 等） | 公開前のセキュリティ監査、依存の見直し、差分のセキュリティレビュー | `claude plugin marketplace add trailofbits/skills --scope local` → `claude plugin install <name>@trailofbits --scope local` | 個別に選ぶ。gh-cli / modern-python / fp-check / zeroize-audit はフックで挙動が変わる（Stop 毎の LLM 呼び出し、pip install の拒否等）ため理由がある場合のみ |
| skill-creator（Anthropic 公式） | 繰り返す手順を自分のスキルにしたいとき | `claude plugin install skill-creator@anthropic-plugin-directory --scope local` | Python スクリプトあり（評価・ベンチマーク用） |

## Stop Slop の入れ方

検証したコミット `8da1f03` に固定してコピーする（`npx skills add` は skills CLI のテレメトリが既定で有効なので使わない）。

```bash
tmp="$(mktemp -d)"
git clone -q https://github.com/hardikpandya/stop-slop "$tmp/stop-slop"
git -C "$tmp/stop-slop" checkout -q 8da1f03
mkdir -p .claude/skills/stop-slop
cp -r "$tmp/stop-slop/SKILL.md" "$tmp/stop-slop/references" .claude/skills/stop-slop/
rm -rf "$tmp"
```

`.claude/skills/stop-slop/` をコミットするか git 管理外にするかはプロジェクトごとに決める。

## Playwright MCP の入れ方

版を固定し、プロファイルをディスクに残さない `--isolated` で起動する。
既定で有効な `browser_run_code_unsafe`（ツール自身の説明で「RCE 相当」）は権限で拒否する。

```bash
claude mcp add playwright --scope local -- npx @playwright/mcp@0.0.86 --isolated
```

`<project>/.claude/settings.local.json` の `permissions.deny` に `"mcp__playwright__browser_run_code_unsafe"` を足す。
`mcp__playwright__*` のようなワイルドカードでの許可はしない。版を上げるときは変更点を確かめてから。

## ここに載せないもの

入れない判断をしたもの: Superpowers と Agent Skills（どちらか一方を全体で試す段階的な候補で、プロジェクト単位ではない）、
security-guidance（初回に約422MB の venv を版未固定で自動作成、毎ターン Opus でレビュー）、hookify、OpenAI Codex プラグイン、
claude-mem、Agent Reach、explanatory-output-style。
