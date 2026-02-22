#!/usr/bin/env python3
"""Blueprint-Flow Hub DB Helper

Safe DB operations with parameter binding.
Hub MUST use this instead of raw sqlite3 commands for all writes.

Usage:
  python3 blueprint/hub.py <command> [args]

Content input:
  Commands that accept markdown content read from stdin.
  Example: echo "# Title\nContent here" | python3 blueprint/hub.py upsert-core overview app-overview "App Name" "Short summary"
"""

import sqlite3
import sys
import json
import os
import subprocess

DB_PATH = "blueprint/blueprint.db"

# Item flow definitions (step progression per type)
ITEM_FLOWS = {
    "page":    ["define", "impl", "test_l1", "test_l2", "test_l3", "done"],
    "partial": ["define", "impl", "test_l1", "test_l2", "test_l3", "done"],
    "action":  ["define", "impl", "test_l1", "test_l2", "test_l3", "done"],
    "table":   ["define", "seed", "impl", "done"],
    "layout":  ["define", "impl", "done"],
    "test":    ["define", "done"],
}


def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.row_factory = sqlite3.Row
    return conn


def next_step(bp_type, current_step):
    """Get the next step in the pipeline for a given blueprint type."""
    flow = ITEM_FLOWS.get(bp_type)
    if not flow:
        return None
    try:
        idx = flow.index(current_step)
        if idx + 1 < len(flow):
            return flow[idx + 1]
    except ValueError:
        pass
    return None


def out(data):
    """Output JSON result."""
    print(json.dumps(data, ensure_ascii=False, indent=2))


# =========================================
# Core operations
# =========================================

def cmd_upsert_core(args):
    """Upsert a core record. Content from stdin.
    Usage: ... | hub.py upsert-core <type> <slug> <name> <summary>
    """
    if len(args) < 4:
        print("Usage: ... | hub.py upsert-core <type> <slug> <name> <summary>")
        sys.exit(1)
    core_type, slug, name, summary = args[0], args[1], args[2], args[3]
    content = sys.stdin.read() if not sys.stdin.isatty() else ""
    if not content:
        print("Error: content required via stdin")
        sys.exit(1)

    conn = get_conn()
    conn.execute(
        """INSERT INTO cores (type, slug, name, summary, content)
           VALUES (?, ?, ?, ?, ?)
           ON CONFLICT(slug) DO UPDATE SET
             type=excluded.type, name=excluded.name,
             summary=excluded.summary, content=excluded.content""",
        (core_type, slug, name, summary, content)
    )
    conn.commit()
    out({"ok": True, "action": "upsert-core", "slug": slug})


def cmd_set_concept(args):
    """Set project concept (5 fields).
    Usage: hub.py set-concept <target> <problem> <solution> <value> <catchphrase>
    catchphrase: 20字以内のハイレベルコンセプト
    """
    if len(args) < 5:
        print("Usage: hub.py set-concept <target> <problem> <solution> <value> <catchphrase>")
        sys.exit(1)
    target, problem, solution, value, catchphrase = args[0], args[1], args[2], args[3], args[4]

    if len(catchphrase) > 40:
        print(f"Error: catchphrase must be ≤40 chars (got {len(catchphrase)})")
        sys.exit(1)

    content = (
        f"## ターゲット\n{target}\n\n"
        f"## ターゲットの課題\n{problem}\n\n"
        f"## ソリューション\n{solution}\n\n"
        f"## 独自価値\n{value}\n\n"
        f"## ハイレベルコンセプト\n{catchphrase}"
    )

    conn = get_conn()
    conn.execute(
        """INSERT INTO cores (type, slug, name, summary, content)
           VALUES ('concept', 'concept', 'プロジェクトコンセプト', ?, ?)
           ON CONFLICT(slug) DO UPDATE SET
             summary=excluded.summary, content=excluded.content""",
        (catchphrase, content)
    )
    conn.commit()
    out({"ok": True, "action": "set-concept", "catchphrase": catchphrase})


