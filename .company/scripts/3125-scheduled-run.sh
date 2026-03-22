#!/bin/bash
# 3125-scheduled-run.sh — スケジュール実行ラッパー
# 各launchdジョブが独立して実行される（チェーン方式は廃止）
#
# Usage: 3125-scheduled-run.sh <command>
# Example: 3125-scheduled-run.sh "report"

COMMAND="$1"
VAULT="/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"
LOG_DIR="$HOME/Library/Logs"

# 朝ジョブ（COMMAND空）の場合、昼用のwakeを先に設定する
# pmset repeatは1つしか使えないため、朝が確実に起動する前提で昼wakeを設定
if [ -z "$COMMAND" ]; then
    NOON_DATE=$(date "+%m/%d/%Y")
    NOON_HOUR=$(date +%H)
    # 既に12時を過ぎていたら翌日
    if [ "$NOON_HOUR" -ge 12 ]; then
        NOON_DATE=$(date -v+1d "+%m/%d/%Y")
    fi
    sudo pmset schedule wake "$NOON_DATE 11:58:00" 2>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') [3125-scheduled] NOON WAKE SET: $NOON_DATE 11:58:00" >> "$LOG_DIR/3125-scheduled.log"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') [3125-scheduled] START: /3125 $COMMAND" >> "$LOG_DIR/3125-scheduled.log"

# Claude Code で実行
cd "$VAULT"
/Users/watanaberyuutarou/.local/bin/claude -p "/3125 $COMMAND"
EXIT_CODE=$?

echo "$(date '+%Y-%m-%d %H:%M:%S') [3125-scheduled] END: /3125 $COMMAND (exit=$EXIT_CODE)" >> "$LOG_DIR/3125-scheduled.log"
