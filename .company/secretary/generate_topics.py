#!/usr/bin/env python3
"""
generate_topics.py
「最近のトピック.md」生成用データ収集スクリプト。
Claude Code（AI）が自然言語要約するための材料を出力する。

出力: JSON（stdout）
  - 事業部ごとのアクティビティ統計
  - 新規/変更ファイルのコンテンツプレビュー（60行）
  - キャッシュ済みのファイルはプレビューなし（summary を返す）
  - _done/ の完了タスク一覧
  - アイデアの動き

キャッシュ:
  .company/secretary/.topics_cache.json に保存。
  ファイルの git hash が一致する場合はキャッシュを流用し、ファイルを読まない。
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# ─────────────────────────────────────────
# 設定
# ─────────────────────────────────────────
VAULT = "/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"
CACHE_PATH = os.path.join(VAULT, ".company/secretary/.topics_cache.json")
DAYS = 7
MAX_PREVIEW_LINES = 60  # ファイル先頭の読み取り上限
MAX_PER_DEPT = 5        # 1部署あたりの最大表示件数

# 対象プレフィックス（これ以外はスキップ）
FOCUS_PREFIXES = (
    "3125",
    ".company/secretary/todos",
    ".company/secretary/notes",
    ".company/ceo/decisions",
)

# スキップするファイル名・パターン
SKIP_FILENAMES = {
    "_template.md", "CLAUDE.md", "_template_アイデア.md",
    "_template_リサーチ.md", "_template_成果物.md",
}
SKIP_NAME_PREFIXES = ("_MOC_",)
SKIP_FOLDERS = (".obsidian", ".company/secretary/daily-briefing")

# _done/ はタイトルのみ（中身読まない）
DONE_FOLDER = "3125情報受付事業部/_done"
IDEAS_FOLDER = "3125アイデア保管事業部"


# ─────────────────────────────────────────
# ユーティリティ
# ─────────────────────────────────────────

def load_cache():
    try:
        with open(CACHE_PATH, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def save_cache(cache: dict):
    os.makedirs(os.path.dirname(CACHE_PATH), exist_ok=True)
    with open(CACHE_PATH, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)


def git_hash(rel_path: str) -> str | None:
    """ファイルの最新コミット hash を取得。"""
    try:
        result = subprocess.run(
            ["git", "log", "-1", "--format=%H", "--", rel_path],
            cwd=VAULT, capture_output=True, text=True
        )
        h = result.stdout.strip()
        return h if h else None
    except Exception:
        return None


def read_preview(rel_path: str) -> str:
    """ファイルの先頭 MAX_PREVIEW_LINES 行を読む。"""
    abs_path = os.path.join(VAULT, rel_path)
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


def should_skip(rel_path: str) -> bool:
    """スキップ対象かどうか判定。"""
    basename = os.path.basename(rel_path)
    if basename in SKIP_FILENAMES:
        return True
    if any(basename.startswith(p) for p in SKIP_NAME_PREFIXES):
        return True
    if any(rel_path.startswith(f) for f in SKIP_FOLDERS):
        return True
    if not rel_path.endswith(".md"):
        return True
    return False


def dept_name(rel_path: str) -> str:
    """パスから事業部名を取得。"""
    parts = rel_path.split("/")
    if parts[0].startswith("3125"):
        return parts[0]
    return parts[0]


# ─────────────────────────────────────────
# Git log 解析
# ─────────────────────────────────────────

def get_changed_files(days: int) -> list[dict]:
    """
    過去 N 日間の変更ファイルを取得。
    Returns: [{"status": "A"/"M"/"D"/"R", "path": rel_path}, ...]
    """
    since = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")
    result = subprocess.run(
        ["git", "-c", "core.quotepath=false", "log",
         f"--since={since}", "--name-status",
         "--pretty=format:COMMIT:%H"],
        cwd=VAULT, capture_output=True, text=True
    )

    files = {}  # path -> {"status", "commit"}
    current_commit = None

    for line in result.stdout.splitlines():
        line = line.strip()
        if line.startswith("COMMIT:"):
            current_commit = line[7:]
            continue
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue

        status_raw = parts[0][0]  # A/M/D/R
        # Rename は R100<tab>old<tab>new
        path = parts[-1]  # 最後のフィールドが新パス

        if not any(path.startswith(p) for p in FOCUS_PREFIXES):
            continue
        if should_skip(path):
            continue

        # 最初に記録したもの（最新コミット）を優先
        if path not in files:
            files[path] = {"status": status_raw, "commit": current_commit, "path": path}

    return list(files.values())


# ─────────────────────────────────────────
# 統計収集
# ─────────────────────────────────────────

def build_dept_stats(changed_files: list[dict]) -> dict:
    stats = {}
    for f in changed_files:
        d = dept_name(f["path"])
        if d not in stats:
            stats[d] = {"added": 0, "modified": 0, "deleted": 0, "renamed": 0}
        s = f["status"]
        if s == "A":
            stats[d]["added"] += 1
        elif s == "M":
            stats[d]["modified"] += 1
        elif s == "D":
            stats[d]["deleted"] += 1
        elif s == "R":
            stats[d]["renamed"] += 1
    return stats


def get_done_tasks(days: int) -> list[str]:
    """_done/ フォルダの直近 N 日のファイル名一覧（タイトルのみ）。"""
    done_dir = os.path.join(VAULT, DONE_FOLDER)
    if not os.path.isdir(done_dir):
        return []
    since = datetime.now() - timedelta(days=days)
    tasks = []
    for f in sorted(os.listdir(done_dir), reverse=True):
        if not f.endswith(".md"):
            continue
        full = os.path.join(done_dir, f)
        mtime = datetime.fromtimestamp(os.path.getmtime(full))
        if mtime >= since:
            tasks.append(os.path.splitext(f)[0])
    return tasks[:20]  # 最大20件


def get_ideas_summary() -> dict:
    """アイデア保管事業部の各フォルダのファイル一覧。"""
    base = os.path.join(VAULT, IDEAS_FOLDER)
    result = {}
    for sub in ["_ideas", "_confirmed", "_archive"]:
        d = os.path.join(base, sub)
        if os.path.isdir(d):
            files = [os.path.splitext(f)[0] for f in sorted(os.listdir(d))
                     if f.endswith(".md") and not f.startswith("_")]
            result[sub] = files
        else:
            result[sub] = []
    return result


# ─────────────────────────────────────────
# メイン
# ─────────────────────────────────────────

def main():
    cache = load_cache()
    changed = get_changed_files(DAYS)

    # 削除ファイルは除外
    active = [f for f in changed if f["status"] != "D"]

    dept_stats = build_dept_stats(changed)
    done_tasks = get_done_tasks(DAYS)
    ideas = get_ideas_summary()

    # ファイルごとにキャッシュチェック・プレビュー収集
    file_entries = []
    dept_count: dict[str, int] = {}

    # 事業部ごとに最大 MAX_PER_DEPT 件に絞る（_done は別扱い）
    for f in active:
        path = f["path"]
        if path.startswith(DONE_FOLDER):
            continue  # _done は done_tasks で管理

        d = dept_name(path)
        dept_count[d] = dept_count.get(d, 0)
        if dept_count[d] >= MAX_PER_DEPT:
            continue
        dept_count[d] += 1

        current_hash = f["commit"]
        cached = cache.get(path, {})
        entry = {
            "path": path,
            "dept": d,
            "status": f["status"],
            "git_hash": current_hash,
        }

        if cached.get("git_hash") == current_hash and cached.get("summary"):
            # キャッシュヒット：プレビュー不要
            entry["cached_summary"] = cached["summary"]
            entry["content_preview"] = None
        else:
            # キャッシュミス：プレビューを読む
            entry["cached_summary"] = None
            entry["content_preview"] = read_preview(path)

        file_entries.append(entry)

    output = {
        "generated_at": datetime.now().isoformat(),
        "days": DAYS,
        "dept_stats": dept_stats,
        "files": file_entries,
        "done_tasks": done_tasks,
        "ideas_summary": ideas,
        "_cache_path": CACHE_PATH,
    }

    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
