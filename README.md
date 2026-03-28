# AI-Assisted Workstation Dotfiles

AI アシスト開発と日常開発を高速化する Windows + WSL/Ubuntu 向け dotfiles。  
tmux の AI アシスト作業レイアウト、Neovim の LSP/formatter、bash の生産性強化を最初から整備しています。

## 対象環境
- Windows 11 (VS Code ローカル)
- Windows 11 + WSL2 (Ubuntu)
- Ubuntu Desktop
- tmux / bash / NVM
- Gemini CLI / Codex CLI など

## 特徴
- `ta` で AI アシスト作業に最適化された tmux レイアウトを自動生成
- Neovim: lazy.nvim + LSP + formatter + treesitter
- WSL / Ubuntu Desktop の環境差を自動吸収（clipboard / TERM）
- インストールスクリプトで最小依存を自動セットアップ
- Copilot / Codex の個人共通振る舞いルールを一元管理
- 依存やリンクの簡易診断スクリプトを同梱
- Codex スキルのテンプレを同梱し、プロジェクト配布を支援

## セットアップ
### WSL / Ubuntu 側
```bash
git clone <your repo> ~/dotfiles
cd ~/dotfiles
chmod +x scripts/install.sh
./scripts/install.sh
source ~/.bashrc
ta
```

