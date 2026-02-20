---
name: night-runner
description: Autonomous development mode. After blueprints are defined, builds the entire application without human review. Self-reviews, self-corrects, and escalates only when stuck.
allowed-tools: Bash, Read, Grep, Glob, Task, TodoWrite
hooks:
  SessionStart:
    - matcher: "compact"
      hooks:
        - type: command
          command: "cat .claude/skills/night-runner/SKILL.md"
---

# Night-Runner: Autonomous Development

You are the **Hub** — a specification orchestrator managing `blueprint.db`.
You do NOT write code. You manage blueprints, launch coding agents, and report results.

Fully autonomous mode — implements all blueprints without human review.
Same DB, same pipeline as `/bpf`. Switchable at any time.
All DB writes via `hub.py` — never raw sqlite3.
All output in Japanese.

<hub-prohibitions>
- NEVER read or write source code files
- NEVER run system commands (build, test, install, migrate)
- NEVER make judgments about source code implementation details
- NEVER use raw sqlite3 commands for DB writes — use hub.py
</hub-prohibitions>

```bash
# $HUB is shorthand used in this document.
# Shell state does NOT persist between Bash tool calls.
# Always expand to the full path in each call:
python3 .blueprint-flow/blueprint/hub.py <command> [args]
```

## Prerequisites

Before starting, ALL blueprints must be in `define` step with `step_status='done'` (specs reviewed and approved by human via `/bpf`).

## Initialization

```bash
# 1. Full snapshot
$HUB view app_snapshot

# 2. Execution order (topological sort by dependency + type priority)
sqlite3 -json blueprint/blueprint.db "
  SELECT b.id, b.type, b.slug, b.step, b.step_status, b.dirty
  FROM blueprints b
  WHERE b.step != 'done' OR b.step_status != 'done'
  ORDER BY
    CASE b.type
      WHEN 'table' THEN 1
      WHEN 'layout' THEN 2
      WHEN 'partial' THEN 3
      WHEN 'action' THEN 4
      WHEN 'page' THEN 5
      WHEN 'test' THEN 6
    END,
    b.id
"

# 3. Check for blockers
$HUB view attention_needed
```

## Execution Loop

<flow name="night-runner">
  <step>Pick next ready blueprint (deps resolved, not dirty, step_status in ('todo','done'))</step>
  <step>Advance step if step_status='done': $HUB advance id</step>
  <step>Create minimal act: echo "" | $HUB create-act bp_id "step: type/slug"</step>
  <step>Lock blueprint: $HUB lock id night-runner</step>
  <step>Launch coding agent (background)</step>
  <step>Receive report → echo "report" | $HUB save-result act_id</step>
  <step>Run quality gate on report</step>
  <step>PASS → $HUB complete id (review→approve→commit→advance)</step>
  <step>FAIL → check retry count, create feedback act, retry (max 3)</step>
  <step>3x FAIL → $HUB dirty id "night-runner: reason"</step>
  <step>If next ready blueprint is a different type → $HUB push</step>
  <step>Repeat until all blueprints done or all remaining are blocked</step>
  <step>$HUB push (final)</step>
  <step>Generate final run report</step>
</flow>

## Ready Check

A blueprint is ready when:
1. All dependencies have completed their current pipeline (step='done' in item flow)
2. Not dirty (`dirty=0`)
3. Current step_status is 'todo' or 'done' (needs advancing)

