#!/usr/bin/env python3
"""
Zephyria World Sync Script
Cardinal JSON -> Supabase
Usage: python sync_to_supabase.py
"""

import json
import os
from datetime import date
from pathlib import Path

try:
    from supabase import create_client, Client
    SUPABASE_AVAILABLE = True
except ImportError:
    SUPABASE_AVAILABLE = False
    print("[警告] supabase-py が未インストールです。pip install supabase でインストールしてください。")

CARDINAL_BASE = Path("/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Cardinal/Worlds/Zephyria")
SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")


def main():
    if not SUPABASE_AVAILABLE:
        print("[エラー] supabase-py が必要です。pip install supabase")
        return
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("[エラー] 環境変数 SUPABASE_URL と SUPABASE_SERVICE_KEY を設定してください。")
        return

    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    sync_nations(supabase)
    sync_npcs(supabase)
    sync_arcadia_floors(supabase)
    sync_economy(supabase)
    sync_resources(supabase)
    sync_news(supabase)

    print(f"[sync_to_supabase] 完了: {date.today()}")


def sync_nations(supabase):
    nations_dir = CARDINAL_BASE / "nations"
    if not nations_dir.exists():
        print(f"[skip] nations/ ディレクトリが存在しません: {nations_dir}")
        return

    count = 0
    for json_path in nations_dir.glob("*.json"):
        if json_path.stem.endswith("_detail"):
            continue
        with open(json_path, encoding="utf-8") as f:
            data = json.load(f)
        row = {
            "id": data["id"],
            "name": data["name"],
            "symbol": data.get("symbol"),
            "treasury": data.get("treasury", data.get("treasury_el", 0)),
            "total_earned": data.get("total_earned", 0),
            "completed_quests": data.get("completed_quests", 0),
            "active_quests": data.get("active_quests", 0),
            "specialties": data.get("specialties", []),
            "weaknesses": data.get("weaknesses", []),
            "personality": data.get("personality"),
            "status": data.get("status", "active"),
            "leader_npc_id": data.get("leader", {}).get("npc_id"),
            "leader_name": data.get("leader", {}).get("name"),
            "leader_title": data.get("leader", {}).get("title"),
            "weather_current": data.get("weather_current", "晴れ"),
            "last_updated": data.get("last_updated", str(date.today())),
        }
        supabase.table("nations").upsert(row).execute()
        count += 1
    print(f"[sync] nations: {count}件 完了")


def sync_npcs(supabase):
    npcs_dir = CARDINAL_BASE / "npcs"
    if not npcs_dir.exists():
        print(f"[skip] npcs/ ディレクトリが存在しません: {npcs_dir}")
        return

    count = 0
    for json_path in npcs_dir.glob("npc_*.json"):
        with open(json_path, encoding="utf-8") as f:
            data = json.load(f)

        secret = data.get("secret_organization", {})
        skills = data.get("skills", {})

        npc_row = {
            "id": data["id"],
            "name": data["name"],
            "nation": data.get("nation", data.get("nation_id", "")),
            "age": data.get("age"),
            "gender": data.get("gender"),
            "profession": data.get("profession", data.get("role", "")),
            "traits": data.get("traits", []),
            "skill_diplomacy": skills.get("外交", 0),
            "skill_management": skills.get("管理", 0),
            "skill_strategy": skills.get("戦略", 0),
            "skill_creation": skills.get("制作", 0),
            "skill_research": skills.get("研究", 0),
            "skill_commerce": skills.get("商才", 0),
            "popularity": data.get("popularity", 0),
            "wealth": data.get("wealth", 0),
            "current_position": data.get("current_position", data.get("role")),
            "history": data.get("history"),
            "personality_deep": data.get("personality_deep"),
            "romance_status": data.get("romance_status"),
            "arcadia_secret": data.get("arcadia_secret"),
            "secret_org_name": secret.get("name", data.get("secret_org_name")),
            "secret_org_role": secret.get("role", data.get("secret_org_role")),
            "secret_org_aware": secret.get("awareness", False),
            "current_action": data.get("current_action"),
            "status": data.get("status", "active"),
            "last_updated": data.get("last_updated", str(date.today())),
        }
        supabase.table("npcs").upsert(npc_row).execute()

        for rel in data.get("relationships", []):
            if isinstance(rel, dict) and "npc_id" in rel:
                rel_row = {
                    "npc_from": data["id"],
                    "npc_to": rel["npc_id"],
                    "relationship_type": rel.get("type", "unknown"),
                    "value": rel.get("value", 0),
                    "note": rel.get("note"),
                    "last_updated": str(date.today()),
                }
                try:
                    supabase.table("npc_relationships").upsert(
                        rel_row, on_conflict="npc_from,npc_to"
                    ).execute()
                except Exception as e:
                    print(f"  [warn] relationship upsert error: {e}")

        count += 1
    print(f"[sync] npcs: {count}件 完了")


