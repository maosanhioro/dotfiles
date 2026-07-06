# dotfiles

AI エージェント並列運用を前提とした開発環境の dotfiles。

- **対象環境**: Ubuntu (WSL2) / Ubuntu Desktop
- **ツール**: zsh + starship, tmux (tmux-dotbar), Neovim (LazyVim), Claude Code, 実装エージェント（Codex CLI または GitHub Copilot CLI）
- **思想**:
  - 1 プロジェクト = 1 tmux セッション。`dev` 一発で 3 ペイン（Claude Code / 実装エージェント / nvim）が立ち上がる
  - Claude Code = 設計・監督、実装エージェント（個人用は Codex、会社支給機は GitHub Copilot CLI）= 実装。最終判断は人間
  - AI への指示ファイルは単一正本（`agents/AGENTS.md`）から全ツールへリンク。編集は 1 箇所
  - 依存は負債。プラグインマネージャ（oh-my-zsh / TPM）は使わず、apt パッケージと直接 clone で構成

## セットアップ

```bash
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./scripts/install.sh        # パッケージ導入 + シンボリックリンク（--dry-run で内容確認可）
exec zsh                     # 新しいシェルへ（次回ログインからは自動で zsh）
dev doctor                   # 健全性チェック
```

初回の nvim 起動時に LazyVim がプラグインを自動導入する（数分）。

**フォント**: starship / tmux-dotbar / eza のアイコン表示には Nerd Font が必要。

- WSL: Windows Terminal の設定 → プロファイル → 外観 → フォントを **Cascadia Code NF**（Windows 11 標準搭載）にする。無ければ JetBrainsMono Nerd Font を Windows にインストール
- Ubuntu Desktop: install.sh が JetBrainsMono Nerd Font を自動導入するので、端末のフォント設定で選ぶ

## dev コマンド

覚えるコマンドは `dev` だけ。

| コマンド | 動作 |
| --- | --- |
| `dev` | カレントプロジェクト（git ルート単位）のセッションを作成 or アタッチ |
| `dev up <path>` | 指定パスのプロジェクトを開く |
| `dev ls` | dev セッション一覧 |
| `dev kill [name]` | セッション削除（`--all` で全部） |
| `dev send <agent> <msg>` | claude / impl ペインへメッセージ送信（`-` で標準入力) |
| `dev peek <agent> [-n N]` | エージェントペインの直近出力を表示 |
| `dev init` / `dev clean` | プロジェクトの AI 設定ファイルを配置 / 削除 |
| `dev install` / `dev uninstall` / `dev doctor` | dotfiles 自体の管理 |

### セッションレイアウト

```
+------------------+------------------+
| claude (監督)    | 実装エージェント |
|                  +------------------+
|                  | nvim             |
+------------------+------------------+
```

- ペイン 2 の実装エージェントは既定で `codex`。`~/.zshrc.local` に
  `export DEV_IMPLEMENTER=copilot` と書くと GitHub Copilot CLI に切り替わる
  （会社支給機など Codex を使わない環境向け）
- ペイン 3 は常に nvim（フォールバック判定なし）
- 別プロジェクトで `dev` すれば別セッション。同名ディレクトリは `-2` `-3`... で共存
- レイアウトを壊したら `dev kill && dev` で作り直す（自動修復はしない）

### AI エージェント連携

Claude Code に「実装して」「codex/copilot にやらせて」と頼むと、
delegate スキルが `dev send impl` / `dev peek impl` で隣のペインの実装エージェントに
委譲する（`impl` は実体が codex でも copilot でも自動で解決される別名）。

- 依頼は `[FROM: Claude Code]` ヘッダ付きで送られ、受け側は完了時に `DEV_DONE` を出力する（`agents/AGENTS.md` で定義）
- 委譲結果の承認・コミットは人間が判断する（スキルに明文化済み）
- 手動でも使える: `git diff | dev send impl -` → `dev peek impl`

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
| `CLAUDE.md` | `AGENTS.md` へのリンク（Claude Code 用。Codex/Copilot は AGENTS.md を直接読む） |
| `AGENT_HANDOFF_LOG.md` | エージェント間の引き継ぎログ |

