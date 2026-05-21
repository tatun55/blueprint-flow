#!/usr/bin/env python3
"""Blueprint-Flow Hub DB Helper (V3)

Safe DB operations with parameter binding.
Hub MUST use this instead of raw sqlite3 commands for all writes.

V3 schema: step_status は (define → impl → test → done) の 4 段。stage は
cores.stage で持つ (proto/mvp/beta/prod/prod_reviewed)。クローン進化 + Review
Scoring Rubric は §9 参照 (BLUEPRINT_FLOW_v3.md)。

Usage:
  python3 blueprint/hub.py <command> [args]

Content input:
  Commands that accept markdown content read from stdin.
"""

import sqlite3
import sys
import json
import os
import subprocess
import urllib.request
import urllib.error

DB_PATH = "blueprint/blueprint.db"

# V3: step_status の進行順序 (4 段)
STATUS_FLOW = ["define", "impl", "test", "done"]

# V3: stage の進行順序 (UX 完成度軸)。prod_reviewed は bpf 終端
STAGE_FLOW = ["proto", "mvp", "beta", "prod", "prod_reviewed"]

# V3: stage → UX 完成度 % (推計用)
STAGE_UX_PCT = {"proto": 25, "mvp": 50, "beta": 75, "prod": 100, "prod_reviewed": 100}

# V3 §9: Review Scoring Rubric — trigger は closed enum
TRIGGER_ENUM = frozenset({
    "F1", "F2", "F3a", "F3b", "F4a", "F4b",
    "F5", "F6", "F7", "F8", "F9", "F10", "F11",
    "default", "cleanup", "mechanical", "uncertain",
})

# V3 §9.7: runner 別 threshold
RUNNER_THRESHOLDS = {"bpf": 75, "night-runner": 95}

# review_decisions.decision_type の許容値
DECISION_TYPES = frozenset({"pre_action", "post_complete", "stage_gate"})


def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.row_factory = sqlite3.Row
    return conn


def next_status(current):
    """Return the next step_status in the V3 flow, or None at terminal."""
    try:
        idx = STATUS_FLOW.index(current)
        if idx + 1 < len(STATUS_FLOW):
            return STATUS_FLOW[idx + 1]
    except ValueError:
        pass
    return None


def out(data):
    """Output JSON result."""
    print(json.dumps(data, ensure_ascii=False, indent=2))


def _parse_kv(args):
    """--key=value 形式を kv dict に、その他は positional list に振り分ける."""
    kv = {}
    pos = []
    for a in args:
        if a.startswith("--") and "=" in a:
            k, v = a[2:].split("=", 1)
            kv[k] = v
        else:
            pos.append(a)
    return kv, pos


