# dotfiles

AI エージェント並列運用を前提とした開発環境の dotfiles。

- **対象環境**: Ubuntu (WSL2) / Ubuntu Desktop
- **ツール**: tmux, Neovim (LazyVim), Claude Code, Codex CLI, Antigravity CLI (agy, 任意)
- **思想**:
  - 1 プロジェクト = 1 tmux セッション。`dev` 一発で 3 ペイン（Claude Code / Codex / agy or nvim）が立ち上がる
  - Claude Code = 設計・監督、Codex = 実装、agy = 第三者レビュー。最終判断は人間
  - AI への指示ファイルは単一正本（`agents/AGENTS.md`）から全ツールへリンク。編集は 1 箇所
  - 依存は負債。bash + tmux + coreutils だけで動く

## セットアップ

```bash
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./scripts/install.sh        # パッケージ導入 + シンボリックリンク（--dry-run で内容確認可）
source ~/.bashrc
dev doctor                   # 健全性チェック
```

初回の nvim 起動時に LazyVim がプラグインを自動導入する（数分）。

## dev コマンド

覚えるコマンドは `dev` だけ。

| コマンド | 動作 |
| --- | --- |
| `dev` | カレントプロジェクト（git ルート単位）のセッションを作成 or アタッチ |
| `dev up <path>` | 指定パスのプロジェクトを開く |
| `dev ls` | dev セッション一覧 |
| `dev kill [name]` | セッション削除（`--all` で全部） |
| `dev send <agent> <msg>` | claude / codex / agy ペインへメッセージ送信（`-` で標準入力) |
| `dev peek <agent> [-n N]` | エージェントペインの直近出力を表示 |
| `dev init` / `dev clean` | プロジェクトの AI 設定ファイルを配置 / 削除 |
| `dev install` / `dev uninstall` / `dev doctor` | dotfiles 自体の管理 |

### セッションレイアウト

```
+------------------+------------------+
| claude (監督)    | codex (実装)     |
|                  +------------------+
|                  | agy or nvim      |
+------------------+------------------+
```

- ペイン 3 は `agy` があれば agy、なければ nvim（`command -v agy` で自動判定）
- 別プロジェクトで `dev` すれば別セッション。同名ディレクトリは `-2` `-3`... で共存
- レイアウトを壊したら `dev kill && dev` で作り直す（自動修復はしない）

### AI エージェント連携

Claude Code に「codex に実装させて」「agy にレビューさせて」と頼むと、
delegate スキルが `dev send` / `dev peek` で隣のペインの CLI に委譲する。

- 依頼は `[FROM: Claude Code]` ヘッダ付きで送られ、受け側は完了時に `DEV_DONE` を出力する（`agents/AGENTS.md` で定義）
- 委譲結果の承認・コミットは人間が判断する（スキルに明文化済み）
- 手動でも使える: `git diff | dev send agy -` → `dev peek agy`

## AI エージェント設定

### グローバル（install が配置）

| 配置先 | 実体 | 備考 |
| --- | --- | --- |
| `~/.claude/CLAUDE.md` | `agents/AGENTS.md` | シンボリックリンク |
| `~/.codex/AGENTS.md` | `agents/AGENTS.md` | シンボリックリンク |
| `~/.gemini/GEMINI.md` | `agents/AGENTS.md` | シンボリックリンク |
| `~/.claude/skills/delegate` | `agents/claude/skills/delegate` | 委譲スキル |
| `~/.codex/config.toml` | `agents/codex/config.toml` | **コピー**（project trust 等のローカル状態を保持するため。テンプレート変更は手動反映） |

正本 `agents/AGENTS.md` を編集すれば 3 ツールに即時反映される。

### プロジェクト（dev init が配置）

| 配置物 | 実体 |
| --- | --- |
| `AGENTS.md` | プロジェクト固有ルールの正本（編集はここへ） |
| `CLAUDE.md` | `AGENTS.md` へのリンク（Claude Code 用） |
| `.antigravity.md` | `AGENTS.md` へのリンク（agy がある環境のみ） |
| `AGENT_HANDOFF_LOG.md` | エージェント間の引き継ぎログ |

