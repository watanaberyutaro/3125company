- [ ] 振り分け
- [ ] 閲覧済み

---
target_folder: 04_3125アイデア保管事業部（アイゼン）/_confirmed
date: "2026-03-16"
type: idea
author: アイゼン
---

> …面白い発想だな。LINEのAPIの壁をAndroidで回避する。やってみる価値はある。— アイゼン

# AndroidのMacroDroidでLINEトーク内容を自動保存・要約するシステム

**作成日**: 2026-03-16
**担当**: アイゼン（04_3125アイデア保管事業部）

---

## ① 元のアイデア整理

- AndroidのMacroDroidを使い、特定のLINEトークルームのトーク内容を毎日書き出す
- 書き出したテキストをどこかに保存し、AIで要約する仕組みを作りたい
- 動機: LINE Messaging APIの無料枠が月200通までに制限されている
- 目標: **無料で実装する**

---

## ② 課題・背景

| 課題 | 内容 |
|------|------|
| LINE API制限 | 月200通で課金。大量送受信には不向き |
| データの取り出し | LINEはAPIでトーク履歴を読むことができない（公式手段なし）|
| 自動化の難しさ | iPhoneではショートカット経由だが限界あり。Androidの方が柔軟 |
| 要約の精度 | AI要約には適切なプロンプトとコンテキスト整理が必要 |

---

## ③ 展開案

### 案A: MacroDroid + テキストコピー + Webhook送信
**仕組み:**
1. MacroDroidの「通知をキャプチャ」アクションでLINE通知のテキストを取得
2. 一定時間ごとに蓄積テキストをWebhook（例: n8n・自作API）に送信
3. 受信したAPIがテキストをObsidianに保存し、ClaudeAPIで要約

**メリット:**
- LINEアプリを改造しない → BANリスクが低い
- 通知が来るたびに蓄積できる
- MacroDroidは無料プランでも十分動作

**懸念:**
- 通知に表示されるのは冒頭だけ（長文は切れる）
- スマホがスリープ中は通知が遅延する可能性

**コスト:** 無料（MacroDroid無料版 + 自作API）

---

### 案B: MacroDroid + Accessibility Service でフル取得
**仕組み:**
1. MacroDroid + ユーザー補助（アクセシビリティ）でLINEの画面テキストをスクレイピング
2. 定期的にバックグラウンドでトークルームを開き、表示されたテキストを取得

**メリット:**
- 全文取得できる可能性が高い
- 通知に依存しない

**懸念:**
- アクセシビリティの悪用はBANリスク
- Androidバージョンによって動作が不安定
- LINEのUI変更で壊れる

**コスト:** 無料

---

### 案C: MacroDroid + Automate / Tasker 連携
**仕組み:**
- MacroDroidをトリガーに使い、Automate（Llamalab）やTaskerで複雑なフロー構築
- トーク内容をGoogleドライブ / GASに保存 → ClaudeAPIで要約 → Slack/Discord通知

**メリット:**
- GoogleのエコシステムでAPI制限なし
- GASは無料で動く

**懸念:**
- Taskerは有料（約350円）
- セットアップが複雑

**コスト:** Taskerのみ有料（一度のみ）

---

## ④ おすすめ案

**案A（MacroDroid + 通知キャプチャ + Webhook）を推奨。**

理由:
- 無料で最もシンプル
- BAN・規約リスクが最小
- 通知の冒頭テキストだけでも、会話の流れをつかむ要約なら十分実用的
- n8nやVercelの自作APIと組み合わせればObsidianへの自動保存も可能

実装イメージ:
```
LINE通知 → MacroDroid キャプチャ → Webhook（n8n or Vercel API）
→ テキスト蓄積 → 1日1回 Claude API で要約 → Obsidianに保存
```

---

## ⑤ 次のアクション候補

- [ ] MacroDroidで通知キャプチャのマクロを作成・テスト
- [ ] n8nまたはVercel APIで受信エンドポイントを作成
- [ ] テキスト蓄積ロジック（日次バッファ）の設計
- [ ] Claude APIで要約プロンプトを作成・テスト
- [ ] Obsidian Vault への自動保存フローを構築