def _slack_post(text):
    """Slack へテキスト POST (best-effort, 失敗しても caller に例外を投げない).

    挙動:
      - 環境変数 SLACK_DRY_RUN=1 → 送信せず stderr に出力
      - 環境変数 SLACK_WEBHOOK_URL 未設定 → 送信せず stderr に skip ログ
      - HTTP/network エラー → stderr に出力して False を返す
    """
    if os.environ.get("SLACK_DRY_RUN") == "1":
        print(f"[slack-dry-run] {text}", file=sys.stderr)
        return True
    url = os.environ.get("SLACK_WEBHOOK_URL")
    if not url:
        print(f"[slack-skip] SLACK_WEBHOOK_URL not set: {text}", file=sys.stderr)
        return False
    payload = json.dumps({"text": text}).encode("utf-8")
    req = urllib.request.Request(
        url, data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status == 200
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
        print(f"[slack-error] {e}: {text}", file=sys.stderr)
        return False


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

    content = f"""# プロジェクトコンセプト

## キャッチフレーズ

{catchphrase}

## ターゲット

{target}

## 解決する課題

{problem}

## ソリューション

{solution}

## 提供価値

{value}
"""

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
    """Set project strategy (positioning + WTA avoidance).
    Usage: hub.py set-strategy <axes> <wta_check> <constraints>
    """
    if len(args) < 3:
        print("Usage: hub.py set-strategy <axes> <wta_check> <constraints>")
        sys.exit(1)
    axes, wta_check, constraints = args[0], args[1], args[2]

    content = f"""# 戦略・ポジショニング

## 戦略軸

{axes}

## WTA 回避チェック

{wta_check}

## 制約・前提

{constraints}
"""

    conn = get_conn()
    conn.execute(
        """INSERT INTO cores (type, slug, name, summary, content)
           VALUES ('concept', 'strategy', '戦略・ポジショニング', ?, ?)
           ON CONFLICT(slug) DO UPDATE SET
             summary=excluded.summary, content=excluded.content""",
        (axes[:80], content)
    )
    conn.commit()
    out({"ok": True, "action": "set-strategy"})


def cmd_set_design(args):
    """Set design direction (visual style + interaction).
    Usage: hub.py set-design <visual> <interaction> <typography>
    """
    if len(args) < 3:
        print("Usage: hub.py set-design <visual> <interaction> <typography>")
        sys.exit(1)
    visual, interaction, typography = args[0], args[1], args[2]

    content = f"""# デザイン指針

## ビジュアル

{visual}

## インタラクション

{interaction}

## タイポグラフィ

{typography}
"""

    conn = get_conn()
    conn.execute(
        """INSERT INTO cores (type, slug, name, summary, content)
           VALUES ('design', 'design', 'デザイン指針', ?, ?)
           ON CONFLICT(slug) DO UPDATE SET
             summary=excluded.summary, content=excluded.content""",
        (visual[:80], content)
    )
    conn.commit()
    out({"ok": True, "action": "set-design"})


# =========================================
# Blueprint operations
# =========================================

def cmd_upsert_blueprint(args):
    """Upsert a blueprint (current stage). Content from stdin.
    Usage: ... | hub.py upsert-blueprint <type> <slug> <name> <summary>

    V3: stage は cores.stage (overview) から自動取得。クローン進化は
    'bpf stage advance' / 'hub.py stage advance' 側で実施。
    """
    if len(args) < 4:
        print("Usage: ... | hub.py upsert-blueprint <type> <slug> <name> <summary>")
        sys.exit(1)
    bp_type, slug, name, summary = args[0], args[1], args[2], args[3]
    content = sys.stdin.read() if not sys.stdin.isatty() else ""
    if not content:
        print("Error: content required via stdin")
        sys.exit(1)

    conn = get_conn()

    # 現 stage を cores.overview から取得
    overview = conn.execute(
        "SELECT stage FROM cores WHERE type='overview' LIMIT 1"
    ).fetchone()
    if not overview:
        print("Error: no 'overview' core found. Run 'bpf init' first.")
        sys.exit(1)
    stage = overview["stage"]
    if stage == "prod_reviewed":
        print("Error: project at prod_reviewed (bpf scope ended). Cannot add blueprints.")
        sys.exit(1)

    conn.execute(
        """INSERT INTO blueprints (type, slug, name, summary, content, stage, frozen)
           VALUES (?, ?, ?, ?, ?, ?, 0)
           ON CONFLICT(type, stage, slug, frozen) DO UPDATE SET
             name=excluded.name, summary=excluded.summary,
             content=excluded.content""",
        (bp_type, slug, name, summary, content, stage)
    )
    conn.commit()
    row = conn.execute(
        "SELECT id FROM blueprints WHERE type=? AND stage=? AND slug=? AND frozen=0",
        (bp_type, stage, slug)
    ).fetchone()
    out({"ok": True, "action": "upsert-blueprint",
         "id": row["id"], "type": bp_type, "slug": slug, "stage": stage})


def cmd_add_dep(args):
    """Add dependency between blueprints.
    Usage: hub.py add-dep <source_id> <target_id> [dep_gate] [detail]
    dep_gate: V3 値 ('define', 'impl', 'test', 'done')  default 'done'
    """
    if len(args) < 2:
        print("Usage: hub.py add-dep <source_id> <target_id> [dep_gate] [detail]")
        sys.exit(1)
    source_id, target_id = int(args[0]), int(args[1])
    dep_gate = args[2] if len(args) > 2 and args[2] else "done"
    detail = args[3] if len(args) > 3 else None

    if dep_gate not in STATUS_FLOW:
        print(f"Error: invalid dep_gate '{dep_gate}'. Valid: {', '.join(STATUS_FLOW)}")
        sys.exit(1)

    conn = get_conn()
    conn.execute(
        "INSERT INTO dependencies (source_id, target_id, dep_gate, detail) VALUES (?, ?, ?, ?)"
        " ON CONFLICT(source_id, target_id) DO UPDATE SET dep_gate=excluded.dep_gate, detail=excluded.detail",
        (source_id, target_id, dep_gate, detail)
    )
    conn.commit()
    out({"ok": True, "action": "add-dep",
         "source_id": source_id, "target_id": target_id, "dep_gate": dep_gate})


# =========================================
# Step status transitions
# =========================================

def cmd_advance(args):
    """Advance blueprint to next step_status (define → impl → test → done).
    Usage: hub.py advance <id> [id2] ...
    """
    if not args:
        print("Usage: hub.py advance <id> [id2] ...")
        sys.exit(1)

    conn = get_conn()
    results = []
    for bp_id in [int(a) for a in args]:
        row = conn.execute(
            "SELECT id, type, slug, step_status FROM blueprints WHERE id=? AND frozen=0",
            (bp_id,)
        ).fetchone()
        if not row:
            results.append({"id": bp_id, "error": "not found or frozen"})
            continue
        ns = next_status(row["step_status"])
        if not ns:
            results.append({"id": bp_id, "error": f"already at terminal '{row['step_status']}'"})
            continue
        conn.execute(
            "UPDATE blueprints SET step_status=?, locked_by=NULL WHERE id=?",
            (ns, bp_id)
        )
        results.append({"id": bp_id, "from": row["step_status"], "to": ns})
    conn.commit()
    out({"ok": True, "action": "advance", "results": results})


def cmd_lock(args):
    """Lock blueprint for work: set locked_by (step_status は変更しない).
    Usage: hub.py lock <id> [locked_by]
    """
    if not args:
        print("Usage: hub.py lock <id> [locked_by]")
        sys.exit(1)
    bp_id = int(args[0])
    locked_by = args[1] if len(args) > 1 else "coding"

    conn = get_conn()
    conn.execute(
        "UPDATE blueprints SET locked_by=? WHERE id=? AND frozen=0",
        (locked_by, bp_id)
    )
    conn.commit()
    out({"ok": True, "action": "lock", "id": bp_id, "locked_by": locked_by})


def cmd_unlock(args):
    """Unlock blueprint: clear locked_by.
    Usage: hub.py unlock <id>
    """
    if not args:
        print("Usage: hub.py unlock <id>")
        sys.exit(1)
    bp_id = int(args[0])

    conn = get_conn()
    conn.execute("UPDATE blueprints SET locked_by=NULL WHERE id=?", (bp_id,))
    conn.commit()
    out({"ok": True, "action": "unlock", "id": bp_id})


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
    """Mark blueprint as dirty and reset step_status to 'define'.
    Usage: hub.py dirty <id> <reason>
    """
    if len(args) < 2:
        print("Usage: hub.py dirty <id> <reason>")
        sys.exit(1)
    bp_id, reason = int(args[0]), args[1]

    conn = get_conn()
    conn.execute(
        "UPDATE blueprints SET dirty=1, dirty_reason=?, step_status='define', locked_by=NULL WHERE id=?",
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
    """Complete current step_status: advance one step, commit, unlock.
    Usage: hub.py complete <id> [--runner=bpf|night-runner]

    V3: define → impl → test → done と1段進める。git commit も同時実施。
    ns='done' に達した時点で `_stage_progress` (test 除く) が全 done なら
    cores.stage_dirty を 0→1 にセット、Slack 通知、F2 を review_decisions に記録。
    --runner は stage_dirty 自動発火を記録する際の runner 列に入る (default: bpf)。
    """
    kv, pos = _parse_kv(args)
    if not pos:
        print("Usage: hub.py complete <id> [--runner=bpf|night-runner]")
        sys.exit(1)
    bp_id = int(pos[0])
    runner = kv.get("runner", "bpf")
    if runner not in RUNNER_THRESHOLDS:
        print(f"Error: --runner must be one of {sorted(RUNNER_THRESHOLDS)} "
              f"(got {runner!r})")
        sys.exit(1)

    conn = get_conn()
    row = conn.execute(
        "SELECT id, type, slug, name, step_status, stage FROM blueprints WHERE id=? AND frozen=0",
        (bp_id,)
    ).fetchone()
    if not row:
        print(f"Error: blueprint {bp_id} not found or frozen")
        sys.exit(1)

    current = row["step_status"]
    ns = next_status(current)
    steps_done = []

    if ns is None:
        out({"ok": False, "action": "complete", "id": bp_id,
             "error": f"already at terminal step_status '{current}'"})
        sys.exit(1)

    # 1段進める
    conn.execute(
        "UPDATE blueprints SET step_status=?, locked_by=NULL WHERE id=?",
        (ns, bp_id)
    )
    conn.commit()
    steps_done.append(f"advance({current}→{ns})")

    # stage_dirty 検知 (§5.4): ns='done' でかつ現 stage の active impl 全 done なら発火
    stage_dirty_fired = False
    ov = _get_overview(conn)
    if ns == "done" and ov and not ov["stage_dirty"]:
        done, total = _stage_progress(conn, ov["stage"])
        if total > 0 and done == total:
            conn.execute(
                "UPDATE cores SET stage_dirty=1 WHERE id=?",
                (ov["id"],)
            )
            # F2 Gate を自動記録 (score=100、threshold 無視で ask)
            _record_review_decision(
                conn,
                act_id=None, blueprint_id=bp_id,
                runner=runner, decision_type="stage_gate",
                trigger="F2", mode="G",
                score=100, threshold=RUNNER_THRESHOLDS[runner],
                asked_human=1, outcome="blocked",
                reason=f"stage_dirty auto-set: stage '{ov['stage']}' active impl 全 done",
                raw_emit=None,
            )
            conn.commit()
            stage_dirty_fired = True
            ux_pct = STAGE_UX_PCT.get(ov["stage"], 0)
            _slack_post(
                f":dart: stage `{ov['stage']}` 完了 (UX {ux_pct}% 達成見込み) "
                f"— `bpf stage review` で確認の上 `bpf stage advance`"
            )
            steps_done.append("stage_dirty=1")

    # git commit
    subprocess.run(["git", "add", "-A"], check=True, capture_output=True)
    diff_result = subprocess.run(["git", "diff", "--cached", "--quiet"])
    if diff_result.returncode != 0:
        msg = (f"feat({row['type']}/{row['slug']}): {current}→{ns} "
               f"({row['stage']})\n\nBlueprint: #{row['id']} {row['name']}")
        subprocess.run(["git", "commit", "-m", msg], check=True, capture_output=True)
        steps_done.append("commit")
    else:
        steps_done.append("commit(skipped)")

    result = {"ok": True, "action": "complete", "id": bp_id,
              "type": row["type"], "slug": row["slug"],
              "stage": row["stage"], "step_status": ns, "steps": steps_done}
    if stage_dirty_fired:
        result["stage_dirty_fired"] = True
    out(result)


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
        "SELECT id, type, slug, name, step_status, stage FROM blueprints WHERE id=?",
        (bp_id,)
    ).fetchone()
    if not row:
        print(f"Error: blueprint {bp_id} not found")
        sys.exit(1)

    subprocess.run(["git", "add", "-A"], check=True, capture_output=True)

    result = subprocess.run(["git", "diff", "--cached", "--quiet"])
    if result.returncode == 0:
        out({"ok": True, "action": "commit", "id": bp_id, "skipped": True, "reason": "no staged changes"})
        return

    msg = (f"feat({row['type']}/{row['slug']}): {row['step_status']} ({row['stage']})\n\n"
           f"Blueprint: #{row['id']} {row['name']}")
    subprocess.run(["git", "commit", "-m", msg], check=True, capture_output=True)
    out({"ok": True, "action": "commit", "id": bp_id,
         "type": row["type"], "slug": row["slug"], "step_status": row["step_status"]})


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
        "SELECT id, type, slug, name, summary, content, reviewed, stage, stage_dirty FROM cores WHERE slug=?",
        (slug,)
    ).fetchone()
    if not row:
        print(f"Error: core '{slug}' not found")
        sys.exit(1)
    out(dict(row))