def cmd_set_strategy(args):
    """Set project strategy analysis. Detailed analysis from stdin.
    Usage: ... | hub.py set-strategy <market_type> <strategic_axis> <moat>
    market_type: 市場構造タイプ（例: "WTA弱・ニッチ特化型"）
    strategic_axis: 選択した戦略軸（例: "領域特化 + 顧客接点特化"）
    moat: 堀の構造（例: "業界固有データ×規制対応"）
    Detailed strategy analysis via stdin (Markdown).
    """
    if len(args) < 3:
        print("Usage: ... | hub.py set-strategy <market_type> <strategic_axis> <moat>")
        sys.exit(1)
    market_type, strategic_axis, moat = args[0], args[1], args[2]
    analysis = sys.stdin.read() if not sys.stdin.isatty() else ""
    if not analysis:
        print("Error: strategy analysis required via stdin")
        sys.exit(1)

    content = (
        f"## 市場構造\n{market_type}\n\n"
        f"## 戦略軸\n{strategic_axis}\n\n"
        f"## 堀の構造\n{moat}\n\n"
        f"## 詳細分析\n{analysis}"
    )

    conn = get_conn()
    conn.execute(
        """INSERT INTO cores (type, slug, name, summary, content)
           VALUES ('strategy', 'strategy', '戦略分析', ?, ?)
           ON CONFLICT(slug) DO UPDATE SET
             summary=excluded.summary, content=excluded.content""",
        (strategic_axis, content)
    )
    conn.commit()
    out({"ok": True, "action": "set-strategy", "strategic_axis": strategic_axis})


def cmd_set_design(args):
    """Set project design direction. Full design spec from stdin.
    Usage: ... | hub.py set-design <style_name>
    style_name: スタイル名（例: "Minimalism", "Neubrutalism"）
    stdin: 完全なデザイン仕様（Markdown — スタイル/CSS/エフェクト/フォント/カラー/軸プロファイル）
    """
    if len(args) < 1:
        print("Usage: ... | hub.py set-design <style_name>")
        sys.exit(1)
    style_name = args[0]
    content = sys.stdin.read() if not sys.stdin.isatty() else ""
    if not content:
        print("Error: design specification required via stdin")
        sys.exit(1)

    conn = get_conn()
    conn.execute(
        """INSERT INTO cores (type, slug, name, summary, content)
           VALUES ('design', 'design', 'デザイン指針', ?, ?)
           ON CONFLICT(slug) DO UPDATE SET
             summary=excluded.summary, content=excluded.content""",
        (style_name, content)
    )
    conn.commit()
    out({"ok": True, "action": "set-design", "style": style_name})


# =========================================
# Blueprint operations
# =========================================

def cmd_upsert_blueprint(args):
    """Upsert a blueprint. Content from stdin.
    Usage: ... | hub.py upsert-blueprint <type> <slug> <name> <summary> [parent_id] [test_level]
    """
    if len(args) < 4:
        print("Usage: ... | hub.py upsert-blueprint <type> <slug> <name> <summary> [parent_id] [test_level]")
        sys.exit(1)
    bp_type, slug, name, summary = args[0], args[1], args[2], args[3]
    parent_id = int(args[4]) if len(args) > 4 and args[4] else None
    test_level = int(args[5]) if len(args) > 5 and args[5] else None
    content = sys.stdin.read() if not sys.stdin.isatty() else ""
    if not content:
        print("Error: content required via stdin")
        sys.exit(1)

    conn = get_conn()
    conn.execute(
        """INSERT INTO blueprints (type, slug, name, summary, content, parent_id, test_level)
           VALUES (?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(type, slug) DO UPDATE SET
             name=excluded.name, summary=excluded.summary,
             content=excluded.content, parent_id=excluded.parent_id,
             test_level=excluded.test_level""",
        (bp_type, slug, name, summary, content, parent_id, test_level)
    )
    conn.commit()
    row = conn.execute("SELECT id FROM blueprints WHERE type=? AND slug=?", (bp_type, slug)).fetchone()
    out({"ok": True, "action": "upsert-blueprint", "id": row["id"], "type": bp_type, "slug": slug})


