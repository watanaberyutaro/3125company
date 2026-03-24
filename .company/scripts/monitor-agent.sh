#!/bin/bash
# monitor-agent.sh — エージェント監視スクリプト
# Usage: monitor-agent.sh <agent-name> <vault-path>
#
# 待機中: 部署ステータス表示
# 稼働中: ログをリアルタイムストリーム表示

AGENT_NAME="$1"
VAULT="${2:-/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault}"
LOG_FILE="$VAULT/.company/logs/${AGENT_NAME}.log"

# エージェント名 → キャラ名・部署名のマッピング
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

# 待機中ステータス表示
show_status() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $CHAR_NAME — $DEPT_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 部署キュー表示
    DEPT_PATH="$VAULT/$DEPT_FOLDER"
    DEPT_PENDING="$DEPT_PATH/_pending"
    DEPT_DONE="$DEPT_PATH/_done"
    if [ -d "$DEPT_PENDING" ]; then
        MY_PENDING=$(ls -1 "$DEPT_PENDING"/*.md 2>/dev/null | wc -l | tr -d ' ')
        MY_DONE=$(ls -1 "$DEPT_DONE"/*.md 2>/dev/null | wc -l | tr -d ' ')
        echo "  📥 部署キュー: ${MY_PENDING}件  ✅ 完了: ${MY_DONE}件"
    fi

    # 全体キュー
    GLOBAL_PENDING="$VAULT/01_3125情報受付事業部（フリーレン）/_pending"
    if [ -d "$GLOBAL_PENDING" ]; then
        GLOBAL_COUNT=$(ls -1 "$GLOBAL_PENDING"/*.md 2>/dev/null | wc -l | tr -d ' ')
        echo "  📬 全体キュー: ${GLOBAL_COUNT}件"
    fi

    # 部署最新ファイル
    if [ -d "$DEPT_PATH" ]; then
        LATEST=$(ls -t "$DEPT_PATH"/*.md 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            echo "  📄 最新: $(basename "$LATEST")"
            echo "  🕐 更新: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$LATEST" 2>/dev/null || echo "不明")"
        fi

        # pending内のファイル名を表示
        if [ "$MY_PENDING" -gt 0 ] 2>/dev/null; then
            echo ""
            echo "  📋 待ちタスク:"
            ls -1 "$DEPT_PENDING"/*.md 2>/dev/null | while read f; do
                echo "    • $(basename "$f")"
            done
        fi
    fi

    echo ""
    echo "  📋 最近のログ:"
    tail -10 "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
        echo "    $line"
    done

    echo ""
    echo "  ⏳ 待機中..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 稼働中表示（ヘッダー + tail -f）
show_active() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🔥 $CHAR_NAME — $DEPT_NAME — ACTIVE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    # 最新のSTART以降のログを全部表示
    local start_line=$(grep -n "=== START" "$LOG_FILE" | tail -1 | cut -d: -f1)
    if [ -n "$start_line" ]; then
        tail -n +"$start_line" "$LOG_FILE"
    else
        tail -20 "$LOG_FILE"
    fi
}

# メインループ
LAST_LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
IS_ACTIVE=false

while true; do
    CURRENT_LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)

    if [ "$CURRENT_LOG_SIZE" -gt "$LAST_LOG_SIZE" ]; then
        # ログに新しい内容 → アクティブ表示
        IS_ACTIVE=true
        show_active

        # 2秒間隔で新しい行を監視（ENDが来たら待機に戻る）
        while true; do
            sleep 2
            NEW_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
            if [ "$NEW_SIZE" -gt "$CURRENT_LOG_SIZE" ]; then
                # 新しいログが追加された → 差分表示
                tail -c +$((CURRENT_LOG_SIZE + 1)) "$LOG_FILE"
                CURRENT_LOG_SIZE=$NEW_SIZE

                # ENDが含まれていたらループを抜ける
                if tail -1 "$LOG_FILE" | grep -q "=== END"; then
                    echo ""
                    echo "  ✅ 処理完了"
                    sleep 3
                    break
                fi
            fi
            # 60秒変化なしでも一旦抜ける
            ELAPSED=$((ELAPSED + 2))
            if [ "${ELAPSED:-0}" -ge 60 ]; then
                break
            fi
        done

        LAST_LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
        IS_ACTIVE=false
    else
        show_status
        sleep 5
    fi
done
