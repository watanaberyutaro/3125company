- [x] 振り分け
- [x] 閲覧済み

---
target_folder: 09_3125制作・納品事業部（ゼーリエ）
date: "2026-03-16"
type: specification
author: ゼーリエ
---

> ふん。シンプルな構成だ。私がやれば一瞬だ。— ゼーリエ

# MacroDroid × LINE トーク保存・要約システム 開発仕様書

**作成日**: 2026-03-16
**担当**: ゼーリエ（09_3125制作・納品事業部）
**ベースアイデア**: `04_3125アイデア保管事業部（アイゼン）/_confirmed/2026-03-16-MacroDroid-LINE代替-トーク保存-要約システム.md`

---

## システム概要

```
[Android LINE通知]
        ↓ MacroDroid（通知キャプチャ）
        ↓ HTTP POST
[/api/line-capture] ← Vercel（3125-secretary）
        ↓ GitHub API
[line-messages/YYYY-MM-DD.json] ← Obsidian Vault
        ↓ 手動 or 秘書アプリから実行
[/api/line-summary] ← Vercel
        ↓ Claude Haiku API（要約）
[02_3125経営日誌事業部（フェルン）/line-summary/YYYY-MM-DD-LINEサマリー.md]
        ↓ Discord通知（フェルン）
```

---

## 実装済みファイル

| ファイル | パス | 状態 |
|---------|------|------|
| 受信API | `api/line-capture.js` | ✅ 実装済み |
| 要約API | `api/line-summary.js` | ✅ 実装済み |

---

## API仕様

### POST /api/line-capture

MacroDroidからメッセージを受信・蓄積する。

**認証**: `Authorization: Bearer <MACRODROID_SECRET>`

**リクエスト Body (JSON):**
```json
{
  "sender": "相手の名前",
  "message": "メッセージ本文",
  "roomName": "グループ名（任意）"
}
```

**レスポンス:**
```json
{ "ok": true, "count": 12, "date": "2026-03-16" }
```

**蓄積先**: `line-messages/YYYY-MM-DD.json`
```json
[
  { "ts": "14:30", "sender": "田中", "roomName": "営業チーム", "message": "明日の会議よろしく" },
  { "ts": "14:35", "sender": "自分", "roomName": null, "message": "了解です" }
]
```

---

### POST /api/line-summary

蓄積メッセージをClaudeで要約してObsidianに保存する。

**リクエスト Body (JSON):**
```json
{ "date": "2026-03-16" }
```
（省略時は今日）

**レスポンス:**
```json
{ "ok": true, "date": "2026-03-16", "messageCount": 15, "summary": "...", "savedTo": "02_..." }
```

---

## 環境変数（Vercel）

| 変数名 | 説明 | 設定方法 |
|-------|------|---------|
| `MACRODROID_SECRET` | MacroDroid認証トークン（任意だが推奨） | Vercel Dashboard → Settings → Environment Variables |

既存の `GITHUB_TOKEN`, `GITHUB_OWNER`, `GITHUB_REPO`, `ANTHROPIC_API_KEY` はそのまま流用。

---

## MacroDroid 設定手順

### 前提
- Android端末にMacroDroidをインストール（無料版でOK）
- LINE通知が端末に届く状態にしておく

### マクロ作成手順

**① 新規マクロを作成**

マクロ名: `LINE通知キャプチャ → 秘書送信`

---

**② トリガーを設定**

`トリガー` → `通知を受信`
- アプリ: `LINE`
- 条件: すべての通知（またはフィルタリング可）

---

**③ アクションを追加: 変数に通知情報を格納**

`アクション` → `変数を設定`
- 変数名: `line_sender` → 値: `{notification_title}` （通知タイトル＝送信者名）
- 変数名: `line_message` → 値: `{notification_text}` （通知本文）

---

**④ アクションを追加: HTTP POST送信**

`アクション` → `HTTP GET/POST` → `POST`

- URL: `https://3125obsidianapp.vercel.app/api/line-capture`
- Content-Type: `application/json`
- Headers:
  ```
  Authorization: Bearer [MACRODROID_SECRETの値]
  ```
- Body:
  ```json
  {
    "sender": "{line_sender}",
    "message": "{line_message}"
  }
  ```

---

**⑤ 保存して有効化**

マクロを保存し、スイッチをONにする。

---

### テスト方法

1. スマホに自分のLINEアカウントから別アカウントでメッセージを送る
2. MacroDroidのログ（マクロ履歴）でHTTP POSTが成功しているか確認
3. Obsidian Vault の `line-messages/[今日].json` にメッセージが追記されているか確認

---

## 要約の実行方法

### 方法A: 秘書アプリから手動実行

テンプレートに追加するか、直接テキスト入力:
```
LINEサマリー作成
```

（stream.jsのclassifyTask対応が必要 → 別途実装）

### 方法B: curlで直接呼び出し

```bash
curl -X POST https://3125obsidianapp.vercel.app/api/line-summary \
  -H "Content-Type: application/json" \
  -d '{"date":"2026-03-16"}'
```

### 方法C: 毎日自動実行（将来対応）

Vercel Cron Jobs（`vercel.json`）で夜22:00に自動実行:
```json
{
  "crons": [
    {
      "path": "/api/line-summary",
      "schedule": "0 13 * * *"
    }
  ]
}
```
（UTC 13:00 = JST 22:00）

---

## 注意事項

- MacroDroidの通知キャプチャはLINEが**通知を送った分だけ**取得できる。アプリ内でのみ表示される長いメッセージは冒頭だけになる場合がある
- グループLINEの場合、`notification_title` にはグループ名が入ることが多い（個人LINEは相手名）。MacroDroid側でフィルタリング可能
- プライバシー配慮: `line-messages/` に会話内容が蓄積されるため、GitHubリポジトリはprivateであることを確認すること
- `MACRODROID_SECRET` は設定することを強く推奨（未設定だと誰でも投稿できる）

---

## 今後の拡張候補

- [ ] 特定のグループ/個人だけキャプチャするフィルター設定
- [ ] 秘書アプリのテンプレートに「LINEサマリー」を追加
- [ ] Vercel Cron Jobsで毎晩自動要約
- [ ] グループ別に要約を分ける（`roomName` でフィルタ）

---

*生成: 2026-03-16 / 09_3125制作・納品事業部（ゼーリエ）*
