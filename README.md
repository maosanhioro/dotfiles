# dotfiles

AI エージェント並列運用を前提とした開発環境の dotfiles。
WSL / Ubuntu Desktop のどちらでも、同じ操作感の開発環境をこのリポジトリ一つで再現する。

- **対象環境**: Ubuntu (WSL2) / Ubuntu Desktop
- **ツール**: zsh + starship, tmux (tmux-dotbar), Neovim (LazyVim), Claude Code, プレイヤー（Codex CLI または GitHub Copilot CLI）
- **範囲**: 端末の中に限らず、開発の操作感に関わるもの（端末エミュレータの設定、キーリマップ）まで含める。
  壁紙や一般アプリの導入など、開発の操作感に関係しないものは含めない
- **思想**:
  - 1 プロジェクト = 1 tmux セッション。`dev` 一発で 3 ペイン（Claude Code / プレイヤー / shell）が立ち上がる
  - Claude Code = 設計・マネジメント（マネージャー）、プレイヤー（個人用は Codex、会社支給機は GitHub Copilot CLI）= 実装。最終判断は人間
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

**フォント**: starship / tmux-dotbar / eza のアイコン表示には Nerd Font が必要。インストールは dotfiles の範囲外なので、好きな Nerd Font（例: PlemolJP NF）を各 OS に手動導入し、端末のフォント設定で指定する。

- WSL: Windows 側に Nerd Font をインストールし、Windows Terminal の設定 → プロファイル → 外観 → フォントで指定
- Ubuntu Desktop: Nerd Font をインストールし、端末のフォント設定で指定

## dev コマンド

覚えるコマンドは `dev` だけ。

| コマンド | 動作 |
| --- | --- |
| `dev` | カレントプロジェクト（git ルート単位）のセッションを作成 or アタッチ |
| `dev up <path>` | 指定パスのプロジェクトを開く |
| `dev ls` | dev セッション一覧 |
| `dev kill [name]` | セッション削除（`--all` で全部） |
| `dev send <agent> <msg>` | claude / player ペインへメッセージ送信（`-` で標準入力) |
| `dev peek <agent> [-n N]` | エージェントペインの直近出力を表示 |
| `dev status <agent>` | エージェントの状態を一語で表示（running / done / blocked / shell） |
| `dev wait <agent>` | 完了・停止の報告まで待つ（`--timeout N`、既定 600 秒） |
| `dev init` / `dev clean` | プロジェクトの AI 設定ファイルを配置 / 削除 |
| `dev install` / `dev uninstall` / `dev doctor` | dotfiles 自体の管理 |

### セッションレイアウト

```
+--------------------------+------------------+
|                          | プレイヤー       |
| claude (マネージャー)    +------------------+
|                          | shell            |
+--------------------------+------------------+
```

claude は作業中ずっと見続けるので全高、プレイヤーと shell は
`dev peek`/`dev status` 越し・実行したら用済みの随時チェックなペインなので
右列に同居させている。

- ペイン 2 のプレイヤーは既定で `codex`。`~/.zshrc.local` に
  `export DEV_PLAYER=copilot` と書くと GitHub Copilot CLI に切り替わる
  （会社支給機など Codex を使わない環境向け）
- ペイン 3（shell）は素の状態で立ち上がる。git 操作など手動で叩きたい作業用で、
  `dev send`/`dev peek`/`dev status` の対象にはならない。nvim もここから手動起動する
  （専用ペインは廃止）
- 別プロジェクトで `dev` すれば別セッション。同名ディレクトリは `-2` `-3`... で共存
- レイアウトを壊したら `dev kill && dev` で作り直す（自動修復はしない）

### AI エージェント連携

Claude Code に「実装して」「codex/copilot にやらせて」と頼むと、
delegate スキルが `dev send player` / `dev peek player` で隣のペインのプレイヤーに
委譲する（`player` は実体が codex でも copilot でも自動で解決される別名）。

- 依頼は `[FROM: Claude Code]` ヘッダ付きで送られ、受け側は完了時に `DEV_DONE` を出力する（`agents/AGENTS.md` で定義）
- 委譲結果の承認・コミットは人間が判断する（スキルに明文化済み）
- 手動でも使える: `git diff | dev send player -` → `dev wait player` → `dev peek player`
- 完了の待ち方は 2 通り。`dev status` は状態を一語返すだけ（ポーリング用）、
  `dev wait` は報告が来るまでブロックする。`dev wait` は tmux の `wait-for` で
  報告と同時に起きるため、待機中は tmux を一切叩かない

