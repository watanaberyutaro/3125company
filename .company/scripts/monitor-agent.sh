#!/bin/bash
# monitor-agent.sh — エージェント監視スクリプト
# Usage: monitor-agent.sh <agent-name> <vault-path>
#
# ステータス:
#   ⏳ 待機中 — タスクなし
#   🧠 思考中 — START後、進捗ログがまだない（エージェント初期化中）
#   🔥 作業中 — [進捗] ログが流れている

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
echo -ne "\033]0;${DEPT_NAME} | ${CHAR_NAME}\007"

# 現在の状態を判定: idle / thinking / working
get_state() {
    local last_start=$(grep -n "=== START" "$LOG_FILE" | tail -1 | cut -d: -f1)
    local last_end=$(grep -n "=== END" "$LOG_FILE" | tail -1 | cut -d: -f1)

    if [ -z "$last_start" ]; then
        echo "idle"; return
    fi

    # ENDがSTARTより後ろ → 完了済み → 待機中
    if [ -n "$last_end" ] && [ "$last_end" -gt "$last_start" ]; then
        echo "idle"; return
    fi

    # START後に[進捗]があるか
    local progress_after=$(tail -n +"$last_start" "$LOG_FILE" | grep -c "\[進捗\]")
    if [ "$progress_after" -gt 0 ]; then
        echo "working"
    else
        echo "thinking"
    fi
}

# ヘッダー表示
show_header() {
    local state="$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    case "$state" in
        idle)     echo "  ⏳ $CHAR_NAME — $DEPT_NAME — 待機中" ;;
        thinking) echo "  🧠 $CHAR_NAME — $DEPT_NAME — 思考中..." ;;
        working)  echo "  🔥 $CHAR_NAME — $DEPT_NAME — 作業中" ;;
    esac
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 待機中ステータス表示
show_idle() {
    clear
    show_header "idle"

    DEPT_PATH="$VAULT/$DEPT_FOLDER"
    DEPT_PENDING="$DEPT_PATH/_pending"
    DEPT_DONE="$DEPT_PATH/_done"
    if [ -d "$DEPT_PENDING" ]; then
        MY_PENDING=$(ls -1 "$DEPT_PENDING"/*.md 2>/dev/null | wc -l | tr -d ' ')
        MY_DONE=$(ls -1 "$DEPT_DONE"/*.md 2>/dev/null | wc -l | tr -d ' ')
        echo "  📥 部署キュー: ${MY_PENDING}件  ✅ 完了: ${MY_DONE}件"
    fi

    GLOBAL_PENDING="$VAULT/01_3125情報受付事業部（フリーレン）/_pending"
    if [ -d "$GLOBAL_PENDING" ]; then
        GLOBAL_COUNT=$(ls -1 "$GLOBAL_PENDING"/*.md 2>/dev/null | wc -l | tr -d ' ')
        echo "  📬 全体キュー: ${GLOBAL_COUNT}件"
    fi

    if [ -d "$DEPT_PATH" ]; then
        LATEST=$(ls -t "$DEPT_PATH"/*.md 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            echo "  📄 最新: $(basename "$LATEST")"
            echo "  🕐 更新: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$LATEST" 2>/dev/null || echo "不明")"
        fi

        if [ "${MY_PENDING:-0}" -gt 0 ] 2>/dev/null; then
            echo ""
            echo "  📋 待ちタスク:"
            ls -1 "$DEPT_PENDING"/*.md 2>/dev/null | while read f; do
                echo "    • $(basename "$f")"
            done
        fi
    fi

    echo ""
    echo "  📋 最近のログ:"
    tail -5 "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
        echo "    $line"
    done
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 思考中表示
show_thinking() {
    clear
    show_header "thinking"

    local start_line=$(grep -n "=== START" "$LOG_FILE" | tail -1 | cut -d: -f1)
    if [ -n "$start_line" ]; then
        tail -n +"$start_line" "$LOG_FILE" | while IFS= read -r line; do
            echo "  $line"
        done
    fi
    echo ""
    echo "  ⋯ エージェント起動・準備中"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 作業中表示
show_working() {
    clear
    show_header "working"

    local start_line=$(grep -n "=== START" "$LOG_FILE" | tail -1 | cut -d: -f1)
    if [ -n "$start_line" ]; then
        tail -n +"$start_line" "$LOG_FILE" | while IFS= read -r line; do
            echo "  $line"
        done
    else
        tail -20 "$LOG_FILE" | while IFS= read -r line; do
            echo "  $line"
        done
    fi
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# メインループ
LAST_LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)

while true; do
    CURRENT_LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
    STATE=$(get_state)

    if [ "$CURRENT_LOG_SIZE" -gt "$LAST_LOG_SIZE" ] || [ "$STATE" != "idle" ]; then
        # アクティブ状態（思考中 or 作業中）
        case "$STATE" in
            thinking) show_thinking ;;
            working)  show_working ;;
            idle)     show_idle ;;
        esac

        # アクティブ中は2秒間隔でポーリング
        IDLE_COUNT=0
        while [ "$STATE" != "idle" ]; do
            sleep 2
            NEW_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
            STATE=$(get_state)

            if [ "$NEW_SIZE" -gt "$CURRENT_LOG_SIZE" ] || [ "$STATE" != "$PREV_STATE" ]; then
                case "$STATE" in
                    thinking) show_thinking ;;
                    working)  show_working ;;
                    idle)
                        show_working  # 最終ログを表示
                        echo ""
                        echo "  ✅ 処理完了"
                        sleep 3
                        ;;
                esac
                CURRENT_LOG_SIZE=$NEW_SIZE
                IDLE_COUNT=0
            else
                IDLE_COUNT=$((IDLE_COUNT + 1))
                # 90秒変化なしでリフレッシュ
                if [ "$IDLE_COUNT" -ge 45 ]; then
                    break
                fi
            fi
            PREV_STATE=$STATE
        done

        LAST_LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
    else
        show_idle
        sleep 5
    fi
done