すべて `.gitignore` に自動追記される（個人設定のためコミットしない）。`dev clean` で完全に元へ戻る。

## マシン固有設定（Git 管理外）

| ファイル | 用途 |
| --- | --- |
| `~/.bashrc.local` | gcloud SDK、仕事用の環境変数、追加 PATH など（bashrc 末尾で source） |
| `~/.gitconfig.local` | user.name / user.email など |
| `~/.codex/config.toml` | Codex の project trust 等（コピー配置なので直接編集してよい） |

## ファイル構成

```
dotfiles/
├── bin/dev              # 唯一のユーザーコマンド
├── scripts/
│   ├── lib.sh           # リンク対応表（install/uninstall/doctor で共有）
│   ├── install.sh / uninstall.sh / doctor.sh
│   └── init.sh / clean.sh          # dev init / dev clean の実体
├── agents/
│   ├── AGENTS.md        # グローバル AI 指示の単一正本
│   ├── codex/config.toml
│   ├── claude/skills/delegate/     # Claude Code 委譲スキル
│   └── templates/       # dev init 用テンプレート
├── bash/bashrc          # WSL / Ubuntu 分岐込みの単一ファイル
├── tmux/tmux.conf       # + tmux.wsl.conf / tmux.ubuntu.conf（クリップボード差分）
├── git/gitconfig
└── nvim/                # LazyVim ベース
```

## リファレンス

### tmux（prefix: `Ctrl-]`）

| キー | 動作 |
| --- | --- |
| `Alt-h/j/k/l` | ペイン移動（nvim 分割との相互移動対応） |
| prefix + `\|` / `-` | 水平 / 垂直分割 |
| prefix + `H/J/K/L` | ペインリサイズ |
| prefix + `z` | ペインズーム（狭い画面で単独表示） |
| prefix + `s` | セッション/ウィンドウツリー |
| prefix + `r` | 設定再読み込み |
| prefix + `X` / `Q` | セッション / サーバー終了（確認あり） |

### Neovim（LazyVim）

標準キーは <https://www.lazyvim.org/keymaps>（`<leader>` = Space）。このリポジトリの追加分:

| キー | 動作 |
| --- | --- |
| `jj` / `kk` | インサートモードから ESC |
| `-` | oil.nvim（ディレクトリ編集） |
| `<leader>w` | 保存 |
| `Alt-h/j/k/l` | tmux ペインへ移動 |

旧自前設定からのキー変更: リネームは `<leader>cr`（旧 `<leader>rn`）、フォーマットは `<leader>cf`、
ファイル検索は `<leader>ff` / grep は `<leader>/`（snacks ピッカー）。

言語サポートの追加は `:LazyExtras`。プラグイン更新は `:Lazy update` → `lazy-lock.json` をコミット。

### Bash

```bash
ll / la / l      # eza ベースの ls
open             # WSL: explorer.exe / Ubuntu: xdg-open
g / gst / gco / gcb / gl / gpl / gps / gpf / gaa / gcm   # git 短縮
cproj            # git ルートへ cd
ff / fcd         # fzf でファイルを開く / ディレクトリ移動
mkcd / extract / path
```

## トラブルシューティング

- **まず**: `dev doctor`
- **nvim の挙動がおかしい（移行直後など）**: キャッシュをクリアして再起動
  ```bash
  rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
  nvim   # LazyVim が全プラグインを再導入する
  ```
- **日本語の曖昧幅文字（○△→ 等）の幅がズレる**: 端末側の曖昧幅設定を narrow（半角）にする。
  nvim 側の `ambiwidth=double` は LazyVim のアイコン UI と非互換のため使わない
- **`dev send` が「シェルに戻っています」と言う**: 対象ペインで CLI（codex 等）を起動し直す

### 旧コマンドからの移行表

| 旧 | 新 |
| --- | --- |
| `ta` / `tan` / `tacc` | `dev` |
| `tl` | `dev ls` |
| `tk` | `dev kill` |
| `treset` | `tmux kill-server` |
| `aidev init` / `aidev clean` | `dev init` / `dev clean` |
| `dotfiles install/uninstall/doctor` | `dev install/uninstall/doctor` |