def cmd_add_dep(args):
    """Add dependency between blueprints.
    Usage: hub.py add-dep <source_id> <target_id> [dep_gate] [detail]
    dep_gate: step the target must reach (default: 'done', use 'impl' for early unlock)
    """
    if len(args) < 2:
        print("Usage: hub.py add-dep <source_id> <target_id> [dep_gate] [detail]")
        sys.exit(1)
    source_id, target_id = int(args[0]), int(args[1])
    dep_gate = args[2] if len(args) > 2 and args[2] else "done"
    detail = args[3] if len(args) > 3 else None

    valid_gates = {"define", "seed", "impl", "test_l1", "test_l2", "test_l3", "done"}
    if dep_gate not in valid_gates:
        print(f"Error: invalid dep_gate '{dep_gate}'. Valid: {', '.join(sorted(valid_gates))}")
        sys.exit(1)

    conn = get_conn()
    conn.execute(
        "INSERT INTO dependencies (source_id, target_id, dep_gate, detail) VALUES (?, ?, ?, ?)"
        " ON CONFLICT(source_id, target_id) DO UPDATE SET dep_gate=excluded.dep_gate, detail=excluded.detail",
        (source_id, target_id, dep_gate, detail)
    )
    conn.commit()
    out({"ok": True, "action": "add-dep", "source_id": source_id, "target_id": target_id, "dep_gate": dep_gate})


# =========================================
# Status transitions (CRITICAL)
# =========================================

def cmd_approve(args):
    """Approve blueprints: step_status → 'done'.
    Usage: hub.py approve <id> [id2] [id3] ...
           hub.py approve --all    (approve all with step_status='todo')
    """
    conn = get_conn()

    if args and args[0] == "--all":
        cur = conn.execute(
            "UPDATE blueprints SET step_status='done' WHERE step_status='todo'"
        )
        conn.commit()
        out({"ok": True, "action": "approve-all", "count": cur.rowcount})
        return

    if not args:
        print("Usage: hub.py approve <id> [id2] ... | --all")
        sys.exit(1)

    ids = [int(a) for a in args]
    for bp_id in ids:
        conn.execute(
            "UPDATE blueprints SET step_status='done' WHERE id=? AND step_status IN ('todo','review')",
            (bp_id,)
        )
    conn.commit()

    rows = conn.execute(
        f"SELECT id, type, slug, step, step_status FROM blueprints WHERE id IN ({','.join('?' * len(ids))})",
        ids
    ).fetchall()
    out({"ok": True, "action": "approve", "blueprints": [dict(r) for r in rows]})


def cmd_advance(args):
    """Advance blueprint to next step: step → next, step_status → 'todo'.
    Usage: hub.py advance <id> [id2] ...
    """
    if not args:
        print("Usage: hub.py advance <id> [id2] ...")
        sys.exit(1)

    conn = get_conn()
    results = []
    for bp_id in [int(a) for a in args]:
        row = conn.execute("SELECT id, type, step, step_status FROM blueprints WHERE id=?", (bp_id,)).fetchone()
        if not row:
            results.append({"id": bp_id, "error": "not found"})
            continue
        if row["step_status"] != "done":
            results.append({"id": bp_id, "error": f"step_status is '{row['step_status']}', must be 'done'"})
            continue
        ns = next_step(row["type"], row["step"])
        if not ns:
            results.append({"id": bp_id, "error": f"no next step after '{row['step']}' for type '{row['type']}'"})
            continue
        conn.execute(
            "UPDATE blueprints SET step=?, step_status='todo', locked_by=NULL WHERE id=?",
            (ns, bp_id)
        )
        results.append({"id": bp_id, "from": row["step"], "to": ns})
    conn.commit()
    out({"ok": True, "action": "advance", "results": results})


