#!/usr/bin/env python3
"""
generate_report.py
各3125事業部の現状データ＋ファイル内容プレビューを収集してJSON出力する。
Claude が内容を要約し、各キャラの口調でDiscordに送信するためのデータ源。

キャッシュ: .company/secretary/.report_cache.json
  ファイルの mtime が変わっていなければキャッシュの summary を流用。
"""

import json
import os
import hashlib
from datetime import datetime, timedelta

VAULT = "/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"
CACHE_PATH = os.path.join(VAULT, ".company/secretary/.report_cache.json")
DAYS = 7
MAX_PREVIEW_LINES = 80   # 内容プレビューの最大行数
MAX_FILES_PER_DEPT = 3   # 部署ごとの最大表示ファイル数


# ──────────────────────────────────────
# キャッシュ
# ──────────────────────────────────────

def load_cache() -> dict:
    try:
        with open(CACHE_PATH, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


# ──────────────────────────────────────
# ファイルユーティリティ
# ──────────────────────────────────────

def file_mtime_key(abs_path: str) -> str:
    """ファイルの mtime を文字列で返す（キャッシュキー用）。"""
    try:
        return str(os.path.getmtime(abs_path))
    except Exception:
        return ""


def read_preview(abs_path: str) -> str:
    """ファイルの先頭 MAX_PREVIEW_LINES 行を返す。"""
    try:
        with open(abs_path, encoding="utf-8", errors="ignore") as f:
            lines = []
            for i, line in enumerate(f):
                if i >= MAX_PREVIEW_LINES:
                    break
                lines.append(line.rstrip())
        return "\n".join(lines)
    except Exception:
        return ""


def recent_md_files(folder: str, days: int = DAYS, max_files: int = MAX_FILES_PER_DEPT) -> list[dict]:
    """
    フォルダ内の直近 N 日間に更新された .md ファイルを返す。
    各エントリ: {name, mtime, abs_path, mtime_key, content_preview or cached_summary}
    """
    cache = load_cache()
    since = datetime.now() - timedelta(days=days)
    base = os.path.join(VAULT, folder)
    if not os.path.isdir(base):
        return []

    results = []
    for f in sorted(os.listdir(base), reverse=True):
        if not f.endswith(".md") or f.startswith("_") or f in ("CLAUDE.md",):
            continue
        abs_path = os.path.join(base, f)
        mtime_dt = datetime.fromtimestamp(os.path.getmtime(abs_path))
        if mtime_dt < since:
            continue

        mtime_key = file_mtime_key(abs_path)
        rel_path = os.path.relpath(abs_path, VAULT)
        cached = cache.get(rel_path, {})

        entry = {
            "name": os.path.splitext(f)[0],
            "mtime": mtime_dt.strftime("%m-%d %H:%M"),
            "rel_path": rel_path,
            "mtime_key": mtime_key,
        }

        if cached.get("mtime_key") == mtime_key and cached.get("summary"):
            entry["cached_summary"] = cached["summary"]
            entry["content_preview"] = None
        else:
            entry["cached_summary"] = None
            entry["content_preview"] = read_preview(abs_path)

        results.append(entry)
        if len(results) >= max_files:
            break

    return results


def count_md(folder: str) -> int:
    base = os.path.join(VAULT, folder)
    if not os.path.isdir(base):
        return 0
    return sum(1 for f in os.listdir(base)
               if f.endswith(".md") and not f.startswith("_") and f != "CLAUDE.md")


def pending_count() -> int:
    d = os.path.join(VAULT, "3125情報受付事業部/_pending")
    return sum(1 for f in os.listdir(d) if f.endswith(".md")) if os.path.isdir(d) else 0


def idea_files(subfolder: str) -> list[dict]:
    """アイデアフォルダのファイル一覧（内容プレビュー付き）。"""
    return recent_md_files(f"3125アイデア保管事業部/{subfolder}", days=30, max_files=5)


# ──────────────────────────────────────
# メイン
# ──────────────────────────────────────

def main():
    report = {
        "generated_at": datetime.now().isoformat(),
        "date": datetime.now().strftime("%Y-%m-%d"),
        "pending_queue": pending_count(),
        "cache_path": CACHE_PATH,
        "departments": {

            "3125アイデア保管事業部": {
                "char": "アイゼン",
                "char_style": "寡黙・簡潔・「俺」一人称・「〜だな」「〜だ」",
                "webhook_file": "3125アイデア保管事業部/discord-webhook.txt",
                "color": 9807270,
                "ideas_count": count_md("3125アイデア保管事業部/_ideas"),
                "confirmed_count": count_md("3125アイデア保管事業部/_confirmed"),
                "ideas_files": idea_files("_ideas"),
                "confirmed_files": idea_files("_confirmed"),
            },

            "3125マーケティング事業部": {
                "char": "フランメ",
                "char_style": "自信家・師匠口調・「私」一人称・「〜だな」「〜ぞ」・少し上から",
                "webhook_file": "3125マーケティング事業部/discord-webhook.txt",
                "color": 16711680,
                "recent_files": recent_md_files("3125マーケティング事業部/SNSマーケティング事業部"),
            },

            "3125営業戦略事業部": {
                "char": "シュタルク",
                "char_style": "少年ぽい・「俺」一人称・弱音あり・でも覚悟を決める・「〜だろ」「やるしかない」",
                "webhook_file": "3125営業戦略事業部/discord-webhook.txt",
                "color": 16744272,
                "recent_files": recent_md_files("3125営業戦略事業部"),
            },

            "3125企画開発事業部": {
                "char": "ハイター",
                "char_style": "明るく朗らか・「私」一人称・丁寧語・「〜ですよ」「〜ですねぇ」",
                "webhook_file": "3125企画開発事業部/discord-webhook.txt",
                "color": 1752220,
                "recent_files": recent_md_files("3125企画開発事業部"),
            },

            "3125経営日誌事業部": {
                "char": "フェルン",
                "char_style": "冷静沈着・敬語・「私」一人称・「…〜です」「ダメです」・淡々と的確",
                "webhook_file": "3125経営日誌事業部/discord-webhook.txt",
                "color": 3447003,
                "news_files": recent_md_files("3125経営日誌事業部/news"),
                "diary_files": recent_md_files("3125経営日誌事業部"),
            },

            "3125制作・納品事業部": {
                "char": "ゼーリエ",
                "char_style": "高圧的・傲慢・「私（わたくし）」一人称・命令形多め・「〜しろ」「ふん」「光栄に思え」",
                "webhook_file": "3125制作・納品事業部/discord-webhook.txt",
                "color": 10181046,
                "recent_files": recent_md_files("3125制作・納品事業部"),
            },

            "3125市場調査事業部": {
                "char": "ヒンメル",
                "char_style": "爽やか・自信家・「僕」一人称・「〜だね」「〜だよ」・美しいが口癖",
                "webhook_file": "3125市場調査事業部/discord-webhook.txt",
                "color": 5793266,
                "recent_files": recent_md_files("3125市場調査事業部"),
            },
        },
    }

    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