def sync_arcadia_floors(supabase):
    floors_path = CARDINAL_BASE / "arcadia_quest" / "floors_all.json"
    if not floors_path.exists():
        print(f"[skip] floors_all.json が存在しません: {floors_path}")
        return

    with open(floors_path, encoding="utf-8") as f:
        data = json.load(f)

    zones = data.get("zones", {})
    rows = []
    for floor_data in data.get("floors", []):
        zone_key = floor_data.get("zone")
        boss = floor_data.get("boss", {})
        row = {
            "floor": floor_data["floor"],
            "zone": zone_key,
            "zone_name": zones.get(zone_key, floor_data.get("zone_name")),
            "name": floor_data["name"],
            "description": floor_data.get("description"),
            "environment": floor_data.get("environment"),
            "status": floor_data.get("status", "未攻略"),
            "boss_name": boss.get("name", floor_data.get("boss")),
            "boss_type": boss.get("type", floor_data.get("boss_type")),
            "boss_level": boss.get("level", floor_data.get("boss_level")),
            "boss_abilities": boss.get("abilities", []),
            "boss_force_needed": boss.get("estimated_force_needed", floor_data.get("required_troops")),
            "clear_reward": floor_data.get("clear_reward", floor_data.get("reward")),
            "strategic_notes": floor_data.get("strategic_notes", floor_data.get("special_rule")),
        }
        rows.append(row)

    supabase.table("arcadia_floors").upsert(rows).execute()
    print(f"[sync] arcadia_floors: {len(rows)}件 完了")


def sync_resources(supabase):
    catalog_path = CARDINAL_BASE / "resources" / "catalog.json"
    if not catalog_path.exists():
        print(f"[skip] catalog.json が存在しません: {catalog_path}")
        return

    with open(catalog_path, encoding="utf-8") as f:
        data = json.load(f)

    count = 0
    for resource in data.get("resources", []):
        res_row = {
            "id": resource["id"],
            "name": resource["name"],
            "category": resource.get("category", "その他"),
            "unit": resource.get("unit", "単位"),
            "base_price": resource.get("base_price_per_unit", resource.get("price_per_unit", 0)),
            "notes": resource.get("notes"),
        }
        supabase.table("resources").upsert(res_row).execute()
        count += 1

    print(f"[sync] resources: {count}件 完了")


def sync_economy(supabase):
    econ_path = CARDINAL_BASE / "economy" / "system.json"
    if not econ_path.exists():
        print(f"[skip] system.json が存在しません: {econ_path}")
        return

    with open(econ_path, encoding="utf-8") as f:
        data = json.load(f)

    today = str(date.today())
    tax = data.get("tax_system", {}).get("tax_revenue_estimate", {})

    for nation_id, revenue in tax.items():
        supabase.table("economy_snapshots").upsert({
            "snapshot_date": today,
            "nation_id": nation_id,
            "tax_revenue": revenue,
        }, on_conflict="snapshot_date,nation_id").execute()

    print("[sync] economy_snapshots: 完了")


def sync_news(supabase):
    news_dir = CARDINAL_BASE / "news"
    if not news_dir.exists():
        print(f"[skip] news/ ディレクトリが存在しません: {news_dir}")
        return

    count = 0
    for json_path in news_dir.glob("*.json"):
        with open(json_path, encoding="utf-8") as f:
            items = json.load(f)
        if isinstance(items, list):
            for item in items:
                supabase.table("news").upsert({
                    "id": item.get("id"),
                    "title": item.get("title", item.get("content", "")[:30]),
                    "body": item.get("body", item.get("content", "")),
                    "category": item.get("category", "world"),
                    "author": item.get("author"),
                    "nation_id": item.get("nation_id"),
                }, on_conflict="id").execute()
                count += 1

    print(f"[sync] news: {count}件 完了")


if __name__ == "__main__":
    main()
