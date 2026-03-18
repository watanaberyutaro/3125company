#!/bin/bash
# monitor-agent.sh — エージェント監視スクリプト
# Usage: monitor-agent.sh <agent-name> <vault-path>
#
# 待機中: 部署ステータス表示（pending件数、最終タスク、最終更新時刻）
# 稼働中: tail -f でログをリアルタイム表示
# 30秒間隔でステータスリフレッシュ

AGENT_NAME="$1"
VAULT="${2:-/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault}"
LOG_FILE="$VAULT/.company/logs/${AGENT_NAME}.log"

# エージェント名 → キャラ名・部署名のマッピング（bash 3.2互換）
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

# ログファイルが存在しなければ作成
touch "$LOG_FILE"

# 部署ステータスを表示する関数
show_status() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $CHAR_NAME — $DEPT_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # pending件数
    PENDING_DIR="$VAULT/01_3125情報受付事業部（フリーレン）/_pending"
    if [ -d "$PENDING_DIR" ]; then
        PENDING_COUNT=$(ls -1 "$PENDING_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
        echo "  📥 全体 Pending: ${PENDING_COUNT}件"
    fi

    # 部署フォルダの最終更新
    DEPT_PATH="$VAULT/$DEPT_FOLDER"
    if [ -d "$DEPT_PATH" ]; then
        LATEST=$(ls -t "$DEPT_PATH"/*.md 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            LATEST_NAME=$(basename "$LATEST")
            LATEST_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$LATEST" 2>/dev/null || echo "不明")
            echo "  📄 最新: $LATEST_NAME"
            echo "  🕐 更新: $LATEST_TIME"
        else
            echo "  📄 ファイルなし"
        fi
    fi

    # ログの最終行
    if [ -s "$LOG_FILE" ]; then
        echo ""
        echo "  📋 最終ログ:"
        tail -3 "$LOG_FILE" | while IFS= read -r line; do
            echo "    $line"
        done
    fi

    echo ""
    echo "  ⏳ 待機中..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# メインループ
LAST_LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)

while true; do
    CURRENT_LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)

    if [ "$CURRENT_LOG_SIZE" -gt "$LAST_LOG_SIZE" ]; then
        # ログに新しい内容がある → ストリーム表示
        clear
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  🔥 $CHAR_NAME — $DEPT_NAME — ACTIVE"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # 新しい部分だけ表示してから tail -f
        tail -c +$((LAST_LOG_SIZE + 1)) "$LOG_FILE"

        # tail -f でリアルタイム監視（5秒タイムアウトで戻る）
        timeout 30 tail -f "$LOG_FILE" 2>/dev/null

        LAST_LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
    else
        # 変更なし → ステータス表示
        show_status
        sleep 10
    fi
done
