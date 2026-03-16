- [ ] 振り分け
- [ ] 閲覧済み

---
target_folder: 09_3125制作・納品事業部（ゼーリエ）
date: "2026-03-16"
type: specification
author: ゼーリエ
supersedes: 2026-03-16-MacroDroid-LINE-capture-開発仕様書.md
---

> ふん。前の仕様は捨てた。こっちの方がずっとマシだ。— ゼーリエ

# MacroDroid × LINE トーク履歴・要約システム 開発仕様書 v2

**作成日**: 2026-03-16
**担当**: ゼーリエ（09_3125制作・納品事業部）
**旧仕様の廃止**: `api/line-capture.js`（通知キャプチャ方式）は本仕様に置き換える

---

## 設計方針

| 旧方式 | 新方式 |
|-------|-------|
| 通知キャプチャ（リアルタイム） | トーク履歴エクスポート（1日3回） |
| 1件ずつPOST送信 | .txtファイルを丸ごと送信 |
| 蓄積なし・直接要約 | `line-messages/YYYY-MM-DD.json` に差分追記して蓄積 |
| 通知の冒頭しか取れない | 全文取得できる |

---

## システム概要

```
[MacroDroid] 07:00 / 15:00 / 23:00（8時間おき）
        ↓ UIオートメーション
[LINE「トーク履歴を送信」] → .txtファイル生成
        ↓ ファイル内容を読み取り
        ↓ HTTP POST（.txt本文ごと送信）
[/api/line-history] ← Vercel（3125-secretary）
        ↓ 今日の日付でフィルタリング
        ↓ 差分のみ抽出（重複除去）
[line-messages/YYYY-MM-DD.json] ← GitHub（Obsidian Vault）に蓄積
        ↓ 毎回実行
        ↓ 直近14日分のJSONを全件読み込み
        ↓ Claude Haiku API（要約・更新）
[02_3125経営日誌事業部（フェルン）/line-summary/YYYY-MM-DD-LINEサマリー.md] ← 上書き更新
        ↓ Discord通知（フェルン）
```

---

## LINEトーク履歴 .txt フォーマット

LINEの「トーク履歴を送信」で出力されるファイルの形式:

```
[LINE]グループ名 のトーク履歴
保存日時：2026/03/16 23:00

2026/03/16(月)
14:30	田中太郎	明日の会議よろしくお願いします
14:35	自分	承知しました。場所はどこですか？
14:37	田中太郎	会議室Aです

2026/03/15(日)
09:00	鈴木花子	おはようございます
```

**パース方針**:
- `YYYY/MM/DD(曜日)` 行が日付セクション区切り
- `HH:MM\t送信者\t本文` が1メッセージ
- 今日の日付セクション以降、次の日付セクションまでを抽出
- `[LINE]` ヘッダー行でルーム名を取得

---

## 実装ファイル

### 新規: `api/line-history.js`

**POST /api/line-history**

LINEの.txtファイル内容を受信し、今日分を差分追記で蓄積する。23:00実行時は要約まで行う。

**認証**: `Authorization: Bearer <MACRODROID_SECRET>`

**リクエスト Body (JSON)**:
```json
{
  "content": "[LINE]グループ名 のトーク履歴\n保存日時：...\n\n2026/03/16(月)\n14:30\t田中\tメッセージ",
  "roomName": "グループ名（任意・上書き用）",
  "summarize": true
}
```

| パラメータ | 説明 |
|-----------|------|
| `content` | LINEの.txtファイル全文（必須） |
| `roomName` | ルーム名の上書き（省略時は.txtのヘッダーから取得） |
| `summarize` | `true` のとき要約・保存まで実行。省略時は蓄積のみ |

**処理フロー**:
1. `content` から今日の日付（JST）のセクションを抽出
2. `HH:MM\t送信者\t本文` をパースして配列化
3. `line-messages/YYYY-MM-DD.json` を GitHub API で読み込む
4. 既存データと照合し、`ts + sender + message` が一致するものは除外（重複除去）
5. 新規メッセージを追記して GitHub API で書き戻す
6. `summarize: true` の場合のみ:
   - Claude Haiku で要約
   - `02_3125経営日誌事業部（フェルン）/line-summary/YYYY-MM-DD-LINEサマリー.md` に保存
   - Discord通知（フェルン）
7. レスポンスを返す

**レスポンス（蓄積のみ）**:
```json
{
  "ok": true,
  "date": "2026-03-16",
  "newMessages": 4,
  "totalMessages": 11
}
```

**レスポンス（要約あり）**:
```json
{
  "ok": true,
  "date": "2026-03-16",
  "newMessages": 3,
  "totalMessages": 14,
  "summary": "【要約内容】",
  "savedTo": "02_3125経営日誌事業部（フェルン）/line-summary/2026-03-16-LINEサマリー.md"
}
```

---

### 蓄積データ形式: `line-messages/YYYY-MM-DD.json`

```json
[
  { "ts": "08:12", "sender": "田中太郎", "roomName": "営業チーム", "message": "今日の件よろしく" },
  { "ts": "12:30", "sender": "自分",    "roomName": "営業チーム", "message": "承知しました" },
  { "ts": "14:30", "sender": "鈴木",    "roomName": null,         "message": "個別で確認したいことが" }
]
```

（既存の `line-summary.js` がそのままこのJSONを読んで要約できる形式を維持）

---

### 既存: `api/line-summary.js`

変更不要。`line-messages/YYYY-MM-DD.json` を読んで要約する既存機能をそのまま流用できる。
`summarize: true` のときは `line-history.js` 内部から直接呼び出す形にする。

---

### 廃止: `api/line-capture.js`

通知キャプチャ方式のため不要になる。ファイルは残しておいて構わないが、MacroDroidのマクロからは呼び出さない。