def cmd_read_blueprint(args):
    """Read a blueprint record (including content).
    Usage: hub.py read-blueprint <id_or_slug> [--include-frozen]

    Default: 現 stage の frozen=0 行のみを検索。--include-frozen で全 stage 検索。
    """
    if not args:
        print("Usage: hub.py read-blueprint <id_or_slug> [--include-frozen]")
        sys.exit(1)
    key = args[0]
    include_frozen = "--include-frozen" in args[1:]

    conn = get_conn()
    cols = ("id, type, slug, name, summary, content, step_status, "
            "stage, parent_blueprint_id, frozen, locked_by, dirty, dirty_reason")

    if include_frozen:
        # ID 指定なら全 stage、slug 指定なら active のみ (slug は stage 間で重複しうる)
        if key.isdigit():
            row = conn.execute(
                f"SELECT {cols} FROM blueprints WHERE id=?", (int(key),)
            ).fetchone()
        else:
            row = conn.execute(
                f"SELECT {cols} FROM active_blueprints WHERE slug=?", (key,)
            ).fetchone()
    else:
        if key.isdigit():
            row = conn.execute(
                f"SELECT {cols} FROM active_blueprints WHERE id=?", (int(key),)
            ).fetchone()
        else:
            row = conn.execute(
                f"SELECT {cols} FROM active_blueprints WHERE slug=?", (key,)
            ).fetchone()

    if not row:
        print(f"Error: blueprint '{key}' not found")
        sys.exit(1)
    out(dict(row))


