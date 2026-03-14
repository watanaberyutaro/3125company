#!/bin/bash
# =============================================================
# 渡邊カンパニー 日次日記自動生成スクリプト
# 毎日22:00に自動実行
# =============================================================

DATE=$(date +%Y-%m-%d)
DAY_JP=$(date +%A | sed 's/Monday/月曜日/;s/Tuesday/火曜日/;s/Wednesday/水曜日/;s/Thursday/木曜日/;s/Friday/金曜日/;s/Saturday/土曜日/;s/Sunday/日曜日/')
WEEK=$(date +%Y-W%V)

VAULT="/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"
COMPANY="/Users/watanaberyuutarou/Desktop/3125映像/Company/.company"
OUTPUT="$VAULT/3125経営日誌事業部/$DATE.md"

# すでに存在する場合はスキップ
if [ -f "$OUTPUT" ]; then
  echo "[$DATE] 日記ファイルはすでに存在します: $OUTPUT"
  exit 0
fi

# =============================================================
# 1. カレンダーから本日の予定を取得（タイムアウト付き）
# =============================================================
APPLESCRIPT_FILE=$(mktemp /tmp/diary-cal.XXXXXX.applescript)
cat > "$APPLESCRIPT_FILE" << 'APPLESCRIPT'
set today to current date
set startOfDay to today - (time of today)
set endOfDay to startOfDay + (23 * hours + 59 * minutes + 59)
set eventList to ""

tell application "Calendar"
  repeat with cal in every calendar
    set calName to name of cal
    if calName is not "誕生日" and calName is not "日本の祝日" and calName is not "Siriからの提案" and calName is not "日時設定ありリマインダー" then
      repeat with e in (every event of cal whose start date >= startOfDay and start date <= endOfDay)
        try
          set eTitle to summary of e
          set eStart to start date of e
          set h to text -2 thru -1 of ("0" & (hours of eStart))
          set m to text -2 thru -1 of ("0" & (minutes of eStart))
          set eventList to eventList & "- " & h & ":" & m & "  " & eTitle & "  [" & calName & "]" & return
        end try
      end repeat
    end if
  end repeat
end tell

if eventList is "" then
  return "（本日の予定なし）"
else
  return eventList
end if
APPLESCRIPT

CALENDAR_EVENTS=$(timeout 10 osascript "$APPLESCRIPT_FILE" 2>/dev/null || echo "（カレンダー取得スキップ）")
rm -f "$APPLESCRIPT_FILE"

# =============================================================
# 2. 本日のTODOを取得
# =============================================================
TODO_FILE="$COMPANY/secretary/todos/$DATE.md"
if [ -f "$TODO_FILE" ]; then
  DONE_TASKS=$(grep '^\- \[x\]' "$TODO_FILE" | sed 's/^/  /' || echo "  （なし）")
  TODO_TASKS=$(grep '^\- \[ \]' "$TODO_FILE" | sed 's/^/  /' || echo "  （なし）")
  if [ -z "$DONE_TASKS" ]; then DONE_TASKS="  （なし）"; fi
  if [ -z "$TODO_TASKS" ]; then TODO_TASKS="  （なし）"; fi
else
  DONE_TASKS="  （TODOファイルなし）"
  TODO_TASKS="  （TODOファイルなし）"
fi

# =============================================================
# 3. 本日の3125情報受付事業部からInboxを取得
# =============================================================
INBOX_DIR="$VAULT/3125情報受付事業部"
INBOX_CONTENT=""
if [ -d "$INBOX_DIR" ]; then
  # 本日作成されたファイル一覧を取得
  TODAY_FILES=$(find "$INBOX_DIR" -maxdepth 1 -name "${DATE}*.md" 2>/dev/null)
  if [ -n "$TODAY_FILES" ]; then
    while IFS= read -r file; do
      TITLE=$(basename "$file" .md | sed "s/^${DATE}-//")
      INBOX_CONTENT="$INBOX_CONTENT  - $TITLE\n"
    done <<< "$TODAY_FILES"
  fi
fi
if [ -z "$INBOX_CONTENT" ]; then INBOX_CONTENT="  （本日のInboxエントリなし）"; fi

# =============================================================
# 4. 日記ファイル生成
# =============================================================
python3 - << PYEOF
content = """---
date: "$DATE"
day: "$DAY_JP"
week: "$WEEK"
type: daily-diary
---

# 日次レポート: $DATE ($DAY_JP)

---

## 📅 本日の予定・活動

$CALENDAR_EVENTS

---

## ✅ タスク実績

### 完了
$DONE_TASKS

### 持ち越し・未完了
$TODO_TASKS

---

## 📥 本日のキャプチャ・メモ

$INBOX_CONTENT

---

## 💭 今日の考え・気づき

（ここに自由記述）

---

## 🔥 明日への引き継ぎ

- [ ]

---

## 📊 今日のまとめ

| 項目 | 内容 |
|------|------|
| 達成感 | ★★★☆☆ |
| 集中度 | ★★★☆☆ |
| ひとこと | |

---
*自動生成: $DATE 22:00 / 渡邊カンパニー 秘書室*
"""
with open(r"$OUTPUT", "w") as f:
    f.write(content)
print("OK")
PYEOF

echo "[$DATE] 日記を生成しました: $OUTPUT"

# =============================================================
# 5. カレンダーに通知を登録（タイムアウト付き）
# =============================================================
NOTIFY_SCRIPT=$(mktemp /tmp/diary-notify.XXXXXX.applescript)
OBSIDIAN_LINK="obsidian://open?vault=Obsidian%20Vault&file=3125%E7%B5%8C%E5%96%B6%E6%97%A5%E8%AA%8C%E4%BA%8B%E6%A5%AD%E9%83%A8%2F$DATE"
cat > "$NOTIFY_SCRIPT" << APPLESCRIPT
set startTime to (current date) + (10 * minutes)
set endTime to startTime + (30 * minutes)
set obsLink to "$OBSIDIAN_LINK"
set desc to "本日の日記が自動生成されました。" & return & return & "Obsidian: " & obsLink

tell application "Calendar"
  tell calendar "渡邊カンパニー"
    make new event with properties {summary:"📔 日次レポート $DATE", start date:startTime, end date:endTime, description:desc}
  end tell
end tell
APPLESCRIPT

timeout 10 osascript "$NOTIFY_SCRIPT" 2>/dev/null && echo "[$DATE] カレンダーに登録しました" || echo "[$DATE] カレンダー登録スキップ"
rm -f "$NOTIFY_SCRIPT"
