#!/bin/bash
# monitor-agent.sh — エージェント監視スクリプト
# Usage: monitor-agent.sh <agent-name> <vault-path>

AGENT_NAME="$1"
VAULT="${2:-/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault}"
LOG_FILE="$VAULT/.company/logs/${AGENT_NAME}.log"

case "$AGENT_NAME" in
    ceo)    CHAR_NAME="フリーレン"; DEPT_FOLDER=".company/ceo" ;;
    himmel) CHAR_NAME="ヒンメル";   DEPT_FOLDER="03_3125市場調査事業部（ヒンメル）" ;;
    fern)   CHAR_NAME="フェルン";   DEPT_FOLDER="02_3125経営日誌事業部（フェルン）" ;;
    eisen)  CHAR_NAME="アイゼン";   DEPT_FOLDER="04_3125アイデア保管事業部（アイゼン）" ;;
    heiter) CHAR_NAME="ハイター";   DEPT_FOLDER="05_3125企画開発事業部（ハイター）" ;;
    flamme) CHAR_NAME="フランメ";   DEPT_FOLDER="06_3125マーケティング事業部（フランメ）" ;;
    stark)  CHAR_NAME="シュタルク"; DEPT_FOLDER="07_3125営業戦略事業部（シュタルク）" ;;
    serie)  CHAR_NAME="ゼーリエ";   DEPT_FOLDER="09_3125制作・納品事業部（ゼーリエ）" ;;
    *)      CHAR_NAME="$AGENT_NAME"; DEPT_FOLDER="" ;;
esac

touch "$LOG_FILE"
printf '\033]0;%s\007' "$CHAR_NAME"

get_state() {
    local last_start last_end
    last_start=$(grep -n "=== START" "$LOG_FILE" | tail -1 | cut -d: -f1)
    last_end=$(grep -n "=== END" "$LOG_FILE" | tail -1 | cut -d: -f1)
    if [ -z "$last_start" ]; then echo "idle"; return; fi
    if [ -n "$last_end" ] && [ "$last_end" -gt "$last_start" ]; then echo "idle"; return; fi
    if tail -n +"$last_start" "$LOG_FILE" | grep -q "\[進捗\]"; then echo "working"; else echo "thinking"; fi
}

render() {
    local STATE="$1"
    local ROWS=$(stty size 2>/dev/null | awk '{print $1}')
    [ -z "$ROWS" ] && ROWS=14

    # バッファ構築
    local buf=""
    local DEPT_PATH="$VAULT/$DEPT_FOLDER"
    local MAX_LOG=$((ROWS - 5))
    [ "$MAX_LOG" -lt 2 ] && MAX_LOG=2

    if [ "$STATE" = "idle" ]; then
        local pend=$(ls "$DEPT_PATH/_pending/"*.md 2>/dev/null | wc -l | tr -d ' ')
        local done_c=$(ls "$DEPT_PATH/_done/"*.md 2>/dev/null | wc -l | tr -d ' ')
        buf+="  📥${pend} ✅${done_c}"$'\n'
        while IFS= read -r line; do
            buf+="  $line"$'\n'
        done < <(tail -${MAX_LOG} "$LOG_FILE" 2>/dev/null)
    else
        local start_line=$(grep -n "=== START" "$LOG_FILE" | tail -1 | cut -d: -f1)
        if [ -n "$start_line" ]; then
            while IFS= read -r line; do
                buf+="  $line"$'\n'
            done < <(tail -n +"$start_line" "$LOG_FILE" | tail -${MAX_LOG})
        fi
    fi

    # 行数計算
    local content_lines=$(printf '%s' "$buf" | wc -l | tr -d ' ')
    local total=$((content_lines + 3))  # ヘッダー区切り+ステータス+区切り
    local start_row=$((ROWS - total))
    [ "$start_row" -lt 1 ] && start_row=1

    # 描画
    printf '\033[2J'
    printf '\033[%d;1H' "$start_row"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    case "$STATE" in
        idle)     echo "  ⏳ $CHAR_NAME — 待機中" ;;
        thinking) echo "  🧠 $CHAR_NAME — 思考中..." ;;
        working)  echo "  🔥 $CHAR_NAME — 作業中" ;;
    esac
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%s' "$buf"
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
