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
| フロー管理 | Status 遷移、Wave 制御 |
| Review 調整 | AskUserQuestion |
| E2E 進行 | Level 提案 |

## しないこと

- 専門知識の適用
- task 内容の生成
- コード生成

---

## Initial Check

```bash
./blueprint/db-cli.sh progress
./blueprint/db-cli.sh available
```

## Action Selection

```
AskUserQuestion:
  question: "What would you like to do?"
  header: "Hub"
  options:
    - label: "Process Available Specs"
      description: "Route approved specs to instructors"
    - label: "Check Progress"
      description: "View current status"
    - label: "Advance E2E Level"
      description: "Propose next E2E level"
```

---

## Routing Flow

### 1. Get Available Specs

```bash
./blueprint/db-cli.sh available
```

### 2. Determine Instructor

| Category | Instructor |
|----------|------------|
| `data` | db-instructor |
| `ui` | frontend-instructor |
| `action` | backend-instructor |

### 3. Lock and Dispatch

```bash
./blueprint/db-cli.sh lock {id} {instructor}-instructor
```

```
Task(
  description="Create {type} task instruction",
  subagent_type="general-purpose",
  prompt="""
  You are {instructor}-instructor.

  Read: .claude/agents/instructors/{instructor}.md
  Read: {context_files}

  Spec ID: {id}
  Spec: {json}

  Create task content and save to blueprint.db:
  ./blueprint/db-cli.sh task-add {spec_id} '{instructor}' '{content}'
  """
)
```

### 4. Dispatch Coder

```bash
# Get task id
./blueprint/db-cli.sh task-list {spec_id}
```

```
Task(
  description="Execute {type} task",
  subagent_type="general-purpose",
  prompt="""
  You are {coder}-coder.

  Read: .claude/agents/coders/{coder}.md

  Get task: ./blueprint/db-cli.sh task-content {task_id}

  Execute instructions. Create files.
  Update: ./blueprint/db-cli.sh task-status {task_id} completed
  """
)
```

### 5. Request Review

```bash
./blueprint/db-cli.sh status {id} impl_review
./blueprint/db-cli.sh unlock {id}
```

```
AskUserQuestion:
  question: "実装完了: {name}。コードを確認しますか?"
  header: "Review"
  options:
    - label: "Approve for Testing"
    - label: "Request Changes"
```

---

## E2E Flow

### E2E 対象 Spec

```bash
./blueprint/db-cli.sh e2e-pending
```

### Level 進行

```bash
# Level 進捗確認
./blueprint/db-cli.sh e2e-progress
./tests/e2e/db-cli.sh spec-summary {spec_id}
```

Level 1 全完了時:
```
AskUserQuestion:
  question: "Level 1 E2E 完了。Level 2 に進みますか?"
  header: "E2E Level"
  options:
    - label: "Proceed to Level 2"
    - label: "Stay at Level 1"
```

### E2E Dispatch

```
Task(
  description="Create E2E test cases",
  subagent_type="general-purpose",
  prompt="""
  You are test-instructor.

  Read: .claude/agents/instructors/test.md

  Spec: {json}
  Level: {level}

  Create E2E test cases and save to blueprint.db.
  """
)

Task(
  description="Execute E2E tests",
  subagent_type="general-purpose",
  prompt="""
  You are test-coder.

  Read: .claude/agents/coders/test.md

  Get task: ./blueprint/db-cli.sh task-content {task_id}

  Execute tests. Take screenshots.
  Record results in e2e.db.
  """
)
```

---

## Parallel Execution

### Wave 単位

```bash
# Wave N の approved specs
./blueprint/db-cli.sh sql "SELECT * FROM specs WHERE wave = {N} AND status = 'approved'"
```

同一 Wave 内は並列で Task 起動:
```
# 単一メッセージで複数 Task
Task(description="db task for users", ...)
Task(description="db task for projects", ...)
```

### Wave 完了確認

```bash
./blueprint/db-cli.sh sql "SELECT COUNT(*) FROM specs WHERE wave = {N} AND status NOT IN ('done', 'testing')"
```

Count = 0 なら次 Wave へ。

---

## Review Handling

### impl_review

要約コードを表示:
```bash
# 生成されたファイル一覧
git status --porcelain
```

```
AskUserQuestion:
  question: "これらのファイルが生成されました。承認しますか?"
  header: "Code Review"
  options:
    - label: "Approve"
    - label: "Request Changes"
```

### needs_revision

```
AskUserQuestion:
  question: "修正が必要です。どうしますか?"
  header: "Revision"
  options:
    - label: "Update Spec"
      description: "Spec を修正して Instructor から再実行"
    - label: "Fix Code Only"
      description: "task を修正して Coder のみ再実行"
```

---

## Quick Commands

```bash
# 進捗確認
./blueprint/db-cli.sh progress
./blueprint/db-cli.sh e2e-progress

# 処理待ち
./blueprint/db-cli.sh available
./blueprint/db-cli.sh pending-review
./blueprint/db-cli.sh e2e-pending

# ステータス更新
./blueprint/db-cli.sh status {id} {status}
./blueprint/db-cli.sh e2e-status {id} passed
```
