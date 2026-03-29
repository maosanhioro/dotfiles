---
name: review-checklist
description: バグ、回帰、テスト不足、設計劣化を洗い出すためのレビュー共通観点。
---

# Review Checklist

## 目的

レビュー時に見落としやすいリスクを体系的に点検する。

## 観点

1. 仕様逸脱やエッジケース漏れはないか
2. 例外系や失敗時挙動は妥当か
3. 既存利用箇所への回帰はないか
4. テストは変更内容を十分にカバーしているか
5. セキュリティ、可観測性、運用面に問題はないか

## 出力テンプレ

1. Findings
2. Severity
3. Why It Matters
4. Suggested Direction
5. Residual Risks