#!/usr/bin/env python3
"""
generate_report.py
各3125事業部の現状データを収集してJSON出力する。
Claude が読んで各部署Discordチャンネルに送信するためのデータ源。

出力: JSON (stdout)
  - 事業部ごとの最新ファイル一覧・件数・アイデア状況・pending件数
"""

import json
import os
from datetime import datetime, timedelta
from pathlib import Path

VAULT = "/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"
DAYS = 7


def recent_files(folder: str, days: int = DAYS) -> list[dict]:
    """フォルダ内の直近N日間に更新されたmdファイル一覧を返す。"""
    since = datetime.now() - timedelta(days=days)
    result = []
    base = os.path.join(VAULT, folder)
    if not os.path.isdir(base):
        return result
    for f in sorted(os.listdir(base), reverse=True):
        if not f.endswith(".md") or f.startswith("_") or f == "CLAUDE.md":
            continue
        full = os.path.join(base, f)
        mtime = datetime.fromtimestamp(os.path.getmtime(full))
        if mtime >= since:
            result.append({
                "name": os.path.splitext(f)[0],
                "mtime": mtime.strftime("%m-%d %H:%M"),
            })
    return result


def count_md(folder: str) -> int:
    base = os.path.join(VAULT, folder)
    if not os.path.isdir(base):
        return 0
    return sum(1 for f in os.listdir(base) if f.endswith(".md") and not f.startswith("_"))


def pending_count() -> int:
    pending_dir = os.path.join(VAULT, "3125情報受付事業部/_pending")
    if not os.path.isdir(pending_dir):
        return 0
    return sum(1 for f in os.listdir(pending_dir) if f.endswith(".md"))


def dept_report(dept_folder: str, subfolders: list[str] = None) -> dict:
    """事業部の現状サマリーを返す。"""
    subfolders = subfolders or []
    recent = recent_files(dept_folder)
    sub_data = {}
    for sub in subfolders:
        path = f"{dept_folder}/{sub}"
        sub_data[sub] = {
            "count": count_md(path),
            "recent": recent_files(path),
        }
    return {
        "recent_files": recent,
        "recent_count": len(recent),
        "subfolders": sub_data,
    }


def main():
    today = datetime.now().strftime("%Y-%m-%d")

    report = {
        "generated_at": datetime.now().isoformat(),
        "date": today,
        "pending_queue": pending_count(),
        "departments": {
            "3125アイデア保管事業部": {
                "char": "アイゼン",
                "webhook_file": "3125アイデア保管事業部/discord-webhook.txt",
                "ideas_count": count_md("3125アイデア保管事業部/_ideas"),
                "confirmed_count": count_md("3125アイデア保管事業部/_confirmed"),
                "ideas_list": [
                    os.path.splitext(f)[0]
                    for f in sorted(os.listdir(os.path.join(VAULT, "3125アイデア保管事業部/_ideas")))
                    if f.endswith(".md") and not f.startswith("_")
                ] if os.path.isdir(os.path.join(VAULT, "3125アイデア保管事業部/_ideas")) else [],
                "confirmed_list": [
                    os.path.splitext(f)[0]
                    for f in sorted(os.listdir(os.path.join(VAULT, "3125アイデア保管事業部/_confirmed")))
                    if f.endswith(".md") and not f.startswith("_")
                ] if os.path.isdir(os.path.join(VAULT, "3125アイデア保管事業部/_confirmed")) else [],
            },
            "3125マーケティング事業部": {
                "char": "フランメ",
                "webhook_file": "3125マーケティング事業部/discord-webhook.txt",
                **dept_report("3125マーケティング事業部/SNSマーケティング事業部"),
            },
            "3125営業戦略事業部": {
                "char": "シュタルク",
                "webhook_file": "3125営業戦略事業部/discord-webhook.txt",
                **dept_report("3125営業戦略事業部"),
            },
            "3125企画開発事業部": {
                "char": "ハイター",
                "webhook_file": "3125企画開発事業部/discord-webhook.txt",
                **dept_report("3125企画開発事業部"),
            },
            "3125経営日誌事業部": {
                "char": "フェルン",
                "webhook_file": "3125経営日誌事業部/discord-webhook.txt",
                "news_recent": recent_files("3125経営日誌事業部/news"),
                "diary_recent": recent_files("3125経営日誌事業部"),
            },
            "3125制作・納品事業部": {
                "char": "ゼーリエ",
                "webhook_file": "3125制作・納品事業部/discord-webhook.txt",
                **dept_report("3125制作・納品事業部"),
            },
            "3125市場調査事業部": {
                "char": "ヒンメル",
                "webhook_file": "3125市場調査事業部/discord-webhook.txt",
                **dept_report("3125市場調査事業部"),
            },
        },
    }

    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
