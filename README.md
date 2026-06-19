# dotfiles

AI アシスト開発に最適化した個人 dotfiles。
tmux 作業レイアウト自動生成・Neovim LSP 環境・AI エージェントのグローバル設定一元管理を含む。

対象: WSL2 (Ubuntu) / Ubuntu Desktop / Windows ローカル VS Code

---

## セットアップ

### WSL / Ubuntu（初回）

```bash
git clone <your repo> ~/dotfiles
cd ~/dotfiles
chmod +x bin/dotfiles bin/aidev
bin/dotfiles install
source ~/.bashrc
```

以下を一括で行います:

- 必要パッケージのインストール（tmux / nvim / rg / fd / fzf / bat / eza / pipx）
- dotfiles のシンボリックリンクを張る（gitconfig / bashrc / tmux.conf / nvim）
- AI グローバル設定のリンクを張る（Claude Code / Codex CLI / Antigravity CLI / Copilot）
- `dotfiles` / `aidev` コマンドを `~/.local/bin/` に配置

### Windows ローカル VS Code（初回）

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dotfiles/install-windows.ps1
```

Copilot instructions を `%APPDATA%/Code*/User/instructions/` に配置します。

---

## コマンドリファレンス

### dotfiles — マシン環境の管理

```bash
dotfiles install          # 環境セットアップ（パッケージ導入 + リンク張り）
dotfiles uninstall        # シンボリックリンクをすべて外す（実ファイルは残る）
dotfiles doctor           # 依存コマンドとリンクの健全性チェック
```

| オプション | 説明 |
| --- | --- |
| `--dry-run` | 実行せずに内容だけ表示 |
| `--force` | Neovim を再インストール / 既存リンクを再作成 |
| `--no-sudo` | sudo を使わない（特殊環境向け） |

### aidev — プロジェクト単位の AI 環境管理

プロジェクトルートで実行します。

```bash
# プリセット（推奨）
aidev init --personal     # 個人開発用: Codex CLI + Claude Code + Antigravity + AGENT_HANDOFF_LOG.md
aidev init --work         # 会社用:     Copilot + Claude Code + AGENT_HANDOFF_LOG.md

# 個別指定
aidev init                # 全ファイルを配置
aidev init claude         # CLAUDE.md を配置
aidev init codex          # SKILL.md を配置
aidev init copilot        # .github/copilot-instructions.md を配置
aidev init antigravity    # .antigravity.md を配置
aidev init agents         # AGENT_HANDOFF_LOG.md を配置

# 削除（対応する .gitignore エントリも除去）
aidev clean               # 全ファイルを削除
aidev clean [claude|codex|copilot|antigravity|agents]

# Copilot team agents / skills テンプレートの配置
aidev copilot team --dest /path/to/repo
aidev copilot team --dest . --agents-only

# Codex SKILL.md テンプレートの配置
aidev codex skill --project --dest /path/to/repo
aidev codex skill --subproject --dest ./apps/foo
```

`aidev init` は配置と同時に対象ファイルを `.gitignore` に追記します（べき等）。
`--force` で既存ファイルを上書き、`--dry-run` で確認のみ。

**Copilot Team Agents（チーム開発向け）**

`aidev copilot team` で役割分担エージェントのテンプレートを配置します。

| エージェント | 役割 |
| --- | --- |
| `planner` | 要件整理、作業分解、未確定事項の洗い出し |
| `architect` | 設計判断、トレードオフ比較、移行方針の整理 |
| `developer` | 最小差分の実装、検証、ドキュメント更新 |
| `reviewer` | バグ、回帰、テスト不足、設計劣化の検出 |

Skills: `project-intake` / `architecture-tradeoffs` / `implementation-safety` / `review-checklist`

### tmux — AI セッション管理

```bash
ta                        # 画面幅に応じてレイアウトを自動選択して起動
ta --layout normal        # レイアウトを明示指定
tan / tacc                # normal / compact のショートカット
ta --agent agy            # 使用するエージェントを指定
tl                        # セッション一覧
tk                        # ai-assist セッション終了
tmr                       # tmux 設定再読込
```

`--agent` は `copilot` / `codex` / `claude` / `agy` を指定できます。

---

## AI エージェント設定

### グローバル設定（マシン全体・自動適用）

`dotfiles install` 実行時にシンボリックリンクが張られ、即時有効になります。
正本を編集すればシンボリックリンク経由で即時反映されます（再インストール不要）。

| エージェント | リンク先 | 正本ファイル |
| --- | --- | --- |
| Claude Code（CLI / VSCode拡張） | `~/.claude/CLAUDE.md` | `claude/CLAUDE.md` |
| Codex CLI | `~/.codex/AGENTS.md` / `~/.codex/config.toml` | `codex/AGENTS.md` / `codex/config.toml` |
| Antigravity CLI（`agy`） | `~/.gemini/GEMINI.md` | `antigravity/GEMINI.md` |
| GitHub Copilot（VSCode） | `~/.vscode-server/data/User/instructions/` | `vscode/instructions/personal-dev-rules.instructions.md` |

### プロジェクト設定（aidev init で配置）

プロジェクトルートに配置するファイルは、グローバル設定の「プロジェクト固有の上書き・補足」として機能します。
配置したファイルはすべて `.gitignore` に自動追記されます（個人設定のためコミット不要）。

| ファイル | 対象 |
| --- | --- |
| `CLAUDE.md` | Claude Code |
| `SKILL.md` | Codex CLI |
| `.antigravity.md` | Antigravity CLI |
| `.github/copilot-instructions.md` | GitHub Copilot |
| `AGENT_HANDOFF_LOG.md` | 全エージェント共通（引き継ぎログ） |

### エージェント間協調（AGENT_HANDOFF_LOG.md）

複数の AI エージェントが同一プロジェクトで作業する際の引き継ぎノートです。
各エージェントはアクション前に末尾を読み、変更後に追記します。

```markdown
## [YYYY-MM-DD] {エージェント名} — {変更の概要}

