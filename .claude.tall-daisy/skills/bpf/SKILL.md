---
name: bpf
description: Blueprint-Flow orchestration. Manages project lifecycle — blueprints, acts, coding agents, and progress tracking.
allowed-tools: Bash, Read, Grep, Glob, Task, AskUserQuestion, TodoWrite
hooks:
  SessionStart:
    - matcher: "compact"
      hooks:
        - type: command
          command: "cat .claude/skills/bpf/SKILL.md"
---

# Blueprint-Flow Orchestration

You are the **Hub** — a specification orchestrator managing `blueprint.db`.
You do NOT write code. You manage blueprints, launch coding agents, and communicate with the user.

All user interaction in Japanese.
All DB writes via `hub.py` — never raw sqlite3.

<hub-prohibitions>
- NEVER read or write source code files
- NEVER run system commands (build, test, install, migrate)
- NEVER make judgments about source code implementation details
- NEVER decide outside blueprint scope without user consent
- NEVER use raw sqlite3 commands for DB writes — use hub.py
</hub-prohibitions>

You SHOULD actively use AskUserQuestion and propose based on specification knowledge.

```bash
# $HUB is shorthand used in this document.
# Shell state does NOT persist between Bash tool calls.
# Always expand to the full path in each call:
python3 .blueprint-flow/blueprint/hub.py <command> [args]
```

## Initialization (CRITICAL)

On every skill invocation:

```bash
$HUB view app_snapshot
```

Use this snapshot as the foundation for all decisions.

## Quick Status

```bash
$HUB status                    # All blueprints overview
$HUB view app_snapshot         # Full project picture
$HUB view project_progress     # Step-level aggregation
$HUB view next_actions         # Ready to work
$HUB view attention_needed     # Issues + review-pending
$HUB view task_board           # Active acts
```

## Project Lifecycle

<flow name="project-lifecycle">
  <phase name="1-define" title="Definition">
    <step>Discuss requirements with user via AskUserQuestion</step>
    <step>Define project concept: $HUB set-concept "target" "problem" "solution" "value" "catchphrase"</step>
    <step>Create core/overview via hub.py → user review</step>
    <step>Create core/config (business rules, constants) via hub.py → user review</step>
    <step>Verify core/tech rules are seeded (run: bpf db seed)</step>
  </phase>
  <phase name="2-design" title="Design">
    <step>Create blueprint table/* definitions via hub.py → user review</step>
    <step>Create blueprint layout/* definitions via hub.py → user review</step>
    <step>Create blueprint page/* definitions via hub.py → user review</step>
    <step>Create blueprint partial/* definitions (if needed) → user review</step>
    <step>Create blueprint action/* definitions (if needed) → user review</step>
    <step>Register dependencies: $HUB add-dep source_id target_id [dep_gate]</step>
  </phase>
  <phase name="3-implement" title="Implementation">
    <step>Check next_actions: $HUB view next_actions</step>
    <step>Create act: echo "content" | $HUB create-act bp_id "title"</step>
    <step>Lock blueprint: $HUB lock id</step>
    <step>Launch coding agent via Task tool</step>
    <step>Receive agent report → echo "report" | $HUB save-result act_id</step>
    <step>Set review: $HUB review id → present review to user</step>
  </phase>
  <phase name="4-test" title="Testing">
    <step>Create test blueprints (parent_id → target, test_level 1/2/3)</step>
    <step>Create acts and launch coding agent for each test</step>
    <gate>test_l2 requires ALL test_l1 done</gate>
    <gate>test_l3 requires ALL test_l2 done</gate>
  </phase>
</flow>

## Dependency Gate (dep_gate)

dep_gate controls when a dependency is considered resolved. Use `impl` to maximize parallelism.

```bash
# Default: target must fully complete pipeline (conservative)
$HUB add-dep {page_id} {table_id}              # dep_gate='done'

# Early unlock: target only needs impl done (parallel-friendly)
$HUB add-dep {page_id} {partial_id} impl       # unlocks when partial impl is done
$HUB add-dep {page_id} {table_id} impl         # unlocks when migration/model exist
$HUB add-dep {page_id} {layout_id} impl        # unlocks when layout exists
```

| dep_gate | 意味 | 主な用途 |
|----------|------|---------|
| `done` (default) | パイプライン完全完了 | テスト依存、厳密な順序が必要な場合 |
| `impl` | コード実装完了 | page→partial, page→table, page→layout |

## Project Concept

プロジェクトの方向性を定義する5項目。設計判断・スコープ判断の基準として参照する。

```bash
$HUB set-concept \
  "ターゲット（誰のための製品か）" \
  "課題（ターゲットが抱える具体的問題）" \
  "ソリューション（課題をどう解決するか）" \
  "独自価値（競合にない強み）" \
  "キャッチフレーズ（20字以内）"
```

- 各項目は1行で、定量的・具体的に記述
- ハイレベルコンセプト（キャッチフレーズ）は他4項目が確定してから決定
- `$HUB read-core concept` で確認可能
- 設計変更時はコンセプトとの整合性を必ず確認

## Act Creation

Acts bridge blueprint specs (50%) and code (100%) at ~75% detail level.

```bash
cat << 'EOF' | $HUB create-act {bp_id} "impl: {type}/{slug}"
- files: app/Livewire/TaskIndex.php, resources/views/livewire/task-index.blade.php
- structure: full-page Livewire component with modal CRUD
- route: GET /tasks → TaskIndex::class
- edge cases: empty state, pagination over 20 items
- notes: {any past feedback or constraints}
EOF
```

**act.content** should include:
- Target file paths and component structure
- Specific implementation decisions
- Edge cases to handle
- Past feedback or failure notes (if retry)

## Agent Launch

```
Task tool:
  subagent_type: "general-purpose"
  model: "sonnet"
  prompt: "Read .claude/agents/coding.md and follow its instructions. act_id={id}"
  run_in_background: true
```

## Review Process

<flow name="review">
  <step>Coding agent completes → Hub receives Task output</step>
  <step>Hub saves report: echo "report" | $HUB save-result act_id</step>
  <step>Hub sets review: $HUB review bp_id</step>
  <step>Hub presents review via AskUserQuestion with 3 options</step>
  <step>User chooses: approve / request changes / defer</step>
</flow>

### Review Actions (CRITICAL — always execute the command)

| User choice | Hub action |
|-------------|-----------|
| **承認** | `$HUB complete {id}` (approve→commit→advance) |
| **修正依頼** | `echo "feedback" \| $HUB create-act {bp_id} "title (revision)"` then `$HUB lock {id}` |
| **後で確認** | No DB change (step_status stays 'review') |

### Push

ユーザーが要望した場合、または区切りの良いタイミングで:

```bash
$HUB push
```

### Review Presentation

```
AskUserQuestion (Japanese):
  "【レビュー】{blueprint_type}/{blueprint_slug} — {act_title}

   {agent summary}
   変更ファイル: {files list}
   スクリーンショット: {paths or N/A}
   問題・備考: {issues/notes or なし}"

  Options:
    - 承認
    - 修正依頼
    - 後で確認
```

## Dirty Flag Handling

<flow name="dirty-handling">
  <step>Identify dirty items: $HUB view attention_needed</step>
  <step>Evaluate impact: $HUB view dependency_map</step>
  <step>AskUserQuestion: rollback step / clear dirty / modify spec</step>
  <step>Apply: $HUB clear-dirty id or $HUB dirty id "reason"</step>
</flow>
