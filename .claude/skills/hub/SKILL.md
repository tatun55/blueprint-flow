---
name: hub
description: Lightweight orchestrator for 3-layer agent architecture. Routes specs to instructors, manages flow, coordinates human review.
allowed-tools: Bash, Task, AskUserQuestion
---

# Hub Orchestrator

軽量な調整役。専門知識は持たず、ルーティングとフロー管理に徹する。

## 責務

| 責務 | 詳細 |
|------|------|
| ルーティング | Category → Instructor |
| フロー管理 | Status 遷移、依存関係制御 |
| Review 調整 | AskUserQuestion |
| E2E 進行 | Level 提案 |

## しないこと

- 専門知識の適用
- task 内容の生成
- コード生成
- worktree操作（Coderの責務）

---

## Initial Check

```bash
./scripts/blueprint-db-cli.sh progress
./scripts/blueprint-db-cli.sh available-with-deps
```

## Action Selection

```
AskUserQuestion:
  question: "What would you like to do?"
  header: "Hub"
  options:
    - label: "Process Available Specs"
      description: "Route specs with resolved dependencies to instructors"
    - label: "Check Progress"
      description: "View current status"
    - label: "Review Pending PRs"
      description: "Review impl_review specs and merge"
    - label: "Advance E2E Level"
      description: "Propose next E2E level"
```

---

## Routing Flow

<workflow name="routing">
  <step id="get_available">
    <description>Get specs with resolved dependencies</description>
    <bash>./scripts/blueprint-db-cli.sh available-with-deps</bash>
    <output>specs[] where status=approved, working_by=NULL, all deps done</output>
  </step>

  <step id="determine_instructor">
    <mapping>
      <route category="data" instructor="db"/>
      <route category="ui" instructor="frontend"/>
      <route category="action" instructor="backend"/>
    </mapping>
  </step>

  <parallel for_each="available_specs">
    <step id="lock">
      <bash>./scripts/blueprint-db-cli.sh lock {id} {instructor}-instructor</bash>
    </step>

    <step id="dispatch_instructor">
      <task subagent="general-purpose">
        <role>{instructor}-instructor</role>
        <read>.claude/agents/instructors/{instructor}.md</read>
        <input>spec_id, spec_json</input>
        <actions>
          1. Check dependencies: ./scripts/blueprint-db-cli.sh deps {id}
          2. If all deps done, create task content
          3. Save: ./scripts/blueprint-db-cli.sh task-add {spec_id} '{instructor}' '{content}'
        </actions>
        <output>task_id or {"status": "blocked", "blocked_by": [...]}</output>
      </task>
    </step>

    <step id="dispatch_coder" after="dispatch_instructor">
      <bash>./scripts/blueprint-db-cli.sh task-list {spec_id}</bash>
      <task subagent="general-purpose">
        <role>{coder}-coder</role>
        <read>.claude/agents/coders/{coder}.md</read>
        <input>task_content from task-content {task_id}</input>
        <actions>
          1. Create worktree if specified
          2. Create files
          3. Commit and push
          4. Create draft PR
          5. Update: ./scripts/blueprint-db-cli.sh task-status {task_id} completed
        </actions>
        <output>{"status": "complete", "pr_url": "...", "files": [...]}</output>
      </task>
    </step>

    <conditional id="handle_result">
      <branch condition="success">
        <bash>./scripts/blueprint-db-cli.sh status {id} impl_review</bash>
        <bash>./scripts/blueprint-db-cli.sh unlock {id}</bash>
      </branch>
      <branch condition="error">
        <bash>./scripts/blueprint-db-cli.sh status {id} blocked</bash>
        <bash>./scripts/blueprint-db-cli.sh unlock {id}</bash>
        <action>Notify user with error details</action>
      </branch>
    </conditional>
  </parallel>
</workflow>

---

## Human Review Flow

<workflow name="human_review">
  <step id="get_pending">
    <bash>./scripts/blueprint-db-cli.sh pending-review</bash>
  </step>

  <loop for_each="pending_specs">
    <step id="ask_decision">
      <prompt>PR ready for review: {name}. What's your decision?</prompt>
      <options>
        - Approve & Merge
        - Request Changes
        - Skip
      </options>
    </step>

    <conditional id="handle_decision">
      <branch condition="Approve & Merge">
        <bash>./scripts/worktree-manager.sh merge {spec_id}</bash>
        <bash>./scripts/blueprint-db-cli.sh status {id} testing</bash>
        <bash>./scripts/blueprint-db-cli.sh reviewed {id}</bash>
      </branch>
      <branch condition="Request Changes">
        <prompt>What changes are needed?</prompt>
        <bash>./scripts/worktree-manager.sh abort {spec_id}</bash>
        <bash>./scripts/blueprint-db-cli.sh revision {id} '{reason}'</bash>
      </branch>
      <branch condition="Skip">
        <action>Continue to next spec</action>
      </branch>
    </conditional>
  </loop>
