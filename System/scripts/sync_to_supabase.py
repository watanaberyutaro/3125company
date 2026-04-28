#!/usr/bin/env python3
"""
Cardinal → Supabase 同期スクリプト
/yui または手動実行時にZephyriaのJSONデータをSupabaseへ同期する
"""

import json
import os
import glob
from datetime import datetime

try:
    from supabase import create_client
except ImportError:
    print("supabase-py未インストール: pip install supabase")
    exit(1)

CARDINAL = "/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Cardinal"
WORLD = f"{CARDINAL}/Worlds/Zephyria"

SUPABASE_URL = "https://iwllwfdohvnqsurmdxaf.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml3bGx3ZmRvaHZucXN1cm1keGFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NTEwMTUsImV4cCI6MjA5MjUyNzAxNX0.9siT996nrOGyuvras2OJDb9oNDZ-DSyX7UZm4qlGD8c"

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

def sync_nations():
    nation_files = glob.glob(f"{WORLD}/nations/*.json")
    for f in nation_files:
        with open(f) as fp:
            data = json.load(fp)
        row = {
            "id": data.get("id"),
            "name": data.get("name"),
            "symbol": data.get("symbol"),
            "treasury": data.get("treasury", 100),
            "total_earned": data.get("total_earned", 100),
            "completed_quests": data.get("completed_quests", 0),
            "active_quests": data.get("active_quests", 0),
            "status": data.get("status", "active"),
            "specialties": data.get("specialties", []),
            "weaknesses": data.get("weaknesses", []),
            "alliances": data.get("alliances", []),
            "tensions": data.get("tensions", []),
            "last_updated": data.get("last_updated"),
        }
        supabase.table("nations").upsert(row).execute()
    print(f"✅ nations: {len(nation_files)}件同期")

def sync_npcs():
    npc_files = glob.glob(f"{WORLD}/npcs/npc_*.json")
    for f in npc_files:
        with open(f) as fp:
            data = json.load(fp)
        row = {
            "id": data.get("id"),
            "name": data.get("name"),
            "nation_id": data.get("nation_id"),
            "age": data.get("age"),
            "role": data.get("role"),
            "personality": data.get("personality"),
            "status": data.get("status", "active"),
            "romance_status": data.get("romance_status"),
            "secret_organization": data.get("secret_organization"),
            "skills": data.get("skills", []),
            "current_action": data.get("current_action"),
            "last_updated": datetime.today().strftime("%Y-%m-%d"),
        }
        supabase.table("npcs").upsert(row).execute()
    print(f"✅ npcs: {len(npc_files)}件同期")

def sync_arcadia():
    floors_file = f"{WORLD}/arcadia_quest/floors_all.json"
    if not os.path.exists(floors_file):
        print("⚠️ arcadia floors_all.json 見つからず")
        return
    with open(floors_file) as fp:
        data = json.load(fp)

    progress_file = f"{WORLD}/arcadia_quest/progress.json"
    cleared = set()
    if os.path.exists(progress_file):
        with open(progress_file) as fp:
            progress = json.load(fp)
            cleared = set(progress.get("cleared_floors", []))

    floors = data.get("floors", [])
    rows = []
    for floor in floors:
        rows.append({
            "floor_number": floor.get("floor"),
            "name": floor.get("name"),
            "zone": floor.get("zone"),
            "boss_name": floor.get("boss"),
            "difficulty": str(floor.get("difficulty", "")),
            "cleared": floor.get("floor") in cleared,
            "reward_unlocked": str(floor.get("reward", "")),
        })
    if rows:
        supabase.table("arcadia_floors").upsert(rows).execute()
    print(f"✅ arcadia_floors: {len(rows)}件同期")

def sync_news():
    news_files = sorted(glob.glob(f"{WORLD}/news/*.md"))[-5:]
    for f in news_files:
        date_str = os.path.basename(f).replace(".md", "")
        with open(f) as fp:
            content = fp.read()
        row = {
            "title": f"ゼフィリア通信 {date_str}",
            "content": content,
            "category": "daily",
            "published_at": f"{date_str}T00:00:00+09:00",
        }
        supabase.table("news").upsert(row, on_conflict="title").execute()
    print(f"✅ news: {len(news_files)}件同期")

if __name__ == "__main__":
    print(f"🌍 Cardinal → Supabase 同期開始 ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})")
    sync_nations()
    sync_npcs()
    sync_arcadia()
    sync_news()
    print("✅ 同期完了")
