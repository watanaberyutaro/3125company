#!/bin/bash
# monitor-agent.sh — エージェント監視スクリプト
# Usage: monitor-agent.sh <agent-name> <vault-path>

AGENT_NAME="$1"
VAULT="${2:-/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Cardinal/Cardinal}"
LOG_FILE="$VAULT/.company/logs/${AGENT_NAME}.log"

case "$AGENT_NAME" in
    ceo)    CHAR_NAME="フリーレン" ;;
    himmel) CHAR_NAME="ヒンメル" ;;
    fern)   CHAR_NAME="フェルン" ;;
    eisen)  CHAR_NAME="アイゼン" ;;
    heiter) CHAR_NAME="ハイター" ;;
    flamme) CHAR_NAME="フランメ" ;;
    stark)  CHAR_NAME="シュタルク" ;;
    serie)  CHAR_NAME="ゼーリエ" ;;
    *)      CHAR_NAME="$AGENT_NAME" ;;
esac

touch "$LOG_FILE"
if [ "$AGENT_NAME" = "ceo" ]; then
    printf '\033]0;CEO %s\007' "$CHAR_NAME"
else
    printf '\033]0;%s\007' "$CHAR_NAME"
fi

get_state() {
    local last_start last_end
    last_start=$(grep -n ">>>" "$LOG_FILE" | tail -1 | cut -d: -f1)
    last_end=$(grep -n "<<<" "$LOG_FILE" | tail -1 | cut -d: -f1)
    if [ -z "$last_start" ]; then echo "idle"; return; fi
    if [ -n "$last_end" ] && [ "$last_end" -gt "$last_start" ]; then echo "idle"; return; fi
    local lines_after=$(tail -n +"$last_start" "$LOG_FILE" | wc -l | tr -d ' ')
    if [ "$lines_after" -gt 1 ]; then echo "working"; else echo "thinking"; fi
}

render() {
    local STATE="$1"
    local ROWS=$(stty size 2>/dev/null | awk '{print $1}')
    [ -z "$ROWS" ] && ROWS=14

    # ログ行数 = 画面高さ - 3行（区切り2本+ステータス1行）
    local MAX_LOG=$((ROWS - 3))
    [ "$MAX_LOG" -lt 1 ] && MAX_LOG=1

    # ログ取得
    local log_buf=""
    if [ "$STATE" = "idle" ]; then
        log_buf=$(tail -${MAX_LOG} "$LOG_FILE" 2>/dev/null | sed 's/^/  /')
    else
        local start_line=$(grep -n "=== START" "$LOG_FILE" | tail -1 | cut -d: -f1)
        if [ -n "$start_line" ]; then
            log_buf=$(tail -n +"$start_line" "$LOG_FILE" | tail -${MAX_LOG} | sed 's/^/  /')
        else
            # === START マーカーがないログでも空表示にせず通常のtailを出す
            log_buf=$(tail -${MAX_LOG} "$LOG_FILE" 2>/dev/null | sed 's/^/  /')
        fi
    fi

    # ログ行数
    local log_lines=0
    if [ -n "$log_buf" ]; then
        log_lines=$(echo "$log_buf" | wc -l | tr -d ' ')
    fi

    # 開始行 = 画面下部に寄せる（ログ + 区切り2 + ステータス1 = log_lines+3）
    local total=$((log_lines + 3))
    local start_row=$((ROWS - total))
    [ "$start_row" -lt 1 ] && start_row=1

    # ステータス文字
    local status_text=""
    case "$STATE" in
        idle)     status_text="⏳ ${CHAR_NAME}: 待機中" ;;
        thinking) status_text="🧠 ${CHAR_NAME}: 思考中..." ;;
        working)  status_text="🔥 ${CHAR_NAME}: 作業中" ;;
    esac

    # 描画
    printf '\033[2J\033[%d;1H' "$start_row"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    [ -n "$log_buf" ] && echo "$log_buf"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$status_text"
}

# メインループ
LAST_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')
LAST_STATE="none"

while true; do
    CUR_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')
    CUR_STATE=$(get_state)

    if [ "$CUR_SIZE" != "$LAST_SIZE" ] || [ "$CUR_STATE" != "$LAST_STATE" ]; then
        render "$CUR_STATE"
        LAST_SIZE="$CUR_SIZE"
        LAST_STATE="$CUR_STATE"
    fi

    [ "$CUR_STATE" = "idle" ] && sleep 5 || sleep 2
done