すべて `.gitignore` に自動追記される（個人設定のためコミットしない）。`dev clean` で完全に元へ戻る。

## マシン固有設定（Git 管理外）

| ファイル | 用途 |
| --- | --- |
| `~/.zshrc.local` | gcloud SDK、仕事用の環境変数、追加 PATH など（zshrc 末尾で source）。`export DEV_IMPLEMENTER=copilot` もここ |
| `~/.bashrc.local` | 同上の bash 版（bash に落ちたとき用） |
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
├── shell/common.sh      # bash / zsh 共通のエイリアス・関数（二重管理を防ぐ）
├── zsh/zshrc            # メインシェル設定 + starship.toml（プロンプト）
├── bash/bashrc          # フォールバック用の薄い bash 設定
├── tmux/tmux.conf       # + tmux.wsl.conf / tmux.ubuntu.conf（クリップボード差分）
├── git/gitconfig
└── nvim/                # LazyVim ベース
```

## リファレンス

### tmux（prefix: `Ctrl-]`）

ステータスバーは tmux-dotbar。左: セッション名（prefix 押下で黄色にハイライト）、
中央: ウィンドウ名、右: `tmux/dotbar-right.sh` が生成する情報バー
（dev エージェント稼働 ●（緑=CLI 実行中 / 灰=シェルに戻った）・負荷・メモリ使用率・時刻。15 秒間隔で更新）。

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

### シェル（zsh + starship）

プロンプトは starship（`zsh/starship.toml`）。ディレクトリ・git ブランチ/状態・
Node/Python バージョンを常時表示し、失敗したコマンドは ❯ が赤くなり右側に終了コードが出る。

| 機能 | 操作 |
| --- | --- |
| 履歴からのゴースト補完（zsh-autosuggestions） | `→` で確定 |
| コマンドの正誤色分け（zsh-syntax-highlighting） | 打つだけ（存在しないコマンドは赤） |
| 履歴のあいまい検索（fzf） | `Ctrl-R` |
| ファイル / ディレクトリ検索（fzf） | `Ctrl-T` / `Alt-C` |
| ディレクトリ名だけで cd / cd 履歴 | `auto_cd` / `cd -<Tab>` |

エイリアス・関数は `shell/common.sh`（bash と共通）:

```bash
ll / la / l      # eza ベースの ls（Nerd Font アイコン付き）
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
- **プロンプトやステータスバーのアイコンが □（豆腐）になる**: 端末のフォントが Nerd Font になっていない。
  セットアップ節のフォント手順を参照
- **nvim ダッシュボードの Find File/Find Text が何も表示せずエラーが一瞬出る**: `fzf` が古い
  （apt 版は `transform` アクション未対応で fzf-lua がエラーになる）。`./scripts/install.sh --force`
  で upstream の最新バイナリに更新される（`dev doctor` で `fzf` のバージョンを確認可能）
- **日本語の曖昧幅文字（○△→ 等）の幅がズレる**: 端末側の曖昧幅設定を narrow（半角）にする。
  nvim 側の `ambiwidth=double` は LazyVim のアイコン UI と非互換のため使わない
- **`dev send` が「シェルに戻っています」と言う**: 対象ペインで CLI（codex/copilot 等）を起動し直す

### 旧コマンドからの移行表

| 旧 | 新 |
| --- | --- |
| `ta` / `tan` / `tacc` | `dev` |
| `tl` | `dev ls` |
| `tk` | `dev kill` |
| `treset` | `tmux kill-server` |
| `aidev init` / `aidev clean` | `dev init` / `dev clean` |
| `dotfiles install/uninstall/doctor` | `dev install/uninstall/doctor` |
