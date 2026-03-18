#!/bin/bash
# 3125-iterm.sh — iTerm2自動画面分割スクリプト
# Usage: bash 3125-iterm.sh "/path/to/vault"
#
# レイアウト:
# ┌──────────────────┬──────────┬──────────┐
# │                  │ ヒンメル │ フェルン │
# │   フリーレン     │ (monitor)│ (monitor)│
# │   (対話ペイン)   ├──────────┼──────────┤
# │                  │ アイゼン │ ハイター │
# │   ※現在セッション│ (monitor)│ (monitor)│
# ├──────────────────┼──────────┼──────────┤
# │   CEO            │フランメ  │シュタルク│
# │   (monitor)      │ (monitor)│ (monitor)│
# └──────────────────┼──────────┼──────────┤
#                    │ ゼーリエ │          │
#                    │ (monitor)│          │
#                    └──────────┘──────────┘

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
        tell current session
            -- 右側にモニタリングペインを作成
            set rightPane to (split vertically with default profile)

            -- 右ペインで最初のモニターを起動（ヒンメル）
            tell rightPane
                write text "bash '$MONITOR' himmel '$VAULT'"

                -- 右側を縦に分割（フェルン）
                set fernPane to (split vertically with default profile)
                tell fernPane
                    write text "bash '$MONITOR' fern '$VAULT'"
                end tell

                -- ヒンメルの下にアイゼン
                set eisenPane to (split horizontally with default profile)
                tell eisenPane
                    write text "bash '$MONITOR' eisen '$VAULT'"
                end tell

                -- フェルンの下にハイター
                tell fernPane
                    set heiterPane to (split horizontally with default profile)
                    tell heiterPane
                        write text "bash '$MONITOR' heiter '$VAULT'"
                    end tell
                end tell

                -- アイゼンの下にフランメ
                tell eisenPane
                    set flammePane to (split horizontally with default profile)
                    tell flammePane
                        write text "bash '$MONITOR' flamme '$VAULT'"
                    end tell
                end tell

                -- ハイターの下にシュタルク
                tell heiterPane
                    set starkPane to (split horizontally with default profile)
                    tell starkPane
                        write text "bash '$MONITOR' stark '$VAULT'"
                    end tell
                end tell

                -- フランメの下にゼーリエ
                tell flammePane
                    set seriePane to (split horizontally with default profile)
                    tell seriePane
                        write text "bash '$MONITOR' serie '$VAULT'"
                    end tell
                end tell

                -- シュタルクの下にCEO
                tell starkPane
                    set ceoPane to (split horizontally with default profile)
                    tell ceoPane
                        write text "bash '$MONITOR' ceo '$VAULT'"
                    end tell
                end tell
            end tell
        end tell
    end tell
end tell
APPLESCRIPT

echo "iTerm2 画面分割完了"
