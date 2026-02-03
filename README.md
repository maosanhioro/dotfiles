# AI-Assisted Workstation Dotfiles

AI アシスト開発と日常開発を高速化する WSL/Ubuntu 向け dotfiles。  
tmux の AI アシスト作業レイアウト、Neovim の LSP/formatter、bash の生産性強化を最初から整備しています。

## 対象環境
- Windows 11 + WSL2 (Ubuntu)
- Ubuntu Desktop
- tmux / bash / NVM
- Gemini CLI / Codex CLI など

## 特徴
- `ta` で AI アシスト作業に最適化された tmux レイアウトを自動生成
- Neovim: lazy.nvim + LSP + formatter + treesitter
- WSL / Ubuntu Desktop の環境差を自動吸収（clipboard / TERM）
- インストールスクリプトで最小依存を自動セットアップ
- 依存やリンクの簡易診断スクリプトを同梱

## セットアップ
```bash
git clone <your repo> ~/dotfiles
cd ~/dotfiles
chmod +x scripts/install.sh
./scripts/install.sh
source ~/.bashrc
ta
```

## インストールオプション
- `./scripts/install.sh --dry-run` 実行せずに内容だけ表示
- `./scripts/install.sh --force` Neovim を再インストール/再リンク
- `./scripts/install.sh --no-sudo` sudo を使わない（特殊環境向け）

## 使い方（コマンド）
- `ta`: AI アシスト作業用 tmux レイアウト起動
- `tl`: tmux セッション一覧
- `tk`: ai-assist セッション終了
- `tmr`: tmux 設定再読込
- `./scripts/doctor.sh`: 依存やリンクの簡易診断

## tmux レイアウト（ta）
```
┌───────────────┬───────────────┬───────────────┐
│ nvim          │ claude        │ codex         │
├───────────────┤               │               │
│ shell         │               │               │
└───────────────┴───────────────┴───────────────┘
```

## tmux の挙動
- セッション名: `ai-assist`
- ウィンドウ名: `ws`
- `ta` は tmux 未起動時にセッションを作成してアタッチ
- `ta` は既存セッションにウィンドウがなければ新規作成
- 既存 `ws` ウィンドウのペイン構成が崩れている場合は再構築
- SSH 接続時は自動で `ta` を起動（`bashrc` 側の条件で制御）

## tmux キーバインド（主要）
- `Prefix`: `Ctrl-]`
- `|`: 垂直分割
- `-`: 水平分割
- `h/j/k/l`: ペイン移動
- `Alt-h/j/k/l`: ペイン移動
- `H/J/K/L`: ペインのリサイズ
- `r`: 設定の再読込
- `s`: ツリー表示
- `Ctrl-s`: synchronize-panes トグル
- `X`: セッション終了（確認あり）
- `Q`: tmux サーバー終了（確認あり）

## 環境別差分（WSL / Ubuntu）
- WSL
- `TERM=screen-256color`
- コピーは `clip.exe` にパイプして Windows クリップボードへ
- Ubuntu Desktop
- `TERM=tmux-256color`
- Wayland なら `wl-copy`、X11 なら `xclip` を利用

## Neovim キーマップ
- `Space w`: 保存
- `Space q`: 終了
- `Space h`: ハイライト解除
- `Space ff`: ファイル検索
- `Space fg`: Ripgrep 検索
- `Space fb`: バッファ一覧
- `Space fh`: ヘルプ検索
- `-`: ファイルエクスプローラ（oil）
- `Space qs`: セッション復元
- `Space ql`: 直近セッション復元
- `Space qd`: セッション停止
- `Space e`: 行診断を表示
- `[d` / `]d`: 診断の前後移動
- `Space xx`: Trouble トグル
- `Space xw`: Trouble（workspace）
- `Space xd`: Trouble（document）
- `Space xl`: Trouble（loclist）
- `Space xq`: Trouble（quickfix）
- `gR`: Trouble（参照一覧）
- `K`: LSP hover
- `gd`: 定義へ移動
- `gr`: 参照一覧
- `gi`: 実装へ移動
- `Space rn`: リネーム
- `Space ca`: コードアクション
- `Space f`: フォーマット
- `[h` / `]h`: 変更 hunk の前後移動
- `Space hs`: hunk を stage
- `Space hr`: hunk を reset
- `Space hS`: バッファを stage
- `Space hu`: hunk の stage を取り消し
- `Space hR`: バッファを reset
- `Space hp`: hunk のプレビュー
- `Space hb`: 行の blame
- `Esc Esc`: ハイライト解除
- `jj` / `kk`（Insert）: ノーマルへ

## Neovim プラグイン概要（主要）
- `lazy.nvim`: プラグイン管理
- `onedark.nvim`: テーマ
- `lualine.nvim`: ステータスライン
- `telescope.nvim`: 検索 UI
- `telescope-ui-select.nvim`: UI 選択拡張
- `treesitter`: 構文解析
- `nvim-lspconfig`: LSP 設定
- `mason.nvim` / `mason-lspconfig.nvim`: LSP インストール
- `nvim-cmp`: 補完
- `conform.nvim`: フォーマッタ
- `gitsigns.nvim`: Git の差分表示
- `oil.nvim`: ファイルエクスプローラ
- `persistence.nvim`: セッション保存
- `trouble.nvim`: 診断一覧

## Bash エイリアス / 関数
- `ll` / `la` / `l`: ls 系（`eza` があれば eza を利用）
- `..` / `...`: 上の階層へ移動
- `cls`: 画面クリア
- `g`: git
- `gst`: `git status -sb`
- `gco`: `git checkout`
- `gcb`: `git checkout -b`
- `gl`: `git log --oneline --graph --decorate`
- `gpl`: `git pull --ff-only`
- `gps`: `git push`
- `gpf`: `git push --force-with-lease`
- `gaa`: `git add -A`
- `gcm`: `git commit -m`
- `path`: PATH を 1 行ずつ表示
- `mkcd <dir>`: 作って移動
- `extract <file>`: アーカイブ展開
- `cproj`: Git ルートに移動
- `ff`: fzf でファイル選択 → エディタで開く（`fzf` 必須）
- `fcd`: fzf でディレクトリ移動（`fzf` 必須）

## doctor.sh について
- 目的: 依存コマンドとリンクの有無を素早く確認
- チェック対象: `tmux`, `nvim`, `rg`, `fd`, `fzf`, `bat`, `eza`, `pipx`, `claude`, `codex`
- 期待結果: `[OK]` であれば PATH に存在
- `[WARN]` の場合は `./scripts/install.sh` を実行

## 主要ファイル
- `bash/`: bash 設定（共通 / WSL / Ubuntu）
- `tmux/`: tmux 設定（共通 / WSL / Ubuntu）
- `nvim/`: Neovim 設定
- `scripts/install.sh`: セットアップスクリプト
- `scripts/doctor.sh`: 簡易診断

## Philosophy
- 自動化できることは最初から自動化する
- OS 差は設定側で吸収する
- AI アシスト作業の「開始コスト」を最小化する
