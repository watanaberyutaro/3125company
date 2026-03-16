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

## 設計方針の変更

| 旧方式 | 新方式 |
|-------|-------|
| 通知キャプチャ（リアルタイム） | トーク履歴エクスポート（1日1回） |
| 1件ずつPOST送信 | .txtファイルを丸ごと送信 |
| `line-messages/YYYY-MM-DD.json` に蓄積 | 直接要約・保存 |
| 通知の冒頭しか取れない | 全文取得できる |

---

## システム概要

```
[MacroDroid] 毎日 23:00
        ↓ UIオートメーション
[LINE「トーク履歴を送信」] → .txtファイル生成
        ↓ ファイル内容を読み取り
        ↓ HTTP POST（本文ごと送信）
[/api/line-history] ← Vercel（3125-secretary）
        ↓ 今日の日付でフィルタリング
        ↓ Claude Haiku API（要約）
[02_3125経営日誌事業部（フェルン）/line-summary/YYYY-MM-DD-LINEサマリー.md]
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

LINEの.txtファイル内容を受信し、今日分を要約してObsidianに保存する。

**認証**: `Authorization: Bearer <MACRODROID_SECRET>`

**リクエスト Body (JSON)**:
```json
{
  "content": "[LINE]グループ名 のトーク履歴\n保存日時：...\n\n2026/03/16(月)\n14:30\t田中\tメッセージ",
  "roomName": "グループ名（任意・上書き用）"
}
```

**処理フロー**:
1. `content` から今日の日付（JST）のセクションを抽出
2. `HH:MM\t送信者\t本文` をパースして配列化
3. メッセージが0件なら `{ ok: true, summary: "本日のトーク履歴なし" }` を返す
4. Claude Haiku で要約
5. `02_3125経営日誌事業部（フェルン）/line-summary/YYYY-MM-DD-LINEサマリー.md` に保存（GitHub API）
6. Discord通知（フェルンチャンネル）
7. `{ ok: true, date, messageCount, summary, savedTo }` を返す

**レスポンス**:
```json
{
  "ok": true,
  "date": "2026-03-16",
  "messageCount": 12,
  "summary": "【要約内容】",
  "savedTo": "02_3125経営日誌事業部（フェルン）/line-summary/2026-03-16-LINEサマリー.md"
}
```

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

### マクロ: `LINE履歴エクスポート → 秘書送信`

**① トリガー設定**

`トリガー` → `日時` → `繰り返し`
- 時刻: `23:00`
- 繰り返し: `毎日`

---

**② アクション: LINEを開いて特定トークへ移動**

`アクション` → `アプリ` → `アプリを起動`
- アプリ: `LINE`

その後、UIオートメーションで対象トーク/グループを開く:

`アクション` → `UI操作` → `UI操作の記録`
1. 対象トークルームをタップ
2. 右上メニュー（⋮）→ `その他` → `トーク設定`
3. `トーク履歴を送信` をタップ
4. 共有先として `ファイルに保存` または `メモアプリ` を選択

> **注意**: `トーク履歴を送信` 後、「メールで送る」「ファイルマネージャーに保存」などが選べる。ファイルマネージャーに保存 → MacroDroidでそのファイルを読む方法が最も安定。

---

**③ アクション: ファイル内容を変数に格納**

`アクション` → `ファイル` → `ファイルを読み込む`
- ファイルパス: `/storage/emulated/0/Download/[LINE]グループ名_のトーク履歴.txt`
  （実際のファイル名はLINEが生成するもの。ワイルドカードが使える場合は `*のトーク履歴.txt` 等）
- 変数: `line_history_text`

---

**④ アクション: HTTP POST送信**

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
    "content": "{line_history_text}"
  }
  ```

---

**⑤ アクション: レスポンス確認（任意）**

`アクション` → `通知` → `通知を表示`
- テキスト: `LINE履歴送信完了`

---

### 複数トークを対象にする場合

ルームごとにマクロを繰り返す。または対象を1つのグループに絞る（推奨）。
送信先が複数ある場合は `api/line-history` を複数回呼べばよい。`roomName` パラメータで区別できる。

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
3. Obsidian Vault の `02_3125経営日誌事業部（フェルン）/line-summary/[今日]-LINEサマリー.md` が作成されているか確認
4. Discord フェルンチャンネルに通知が届いているか確認

curl でも直接テスト可能:
```bash
curl -X POST https://3125obsidianapp.vercel.app/api/line-history \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [MACRODROID_SECRET]" \
  -d '{
    "content": "[LINE]テスト のトーク履歴\n保存日時：2026/03/16 23:00\n\n2026/03/16(月)\n14:30\t田中\tテストメッセージです\n14:35\t自分\tありがとう"
  }'
```

---

## 注意事項

- トーク履歴の送信はLINE側の仕様変更で動作が変わる可能性がある
- MacroDroidのUIオートメーションは、LINEのアップデートで動作しなくなる場合がある（再記録が必要）
- `line_history_text` にトーク全文が入るため、長い会話はAPIのボディサイズに注意（通常は問題なし）
- GitHubリポジトリはprivateであることを確認（要約結果に会話内容が含まれるため）

---

## 今後の拡張候補

- [ ] 複数グループへの対応（ルームごとにサマリーを分ける）
- [ ] 秘書アプリのテンプレートに「LINEサマリー確認」を追加
- [ ] 取得失敗時のリトライマクロ
- [ ] 週次でまとめた「週間LINEレポート」の生成

---

*生成: 2026-03-16 v2 / 09_3125制作・納品事業部（ゼーリエ）*
