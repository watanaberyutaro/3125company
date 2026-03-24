#!/bin/bash
# 3125-scheduled-run.sh — スケジュール実行ラッパー
# 各launchdジョブが独立して実行される（チェーン方式は廃止）
#
# Usage: 3125-scheduled-run.sh <command>
# Example: 3125-scheduled-run.sh "report"

COMMAND="$1"
VAULT="/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"
LOG_DIR="$HOME/Library/Logs"
MAX_RETRIES=3

# ネットワーク接続を待つ（wake直後はまだ繋がっていないことがある）
for i in $(seq 1 30); do
    if curl -s --max-time 3 https://api.anthropic.com > /dev/null 2>&1; then
        break
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') [3125-scheduled] WAITING: network not ready (attempt $i/30)" >> "$LOG_DIR/3125-scheduled.log"
    sleep 2
done

echo "$(date '+%Y-%m-%d %H:%M:%S') [3125-scheduled] START: /3125 $COMMAND" >> "$LOG_DIR/3125-scheduled.log"

# Claude Code で実行（失敗時リトライ）
cd "$VAULT"
for attempt in $(seq 1 $MAX_RETRIES); do
    /Users/watanaberyuutarou/.local/bin/claude -p "/3125 $COMMAND"
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        break
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') [3125-scheduled] RETRY: attempt $attempt/$MAX_RETRIES (exit=$EXIT_CODE)" >> "$LOG_DIR/3125-scheduled.log"
    sleep 5
done

echo "$(date '+%Y-%m-%d %H:%M:%S') [3125-scheduled] END: /3125 $COMMAND (exit=$EXIT_CODE)" >> "$LOG_DIR/3125-scheduled.log"
