#!/bin/bash
# monitor-agent.sh — エージェント監視スクリプト
# Usage: monitor-agent.sh <agent-name> <vault-path>

AGENT_NAME="$1"
VAULT="${2:-/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault}"
LOG_FILE="$VAULT/.company/logs/${AGENT_NAME}.log"

case "$AGENT_NAME" in
    ceo)    CHAR_NAME="フリーレン"; DEPT_NAME="CEO・意思決定";       DEPT_FOLDER=".company/ceo" ;;
    himmel) CHAR_NAME="ヒンメル";   DEPT_NAME="03_市場調査";        DEPT_FOLDER="03_3125市場調査事業部（ヒンメル）" ;;
    fern)   CHAR_NAME="フェルン";   DEPT_NAME="02_経営日誌";        DEPT_FOLDER="02_3125経営日誌事業部（フェルン）" ;;
    eisen)  CHAR_NAME="アイゼン";   DEPT_NAME="04_アイデア保管";    DEPT_FOLDER="04_3125アイデア保管事業部（アイゼン）" ;;
    heiter) CHAR_NAME="ハイター";   DEPT_NAME="05_企画開発";        DEPT_FOLDER="05_3125企画開発事業部（ハイター）" ;;
    flamme) CHAR_NAME="フランメ";   DEPT_NAME="06_マーケティング";  DEPT_FOLDER="06_3125マーケティング事業部（フランメ）" ;;
    stark)  CHAR_NAME="シュタルク"; DEPT_NAME="07_営業戦略";        DEPT_FOLDER="07_3125営業戦略事業部（シュタルク）" ;;
    serie)  CHAR_NAME="ゼーリエ";   DEPT_NAME="09_制作・納品";      DEPT_FOLDER="09_3125制作・納品事業部（ゼーリエ）" ;;
    *)      CHAR_NAME="$AGENT_NAME"; DEPT_NAME="不明";              DEPT_FOLDER="" ;;
esac

touch "$LOG_FILE"
printf '\033]0;%s | %s\007' "$DEPT_NAME" "$CHAR_NAME"

get_state() {
    local last_start last_end progress_after
    last_start=$(grep -n "=== START" "$LOG_FILE" | tail -1 | cut -d: -f1)
    last_end=$(grep -n "=== END" "$LOG_FILE" | tail -1 | cut -d: -f1)
    if [ -z "$last_start" ]; then echo "idle"; return; fi
    if [ -n "$last_end" ] && [ "$last_end" -gt "$last_start" ]; then echo "idle"; return; fi
    progress_after=$(tail -n +"$last_start" "$LOG_FILE" | grep -c "\[進捗\]")
    if [ "$progress_after" -gt 0 ]; then echo "working"; else echo "thinking"; fi
}

render() {
    local STATE="$1"
    local LINES=$(stty size 2>/dev/null | awk '{print $1}')
    [ -z "$LINES" ] && LINES=24

    local DEPT_PATH="$VAULT/$DEPT_FOLDER"
    local MAX_LOG=$((LINES - 7))  # ヘッダー3行+情報3行+フッター1行を引く
    [ "$MAX_LOG" -lt 2 ] && MAX_LOG=2

    # コンテンツをバッファに貯める
    local buf=""

    if [ "$STATE" = "idle" ]; then
        local pend=$(ls "$DEPT_PATH/_pending/"*.md 2>/dev/null | wc -l | tr -d ' ')
        local done_c=$(ls "$DEPT_PATH/_done/"*.md 2>/dev/null | wc -l | tr -d ' ')
        buf+="  📥 ${pend}件  ✅ ${done_c}件"$'\n'
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
        if [ "$STATE" = "thinking" ]; then
            buf+="  ⋯ 準備中"$'\n'
        fi
    fi

    local content_lines=$(echo "$buf" | wc -l | tr -d ' ')
    local header_lines=3  # ステータス行+区切り2本
    local total=$((header_lines + content_lines + 1))
    local pad=$((LINES - total))

    # 画面クリア+下寄せ
    printf '\033[2J\033[H'
    if [ "$pad" -gt 0 ]; then
        printf "%0.s\n" $(seq 1 $pad)
    fi

    # ステータスヘッダー
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    case "$STATE" in
        idle)     echo "  ⏳ $CHAR_NAME — 待機中" ;;
        thinking) echo "  🧠 $CHAR_NAME — 思考中..." ;;
        working)  echo "  🔥 $CHAR_NAME — 作業中" ;;
    esac
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # コンテンツ
    echo "$buf"

    # コンテンツの行数を数える
    local content_lines=$(echo "$buf" | wc -l | tr -d ' ')

    # 画面クリア
    printf '\033[2J\033[H'

    # 空行で下に押す
    local pad=$((LINES - content_lines))
    if [ "$pad" -gt 0 ]; then
        printf "%0.s\n" $(seq 1 $pad)
    fi

    # コンテンツ出力
    echo "$buf"
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

    if [ "$CUR_STATE" = "idle" ]; then
        sleep 5
    else
        sleep 2
    fi
done