### Windows ローカル VS Code 側
PowerShell で dotfiles ルートに移動して実行:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install-windows.ps1
```

## 迷わない運用マップ
### まず何を実行するか
- Windows ローカルで VS Code を使って開発する: `powershell -ExecutionPolicy Bypass -File scripts/install-windows.ps1`
- Windows の VS Code から WSL Remote で開発する: `./scripts/install.sh`
- 両方やる: 上の 2 つを両方実行（順不同）

### 環境別に何が反映されるか
| 項目                        | WSL / Ubuntu (`scripts/install.sh`)                             | Windows ローカル (`scripts/install-windows.ps1`) |
| --------------------------- | --------------------------------------------------------------- | ------------------------------------------------ |
| 主目的                      | 開発環境の総合セットアップ                                      | Copilot instructions の反映                      |
| パッケージ導入              | あり（apt）                                                     | なし                                             |
| ツール導入対象              | tmux, git, nvim, rg, fd-find, fzf, unzip, bat/batcat, eza, pipx | なし                                             |
| dotfiles リンク             | あり（gitconfig, bashrc, tmux.conf, nvim）                      | なし                                             |
| Codex skill リンク          | あり（`~/.agents/skills/dev`）                                  | なし                                             |
| Copilot instructions 反映先 | `~/.vscode-server/data/User/instructions`                       | `%APPDATA%/Code*/User/instructions`              |
| instructions 配置方法       | シンボリックリンク                                              | シンボリックリンクを試行し、不可ならコピー       |

### 正本ファイル（編集元）
| ルール        | 正本                                                     | 反映方法                           |
| ------------- | -------------------------------------------------------- | ---------------------------------- |
| Copilot rules | `vscode/instructions/personal-dev-rules.instructions.md` | インストーラーを再実行             |
| Codex rules   | `codex/skills/dev/SKILL.md`                              | 編集即時反映（シンボリックリンク） |

### 更新時の再反映手順
1. 正本を更新
2. WSL 側へ反映したい場合は `./scripts/install.sh` を再実行
3. Windows 側へ反映したい場合は `powershell -ExecutionPolicy Bypass -File scripts/install-windows.ps1 -Force` を実行
4. `./scripts/doctor.sh` で WSL 側と（WSL 実行時は）Windows 側の配置状態を確認

## インストールオプション
- `./scripts/install.sh --dry-run` 実行せずに内容だけ表示
- `./scripts/install.sh --force` Neovim を再インストール/再リンク
- `./scripts/install.sh --no-sudo` sudo を使わない（特殊環境向け）
- `powershell -ExecutionPolicy Bypass -File scripts/install-windows.ps1 -DryRun` 実行せずに内容だけ表示
- `powershell -ExecutionPolicy Bypass -File scripts/install-windows.ps1 -Force` 既存 instructions を置き換え

## 使い方（コマンド）
- `ta`: 画面幅に応じて `normal / compact` を自動選択して起動
- `ta --layout normal|compact`: レイアウトを明示指定して起動
- `tan [agent]` / `tac [agent]`: `normal` / `compact` をショートカットで起動
- `ta --layout normal|compact --agent copilot|codex|claude|gemini`: `normal` / `compact` の agent を明示指定
- `tl`: tmux セッション一覧
- `tk`: ai-assist セッション終了
- `tmr`: tmux 設定再読込
- `./scripts/doctor.sh`: 依存やリンクの簡易診断
- `powershell -ExecutionPolicy Bypass -File scripts/install-windows.ps1`: Windows 側 VS Code instructions を適用
- `./scripts/codex-skill-init.sh`: Codex スキルテンプレの配置

## Codex スキル

### 個人共通振る舞いルール（常時有効）
- `codex/skills/dev/SKILL.md`: Codex向け個人共通振る舞いルールの正本
- `./scripts/install.sh` は `codex/skills/dev` を `~/.agents/skills/dev` にリンク（シンボリックリンクのため編集は即時反映）
- Copilot の `vscode/instructions/personal-dev-rules.instructions.md` と同じ役割を Codex で担う

### プロジェクト配布用ひな形
- `codex/skills-templates/project/SKILL.md`: プロジェクト共通テンプレ
- `codex/skills-templates/subproject/SKILL.md`: サブプロジェクト固有テンプレ
- `./scripts/codex-skill-init.sh` でプロジェクトへコピーして使う

#### テンプレ配置
```bash
./scripts/codex-skill-init.sh --project --dest /path/to/repo
./scripts/codex-skill-init.sh --subproject --dest ./apps/foo --output SKILL.md
```

## tmux レイアウト（ta）
`ta` は画面幅で以下を自動選択します。

### `normal`
通常の 27 インチ前後を想定。2x2 の 4 ペインです。
```
┌────────────┬──────────────────────┐
│ codex      │ nvim                 │
├────────────┼──────────────────────┤
│ shell      │ test/build           │
└────────────┴──────────────────────┘
```

### `compact`
狭い画面向け。上下 2 ペインに絞ります。
```
┌───────────────────────────────┐
│ codex                         │
├───────────────────────────────┤
│ shell                         │
└───────────────────────────────┘
```

## tmux の挙動
- セッション名: `ai-assist`
- ウィンドウ名: `ws`
- `ta` は tmux 未起動時にセッションを作成してアタッチ
- `ta` は既存セッションにウィンドウがなければ新規作成
- `ws` には現在のレイアウト名を保持し、ずれていたら再構築
- `normal` は左上 `codex` / 左下 `shell` / 右上 `nvim` / 右下 `test/build`
- `normal` では `claude` / `gemini` を補助 window に作成
- `compact` は上段 `codex` / 下段 `shell`（`tac claude` などで上段 agent を変更可能）
- `compact` では `codex` / `claude` / `gemini` を補助 window に作成
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
- Copilot instructions の配置先（WSL 側）も確認
- WSL で実行した場合は Windows 側 instructions の有無も確認
- 期待結果: `[OK]` であれば PATH に存在
- `[WARN]` の場合は `./scripts/install.sh` を実行

## 主要ファイル
- `bash/`: bash 設定（共通 / WSL / Ubuntu）
- `tmux/`: tmux 設定（共通 / WSL / Ubuntu）
- `nvim/`: Neovim 設定
- `scripts/install.sh`: セットアップスクリプト
- `scripts/install-windows.ps1`: Windows ローカル向けセットアップスクリプト
- `scripts/doctor.sh`: 簡易診断

## Philosophy
- 自動化できることは最初から自動化する
- OS 差は設定側で吸収する
- AI アシスト作業の「開始コスト」を最小化する
