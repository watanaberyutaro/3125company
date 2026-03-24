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
    printf '\033[2J\033[H'

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    case "$STATE" in
        idle)     echo "  ⏳ $CHAR_NAME — $DEPT_NAME — 待機中" ;;
        thinking) echo "  🧠 $CHAR_NAME — $DEPT_NAME — 思考中..." ;;
        working)  echo "  🔥 $CHAR_NAME — $DEPT_NAME — 作業中" ;;
    esac
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ "$STATE" = "idle" ]; then
        # キュー表示
        local DEPT_PATH="$VAULT/$DEPT_FOLDER"
        if [ -d "$DEPT_PATH/_pending" ]; then
            local pend=$(ls "$DEPT_PATH/_pending/"*.md 2>/dev/null | wc -l | tr -d ' ')
            local done=$(ls "$DEPT_PATH/_done/"*.md 2>/dev/null | wc -l | tr -d ' ')
            echo "  📥 部署キュー: ${pend}件  ✅ 完了: ${done}件"
        fi
        local gpend=$(ls "$VAULT/01_3125情報受付事業部（フリーレン）/_pending/"*.md 2>/dev/null | wc -l | tr -d ' ')
        echo "  📬 全体キュー: ${gpend}件"

        # 最新ファイル
        local latest=$(ls -t "$DEPT_PATH/"*.md 2>/dev/null | head -1)
        if [ -n "$latest" ]; then
            echo "  📄 最新: $(basename "$latest")"
        fi
        echo ""

        # 最近のログ
        echo "  📋 最近のログ:"
        tail -5 "$LOG_FILE" 2>/dev/null | sed 's/^/    /'
    else
        # 思考中・作業中: START以降のログ表示
        local start_line=$(grep -n "=== START" "$LOG_FILE" | tail -1 | cut -d: -f1)
        if [ -n "$start_line" ]; then
            tail -n +"$start_line" "$LOG_FILE" | sed 's/^/  /'
        fi
        if [ "$STATE" = "thinking" ]; then
            echo ""
            echo "  ⋯ エージェント起動・準備中"
        fi
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
