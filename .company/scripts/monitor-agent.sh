#!/bin/bash
# monitor-agent.sh — エージェント監視スクリプト
# Usage: monitor-agent.sh <agent-name> <vault-path>
#
# ステータス:
#   ⏳ 待機中 — タスクなし
#   🧠 思考中 — START後、進捗ログがまだない
#   🔥 作業中 — [進捗] ログが流れている

AGENT_NAME="$1"
VAULT="${2:-/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault}"
LOG_FILE="$VAULT/.company/logs/${AGENT_NAME}.log"
MY_TTY=$(tty)

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

# TTYに直接出力する関数（AppleScript write textの代わり）
out() {
    echo "$@" > "$MY_TTY"
}

cls() {
    printf '\033[2J\033[H' > "$MY_TTY"
}

# ペインタイトル設定
printf '\033]0;%s | %s\007' "$DEPT_NAME" "$CHAR_NAME" > "$MY_TTY"

# 状態判定
get_state() {
    local last_start=$(grep -n "=== START" "$LOG_FILE" | tail -1 | cut -d: -f1)
    local last_end=$(grep -n "=== END" "$LOG_FILE" | tail -1 | cut -d: -f1)

    if [ -z "$last_start" ]; then echo "idle"; return; fi
    if [ -n "$last_end" ] && [ "$last_end" -gt "$last_start" ]; then echo "idle"; return; fi

    local progress_after=$(tail -n +"$last_start" "$LOG_FILE" | grep -c "\[進捗\]")
    if [ "$progress_after" -gt 0 ]; then echo "working"; else echo "thinking"; fi
}

# 待機中表示
show_idle() {
    cls
    out "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    out "  ⏳ $CHAR_NAME — $DEPT_NAME — 待機中"
    out "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    out ""

    local DEPT_PATH="$VAULT/$DEPT_FOLDER"
    local DEPT_PENDING="$DEPT_PATH/_pending"
    local DEPT_DONE="$DEPT_PATH/_done"
    if [ -d "$DEPT_PENDING" ]; then
        local MY_PENDING=$(ls "$DEPT_PENDING"/*.md 2>/dev/null | wc -l | tr -d ' ')
        local MY_DONE=$(ls "$DEPT_DONE"/*.md 2>/dev/null | wc -l | tr -d ' ')
        out "  📥 部署キュー: ${MY_PENDING}件  ✅ 完了: ${MY_DONE}件"
    fi

    local GLOBAL_PENDING="$VAULT/01_3125情報受付事業部（フリーレン）/_pending"
    if [ -d "$GLOBAL_PENDING" ]; then
        local GLOBAL_COUNT=$(ls "$GLOBAL_PENDING"/*.md 2>/dev/null | wc -l | tr -d ' ')
        out "  📬 全体キュー: ${GLOBAL_COUNT}件"
    fi

    if [ -d "$DEPT_PATH" ]; then
        local LATEST=$(ls -t "$DEPT_PATH"/*.md 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            out "  📄 最新: $(basename "$LATEST")"
            out "  🕐 更新: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$LATEST" 2>/dev/null || echo "不明")"
        fi
    fi

    out ""
    out "  📋 最近のログ:"
    tail -5 "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
        out "    $line"
    done
    out ""
    out "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 思考中表示
show_thinking() {
    cls
    out "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    out "  🧠 $CHAR_NAME — $DEPT_NAME — 思考中..."
    out "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    out ""

    local start_line=$(grep -n "=== START" "$LOG_FILE" | tail -1 | cut -d: -f1)
    if [ -n "$start_line" ]; then
        tail -n +"$start_line" "$LOG_FILE" | while IFS= read -r line; do
            out "  $line"
        done
    fi
    out ""
    out "  ⋯ エージェント起動・準備中"
    out "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 作業中表示
show_working() {
    cls
    out "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    out "  🔥 $CHAR_NAME — $DEPT_NAME — 作業中"
    out "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    out ""

    local start_line=$(grep -n "=== START" "$LOG_FILE" | tail -1 | cut -d: -f1)
    if [ -n "$start_line" ]; then
        tail -n +"$start_line" "$LOG_FILE" | while IFS= read -r line; do
            out "  $line"
        done
    else
        tail -20 "$LOG_FILE" | while IFS= read -r line; do
            out "  $line"
        done
    fi
    out ""
    out "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# メインループ
LAST_LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')
PREV_STATE="idle"

while true; do
    CURRENT_LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')
    STATE=$(get_state)

    if [ "$CURRENT_LOG_SIZE" != "$LAST_LOG_SIZE" ] || [ "$STATE" != "$PREV_STATE" ]; then
        # 変化あり → 即時描画
        case "$STATE" in
            idle)     show_idle ;;
            thinking) show_thinking ;;
            working)  show_working ;;
        esac
        LAST_LOG_SIZE="$CURRENT_LOG_SIZE"
        PREV_STATE="$STATE"

        # アクティブ中は2秒ポーリング
        if [ "$STATE" != "idle" ]; then
            while true; do
                sleep 2
                local_size=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')
                local_state=$(get_state)
                if [ "$local_size" != "$LAST_LOG_SIZE" ] || [ "$local_state" != "$STATE" ]; then
                    STATE="$local_state"
                    case "$STATE" in
                        idle)
                            show_working
                            out ""; out "  ✅ 処理完了"
                            sleep 3
                            show_idle
                            ;;
                        thinking) show_thinking ;;
                        working)  show_working ;;
                    esac
                    LAST_LOG_SIZE="$local_size"
                    if [ "$STATE" = "idle" ]; then break; fi
                fi
            done
            PREV_STATE="$STATE"
        fi
    else
        # 変化なし → 待機表示リフレッシュ
        show_idle
    fi
    sleep 5
done
