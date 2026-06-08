#!/bin/bash
# 3125-scheduled-run.sh — スケジュール実行ラッパー
#
# Usage: 3125-scheduled-run.sh <command>
# Example: 3125-scheduled-run.sh "report"

COMMAND="$1"
VAULT="/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Cardinal/Cardinal"
LOG_DIR="$HOME/Library/Logs"
LOG_FILE="$LOG_DIR/3125-scheduled.log"
OUTPUT_LOG="$LOG_DIR/3125-claude-output.log"
MAX_RETRIES=3
TODAY=$(date '+%Y-%m-%d')

# ネットワーク接続を待つ（wake直後はまだ繋がっていないことがある）
for i in $(seq 1 30); do
    if curl -s --max-time 3 https://api.anthropic.com > /dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [3125] ネットワーク接続OK (attempt $i)" >> "$LOG_FILE"
        break
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') [3125] ネットワーク待機中 ($i/30)" >> "$LOG_FILE"
    sleep 2
done

echo "$(date '+%Y-%m-%d %H:%M:%S') [3125] START: /3125 $COMMAND" >> "$LOG_FILE"

# Claude Code で実行（出力もログに保存）
cd "$VAULT"
for attempt in $(seq 1 $MAX_RETRIES); do
    /Users/watanaberyuutarou/.local/bin/claude -p "/3125 $COMMAND" \
        --allowedTools "Bash,Read,Write,Edit,Glob,Grep,Agent,AskUserQuestion" \
        2>&1 | tee -a "$OUTPUT_LOG"
    EXIT_CODE=${PIPESTATUS[0]}

    # 成功判定: exit 0 かつ成果物が存在するか
    SUCCESS=false
    if [ $EXIT_CODE -eq 0 ]; then
        if [ -z "$COMMAND" ]; then
            # 朝の定例: ブリーフィングファイルが作られたか
            if [ -f "$VAULT/.company/secretary/daily-briefing/${TODAY}.md" ]; then
                SUCCESS=true
            fi
        elif [ "$COMMAND" = "diary" ]; then
            # diary: 日誌ファイルが作られたか
            if ls "$VAULT/00_受信トレイ/フェルンより_${TODAY}"*.md 1>/dev/null 2>&1 || \
               ls "$VAULT/02_3125経営日誌事業部（フェルン）/daily/${TODAY}.md" 1>/dev/null 2>&1; then
                SUCCESS=true
            fi
        elif [ "$COMMAND" = "report" ]; then
            # report: 成功とみなす（レポートは毎回上書きされるため判定しにくい）
            SUCCESS=true
        fi
    fi

    if $SUCCESS; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [3125] SUCCESS: /3125 $COMMAND (attempt $attempt)" >> "$LOG_FILE"
        break
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [3125] FAILED: /3125 $COMMAND (attempt $attempt, exit=$EXIT_CODE, success=$SUCCESS)" >> "$LOG_FILE"
        if [ $attempt -lt $MAX_RETRIES ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [3125] RETRY: waiting 10s..." >> "$LOG_FILE"
            sleep 10
        fi
    fi
done

echo "$(date '+%Y-%m-%d %H:%M:%S') [3125] END: /3125 $COMMAND (exit=$EXIT_CODE)" >> "$LOG_FILE"
