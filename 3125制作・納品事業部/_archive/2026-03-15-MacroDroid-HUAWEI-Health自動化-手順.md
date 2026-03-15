- [ ] 閲覧済み

---
created: 2026-03-15
type: setup_guide
status: in_progress
project: HUAWEI HealthKit × 秘書強化（MacroDroid方式）
---

# MacroDroid × HUAWEI Health 自動化 手順書

**方式**: APIなし・本人確認なし・無料
**仕組み**: Androidが毎朝自動でデータをエクスポート → Google Drive → Macの秘書が読む

---

## 全体ステップ

- [ ] **Step 1**: HUAWEI HealthアプリでGoogle Driveへのアクセスを許可
- [ ] **Step 2**: MacroDroidをインストールしてマクロを設定
- [ ] **Step 3**: Google Drive Desktop をMacにインストール・同期設定
- [ ] **Step 4**: Macにパーサースクリプトを配置
- [ ] **Step 5**: 動作確認

---

## Step 1: HUAWEI HealthアプリでGoogle Driveへのアクセスを許可

**Androidで操作**

1. HUAWEI Healthアプリを開く
2. 右下「プロフィール（Me）」タブ
3. 「設定（Settings）」→「プライバシーセンター」
4. 「データのエクスポート」をタップ
5. 「Google Driveにエクスポート」を一度手動で実行する
   → このとき「Google Driveへのアクセスを許可しますか？」が出たら「許可」

> ✅ エクスポートが完了し、Google Drive上にZIPファイルが届いたら次へ

---

## Step 2: MacroDroidをインストール・マクロ設定

**Androidで操作**

### インストール
1. Google Play Storeで「MacroDroid」を検索してインストール（無料）

### マクロ作成
1. MacroDroidを開く
2. 「＋ マクロを追加」をタップ
3. マクロ名: `毎朝ヘルスデータエクスポート`

---

### トリガー設定（いつ実行するか）

1. 「トリガー」→「日時」→「時刻指定」
2. 時刻: **06:00**
3. 繰り返し: **毎日**

---

### アクション設定（何をするか）

以下のアクションを順番に追加する:

**アクション1: HUAWEI Healthアプリを起動**
- 「アクション」→「アプリ」→「アプリを起動」
- アプリ: 「HUAWEI Health」

**アクション2: 3秒待機**（アプリ起動待ち）
- 「アクション」→「制御」→「待機」→ 3000ミリ秒

**アクション3: UIクリック（プロフィールタブ）**
- 「アクション」→「UI操作」→「画面をタップ」
- 「Meタブ」の座標をタップ（画面右下あたり）

**アクション4: 3秒待機**

**アクション5: UIクリック（設定ボタン）**
- 「UI操作」→「テキストでタップ」→ `Settings` または `設定`

**アクション6: UIクリック（Privacy Center）**
- 「UI操作」→「テキストでタップ」→ `Privacy` または `プライバシー`

**アクション7: UIクリック（Export data）**
- 「UI操作」→「テキストでタップ」→ `Export` または `エクスポート`

**アクション8: UIクリック（Google Drive選択）**
- 「UI操作」→「テキストでタップ」→ `Google Drive`

**アクション9: 5秒待機**（エクスポート処理待ち）

**アクション10: ホームに戻る**
- 「アクション」→「デバイス」→「ホームボタン」

> ⚠️ UI操作のタップ座標はお使いのAndroid/HUAWEIアプリのバージョンによって異なります。
> 実際に画面を見ながら座標を調整してください。

---

### 代替: シェアシートを使う方法（より安定）

UI操作が不安定な場合は、以下のアプローチが安定します:

1. HUAWEI Healthのウィジェット/ショートカットを使って手動エクスポート画面を開く
2. MacroDroidの「インテント送信」でHUAWEI Healthのエクスポート機能を直接呼び出す
   - パッケージ名: `com.huawei.health`
   - 実行後、シェアシートでGoogle Driveを選択

---

## Step 3: Google Drive Desktop をMacに設定

**Macで操作**

1. https://drive.google.com/drive/downloads → 「Google Drive for desktop」をダウンロード
2. インストールして同期フォルダを設定
3. HUAWEI HealthのエクスポートZIPが保存されるフォルダを確認
   - 通常: `My Drive/HuaweiHealth/` または `マイドライブ/`
4. そのフォルダのローカルパスをメモ（例: `~/Google Drive/My Drive/HuaweiHealth/`）

---

## Step 4: Macにパーサースクリプトを配置

スクリプトは既に配置済みです（`~/.claude/huawei-health/fetch_health.py`）。

Google Driveのフォルダパスをconfigファイルにセットするだけです:

```bash
python3 ~/.claude/huawei-health/setup_gdrive.py \
  --drive_folder "~/Google Drive/My Drive/HuaweiHealth"
```

---

## Step 5: 動作確認

```bash
# 朝モード（昨日のデータ）
python3 ~/.claude/huawei-health/fetch_health.py

# 夜モード（今日のデータ）
python3 ~/.claude/huawei-health/fetch_health.py --mode evening
```

健康データのJSONが返ってきたら完了です。

---

## 進捗メモ

| 日時 | ステップ | 状況 |
|------|---------|------|
| 2026-03-15 | 手順書作成 | ✅ |
| - | Step 1: HUAWEI Health → Google Drive手動エクスポート確認 | ⏳ |
| - | Step 2: MacroDroid設定 | ⏳ |
| - | Step 3: Google Drive Desktop Mac設定 | ⏳ |
| - | Step 4: スクリプト設定 | ⏳ |
| - | Step 5: 動作確認 | ⏳ |