</workflow>

---

## Error Recovery Flow

<workflow name="error_recovery">
  <step id="get_blocked">
    <bash>./scripts/blueprint-db-cli.sh needs-attention</bash>
  </step>

  <loop for_each="blocked_specs">
    <step id="ask_action">
      <prompt>Spec '{name}' is blocked. How to proceed?</prompt>
      <options>
        - Add Missing Dependency
        - Fix Spec
        - Retry
        - Skip
      </options>
    </step>

    <conditional id="handle_action">
      <branch condition="Add Missing Dependency">
        <action>Create new spec for missing model/component</action>
        <bash>./scripts/blueprint-db-cli.sh add-dep {spec_id} {new_spec_id}</bash>
      </branch>
      <branch condition="Fix Spec">
        <action>Update spec data via /blueprint</action>
        <bash>./scripts/blueprint-db-cli.sh status {id} pending_review</bash>
      </branch>
      <branch condition="Retry">
        <bash>./scripts/blueprint-db-cli.sh status {id} approved</bash>
        <action>Re-run routing flow</action>
      </branch>
      <branch condition="Skip">
        <action>Handle later</action>
      </branch>
    </conditional>
  </loop>
</workflow>

---

## Parallel Execution

<workflow name="parallel_execution">
  <step id="get_available">
    <bash>./scripts/blueprint-db-cli.sh available-with-deps</bash>
    <output>specs[]</output>
  </step>

  <parallel for_each="specs">
    <task>db task for {slug}</task>
    <task>frontend task for {slug}</task>
    <task>backend task for {slug}</task>
  </parallel>

  <step id="check_unblocked" after="any_task_completes">
    <bash>./scripts/blueprint-db-cli.sh available-with-deps</bash>
    <action>Launch newly unblocked specs</action>
  </step>

  <step id="add_dependency" trigger="instructor_reports_blocked">
    <bash>./scripts/blueprint-db-cli.sh add-dep {spec_id} {blocked_by_spec_id}</bash>
  </step>
</workflow>

---

## E2E Flow

<workflow name="e2e">
  <step id="get_pending">
    <bash>./scripts/blueprint-db-cli.sh e2e-pending</bash>
  </step>

  <step id="check_progress">
    <bash>./scripts/blueprint-db-cli.sh e2e-progress</bash>
    <bash>./scripts/e2e-db-cli.sh spec-summary {spec_id}</bash>
  </step>

  <conditional id="level_progression" trigger="level_complete">
    <prompt>Level {N} E2E 完了。Level {N+1} に進みますか?</prompt>
    <branch condition="Proceed">
      <action>Increment e2e_level</action>
    </branch>
    <branch condition="Stay">
      <action>Keep current level</action>
    </branch>
  </conditional>

  <step id="dispatch_test_instructor">
    <task subagent="general-purpose">
      <role>test-instructor</role>
      <read>.claude/agents/instructors/test.md</read>
      <input>spec_json, level</input>
      <output>E2E test cases saved to blueprint.db</output>
    </task>
  </step>

  <step id="dispatch_test_coder" after="dispatch_test_instructor">
    <task subagent="general-purpose">
      <role>test-coder</role>
      <read>.claude/agents/coders/test.md</read>
      <input>task_content</input>
      <actions>
        Execute tests, take screenshots, record in e2e.db
      </actions>
    </task>
  </step>
</workflow>

---

## Quick Commands

```bash
# Progress
./scripts/blueprint-db-cli.sh progress
./scripts/blueprint-db-cli.sh e2e-progress

# Available (dependency-aware)
./scripts/blueprint-db-cli.sh available-with-deps
./scripts/blueprint-db-cli.sh pending-review
./scripts/blueprint-db-cli.sh e2e-pending
./scripts/blueprint-db-cli.sh needs-attention

# Dependencies
./scripts/blueprint-db-cli.sh deps {id}
./scripts/blueprint-db-cli.sh blockers {id}
./scripts/blueprint-db-cli.sh add-dep {id} {blocked_by_id}

# Worktree
./scripts/worktree-manager.sh list
./scripts/worktree-manager.sh status {spec_id}
./scripts/worktree-manager.sh merge {spec_id}
./scripts/worktree-manager.sh abort {spec_id}

# Status
./scripts/blueprint-db-cli.sh status {id} {status}
./scripts/blueprint-db-cli.sh e2e-status {id} passed
```
