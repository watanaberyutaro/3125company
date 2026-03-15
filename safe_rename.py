#!/usr/bin/env python3
"""
safe_rename.py
Android共有ストレージ互換ファイル名に一括リネームするスクリプト。

使い方:
  python3 safe_rename.py                # dry-run（変更内容のみ表示）
  python3 safe_rename.py --execute      # 本実行（git mv + git commit）
  python3 safe_rename.py --no-commit    # git mv だけ実行、commit はしない
  python3 safe_rename.py --path /path   # 対象リポジトリを指定（省略時はカレント）
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path


# ─────────────────────────────────────────────
# 設定
# ─────────────────────────────────────────────

# Android / Windows で使えない文字（パス区切りの / は除く）
FORBIDDEN_CHARS = r'[:\*\?"<>|\\]'

# ファイル名の最大バイト数（Android の FAT32/exFAT は 255 bytes）
MAX_BYTES = 200   # 少し余裕を持たせる（絵文字・日本語は1文字3〜4バイト）

# リネーム後に衝突したファイルに付けるカウンタ上限
MAX_SUFFIX = 99


# ─────────────────────────────────────────────
# サニタイズロジック
# ─────────────────────────────────────────────

def sanitize_name(name: str) -> str:
    """
    ファイル名（basename）のみを受け取り、安全な名前を返す。
    変更不要なら元の name をそのまま返す。
    """
    original = name

    # 1. 制御文字（改行・タブ含む 0x00–0x1F）を空白に置換
    name = re.sub(r'[\x00-\x1f]', ' ', name)

    # 2. Android / Windows 禁止文字を置換
    #    : → -  (最も頻出)
    name = name.replace(':', '-')
    #    その他禁止文字 (* ? " < > | \) → - に置換
    name = re.sub(r'[*?"<>|\\]', '-', name)

    # 3. ファイル名中に / が混入している場合は - に置換
    #    ※ basename を受け取るのでパス区切りとしての / は既にない想定だが念のため
    name = name.replace('/', '-')

    # 4. 連続スペース・ハイフンを1つに圧縮
    name = re.sub(r' {2,}', ' ', name)
    name = re.sub(r'-{2,}', '-', name)

    # 5. 先頭・末尾の空白とハイフンを除去
    name = name.strip(' -')

    # 6. ファイル名が長すぎる場合、拡張子を保持して切り詰め
    name = truncate_name(name)

    # 7. 空になった場合はフォールバック
    if not name or name in ('.', '..'):
        name = 'untitled'

    return name


def truncate_name(name: str) -> str:
    """拡張子を保持しつつ MAX_BYTES バイト以内に収める。"""
    encoded = name.encode('utf-8')
    if len(encoded) <= MAX_BYTES:
        return name

    # 拡張子を分離
    stem, _, ext = name.rpartition('.')
    if not stem:
        # 拡張子なし
        stem = name
        ext_part = ''
    else:
        ext_part = '.' + ext

    ext_bytes = len(ext_part.encode('utf-8'))
    budget = MAX_BYTES - ext_bytes

    # stem を budget バイトに収める（マルチバイト文字を壊さないよう調整）
    stem_encoded = stem.encode('utf-8')
    truncated = stem_encoded[:budget]
    # UTF-8 の途中でカットしていたら削る
    while truncated:
        try:
            truncated.decode('utf-8')
            break
        except UnicodeDecodeError:
            truncated = truncated[:-1]

    return truncated.decode('utf-8').rstrip(' -') + ext_part


# ─────────────────────────────────────────────
# Git ユーティリティ
# ─────────────────────────────────────────────

def git_tracked_files(repo: Path) -> list[str]:
    """git ls-files -z でリポジトリ内の全追跡ファイルを取得。"""
    result = subprocess.run(
        ['git', '-c', 'core.quotepath=false', 'ls-files', '-z'],
        cwd=repo,
        capture_output=True,
    )
    if result.returncode != 0:
        print(f'[ERROR] git ls-files 失敗: {result.stderr.decode()}', file=sys.stderr)
        sys.exit(1)
    raw = result.stdout.split(b'\x00')
    return [f.decode('utf-8') for f in raw if f]


def git_mv(repo: Path, old: str, new: str, dry_run: bool) -> bool:
    """git mv を実行。dry_run=True なら表示のみ。成功した場合 True を返す。"""
    if dry_run:
        return True  # dry-run では常に成功扱い
    result = subprocess.run(
        ['git', 'mv', '--', old, new],
        cwd=repo,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return False
    return True


def git_commit(repo: Path, message: str) -> bool:
    result = subprocess.run(
        ['git', 'commit', '-m', message],
        cwd=repo,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f'[WARN] git commit 失敗:\n{result.stderr}', file=sys.stderr)
        return False
    print(result.stdout.strip())
    return True


# ─────────────────────────────────────────────
# メイン処理
# ─────────────────────────────────────────────

def build_rename_plan(repo: Path, files: list[str]) -> list[dict]:
    """
    変更が必要なファイルのリネーム計画を作成する。
    衝突チェックも行い、plan リストを返す。

    plan の各要素:
      { old, new, status }
      status: 'rename' | 'conflict' | 'skip_same'
    """
    # 既存ファイル名（新旧衝突検出用）
    existing_names: set[str] = set(files)

    plan = []

    for rel_path in files:
        dirpart = str(Path(rel_path).parent)
        if dirpart == '.':
            dirpart = ''
        basename = Path(rel_path).name

        new_basename = sanitize_name(basename)

        # 変更なし
        if new_basename == basename:
            continue

        if dirpart:
            new_rel = dirpart + '/' + new_basename
        else:
            new_rel = new_basename

        # 衝突チェック（リネーム先が既存ファイルと被る）
        if new_rel in existing_names and new_rel != rel_path:
            # サフィックスで回避を試みる
            resolved = False
            stem, _, ext = new_basename.rpartition('.')
            ext_part = ('.' + ext) if ext else ''
            for i in range(2, MAX_SUFFIX + 2):
                candidate_name = f"{stem}-{i}{ext_part}"
                candidate_path = (dirpart + '/' + candidate_name) if dirpart else candidate_name
                if candidate_path not in existing_names:
                    new_rel = candidate_path
                    new_basename = candidate_name
                    resolved = True
                    break
            if not resolved:
                plan.append({'old': rel_path, 'new': new_rel, 'status': 'conflict'})
                continue

        # リネーム計画に追加し、既存セットも更新
        existing_names.discard(rel_path)
        existing_names.add(new_rel)
        plan.append({'old': rel_path, 'new': new_rel, 'status': 'rename'})

    return plan


def print_plan(plan: list[dict]) -> None:
    renames   = [p for p in plan if p['status'] == 'rename']
    conflicts = [p for p in plan if p['status'] == 'conflict']

    print(f"\n{'='*60}")
    print(f"  変更対象: {len(renames)} 件  /  衝突スキップ: {len(conflicts)} 件")
    print(f"{'='*60}\n")

    if renames:
        print("【リネーム一覧】")
        for p in renames:
            old_base = Path(p['old']).name
            new_base = Path(p['new']).name
            print(f"  {p['old']}")
            print(f"    → {p['new']}")
            # 何が変わったかを分かりやすく表示
            diffs = []
            if '\n' in old_base or '\r' in old_base:
                diffs.append('改行除去')
            if ':' in old_base:
                diffs.append(': → -')
            if re.search(FORBIDDEN_CHARS.replace(':', ''), old_base):
                diffs.append('禁止文字除去')
            if len(old_base.encode('utf-8')) > MAX_BYTES:
                diffs.append(f'長さ短縮({len(old_base.encode())}→{len(new_base.encode())}bytes)')
            if diffs:
                print(f"    ({'、'.join(diffs)})")
        print()

    if conflicts:
        print("【衝突のためスキップ】")
        for p in conflicts:
            print(f"  {p['old']}  →  {p['new']}  ※ 既存ファイルと衝突")
        print()


def execute_plan(repo: Path, plan: list[dict], dry_run: bool) -> dict:
    """リネーム計画を実行し、結果サマリを返す。"""
    done = []
    failed = []
    skipped = []

    for p in plan:
        if p['status'] == 'conflict':
            skipped.append(p)
            continue

        # 親ディレクトリの新旧で rename 先が同ディレクトリか確認
        new_abs = repo / p['new']
        if not dry_run and new_abs.exists():
            skipped.append({**p, 'reason': '実行時点で衝突'})
            continue

        ok = git_mv(repo, p['old'], p['new'], dry_run)
        if ok:
            done.append(p)
        else:
            failed.append(p)

    return {'done': done, 'failed': failed, 'skipped': skipped}


def print_report(result: dict, dry_run: bool) -> None:
    label = '[DRY-RUN] ' if dry_run else ''
    done    = result['done']
    failed  = result['failed']
    skipped = result['skipped']

    print(f"\n{'='*60}")
    print(f"  {label}実行結果")
    print(f"  完了: {len(done)}  失敗: {len(failed)}  スキップ: {len(skipped)}")
    print(f"{'='*60}\n")

    if done:
        print(f"【{label}完了】")
        for p in done:
            print(f"  ✓ {Path(p['old']).name}")
            print(f"      → {Path(p['new']).name}")
        print()

    if failed:
        print("【失敗】")
        for p in failed:
            print(f"  ✗ {p['old']}")
        print()

    if skipped:
        print("【スキップ】")
        for p in skipped:
            reason = p.get('reason', '衝突')
            print(f"  - {p['old']}  ({reason})")
        print()


# ─────────────────────────────────────────────
# Obsidian リンク切れ警告
# ─────────────────────────────────────────────

OBSIDIAN_LINK_RE = re.compile(r'\[\[([^\[\]|#\n]+?)(?:[|#][^\]]*?)?\]\]')

def check_link_breakage(repo: Path, plan: list[dict]) -> None:
    """
    リネームするファイルが他の .md ファイルから [[wikilink]] で参照されているか確認。
    あれば警告を出す（自動修正はしない）。
    """
    rename_stems = {
        Path(p['old']).stem: Path(p['new']).stem
        for p in plan if p['status'] == 'rename'
    }
    if not rename_stems:
        return

    warnings = []
    for md_file in repo.rglob('*.md'):
        try:
            text = md_file.read_text(encoding='utf-8', errors='ignore')
        except Exception:
            continue
        for m in OBSIDIAN_LINK_RE.finditer(text):
            link_target = m.group(1).strip()
            # wikilink はパスなし or パスあり両方あるので basename で比較
            target_stem = Path(link_target).stem
            if target_stem in rename_stems:
                new_stem = rename_stems[target_stem]
                rel = md_file.relative_to(repo)
                warnings.append(
                    f"  {rel}\n"
                    f"    [[{link_target}]] → リネーム後は [[{new_stem}]] に更新が必要"
                )

    if warnings:
        print("⚠️  【Obsidian リンク切れ警告】")
        print("   以下のファイルでリンク先がリネームされます。")
        print("   手動または Obsidian の「ファイルを移動」機能でリンク更新を推奨します。\n")
        for w in warnings[:30]:   # 多すぎる場合は先頭30件のみ
            print(w)
        if len(warnings) > 30:
            print(f"  ... 他 {len(warnings)-30} 件")
        print()


# ─────────────────────────────────────────────
# エントリポイント
# ─────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description='Android互換ファイル名への一括リネームスクリプト'
    )
    parser.add_argument(
        '--execute', action='store_true',
        help='本実行モード（省略時は dry-run）'
    )
    parser.add_argument(
        '--no-commit', action='store_true',
        help='git mv のみ実行、git commit はしない'
    )
    parser.add_argument(
        '--path', type=str, default='.',
        help='対象リポジトリのパス（省略時はカレントディレクトリ）'
    )
    args = parser.parse_args()

    dry_run = not args.execute
    repo = Path(args.path).resolve()

    if not (repo / '.git').exists():
        print(f'[ERROR] {repo} は Git リポジトリではありません', file=sys.stderr)
        sys.exit(1)

    print(f"対象リポジトリ: {repo}")
    print(f"モード: {'🔴 本実行' if not dry_run else '🟡 DRY-RUN（変更なし）'}")

    # 1. ファイル一覧取得
    files = git_tracked_files(repo)
    print(f"追跡ファイル数: {len(files)} 件\n")

    # 2. リネーム計画を作成
    plan = build_rename_plan(repo, files)

    if not plan:
        print("✅ 変更が必要なファイルはありませんでした。")
        return

    # 3. 計画表示
    print_plan(plan)

    # 4. Obsidian リンク切れ警告
    check_link_breakage(repo, plan)

    if dry_run:
        print("📋 dry-run 完了。本実行するには --execute を付けて再実行してください。")
        print(f"   python3 {Path(__file__).name} --execute\n")
        return

    # 5. 本実行
    result = execute_plan(repo, plan, dry_run=False)
    print_report(result, dry_run=False)

    # 6. git commit
    if not args.no_commit and result['done']:
        n = len(result['done'])
        msg = f"fix: sanitize {n} filename(s) for Android compatibility"
        print(f"git commit: {msg}")
        git_commit(repo, msg)

        print("\n次のステップ:")
        print("  git push origin main")
    elif result['done'] and args.no_commit:
        print("git mv 完了。コミットするには:")
        print("  git add -A")
        print('  git commit -m "fix: sanitize filenames for Android compatibility"')
        print("  git push origin main")


if __name__ == '__main__':
    main()