def cmd_status(args):
    """Show active blueprints status (current stage, frozen=0).
    Usage: hub.py status
    """
    conn = get_conn()
    rows = conn.execute(
        "SELECT id, type, slug, name, step_status, stage, locked_by, dirty "
        "FROM active_blueprints ORDER BY "
        "CASE type WHEN 'table' THEN 1 WHEN 'layout' THEN 2 WHEN 'partial' THEN 3 "
        "WHEN 'action' THEN 4 WHEN 'page' THEN 5 WHEN 'test' THEN 6 END, id"
    ).fetchall()
    out([dict(r) for r in rows])


# =========================================
# Stage operations (V3)
# =========================================

def _get_overview(conn):
    """現 overview core を取得 (1 件想定)."""
    return conn.execute(
        "SELECT id, stage, stage_dirty FROM cores WHERE type='overview' LIMIT 1"
    ).fetchone()


def _next_stage(current):
    """次 stage を返す。終端なら None."""
    try:
        idx = STAGE_FLOW.index(current)
        if idx + 1 < len(STAGE_FLOW):
            return STAGE_FLOW[idx + 1]
    except ValueError:
        pass
    return None


def _stage_progress(conn, stage):
    """指定 stage の active blueprint (test 除く) の (done, total) を返す."""
    row = conn.execute(
        "SELECT SUM(step_status='done') AS done, COUNT(*) AS total "
        "FROM blueprints WHERE stage=? AND frozen=0 AND type!='test'",
        (stage,)
    ).fetchone()
    done = row["done"] or 0
    total = row["total"] or 0
    return done, total


