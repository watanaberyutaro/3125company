#!/bin/bash
# 3125-iterm.sh — iTerm2自動画面分割スクリプト
# Usage: bash 3125-iterm.sh "/path/to/vault"
#
# レイアウト（3列構成）:
# ┌──────────────┬─────────┬─────────┐
# │              │ヒンメル │フェルン │
# │  フリーレン  ├─────────┼─────────┤
# │  (対話)      │アイゼン │ハイター │
# │              ├─────────┼─────────┤
# ├──────────────┤フランメ │シュタルク│
# │              ├─────────┤         │
# │  CEO         │ゼーリエ │         │
# └──────────────┴─────────┴─────────┘
# 分割戦略: 列を先に作り、各列を独立して水平分割する

VAULT="${1:-/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MONITOR="$SCRIPT_DIR/monitor-agent.sh"

# ログディレクトリ確認
mkdir -p "$VAULT/.company/logs"

# 各エージェントのログファイル初期化（存在しなければ作成）
for agent in ceo himmel fern eisen heiter flamme stark serie; do
    touch "$VAULT/.company/logs/${agent}.log"
done

osascript <<APPLESCRIPT
tell application "iTerm2"
    tell current window
        -- ==========================================
        -- Step 1: 3列に分割（左=フリーレン / 中 / 右）
        -- ==========================================
        -- 現在のセッション = フリーレン（対話ペイン）
        set frierenSession to current session

        -- 左→右に分割して中央列を作る
        tell frierenSession
            set midCol to (split vertically with default profile)
        end tell

        -- 中央列→右に分割して右列を作る
        tell midCol
            set rightCol to (split vertically with default profile)
        end tell

        -- ==========================================
        -- Step 2: 左列を上下に分割（フリーレン / CEO）
        -- ==========================================
        tell frierenSession
            set ceoPane to (split horizontally with default profile)
        end tell
        tell ceoPane
            write text "bash '$MONITOR' ceo '$VAULT'"
        end tell

        -- ==========================================
        -- Step 3: 中央列を上下に分割（ヒンメル / アイゼン / フランメ / ゼーリエ）
        -- ==========================================
        -- midCol = ヒンメル
        tell midCol
            write text "bash '$MONITOR' himmel '$VAULT'"
        end tell

        -- ヒンメルの下にアイゼン
        tell midCol
            set eisenPane to (split horizontally with default profile)
        end tell
        tell eisenPane
            write text "bash '$MONITOR' eisen '$VAULT'"
        end tell

        -- アイゼンの下にフランメ
        tell eisenPane
            set flammePane to (split horizontally with default profile)
        end tell
        tell flammePane
            write text "bash '$MONITOR' flamme '$VAULT'"
        end tell

        -- フランメの下にゼーリエ
        tell flammePane
            set seriePane to (split horizontally with default profile)
        end tell
        tell seriePane
            write text "bash '$MONITOR' serie '$VAULT'"
        end tell

        -- ==========================================
        -- Step 4: 右列を上下に分割（フェルン / ハイター / シュタルク）
        -- ==========================================
        -- rightCol = フェルン
        tell rightCol
            write text "bash '$MONITOR' fern '$VAULT'"
        end tell

        -- フェルンの下にハイター
        tell rightCol
            set heiterPane to (split horizontally with default profile)
        end tell
        tell heiterPane
            write text "bash '$MONITOR' heiter '$VAULT'"
        end tell

        -- ハイターの下にシュタルク
        tell heiterPane
            set starkPane to (split horizontally with default profile)
        end tell
        tell starkPane
            write text "bash '$MONITOR' stark '$VAULT'"
        end tell
    end tell
end tell
APPLESCRIPT

echo "iTerm2 画面分割完了"