def cmd_lock(args):
    """Lock blueprint for work: step_status → 'doing'.
    Usage: hub.py lock <id> [locked_by]
    """
    if not args:
        print("Usage: hub.py lock <id> [locked_by]")
        sys.exit(1)
    bp_id = int(args[0])
    locked_by = args[1] if len(args) > 1 else "coding"

    conn = get_conn()
    conn.execute(
        "UPDATE blueprints SET step_status='doing', locked_by=? WHERE id=?",
        (locked_by, bp_id)
    )
    conn.commit()
    out({"ok": True, "action": "lock", "id": bp_id, "locked_by": locked_by})


def cmd_review(args):
    """Set blueprint to review state: step_status → 'review', unlock.
    Usage: hub.py review <id>
    """
    if not args:
        print("Usage: hub.py review <id>")
        sys.exit(1)
    bp_id = int(args[0])

    conn = get_conn()
    conn.execute(
        "UPDATE blueprints SET step_status='review', locked_by=NULL WHERE id=?",
        (bp_id,)
    )
    conn.commit()
    out({"ok": True, "action": "review", "id": bp_id})


# =========================================
# Act operations
# =========================================

def cmd_create_act(args):
    """Create an act. Content from stdin.
    Usage: ... | hub.py create-act <blueprint_id> <title>
    """
    if len(args) < 2:
        print("Usage: ... | hub.py create-act <blueprint_id> <title>")
        sys.exit(1)
    bp_id, title = int(args[0]), args[1]
    content = sys.stdin.read() if not sys.stdin.isatty() else ""

    conn = get_conn()
    cur = conn.execute(
        "INSERT INTO acts (blueprint_id, title, content) VALUES (?, ?, ?)",
        (bp_id, title, content)
    )
    conn.commit()
    out({"ok": True, "action": "create-act", "act_id": cur.lastrowid, "blueprint_id": bp_id})


def cmd_save_result(args):
    """Save agent report to act. Result from stdin.
    Usage: ... | hub.py save-result <act_id> [status]
    """
    if not args:
        print("Usage: ... | hub.py save-result <act_id> [status]")
        sys.exit(1)
    act_id = int(args[0])
    status = args[1] if len(args) > 1 else "done"
    result = sys.stdin.read() if not sys.stdin.isatty() else ""

    conn = get_conn()
    conn.execute(
        "UPDATE acts SET status=?, result=?, completed_at=CURRENT_TIMESTAMP WHERE id=?",
        (status, result, act_id)
    )
    conn.commit()
    out({"ok": True, "action": "save-result", "act_id": act_id, "status": status})


# =========================================
# Dirty flags
# =========================================

def cmd_dirty(args):
    """Mark blueprint as dirty.
    Usage: hub.py dirty <id> <reason>
    """
    if len(args) < 2:
        print("Usage: hub.py dirty <id> <reason>")
        sys.exit(1)
    bp_id, reason = int(args[0]), args[1]

    conn = get_conn()
    conn.execute(
        "UPDATE blueprints SET dirty=1, dirty_reason=?, step_status='todo', locked_by=NULL WHERE id=?",
        (reason, bp_id)
    )
    conn.commit()
    out({"ok": True, "action": "dirty", "id": bp_id})


def cmd_clear_dirty(args):
    """Clear dirty flag.
    Usage: hub.py clear-dirty <id>
    """
    if not args:
        print("Usage: hub.py clear-dirty <id>")
        sys.exit(1)
    bp_id = int(args[0])

    conn = get_conn()
    conn.execute(
        "UPDATE blueprints SET dirty=0, dirty_reason=NULL WHERE id=?",
        (bp_id,)
    )
    conn.commit()
    out({"ok": True, "action": "clear-dirty", "id": bp_id})


# =========================================
# Compound operations
# =========================================