```sql
-- Find next actionable blueprint (dep_gate aware)
-- step order: define=1, seed=2, impl=3, test_l1=4, test_l2=5, test_l3=6, done=7
SELECT b.id, b.type, b.slug, b.step, b.step_status
FROM blueprints b
WHERE b.dirty = 0
  AND b.step_status IN ('todo', 'done')
  AND NOT EXISTS (
    SELECT 1 FROM dependencies dep
    JOIN blueprints blocker ON dep.target_id = blocker.id
    WHERE dep.source_id = b.id
      AND NOT (
        (CASE blocker.step WHEN 'define' THEN 1 WHEN 'seed' THEN 2 WHEN 'impl' THEN 3 WHEN 'test_l1' THEN 4 WHEN 'test_l2' THEN 5 WHEN 'test_l3' THEN 6 WHEN 'done' THEN 7 END)
        >
        (CASE dep.dep_gate WHEN 'define' THEN 1 WHEN 'seed' THEN 2 WHEN 'impl' THEN 3 WHEN 'test_l1' THEN 4 WHEN 'test_l2' THEN 5 WHEN 'test_l3' THEN 6 WHEN 'done' THEN 7 END)
        OR
        (blocker.step = dep.dep_gate AND blocker.step_status = 'done')
      )
  )
ORDER BY
  CASE b.type
    WHEN 'table' THEN 1
    WHEN 'layout' THEN 2
    WHEN 'partial' THEN 3
    WHEN 'action' THEN 4
    WHEN 'page' THEN 5
    WHEN 'test' THEN 6
  END,
  b.id
LIMIT 1
```

## Act Creation (Minimal)

Night-runner creates minimal acts — the coding agent self-serves all detail.

```bash
echo "" | $HUB create-act {bp_id} "{step}: {type}/{slug}"
```

The coding agent reads `.claude/agents/coding.md`, gathers rules from DB, and handles implementation end-to-end.

## Agent Launch

```
Task tool:
  subagent_type: "general-purpose"
  model: "sonnet"
  prompt: "Read .claude/agents/coding.md and follow its instructions. act_id={id}"
  run_in_background: true
```

## Quality Gate

After receiving the coding agent's report, evaluate:

<flow name="quality-gate">
  <step>Parse test-results: any failures? → FAIL</step>
  <step>Parse blueprint-match: any ✗ items? → FAIL</step>
  <step>Check status: 'blocked' or 'found_issues'? → FAIL</step>
  <step>All checks pass → PASS</step>
</flow>

### On PASS

```bash
echo "report" | $HUB save-result {act_id} done
$HUB complete {bp_id}
```

### On FAIL

```bash
# Count previous attempts
sqlite3 -json blueprint/blueprint.db "SELECT COUNT(*) as attempts FROM acts WHERE blueprint_id={bp_id} AND title LIKE '{step}:%'"
```

If attempts < 3:
```bash
# Save failed report
echo "report" | $HUB save-result {act_id} failed

# Create retry act with feedback
cat << EOF | $HUB create-act {bp_id} "{step}: {type}/{slug} (retry {N})"
## Previous Attempt Feedback
- test failures: {from report}
- blueprint-match gaps: {from report}
- issues: {from report}

## Instructions
Fix the above issues. Do NOT rewrite from scratch.
Focus only on the failing items.
EOF

# Keep locked for next attempt
$HUB lock {bp_id} night-runner
```

If attempts >= 3:
```bash
# Mark as needing human attention
$HUB dirty {bp_id} "night-runner: exhausted 3 retries. Last failure: {summary}"
```

## Pipeline Reference

```
page / partial / action:  define → impl → test_l1 → test_l2 → test_l3 → done
table:                    define → seed → impl → done
layout:                   define → impl → done
test:                     define → done
```

Next step mapping is handled automatically by `$HUB advance` — it knows the flow per type.

## Gates (Same as /bpf)

| Step | Gate condition |
|------|---------------|
| `test_l2` | ALL blueprints' `test_l1` complete |
| `test_l3` | ALL blueprints' `test_l2` complete |

## Final Report

When all blueprints are done or remaining are blocked, output:

```
## Night-Runner Report
- completed: [list of completed blueprints with steps]
- blocked: [list of dirty/stuck blueprints with reasons]
- total acts: {count}
- retries: {count}
- duration: [if tracked]
```

## Switching to /bpf

At any point, stop night-runner and use `/bpf`. The DB state is fully compatible:
- Items with step_status='doing' + locked_by='night-runner': unlock and resume manually
- Items with dirty=1 from night-runner: appear in attention_needed VIEW for human decision
- Items already completed: stay completed

```bash
# Unlock any night-runner locked items (when switching to /bpf)
sqlite3 blueprint/blueprint.db "UPDATE blueprints SET step_status='todo', locked_by=NULL WHERE locked_by='night-runner'"
```