def cmd_stage(args):
    """Stage コマンド群 (V3).
    Usage:
      hub.py stage                  現 stage と UX% を表示
      hub.py stage status           各 step_status の集計 + done/total + UX 進捗
      hub.py stage review           現 stage の全 active blueprint 一覧 (人間レビュー用)
      hub.py stage advance          次 stage へクローン進化
    """
    sub = args[0] if args else None
    conn = get_conn()
    ov = _get_overview(conn)
    if not ov:
        print("Error: no 'overview' core found. Run 'bpf init' first.")
        sys.exit(1)

    if sub is None:
        # 現 stage 表示
        done, total = _stage_progress(conn, ov["stage"])
        out({
            "ok": True, "action": "stage",
            "stage": ov["stage"],
            "ux_pct_target": STAGE_UX_PCT.get(ov["stage"]),
            "blueprints_done": done, "blueprints_total": total,
            "stage_dirty": bool(ov["stage_dirty"]),
        })
        return

    if sub == "status":
        # project_progress + done/total + UX 推計
        rows = conn.execute(
            "SELECT step_status, COUNT(*) AS total, SUM(step_status='done') AS done "
            "FROM active_blueprints WHERE type!='test' GROUP BY step_status"
        ).fetchall()
        done, total = _stage_progress(conn, ov["stage"])
        ux_est = (done / total * STAGE_UX_PCT.get(ov["stage"], 0)) if total else 0
        out({
            "ok": True, "action": "stage-status",
            "stage": ov["stage"],
            "ux_pct_target": STAGE_UX_PCT.get(ov["stage"]),
            "ux_pct_estimated": round(ux_est, 1),
            "blueprints_done": done, "blueprints_total": total,
            "stage_dirty": bool(ov["stage_dirty"]),
            "by_status": [dict(r) for r in rows],
        })
        return

    if sub == "review":
        # 現 stage の active blueprint 一覧 (人間レビュー用、対話 UI は別途)
        rows = conn.execute(
            "SELECT id, type, slug, name, summary, step_status, dirty, dirty_reason "
            "FROM active_blueprints ORDER BY type, id"
        ).fetchall()
        done, total = _stage_progress(conn, ov["stage"])
        out({
            "ok": True, "action": "stage-review",
            "stage": ov["stage"],
            "blueprints_done": done, "blueprints_total": total,
            "stage_dirty": bool(ov["stage_dirty"]),
            "blueprints": [dict(r) for r in rows],
            "hint": "approve all with `bpf stage advance` once reviewed",
        })
        return

    if sub == "advance":
        _stage_advance(conn, ov)
        return

    print(f"Error: unknown stage subcommand '{sub}'. "
          f"Use: stage [status|review|advance]")
    sys.exit(1)