def cmd_complete(args):
    """Complete a blueprint step: review → approve → commit → advance.
    Usage: hub.py complete <id>
    """
    if not args:
        print("Usage: hub.py complete <id>")
        sys.exit(1)
    bp_id = int(args[0])

    conn = get_conn()
    row = conn.execute(
        "SELECT id, type, slug, name, step, step_status FROM blueprints WHERE id=?", (bp_id,)
    ).fetchone()
    if not row:
        print(f"Error: blueprint {bp_id} not found")
        sys.exit(1)

    status = row["step_status"]
    steps_done = []

    # review (if currently doing)
    if status == "doing":
        conn.execute(
            "UPDATE blueprints SET step_status='review', locked_by=NULL WHERE id=?",
            (bp_id,)
        )
        conn.commit()
        steps_done.append("review")
        status = "review"

    # approve (if currently review or todo)
    if status in ("review", "todo"):
        conn.execute(
            "UPDATE blueprints SET step_status='done' WHERE id=?",
            (bp_id,)
        )
        conn.commit()
        steps_done.append("approve")
    else:
        out({"ok": False, "action": "complete", "id": bp_id,
             "error": f"cannot complete: step_status is '{status}'"})
        sys.exit(1)

    # commit
    subprocess.run(["git", "add", "-A"], check=True, capture_output=True)
    diff_result = subprocess.run(["git", "diff", "--cached", "--quiet"])
    if diff_result.returncode != 0:
        msg = f"feat({row['type']}/{row['slug']}): {row['step']}完了\n\nBlueprint: #{row['id']} {row['name']}"
        subprocess.run(["git", "commit", "-m", msg], check=True, capture_output=True)
        steps_done.append("commit")
    else:
        steps_done.append("commit(skipped)")

    # advance
    ns = next_step(row["type"], row["step"])
    if ns:
        conn.execute(
            "UPDATE blueprints SET step=?, step_status='todo', locked_by=NULL WHERE id=?",
            (ns, bp_id)
        )
        conn.commit()
        steps_done.append(f"advance({row['step']}→{ns})")
    else:
        steps_done.append("advance(already final)")

    out({"ok": True, "action": "complete", "id": bp_id,
         "type": row["type"], "slug": row["slug"], "steps": steps_done})


# =========================================
# Git operations
# =========================================

def cmd_commit(args):
    """Commit changes for a blueprint.
    Usage: hub.py commit <bp_id>
    """
    if not args:
        print("Usage: hub.py commit <bp_id>")
        sys.exit(1)
    bp_id = int(args[0])

    conn = get_conn()
    row = conn.execute(
        "SELECT id, type, slug, name, step FROM blueprints WHERE id=?", (bp_id,)
    ).fetchone()
    if not row:
        print(f"Error: blueprint {bp_id} not found")
        sys.exit(1)

    # Stage all changes
    subprocess.run(["git", "add", "-A"], check=True, capture_output=True)

    # Check for staged changes
    result = subprocess.run(["git", "diff", "--cached", "--quiet"])
    if result.returncode == 0:
        out({"ok": True, "action": "commit", "id": bp_id, "skipped": True, "reason": "no staged changes"})
        return

    # Commit with structured message
    msg = f"feat({row['type']}/{row['slug']}): {row['step']}完了\n\nBlueprint: #{row['id']} {row['name']}"
    subprocess.run(["git", "commit", "-m", msg], check=True, capture_output=True)
    out({"ok": True, "action": "commit", "id": bp_id, "type": row["type"], "slug": row["slug"], "step": row["step"]})


def cmd_push(args):
    """Push to remote repository.
    Usage: hub.py push
    """
    result = subprocess.run(["git", "push"], capture_output=True, text=True)
    if result.returncode != 0:
        out({"ok": False, "action": "push", "error": result.stderr.strip()})
        sys.exit(1)
    out({"ok": True, "action": "push"})


# =========================================
# Read helpers (JSON output)
# =========================================

def cmd_read_core(args):
    """Read a core record (including content).
    Usage: hub.py read-core <slug>
    """
    if not args:
        print("Usage: hub.py read-core <slug>")
        sys.exit(1)
    slug = args[0]

    conn = get_conn()
    row = conn.execute(
        "SELECT id, type, slug, name, summary, content, reviewed FROM cores WHERE slug=?",
        (slug,)
    ).fetchone()
    if not row:
        print(f"Error: core '{slug}' not found")
        sys.exit(1)
    out(dict(row))