---

## 環境変数（Vercel）

| 変数名 | 説明 |
|-------|------|
| `MACRODROID_SECRET` | MacroDroid認証トークン（推奨） |
| `GITHUB_TOKEN` | 既存（流用） |
| `GITHUB_OWNER` | 既存（流用） |
| `GITHUB_REPO` | 既存（流用） |
| `ANTHROPIC_API_KEY` | 既存（流用） |

---

## MacroDroid 設定手順

### 前提

- Android端末にMacroDroidをインストール（無料版でOK）
- LINEのトーク履歴エクスポートが有効（デフォルトで可能）

---

### トリガー：8時間おき3回

**方法A（推奨）: 時刻指定で3つのトリガー**

`トリガー` → `日時` → `特定の時刻`

| トリガー名 | 時刻 | `summarize` パラメータ |
|-----------|------|----------------------|
| 朝の収集   | 07:00 | `false`（蓄積のみ） |
| 昼の収集   | 15:00 | `false`（蓄積のみ） |
| 夜の収集   | 23:00 | `true`（蓄積 + 要約） |

1つのマクロ内に3つのトリガーを登録するか、マクロを3つに分けて作成する。

**方法B: 間隔トリガー**

`トリガー` → `日時` → `繰り返し` → `間隔: 8時間`

（開始時刻を 07:00 に設定すると 07:00 / 15:00 / 23:00 になる）

> 方法Bの場合、常に `summarize: false` にしておき、23:00 専用マクロを別途作る形が確実。

---

### マクロ: `LINE履歴収集（朝・昼）`

**① トリガー設定**

`トリガー` → `日時` → `特定の時刻`
- 07:00 と 15:00 の2つを追加

---

**② アクション: LINEを開いてトーク履歴をエクスポート**

`アクション` → `アプリ` → `アプリを起動`
- アプリ: `LINE`

`アクション` → `UI操作` → `UI操作の記録`
1. 対象トークルームをタップ
2. 右上メニュー（⋮）→ `その他` → `トーク設定`
3. `トーク履歴を送信` をタップ
4. `ファイルに保存`（Downloadフォルダ等に保存）

---

**③ アクション: ファイル内容を変数に格納**

`アクション` → `ファイル` → `ファイルを読み込む`
- ファイルパス: `/storage/emulated/0/Download/[LINE]グループ名_のトーク履歴.txt`
- 変数: `line_history_text`

---

**④ アクション: HTTP POST送信（蓄積のみ）**

`アクション` → `HTTP GET/POST` → `POST`

- URL: `https://3125obsidianapp.vercel.app/api/line-history`
- Content-Type: `application/json`
- Headers:
  ```
  Authorization: Bearer [MACRODROID_SECRETの値]
  ```
- Body:
  ```json
  {
    "content": "{line_history_text}",
    "summarize": false
  }
  ```

---

### マクロ: `LINE履歴収集 + 要約（夜）`

上記と同じ構成だが、POSTのBodyのみ変更:

```json
{
  "content": "{line_history_text}",
  "summarize": true
}
```

---

### 複数トークを対象にする場合

ルームごとに「トーク履歴エクスポート → POST」のアクションセットを繰り返す。
`roomName` パラメータで区別される。

---

## トーク履歴エクスポートのファイル名について

LINEが生成する .txt のファイル名パターン:
```
[LINE]◯◯ のトーク履歴.txt
[LINE]グループ◯◯ のトーク履歴.txt
```

MacroDroidの「最新ファイルを読む」機能や、ファイル名のワイルドカードを使うと複数ルームに対応しやすい。

---

## テスト方法

1. MacroDroidで一度だけマクロを手動実行（▶ ボタン）
2. MacroDroidのログで HTTP POST が 200 OK になっているか確認
3. `line-messages/[今日].json` に蓄積されているか確認
4. `summarize: true` で実行後、`02_3125経営日誌事業部（フェルン）/line-summary/[今日]-LINEサマリー.md` が作成されているか確認
5. Discord フェルンチャンネルに通知が届いているか確認

curl でも直接テスト可能:
```bash
# 蓄積のみ
curl -X POST https://3125obsidianapp.vercel.app/api/line-history \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [MACRODROID_SECRET]" \
  -d '{
    "content": "[LINE]テスト のトーク履歴\n保存日時：2026/03/16 15:00\n\n2026/03/16(月)\n14:30\t田中\tテストメッセージ",
    "summarize": false
  }'

# 要約まで実行
curl -X POST https://3125obsidianapp.vercel.app/api/line-history \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [MACRODROID_SECRET]" \
  -d '{
    "content": "[LINE]テスト のトーク履歴\n保存日時：2026/03/16 23:00\n\n2026/03/16(月)\n14:30\t田中\tテストメッセージ",
    "summarize": true
  }'
```

---

## 注意事項

- トーク履歴の送信はLINE側の仕様変更で動作が変わる可能性がある
- MacroDroidのUIオートメーションは、LINEのアップデートで動作しなくなる場合がある（再記録が必要）
- 重複除去は `ts + sender + message` の完全一致で行う。同じ時刻に同じ人が同じ文を送った場合は除外される（実用上問題なし）
- GitHubリポジトリはprivateであることを確認（会話内容が蓄積されるため）

---

## 今後の拡張候補

- [ ] 複数グループへの対応（ルームごとにサマリーを分ける）
- [ ] 秘書アプリのテンプレートに「LINEサマリー確認」を追加
- [ ] 取得失敗時のリトライマクロ
- [ ] 週次でまとめた「週間LINEレポート」の生成

---

*生成: 2026-03-16 v2.1 / 09_3125制作・納品事業部（ゼーリエ）*
