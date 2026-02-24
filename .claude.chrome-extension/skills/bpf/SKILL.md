---
name: bpf
description: Blueprint-Flow orchestration. Manages Chrome Extension project lifecycle — blueprints, acts, coding agents, and progress tracking.
allowed-tools: Bash, Read, Grep, Glob, Task, AskUserQuestion, TodoWrite
hooks:
  SessionStart:
    - matcher: "compact"
      hooks:
        - type: command
          command: "cat .claude/skills/bpf/SKILL.md"
---

# Blueprint-Flow Orchestration (Chrome Extension)

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

## Blueprint Type Reference (Chrome Extension)

| type | Maps to | Flow |
|------|---------|------|
| `table` | chrome.storage schema | define → seed → impl → done |
| `layout` | Root providers, ThemeProvider, app shell | define → impl → done |
| `partial` | Shared React components, hooks | define → impl → test_l1 → ... → done |
| `action` | Background SW handlers, content script logic | define → impl → test_l1 → ... → done |
| `page` | Popup, Options, Side Panel pages | define → impl → test_l1 → ... → done |
| `test` | Test definitions | define → done |

## Project Lifecycle

<flow name="project-lifecycle">
  <phase name="0-concept" title="Concept-Making（戦略的コンセプト策定）">
    <step>/concept-making スキルを起動（戦略分析 → コンセプト導出）</step>
  </phase>
  <phase name="1-define" title="Definition">
    <step>Define design direction: LP デモページ生成 → ユーザー選択 → ... | $HUB set-design "{スタイル名}"</step>
    <step>Create core/overview via hub.py → user review</step>
    <step>Create core/config (manifest permissions, constants) via hub.py → user review</step>
    <step>Verify core/tech rules are seeded (run: bpf db seed)</step>
  </phase>
  <phase name="2-storage" title="Storage Design">
    <step>Create blueprint table/* (chrome.storage schemas) → user review</step>
  </phase>
  <phase name="3-arch" title="Architecture">
    <step>Create blueprint layout/* (root providers, app shell) → user review</step>
    <step>Create blueprint action/* (background SW, content scripts) → user review</step>
    <step>Register dependencies: $HUB add-dep source_id target_id [dep_gate]</step>
  </phase>
  <phase name="4-ui" title="UI Design">
    <step>Create blueprint page/* (popup, options, sidepanel) → user review</step>
    <step>Create blueprint partial/* (shared components, hooks) → user review</step>
    <step>Register dependencies</step>
  </phase>
  <phase name="5-implement" title="Implementation">
    <step>Check next_actions: $HUB view next_actions</step>
    <step>Create act: echo "content" | $HUB create-act bp_id "title"</step>
    <step>Lock blueprint: $HUB lock id</step>
    <step>Launch coding agent via Task tool</step>
    <step>Receive agent report → echo "report" | $HUB save-result act_id</step>
    <step>Set review: $HUB review id → present review to user</step>
  </phase>
  <phase name="6-test" title="Testing">
    <step>Create test blueprints (parent_id → target, test_level 1/2/3)</step>
    <step>Create acts and launch coding agent for each test</step>
    <gate>test_l2 requires ALL test_l1 done</gate>
    <gate>test_l3 requires ALL test_l2 done</gate>
  </phase>
</flow>

## Dependency Gate (dep_gate)

dep_gate controls when a dependency is considered resolved.

```bash
# Default: target must fully complete pipeline
$HUB add-dep {page_id} {table_id}              # dep_gate='done'

# Early unlock: target only needs impl done
$HUB add-dep {page_id} {partial_id} impl       # unlocks when partial impl is done
$HUB add-dep {page_id} {table_id} impl         # unlocks when storage wrappers exist
$HUB add-dep {page_id} {layout_id} impl        # unlocks when layout exists
```

| dep_gate | 意味 | 主な用途 |
|----------|------|---------|
| `done` (default) | パイプライン完全完了 | テスト依存、厳密な順序が必要な場合 |
| `impl` | コード実装完了 | page→partial, page→table, page→layout |

## Design Direction

コンセプト確定後、以下のフローでデザイン方針を決定する。

<flow name="design-direction">
  <step order="1">コンセプトから対立軸プロファイルを導出する。7軸: density, temp, gravity, speed, age, volume, order</step>
  <step order="2">シャッフラーを複数パターンで実行し、素材を収集:
    python3 .blueprint-flow/blueprint/design_shuffle.py --axes {軸ワード...}</step>
  <step order="3">収集した素材を創造的に組み合わせて 3 つの独自デザイン案を構成</step>
  <step order="4">3 案それぞれについて LP デモページを生成（frontend-design スキル使用）
    出力先: blueprint/demos/design-{a|b|c}.html</step>
  <step order="5">デモページのスクリーンショットを撮り、AskUserQuestion で 3 案を提示</step>
  <step order="6">選択されたデザインからグローバルデザインシステムを構築。
    ... | $HUB set-design "{スタイル名}"</step>
</flow>

## Act Creation

Acts bridge blueprint specs (50%) and code (100%) at ~75% detail level.

```bash
cat << 'EOF' | $HUB create-act {bp_id} "impl: {type}/{slug}"
- files: src/popup/Popup.tsx, src/popup/index.html
- structure: React component with useStorage hook
- chrome apis: chrome.storage.local, chrome.tabs.query
- edge cases: empty state, loading state, error state
- notes: {any past feedback or constraints}
EOF
```

**act.content** should include:
- Target file paths and component structure
- Chrome APIs to use
- Edge cases to handle (service worker restart, storage limits)
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
