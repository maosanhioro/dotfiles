---
name: implementation-safety
description: 最小差分実装、検証、ドキュメント更新を漏らさないための実装ガードレール。
---

# Implementation Safety

## 目的

変更を必要最小限に保ちつつ、検証と周辺更新を抜け漏れなく行う。

## 実装前チェック

1. 変更対象ファイルは十分に読んだか
2. 既存 API や公開契約を壊さないか
3. 依存追加は本当に必要か

## 実装後チェック

1. 関連テストを実行したか
2. 構文チェックや lint を通したか
3. README や設定説明の更新が必要か
4. 未解決の制約を報告したか

## 出力テンプレ

1. Change Summary
2. Validation
3. Docs Updated
4. Remaining Risks