### 状態表示と通知（hooks）

3 つの CLI の hooks から `dev hook` を呼び、ステータスバーのドットと通知を自動で更新する。
`dev report`（タスク完了の明示的な報告）とは別の状態として持つ。

| 状態 | きっかけ | 表示 | 通知 |
| --- | --- | --- | --- |
| 作業中 | プロンプト送信・ツール実行 | 緑 ● | なし |
| 入力待ち | 1 ターン終了（Stop） | 緑 ○ | Claude が 60 秒放置されたときだけ |
| 承認待ち | 承認・質問のプロンプト | 橙 ● | あり |

- 設定の正本: `agents/claude/hooks.json`（install が `~/.claude/settings.json` の `hooks` キーを丸ごと置き換える。
  手で足した hook は消えるので、足すときはこのファイルへ）、`agents/codex/hooks.json`、
  `agents/copilot/hooks/dev.json`（この 2 つはリンク）
- Codex は hooks を初めて読み込んだときと、hooks.json を変えたあとに、Codex 内の `/hooks` で信頼の承認が要る
- Copilot / Codex は起動時に hooks を読むため、変更後は CLI を起動し直す
- デスクトップ通知: Ubuntu は `notify-send`、WSL は Windows の `powershell.exe` でトースト通知

## AI エージェント設定

### グローバル（install が配置）

| 配置先 | 実体 | 備考 |
| --- | --- | --- |
| `~/.claude/CLAUDE.md` | `agents/AGENTS.md` | シンボリックリンク |
| `~/.codex/AGENTS.md` | `agents/AGENTS.md` | シンボリックリンク |
| `~/.gemini/GEMINI.md` | `agents/AGENTS.md` | シンボリックリンク |
| `~/.claude/skills/delegate` | `agents/claude/skills/delegate` | 委譲スキル |
| `~/.codex/config.toml` | `agents/codex/config.toml` | **コピー**（project trust 等のローカル状態を保持するため。テンプレート変更は手動反映） |
| `~/.codex/hooks.json` | `agents/codex/hooks.json` | シンボリックリンク（状態表示の hooks） |
| `~/.copilot/hooks/dev.json` | `agents/copilot/hooks/dev.json` | シンボリックリンク（同上） |
| `~/.claude/settings.json` の `hooks` | `agents/claude/hooks.json` | **キー単位で置き換え**（他の設定は触らない） |

正本 `agents/AGENTS.md` を編集すれば 3 ツールに即時反映される。

`~/.codex/config.toml` はコピーのため、既にあるマシンにはテンプレートの変更がそのままでは入らない。
後から足した設定は install.sh が個別に補う（現在は `[tui] alternate_screen`）。テンプレートに設定を
足したときは、install.sh の同じ箇所にも補う処理を足すこと。

### プロジェクト（dev init が配置）

| 配置物 | 実体 |
| --- | --- |
| `AGENTS.md` | プロジェクト固有ルールの正本（編集はここへ） |
| `CLAUDE.md` | `AGENTS.md` へのリンク（Claude Code 用。Codex/Copilot は AGENTS.md を直接読む） |
| `AGENT_HANDOFF_LOG.md` | エージェント間の引き継ぎログ（`--force` でも上書きされない） |

すべて `.gitignore` に自動追記される（個人設定のためコミットしない）。`dev clean` で完全に元へ戻る。

設定ファイルは正本から再生成できるが、引き継ぎログは作業の記録そのもので復元できない。
そのため `dev init --force` は `AGENTS.md` を最新化してもログには触らない（消したいときは
`dev clean` を使う）。

## マシン固有設定（Git 管理外）

| ファイル | 用途 |
| --- | --- |
| `~/.zshrc.local` | gcloud SDK、仕事用の環境変数、追加 PATH など（zshrc 末尾で source）。`export DEV_PLAYER=copilot` もここ |
| `~/.bashrc.local` | 同上の bash 版（bash に落ちたとき用） |
| `~/.gitconfig.local` | user.name / user.email など |
| `~/.codex/config.toml` | Codex の project trust 等（コピー配置なので直接編集してよい） |