def cmd_read_blueprint(args):
    """Read a blueprint record (including content).
    Usage: hub.py read-blueprint <id_or_slug>
    """
    if not args:
        print("Usage: hub.py read-blueprint <id_or_slug>")
        sys.exit(1)
    key = args[0]

    conn = get_conn()
    # Try by ID first, then by slug
    if key.isdigit():
        row = conn.execute(
            "SELECT id, type, slug, name, summary, content, step, step_status, "
            "locked_by, dirty, dirty_reason, parent_id, test_level FROM blueprints WHERE id=?",
            (int(key),)
        ).fetchone()
    else:
        row = conn.execute(
            "SELECT id, type, slug, name, summary, content, step, step_status, "
            "locked_by, dirty, dirty_reason, parent_id, test_level FROM blueprints WHERE slug=?",
            (key,)
        ).fetchone()
    if not row:
        print(f"Error: blueprint '{key}' not found")
        sys.exit(1)
    out(dict(row))


def cmd_status(args):
    """Show all blueprints status.
    Usage: hub.py status
    """
    conn = get_conn()
    rows = conn.execute(
        "SELECT id, type, slug, name, step, step_status, locked_by, dirty FROM blueprints ORDER BY "
        "CASE type WHEN 'table' THEN 1 WHEN 'layout' THEN 2 WHEN 'partial' THEN 3 "
        "WHEN 'action' THEN 4 WHEN 'page' THEN 5 WHEN 'test' THEN 6 END, id"
    ).fetchall()
    out([dict(r) for r in rows])


def cmd_view(args):
    """Query a VIEW by name.
    Usage: hub.py view <view_name>
    """
    if not args:
        print("Usage: hub.py view <view_name>")
        sys.exit(1)
    view_name = args[0]
    # Whitelist of allowed views
    allowed = {"app_snapshot", "project_progress", "item_status", "next_actions",
               "attention_needed", "test_coverage", "dependency_map", "task_board"}
    if view_name not in allowed:
        print(f"Error: unknown view '{view_name}'. Allowed: {', '.join(sorted(allowed))}")
        sys.exit(1)

    conn = get_conn()
    rows = conn.execute(f"SELECT * FROM {view_name}").fetchall()
    out([dict(r) for r in rows])


# =========================================
# Main dispatch
# =========================================

COMMANDS = {
    "set-strategy": cmd_set_strategy,
    "set-concept": cmd_set_concept,
    "set-design": cmd_set_design,
    "upsert-core": cmd_upsert_core,
    "upsert-blueprint": cmd_upsert_blueprint,
    "add-dep": cmd_add_dep,
    "approve": cmd_approve,
    "advance": cmd_advance,
    "lock": cmd_lock,
    "review": cmd_review,
    "create-act": cmd_create_act,
    "save-result": cmd_save_result,
    "dirty": cmd_dirty,
    "clear-dirty": cmd_clear_dirty,
    "complete": cmd_complete,
    "read-core": cmd_read_core,
    "read-blueprint": cmd_read_blueprint,
    "status": cmd_status,
    "view": cmd_view,
    "commit": cmd_commit,
    "push": cmd_push,
}

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "help"):
        print("Blueprint-Flow Hub DB Helper")
        print()
        print("Commands:")
        for name, fn in COMMANDS.items():
            doc = (fn.__doc__ or "").strip().split("\n")[0]
            print(f"  {name:20s} {doc}")
        print()
        print("All write commands use parameter binding (no SQL injection risk).")
        print("Commands accepting content read from stdin (pipe markdown in).")
        sys.exit(0)

    cmd = sys.argv[1]
    if cmd not in COMMANDS:
        print(f"Error: unknown command '{cmd}'. Run with --help for usage.")
        sys.exit(1)

    COMMANDS[cmd](sys.argv[2:])


if __name__ == "__main__":
    main()
