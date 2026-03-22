#!/bin/bash
# 3125-scheduled-run.sh — スケジュール実行ラッパー
# 各launchdジョブが独立して実行される（チェーン方式は廃止）
#
# Usage: 3125-scheduled-run.sh <command>
# Example: 3125-scheduled-run.sh "report"

COMMAND="$1"
VAULT="/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"
LOG_DIR="$HOME/Library/Logs"

echo "$(date '+%Y-%m-%d %H:%M:%S') [3125-scheduled] START: /3125 $COMMAND" >> "$LOG_DIR/3125-scheduled.log"

# Claude Code で実行
cd "$VAULT"
/Users/watanaberyuutarou/.local/bin/claude -p "/3125 $COMMAND"
EXIT_CODE=$?

echo "$(date '+%Y-%m-%d %H:%M:%S') [3125-scheduled] END: /3125 $COMMAND (exit=$EXIT_CODE)" >> "$LOG_DIR/3125-scheduled.log"
