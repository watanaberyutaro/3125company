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
# │ フリーレン   │ゼーリエ │         │
# │ (CEO)        │         │         │
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
    -- Per-pane title bar を有効化
    tell current window
        tell current tab
            -- メニュー操作で per-pane title bar をトグル
        end tell
    end tell

    -- View > Show Per-Pane Title Bars を有効化
    activate
    tell application "System Events"
        tell process "iTerm2"
            click menu item "Show Per-Pane Title Bars" of menu "View" of menu bar 1
        end tell
    end tell

    tell current window
        tell current tab
            -- ==========================================
            -- Step 1: ペインを全部作る（構造だけ先に作成）
            -- ==========================================
            -- session 1 = フリーレン（対話、既存）
            set s1 to current session

            -- 左→右に分割 → session 2（中央列トップ）
            tell s1
                set s2 to (split vertically with default profile)
            end tell

            -- 中央→右に分割 → session 3（右列トップ）
            tell s2
                set s3 to (split vertically with default profile)
            end tell

            -- 左列: フリーレンの下 → session 4（CEO）
            tell s1
                set s4 to (split horizontally with default profile)
            end tell

            -- 中央列: s2の下 → session 5
            tell s2
                set s5 to (split horizontally with default profile)
            end tell

            -- 中央列: s5の下 → session 6
            tell s5
                set s6 to (split horizontally with default profile)
            end tell

            -- 中央列: s6の下 → session 7
            tell s6
                set s7 to (split horizontally with default profile)
            end tell

            -- 右列: s3の下 → session 8
            tell s3
                set s8 to (split horizontally with default profile)
            end tell

            -- 右列: s8の下 → session 9
            tell s8
                set s9 to (split horizontally with default profile)
            end tell

            -- ==========================================
            -- Step 2: 各セッションに名前とモニターを割り当て
            -- ==========================================
            -- s1 = フリーレン（対話ペイン、何も起動しない）
            -- s2 = ヒンメル（中央上）
            -- s3 = フェルン（右上）
            -- s4 = フリーレン/CEO（左下）
            -- s5 = アイゼン（中央2段目）
            -- s6 = フランメ（中央3段目）
            -- s7 = ゼーリエ（中央4段目）
            -- s8 = ハイター（右2段目）
            -- s9 = シュタルク（右3段目）

            tell s1
                set name to "01_情報受付 | フリーレン"
            end tell
            tell s2
                set name to "03_市場調査 | ヒンメル"
                write text "bash '$MONITOR' himmel '$VAULT'"
            end tell
            tell s3
                set name to "02_経営日誌 | フェルン"
                write text "bash '$MONITOR' fern '$VAULT'"
            end tell
            tell s4
                set name to "CEO | フリーレン"
                write text "bash '$MONITOR' ceo '$VAULT'"
            end tell
            tell s5
                set name to "04_アイデア保管 | アイゼン"
                write text "bash '$MONITOR' eisen '$VAULT'"
            end tell
            tell s6
                set name to "06_マーケティング | フランメ"
                write text "bash '$MONITOR' flamme '$VAULT'"
            end tell
            tell s7
                set name to "09_制作・納品 | ゼーリエ"
                write text "bash '$MONITOR' serie '$VAULT'"
            end tell
            tell s8
                set name to "05_企画開発 | ハイター"
                write text "bash '$MONITOR' heiter '$VAULT'"
            end tell
            tell s9
                set name to "07_営業戦略 | シュタルク"
                write text "bash '$MONITOR' stark '$VAULT'"
            end tell
        end tell
    end tell
end tell
APPLESCRIPT

echo "iTerm2 画面分割完了"