**Intent**  変更の背景と意図
**Files**   変更したファイルの一覧
**Result**  結果・申し送り事項
**Status**: pending | in_progress | done
```

---

## ファイル構成

```
dotfiles/
├── bin/
│   ├── dotfiles          # dotfiles install / uninstall / doctor
│   └── aidev             # aidev init / clean / copilot team / codex skill
├── scripts/
│   ├── dotfiles/         # install / uninstall / doctor / install-windows
│   └── aidev/            # init / clean / copilot-team / codex-skill
├── templates/            # aidev init が配置するプロジェクトテンプレート
│   ├── CLAUDE.md
│   ├── antigravity.md
│   ├── copilot-instructions.md
│   └── AGENT_HANDOFF_LOG.md
├── claude/
│   └── CLAUDE.md         # Claude Code グローバル設定
├── codex/
│   ├── AGENTS.md         # Codex CLI グローバル指示
│   ├── config.toml       # SKILL.md 自動認識設定
│   ├── skills/dev/       # Codex CLI グローバルスキル
│   └── skills-templates/ # プロジェクト配布テンプレート（SKILL.md）
├── antigravity/
│   └── GEMINI.md         # Antigravity CLI グローバル設定
├── vscode/
│   └── instructions/     # GitHub Copilot グローバル設定
├── copilot/
│   ├── agents-templates/ # Copilot team agents テンプレート
│   └── skills-templates/ # Copilot team skills テンプレート
├── bash/                 # bash 設定（共通 / WSL / Ubuntu）
├── tmux/                 # tmux 設定（共通 / WSL / Ubuntu）
├── nvim/                 # Neovim 設定
└── git/                  # Git 設定
```

---

## リファレンス

### tmux レイアウト

**normal**（27インチ前後・4ペイン）
```
┌────────────┬──────────────────────┐
│ codex      │ nvim                 │
├────────────┼──────────────────────┤
│ shell      │ test/build           │
└────────────┴──────────────────────┘
```

**compact**（狭い画面・2ペイン）
```
┌───────────────────────────────┐
│ codex                         │
├───────────────────────────────┤
│ shell                         │
└───────────────────────────────┘
```

- セッション名: `ai-assist` / ウィンドウ名: `ws`
- SSH 接続時は自動で `ta` を起動
- `normal` は `claude` / `agy` を補助 window に作成
- `compact` は `codex` / `claude` / `agy` を補助 window に作成

### tmux キーバインド

| キー | 動作 |
| --- | --- |
| `Prefix` | `Ctrl-]` |
| `\|` / `-` | 垂直 / 水平分割 |
| `h/j/k/l` | ペイン移動 |
| `Alt-h/j/k/l` | ペイン移動（Prefix不要） |
| `H/J/K/L` | ペインのリサイズ |
| `r` | 設定の再読込 |
| `Ctrl-s` | synchronize-panes トグル |
| `X` | セッション終了（確認あり） |
| `Q` | tmux サーバー終了（確認あり） |

### Neovim キーマップ

| キー | 動作 |
| --- | --- |
| `Space w` / `Space q` | 保存 / 終了 |
| `-` | ファイルエクスプローラ（oil） |
| `Space ff` / `fg` / `fb` | ファイル / Ripgrep / バッファ 検索 |
| `K` | hover（LSP） |
| `gd` / `gr` | 定義へ移動 / 参照一覧 |
| `Space rn` / `ca` / `f` / `e` | リネーム / コードアクション / フォーマット / 行診断 |
| `Space xx` | Trouble トグル |
| `[h` / `]h` | Git hunk の前後移動 |
| `Space hs` / `hr` / `hb` | hunk stage / reset / blame |
| `Space qs` / `ql` | セッション復元 / 直近復元 |

### Bash エイリアス

```bash
# ディレクトリ
ll / la / l          # ls 系（eza があれば eza を使用）
.. / ...             # 上の階層
mkcd <dir>           # 作成して移動
cproj                # Git ルートに移動
ff / fcd             # fzf でファイル選択 / ディレクトリ移動

# Git
gst                  # git status -sb
gco / gcb            # checkout / checkout -b
gl                   # log --oneline --graph
gpl / gps / gpf      # pull --ff-only / push / push --force-with-lease
gaa / gcm            # add -A / commit -m

# その他
extract <file>       # アーカイブ展開
path                 # PATH を1行ずつ表示
```