def _stage_advance(conn, ov):
    """クローン進化: 現 stage を frozen=1、次 stage 用に全 active blueprint を
    クローン (parent_blueprint_id で履歴 link)、dependencies も id マップで再構築、
    cores.stage を更新、stage_transitions に記録."""
    current = ov["stage"]
    ns = _next_stage(current)
    if ns is None:
        out({"ok": False, "action": "stage-advance",
             "error": f"already at terminal stage '{current}'"})
        sys.exit(1)

    # prod_reviewed (bpf 終端) はクローン不要、cores.stage 更新と記録のみ
    if ns == "prod_reviewed":
        with conn:
            # 現 stage の active blueprint をすべて frozen に
            conn.execute(
                "UPDATE blueprints SET frozen=1 WHERE stage=? AND frozen=0",
                (current,)
            )
            conn.execute(
                "UPDATE cores SET stage=?, stage_dirty=0 WHERE id=?",
                (ns, ov["id"])
            )
            conn.execute(
                "INSERT INTO stage_transitions (core_id, from_stage, to_stage, notes) "
                "VALUES (?, ?, ?, ?)",
                (ov["id"], current, ns, "bpf scope end (no clone)")
            )
        out({"ok": True, "action": "stage-advance",
             "from": current, "to": ns,
             "cloned_blueprints": 0, "cloned_dependencies": 0,
             "note": "bpf scope ended (prod_reviewed)"})
        return

    with conn:
        # 1. 現 stage の active blueprint を全部取得 (test 含む)
        active = conn.execute(
            "SELECT id, type, slug, name, summary, content "
            "FROM blueprints WHERE stage=? AND frozen=0",
            (current,)
        ).fetchall()

        # 2. 旧 blueprint を frozen=1 に
        conn.execute(
            "UPDATE blueprints SET frozen=1 WHERE stage=? AND frozen=0",
            (current,)
        )

        # 3. 次 stage 用にクローン (step_status='define'、parent_blueprint_id で履歴 link)
        id_map = {}
        for bp in active:
            cur = conn.execute(
                "INSERT INTO blueprints "
                "(type, slug, name, summary, content, step_status, stage, "
                " parent_blueprint_id, frozen) "
                "VALUES (?, ?, ?, ?, ?, 'define', ?, ?, 0)",
                (bp["type"], bp["slug"], bp["name"], bp["summary"], bp["content"],
                 ns, bp["id"])
            )
            id_map[bp["id"]] = cur.lastrowid

        # 4. dependencies を新 id ペアで再構築 (両端が新 stage に存在する場合のみ)
        old_ids = tuple(id_map.keys())
        cloned_deps = 0
        if old_ids:
            placeholder = ",".join("?" * len(old_ids))
            deps = conn.execute(
                f"SELECT source_id, target_id, dep_gate, detail FROM dependencies "
                f"WHERE source_id IN ({placeholder}) AND target_id IN ({placeholder})",
                old_ids + old_ids
            ).fetchall()
            for d in deps:
                conn.execute(
                    "INSERT OR IGNORE INTO dependencies "
                    "(source_id, target_id, dep_gate, detail) VALUES (?, ?, ?, ?)",
                    (id_map[d["source_id"]], id_map[d["target_id"]],
                     d["dep_gate"], d["detail"])
                )
                cloned_deps += 1

        # 5. cores.stage を更新、dirty クリア
        conn.execute(
            "UPDATE cores SET stage=?, stage_dirty=0 WHERE id=?",
            (ns, ov["id"])
        )

        # 6. stage_transitions に記録
        conn.execute(
            "INSERT INTO stage_transitions (core_id, from_stage, to_stage, notes) "
            "VALUES (?, ?, ?, ?)",
            (ov["id"], current, ns,
             f"cloned {len(active)} blueprints + {cloned_deps} deps")
        )

    out({"ok": True, "action": "stage-advance",
         "from": current, "to": ns,
         "ux_pct_target": STAGE_UX_PCT[ns],
         "cloned_blueprints": len(active),
         "cloned_dependencies": cloned_deps})


