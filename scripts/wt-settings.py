#!/usr/bin/env python3
"""Windows Terminal の settings.json に dotfiles 前提の設定を足す（WSL の install.sh から呼ぶ）。

- WSL のプロファイルで suppressApplicationTitle を false にする
  （WSL が自動生成するプロファイルは true で、tmux の set-titles によるタブ名変更が無視される）
- Shift+Enter に ESC + Enter（Alt+Enter と同じ）を送らせる
  （Windows Terminal は Shift+Enter を Enter と同じ文字で送り、tmux 側では区別できない）
- Alt+Enter の既定動作（全画面切り替え）を外す（Alt+Enter で改行できるように）

既に設定済みの項目と、利用者が同じキーに別の割り当てをしている項目は触らない。
JSON として読めない（コメント入りなど）ときは何も変えずに終わる。手順は README の
「マシン固有設定 → Windows Terminal」にある。
"""
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

SHIFT_ENTER_ID = "User.shiftEnterNewline"
SHIFT_ENTER_ACTION = {
    "command": {"action": "sendInput", "input": "\u001b\r"},
    "id": SHIFT_ENTER_ID,
}


def bound_keys(settings):
    """keybindings（新形式）と actions 内の keys（旧形式）の両方から割り当て済みのキーを集める。"""
    keys = set()
    for entry in settings.get("keybindings", []) + settings.get("actions", []):
        value = entry.get("keys")
        for key in value if isinstance(value, list) else [value]:
            if isinstance(key, str):
                keys.add(key.lower())
    return keys


def ensure_key_bindings(settings, changes):
    actions = settings.setdefault("actions", [])
    keybindings = settings.setdefault("keybindings", [])
    keys = bound_keys(settings)

    if "shift+enter" not in keys:
        if not any(a.get("id") == SHIFT_ENTER_ID for a in actions):
            actions.append(SHIFT_ENTER_ACTION)
        keybindings.append({"id": SHIFT_ENTER_ID, "keys": "shift+enter"})
        changes.append("Shift+Enter に改行（ESC + Enter）を割り当て")

    if "alt+enter" not in keys:
        keybindings.append({"id": None, "keys": "alt+enter"})
        changes.append("Alt+Enter の全画面切り替えを解除")


def wsl_profiles(settings):
    profiles = settings.get("profiles", {})
    entries = profiles if isinstance(profiles, list) else profiles.get("list", [])
    return [p for p in entries if p.get("source") == "Microsoft.WSL"]


def ensure_tab_titles(settings, changes):
    for profile in wsl_profiles(settings):
        if profile.get("suppressApplicationTitle") is False:
            continue
        profile["suppressApplicationTitle"] = False
        changes.append(f"タブ名の上書きを許可: {profile.get('name', profile.get('guid'))}")


def main():
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    paths = [a for a in args if a != "--dry-run"]
    if len(paths) != 1:
        print("使い方: wt-settings.py [--dry-run] <settings.json>", file=sys.stderr)
        return 1
    path = Path(paths[0])

    try:
        settings = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"  {path} を JSON として読めないため変更しません（{error}）")
        print("  README「マシン固有設定 → Windows Terminal」の手順で手作業してください")
        return 0

    changes = []
    ensure_key_bindings(settings, changes)
    ensure_tab_titles(settings, changes)
    if not wsl_profiles(settings):
        print("  WSL のプロファイルがまだ登録されていません。Windows Terminal でディストリを一度開いてから install を再実行してください")

    if not changes:
        print(f"  {path}: 設定済み")
        return 0
    for change in changes:
        print(f"  {change}")
    if dry_run:
        print("  [dry-run] 書き込みはしません")
        return 0

    backup = path.with_name(f"{path.name}.bak-dotfiles-{datetime.now():%Y%m%d%H%M%S}")
    shutil.copy2(path, backup)
    path.write_text(json.dumps(settings, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
    print(f"  書き込みました（バックアップ: {backup.name}）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
