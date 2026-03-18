#!/bin/bash
# 3125-scheduled-run.sh — スケジュール実行ラッパー
# 各launchdジョブが完了後に、次のジョブの起床時刻をpmsetで設定する
#
# Usage: 3125-scheduled-run.sh <command> <next_wake_HH:MM>
# Example: 3125-scheduled-run.sh "report" "23:28"
#
# チェーン: 朝(6:00)→昼(11:58)→夜(23:28)→翌朝(5:58)

COMMAND="$1"
NEXT_WAKE="$2"
VAULT="/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"
LOG_DIR="$HOME/Library/Logs"

echo "$(date '+%Y-%m-%d %H:%M:%S') [3125-scheduled] START: /3125 $COMMAND" >> "$LOG_DIR/3125-scheduled.log"

# Claude Code で実行
cd "$VAULT"
/Users/watanaberyuutarou/.local/bin/claude -p "/3125 $COMMAND"
EXIT_CODE=$?

echo "$(date '+%Y-%m-%d %H:%M:%S') [3125-scheduled] END: /3125 $COMMAND (exit=$EXIT_CODE)" >> "$LOG_DIR/3125-scheduled.log"

# 次の起床時刻を設定
if [ -n "$NEXT_WAKE" ]; then
    NEXT_HOUR=$(echo "$NEXT_WAKE" | cut -d: -f1)
    CURRENT_HOUR=$(date +%H)

    # 次の起床が現在時刻より前なら翌日
    if [ "$NEXT_HOUR" -lt "$CURRENT_HOUR" ]; then
        NEXT_DATE=$(date -v+1d "+%m/%d/%Y")
    else
        NEXT_DATE=$(date "+%m/%d/%Y")
    fi

    sudo pmset schedule wake "$NEXT_DATE $NEXT_WAKE:00"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [3125-scheduled] WAKE SET: $NEXT_DATE $NEXT_WAKE:00" >> "$LOG_DIR/3125-scheduled.log"
fi