# =========================================
# Review operations (V3 §9 Review Scoring Rubric)
# =========================================

def _record_review_decision(conn, act_id, blueprint_id, runner, decision_type,
                            trigger, mode, score, threshold, asked_human,
                            outcome, reason, raw_emit):
    """review_decisions に 1 行 INSERT (commit は caller 側)."""
    conn.execute(
        "INSERT INTO review_decisions "
        "(act_id, blueprint_id, runner, decision_type, trigger, mode, "
        " score, threshold, asked_human, outcome, reason, raw_emit) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (act_id, blueprint_id, runner, decision_type, trigger, mode,
         score, threshold, asked_human, outcome, reason, raw_emit)
    )


def _decide_outcome(runner, score):
    """§9.7 threshold gate → (outcome, should_record, asked_human).

    bpf: score>=75 → blocked (ask), 30<=score<75 → approved (silent), <30 → 記録省略
    night-runner: >=95 → blocked (alert), 75<=score<95 → queued (dirty queue),
                  30<=score<75 → approved, <30 → 記録省略
    """
    threshold = RUNNER_THRESHOLDS[runner]
    if runner == "bpf":
        if score >= threshold:
            return "blocked", True, 1
        if score >= 30:
            return "approved", True, 0
        return "approved", False, 0
    if runner == "night-runner":
        if score >= threshold:
            return "blocked", True, 1
        if score >= 75:
            return "queued", True, 0
        if score >= 30:
            return "approved", True, 0
        return "approved", False, 0
    raise ValueError(f"unknown runner: {runner}")


def cmd_review(args):
    """Review コマンド群 (Review Scoring Rubric §9).
    Usage:
      hub.py review queue [--runner=night-runner] [--limit=N]
                                         dirty queue (outcome='queued') 一覧
      hub.py review log [--limit=N] [--act=ID] [--blueprint=ID] [--runner=R]
                                         最近の判定ログ
      hub.py review record-decision --runner={bpf|night-runner}
                                    [--act=ID] [--blueprint=ID]
                                    [--type=pre_action|post_complete|stage_gate]
                                         stdin の JSON (§9.6) を読んで判定・記録
    """
    sub = args[0] if args else None
    if sub == "queue":
        return _cmd_review_queue(args[1:])
    if sub == "log":
        return _cmd_review_log(args[1:])
    if sub == "record-decision":
        return _cmd_review_record(args[1:])
    print("Usage: hub.py review {queue|log|record-decision} [opts]")
    sys.exit(1)


def _cmd_review_queue(args):
    kv, _ = _parse_kv(args)
    runner = kv.get("runner", "night-runner")
    limit = int(kv.get("limit", "50"))
    conn = get_conn()
    rows = conn.execute(
        "SELECT id, act_id, blueprint_id, runner, decision_type, trigger, "
        "mode, score, threshold, outcome, reason, created_at "
        "FROM review_decisions WHERE outcome='queued' AND runner=? "
        "ORDER BY created_at DESC LIMIT ?",
        (runner, limit)
    ).fetchall()
    out({"ok": True, "action": "review-queue", "runner": runner,
         "count": len(rows), "decisions": [dict(r) for r in rows]})


def _cmd_review_log(args):
    kv, _ = _parse_kv(args)
    limit = int(kv.get("limit", "20"))
    where, params = [], []
    if "act" in kv:
        where.append("act_id=?")
        params.append(int(kv["act"]))
    if "blueprint" in kv:
        where.append("blueprint_id=?")
        params.append(int(kv["blueprint"]))
    if "runner" in kv:
        where.append("runner=?")
        params.append(kv["runner"])
    where_sql = (" WHERE " + " AND ".join(where)) if where else ""
    params.append(limit)
    conn = get_conn()
    rows = conn.execute(
        "SELECT id, act_id, blueprint_id, runner, decision_type, trigger, "
        "mode, score, threshold, asked_human, outcome, reason, created_at "
        "FROM review_decisions" + where_sql +
        " ORDER BY created_at DESC LIMIT ?",
        tuple(params)
    ).fetchall()
    out({"ok": True, "action": "review-log",
         "count": len(rows), "decisions": [dict(r) for r in rows]})


