- [ ] 振り分け
- [ ] 閲覧済み

---
target_folder: 09_3125制作・納品事業部（ゼーリエ）
date: "2026-04-23"
type: spec
author: ゼーリエ
---

> このゼーリエの設計書を渡してやる。光栄に思え。 — ゼーリエ

# Zephyria Webアプリ設計仕様書

## 成果物

**本体保存先**: `Cardinal/Worlds/Zephyria/docs/ゼフィリア世界_Webアプリ設計仕様書.md`

---

## 設計概要

「現実とゲームの融合」コンセプトのZephyria WebアプリケーションについてNext.js 15 + Supabase構成の完全な設計仕様書を作成した。

### 作成したもの

1. **アーキテクチャ全体図** — Cardinal JSON → Python同期スクリプト → Supabase → Next.js の4層構造をテキスト図で定義
2. **画面遷移図** — ログイン・ダッシュボード・国詳細・NPC・クエスト・アルカディア・経済・ニュースの8画面遷移を定義
3. **コンポーネント設計** — 全8画面のコンポーネントツリーを詳細に記述。IslandMesh・WeatherAnimation・RelationshipNetworkなど固有コンポーネントの仕様も含む
4. **Supabaseテーブル定義（11テーブル）** — 全カラム・型・制約・インデックス・Realtime設定・RLSポリシーをSQL形式で記述
5. **API Routes設計** — 14エンドポイントの仕様・リクエスト/レスポンス型定義
6. **同期スクリプト（Python）** — `sync_to_supabase.py` の完全な疑似コード実装。nations/npcs/relationships/arcadia/economy/resources/newsの7種同期
7. **実装フェーズ計画** — Phase 1（基盤）/ Phase 2（ゲームUI）/ Phase 3（経済・高度機能）の3段階計画

### テーブル一覧

| テーブル名 | 件数 | 内容 |
|---|---|---|
| nations | 5 | 5カ国の状態 |
| npcs | 47 | 全NPC詳細 |
| npc_relationships | 可変 | NPC間関係値 |
| quests | 可変 | クエスト履歴 |
| quest_assignments | 可変 | クエスト担当 |
| arcadia_floors | 100 | フロア状態 |
| resources | 23 | 資源カタログ |
| resource_flows | 可変 | 産出・消費フロー |
| economy_snapshots | 可変 | 経済履歴 |
| news | 可変 | ニュース |
| world_events | 可変 | 世界イベント |
| users | 可変 | 招待ユーザー |

---

## ブリーフィング（CEOへ）

### 気づいたこと・注目点

- CardinalのJSONスキーマは既に十分な構造を持っており、Supabaseへのマッピングは直接的。同期スクリプトは比較的シンプルに実装できる
- NPCのrelationshipsはJSONでは `npc_from → {npc_to: {type, value, note}}` の構造のため、DB側では `npc_relationships` に正規化している。方向性（誰が誰をどう思うか）が保持される
- 秘密組織情報はRLS + APIレイヤーでownerのみ参照可能にする設計とした。NPCカード上では「バッジ表示のみ」で内容は権限次第
- Three.jsは世界マップの3D表示に使うが、パフォーマンスを考慮してPhase 1ではSVG代替でMVPを作り、Phase 2でThree.jsに移行することを推奨する

### 他部署への推奨アクション（任意）

- 【開発部へ】本設計書をベースにClaude Code MVP用プロンプトを生成することを推奨する
- 【アイゼン（アイデア保管部）へ】ゼフィリア通信（ニュース機能）はコンテンツ生成フローが必要。ユイとの連携仕様を別途検討すること

### このタスクの完結度

- [x] 完結（詳細設計書作成まで。実装はClaude Code MVP用プロンプト経由で行うこと）
