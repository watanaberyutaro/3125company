- [ ] 閲覧済み

---
created: 2026-03-15
type: setup_guide
status: in_progress
project: HUAWEI HealthKit × 秘書強化
---

# HUAWEI Health Kit API 取得手順書

**対象デバイス**: HUAWEI GT 4
**目的**: 秘書がHealth Kitデータを取得できるようにする
**所要時間**: 約30〜60分（審査待ち除く）

---

## 全体ステップ

- [x] HUAWEIアカウント取得済み
- [x] HUAWEI GT 4 所持済み
- [ ] **Step 1**: Developer登録
- [ ] **Step 2**: AppGallery Connectでプロジェクト作成
- [ ] **Step 3**: Health Kit API 有効化・申請
- [ ] **Step 4**: OAuth認証情報（Client ID / Secret）取得
- [ ] **Step 5**: Access Token 取得（セットアップスクリプト実行）
- [ ] **Step 6**: config.json 保存・動作確認

---

## Step 1: Developerアカウント登録

**ブラウザで操作（オーナー）**

1. https://developer.huawei.com/consumer/en/ を開く
2. 右上「Register」→ 既存のHUAWEI IDでサインイン（新規登録不要）
3. 「Individual Developer」を選択
4. 名前・国（Japan）・電話番号を入力して登録完了

> ✅ 登録完了したら次のステップへ（審査なし・即時）

---

## Step 2: AppGallery Connectでプロジェクト作成

**ブラウザで操作（オーナー）**

1. https://developer.huawei.com/consumer/en/service/josp/agc/index.html を開く
2. 「My Projects」→「Add Project」
3. プロジェクト名: `huawei-health-secretary`（任意）
4. プロジェクト作成後、「Add app」をクリック
5. 以下を入力:
   - Platform: **Android**（REST API利用のため形式上選択）
   - App name: `health-secretary`
   - Package name: `com.watanabe.healthsecretary`（任意）
   - Default language: Japanese
6. 「OK」で作成

> ✅ App情報ページが開いたら次のステップへ

---

## Step 3: Health Kit API 有効化

**ブラウザで操作（オーナー）**

1. 作成したプロジェクトのページで「APIs」タブを開く
2. 「Health Kit」を検索して「Enable」
3. 左メニューから「Auth Service」→「Enable」もONにする

> ⚠️ Health Kit は申請が必要な場合があります。
> 「Apply」ボタンが表示された場合: 用途（「Personal health data integration for productivity tool」等）を入力して申請。
> 審査は通常1〜3営業日。通知メールが届いたら Step 4 へ進む。

---

## Step 4: OAuth認証情報を取得

**ブラウザで操作（オーナー）**

1. AppGallery Connect → 対象アプリ → 「General information」タブ
2. 以下の2つをコピーしてメモ:
   - **App ID**（= Client ID）
   - **App Secret**（= Client Secret）
3. 「OAuth 2.0」または「Credentials」セクションで以下を設定:
   - Redirect URI: `http://localhost:8888/callback`
   - スコープに以下を追加（チェックを入れる）:
     - `https://www.huawei.com/healthkit/sleep.read`
     - `https://www.huawei.com/healthkit/heartrate.read`
     - `https://www.huawei.com/healthkit/stress.read`
     - `https://www.huawei.com/healthkit/step.read`
     - `https://www.huawei.com/healthkit/calories.read`

> ✅ Client ID と Client Secret をメモしたら次のステップへ

---

## Step 5: Access Token 取得（スクリプト実行）

**ターミナルで操作**

以下のコマンドを実行してセットアップスクリプトを起動します:

```bash
python3 ~/.claude/huawei-health/setup_oauth.py \
  --client_id "YOUR_CLIENT_ID" \
  --client_secret "YOUR_CLIENT_SECRET"
```

スクリプトが以下を自動で行います:
1. ブラウザでHUAWEI認可ページを開く
2. ローカルサーバー（localhost:8888）で認可コードを受け取る
3. 認可コードをAccess Token / Refresh Tokenに交換
4. `~/.claude/huawei-health/config.json` に自動保存

---

## Step 6: 動作確認

```bash
# 朝モード（昨日のデータ）
python3 ~/.claude/huawei-health/fetch_health.py

# 夜モード（今日のデータ）
python3 ~/.claude/huawei-health/fetch_health.py --mode evening
```

JSONが返ってきたらセットアップ完了です。
次回 `/company` を叩くと健康データがブリーフィングに表示されます。

---

## 進捗メモ

| 日時 | ステップ | 状況 |
|------|---------|------|
| 2026-03-15 | 手順書作成 | ✅ |
| - | Step 1: Developer登録 | ⏳ |