### Windows Terminal（WSL では install が自動で設定）

WSL で `./scripts/install.sh` を実行すると、`scripts/wt-settings.py` が Windows 側の
`settings.json` に以下を足す（設定済みの項目は触らず、書き込む前にバックアップを取る）。
ディストリを足したときは、Windows Terminal でそのディストリを一度開いてから install を再実行する。

install が「JSON として読めないため変更しません」と表示したとき（自分でコメントを書き込んだ場合など）だけ、
以下の手順で手作業する。

**できるようになること**
- タブ名が tmux のセッション名（＝プロジェクト名）になる
- Shift+Enter で、Claude Code などの入力欄の中で改行できる（Alt+Enter と同じ動き）

**編集するファイル**

```text
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

Windows Terminal の設定画面（`Ctrl+,`）の左下「JSON ファイルを開く」でも同じファイルが開く。
編集前にコピーを取っておくと、壊したときに戻せる。保存すると即反映され、再起動は不要。

**手順 1. Shift+Enter のキー割り当てを足す**

ファイル内の `"actions": [` の直後に、次の 1 項目を足す（後ろにカンマを付ける）。

```json
{ "command": { "action": "sendInput", "input": "\u001b\r" }, "id": "User.shiftEnterNewline" },
```

同じく `"keybindings": [` の直後に、次の 2 項目を足す。

```json
{ "id": "User.shiftEnterNewline", "keys": "shift+enter" },
{ "id": null, "keys": "alt+enter" },
```

2 行目は Alt+Enter の既定動作（全画面切り替え）を外す設定。これで Alt+Enter でも改行できる
（`"keys": "alt+enter"` の項目が既にあれば 2 行目は不要）。

**手順 2. タブ名の上書きを許可する**

`"profiles"` → `"list"` の中から、WSL のディストリの項目（`"source": "Microsoft.WSL"` があるもの）を探し、
`"suppressApplicationTitle": false,` を 1 行足す。ディストリが複数あれば全部に足す。

```json
{
    "guid": "{ca8057ad-...}",
    "hidden": false,
    "name": "Ubuntu",
    "source": "Microsoft.WSL",
    "suppressApplicationTitle": false
}
```

WSL が自動で作るプロファイルではこの値が `true` になっていて、tmux からのタブ名の変更が無視される。
ディストリを作った直後は一覧に無いことがある。そのときは Windows Terminal でそのディストリを一度開くと追加される。

**確認**
- tmux のセッション（`dev`）に入ると、タブ名がプロジェクト名になる
- Claude Code の入力欄で Shift+Enter を押すと、送信されずに改行される
- 保存後に Windows Terminal が設定エラーを出したら、カンマの付け忘れか付けすぎ。エラーに出る位置を直す

Shift+Enter は全タブ共通で効く。zsh でも Shift+Enter はコマンド実行ではなく改行になる。

Ubuntu デスクトップの GNOME Terminal には同じ設定が無いため、Shift+Enter を Alt+Enter に変換する
xremap のルールで代用している（`xremap/config.yml`、導入手順は次節）。
xremap が無い環境では Alt+Enter で改行する。

### キーリマップ（Ubuntu Desktop: xremap）

Emacs 風のカーソル移動・編集キーに、Windows 流の `Ctrl-C` / `Ctrl-V` / `Ctrl-X` を残したハイブリッド。
端末（GNOME Terminal）は除外し、代わりに Shift+Enter の改行だけを効かせる。

設定ファイル（`~/.config/xremap/config.yml`）とユーザーユニット（`~/.config/systemd/user/xremap.service`）は
install がリンクする。xremap 本体まわりは手動で入れる（cargo と sudo が要るため install には含めない）。

1. `cargo install xremap --features gnome`（`~/.cargo/bin/xremap` に入る。ユニットはこの場所を起動する）
2. GNOME 拡張「xremap」（`xremap@k0kubun.com`）を extensions.gnome.org から入れて有効化
   （アクティブなアプリ名を xremap に渡す。無いとアプリ別の設定が効かない）
3. uinput を sudo 無しで使えるようにする:
   ```bash
   echo 'KERNEL=="uinput", GROUP="input", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/input.rules
   sudo gpasswd -a "$USER" input   # 反映には再ログインが必要
   ```
4. `systemctl --user enable --now xremap`

設定を変えたら `systemctl --user restart xremap` で反映する（`--watch` はデバイスの抜き差しの監視で、
設定ファイルの変更は自動では読み直さない）。アプリ名は `journalctl --user -u xremap` の
`application:` 行で確認できる。OS アップグレードでアプリ名が変わると除外が外れる
（Ubuntu 26.04 で `gnome-terminal-server` → `org.gnome.Terminal` になった）。

## ファイル構成

```
dotfiles/
├── bin/dev              # 唯一のユーザーコマンド
├── scripts/
│   ├── lib.sh           # リンク対応表（install/uninstall/doctor で共有）
│   ├── install.sh / uninstall.sh / doctor.sh
│   ├── init.sh / clean.sh          # dev init / dev clean の実体
│   └── wt-settings.py   # WSL で Windows Terminal の設定を足す（install から呼ぶ）
├── agents/
│   ├── AGENTS.md        # グローバル AI 指示の単一正本
│   ├── codex/config.toml / hooks.json
│   ├── copilot/hooks/dev.json
│   ├── claude/hooks.json           # ~/.claude/settings.json の hooks の正本
│   ├── claude/skills/delegate/     # Claude Code 委譲スキル
│   └── templates/       # dev init 用テンプレート
├── shell/common.sh      # bash / zsh 共通のエイリアス・関数（二重管理を防ぐ）
├── zsh/zshrc            # メインシェル設定 + starship.toml（プロンプト）
├── bash/bashrc          # フォールバック用の薄い bash 設定
├── tmux/tmux.conf       # + tmux.wsl.conf / tmux.ubuntu.conf（クリップボード差分）
│   └── pick.sh          # prefix + y / u の実体（画面の行・URL を fzf で拾う。試用中）
├── git/gitconfig
├── nvim/                # LazyVim ベース
└── xremap/              # Ubuntu Desktop のキーリマップ（config.yml + ユーザーユニット）
```

## リファレンス

### tmux（prefix: `Ctrl-]`）

ステータスバーは tmux-dotbar。左: セッション名（prefix 押下で黄色にハイライト）、
中央: ウィンドウ名、右: `tmux/dotbar-right.sh` が生成する情報バー
（dev エージェント稼働・負荷・メモリ使用率・時刻。15 秒間隔で更新）。
エージェントのドットは、緑 ● 作業中 / 緑 ○ 入力待ち / 橙 ● 承認待ち / 黄 ● 完了報告あり /
赤 ● 停止報告あり / 灰 ● シェルに戻った（hooks による状態は「状態表示と通知」参照）。

| キー | 動作 |
| --- | --- |
| `Alt-h/j/k/l` | ペイン移動（nvim 分割との相互移動対応） |
| prefix + `\|` / `-` | 水平 / 垂直分割 |
| prefix + `H/J/K/L` | ペインリサイズ |
| prefix + `z` | ペインズーム（狭い画面で単独表示） |
| prefix + `y` | 画面の行を fzf で拾う（**試用中**。Enter で shell ペインへ入力 / `Ctrl-Y` でコピーのみ / `Tab` で複数選択） |
| prefix + `u` | 画面の URL を fzf で拾う（**試用中**。Enter でブラウザを開く / `Ctrl-Y` でコピーのみ。WSL は explorer.exe 経由） |
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
- **`dev send` が「画面が変化していません」と警告する**: Enter が TUI に届かず、指示が
  入力欄に残ったままの可能性がある（`dev send` は自動で1回だけ Enter を再送している）。
  `dev peek` で入力欄を確認する。TUI が重いときに起きやすい

### 旧コマンドからの移行表

| 旧 | 新 |
| --- | --- |
| `ta` / `tan` / `tacc` | `dev` |
| `tl` | `dev ls` |
| `tk` | `dev kill` |
| `treset` | `tmux kill-server` |
| `aidev init` / `aidev clean` | `dev init` / `dev clean` |
| `dotfiles install/uninstall/doctor` | `dev install/uninstall/doctor` |