def _cmd_review_record(args):
    kv, _ = _parse_kv(args)
    runner = kv.get("runner")
    if runner not in RUNNER_THRESHOLDS:
        print(f"Error: --runner={{bpf|night-runner}} required (got: {runner!r})")
        sys.exit(1)
    act_id = int(kv["act"]) if "act" in kv else None
    blueprint_id = int(kv["blueprint"]) if "blueprint" in kv else None
    decision_type = kv.get("type", "pre_action")
    if decision_type not in DECISION_TYPES:
        print(f"Error: --type must be one of {sorted(DECISION_TYPES)} "
              f"(got {decision_type!r})")
        sys.exit(1)

    raw = sys.stdin.read()
    try:
        emit = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON on stdin: {e}")
        sys.exit(1)

    # §9.6 必須フィールド
    for field in ("score", "trigger", "mode", "decision", "reason"):
        if field not in emit:
            print(f"Error: missing required field '{field}' in emit")
            sys.exit(1)

    if not isinstance(emit["score"], int) or not (0 <= emit["score"] <= 100):
        print(f"Error: score must be int 0-100 (got {emit['score']!r})")
        sys.exit(1)
    if emit["trigger"] not in TRIGGER_ENUM:
        print(f"Error: trigger must be one of {sorted(TRIGGER_ENUM)} "
              f"(got {emit['trigger']!r})")
        sys.exit(1)

    score = emit["score"]
    trigger = emit["trigger"]
    mode = emit.get("mode") or ""
    reason = emit.get("reason") or ""

    outcome, should_record, asked_human = _decide_outcome(runner, score)
    threshold = RUNNER_THRESHOLDS[runner]

    conn = get_conn()
    if should_record:
        with conn:
            _record_review_decision(
                conn, act_id, blueprint_id, runner, decision_type,
                trigger, mode, score, threshold, asked_human,
                outcome, reason, raw
            )

    # night-runner block → Slack alert (§9.7)
    if runner == "night-runner" and outcome == "blocked":
        also = emit.get("also_fired") or []
        also_str = f" also_fired={also}" if also else ""
        _slack_post(
            f":octagonal_sign: night-runner block: score={score} "
            f"trigger={trigger}{also_str} mode={mode} — {reason[:200]}"
        )

    out({"ok": True, "action": "review-record",
         "runner": runner, "score": score, "threshold": threshold,
         "trigger": trigger, "mode": mode, "outcome": outcome,
         "asked_human": bool(asked_human), "recorded": should_record})


def cmd_view(args):
    """Query a VIEW by name.
    Usage: hub.py view <view_name>
    """
    if not args:
        print("Usage: hub.py view <view_name>")
        sys.exit(1)
    view_name = args[0]
    # V3 whitelist (test_coverage は削除、active_blueprints を追加)
    allowed = {"active_blueprints", "app_snapshot", "project_progress", "item_status",
               "next_actions", "attention_needed", "dependency_map", "task_board"}
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
    "set-strategy":     cmd_set_strategy,
    "set-concept":      cmd_set_concept,
    "set-design":       cmd_set_design,
    "upsert-core":      cmd_upsert_core,
    "upsert-blueprint": cmd_upsert_blueprint,
    "add-dep":          cmd_add_dep,
    "advance":          cmd_advance,
    "lock":             cmd_lock,
    "unlock":           cmd_unlock,
    "create-act":       cmd_create_act,
    "save-result":      cmd_save_result,
    "dirty":            cmd_dirty,
    "clear-dirty":      cmd_clear_dirty,
    "complete":         cmd_complete,
    "read-core":        cmd_read_core,
    "read-blueprint":   cmd_read_blueprint,
    "status":           cmd_status,
    "view":             cmd_view,
    "commit":           cmd_commit,
    "push":             cmd_push,
    "stage":            cmd_stage,
    "review":           cmd_review,
}

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "help"):
        print("Blueprint-Flow Hub DB Helper (V3)")
        print()
        print("Commands:")
        for name, fn in COMMANDS.items():
            doc = (fn.__doc__ or "").strip().split("\n")[0]
            print(f"  {name:20s} {doc}")
        print()
        print("V3 schema: step_status (define → impl → test → done) + cores.stage")
        print("All write commands use parameter binding (no SQL injection risk).")
        sys.exit(0)

    cmd = sys.argv[1]
    if cmd not in COMMANDS:
        print(f"Error: unknown command '{cmd}'. Run with --help for usage.")
        sys.exit(1)

    COMMANDS[cmd](sys.argv[2:])


if __name__ == "__main__":
    main()
