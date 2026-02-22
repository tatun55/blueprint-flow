# Blueprint-Flow v2

> Document-driven development framework with 3-layer architecture

---

## 1. Architecture

### 3 Layers

```
core layer (foundation)     Project-wide definitions. Referenced by all layers.
blueprint layer (spec)      Feature/table/test definitions with dependencies. ~50% detail.
act layer (task)            Implementation instructions + work log. ~75% detail.
```

### Detail Levels

```
blueprint (~50%)  →  act (~75%)  →  code (100%)
  what to build       how to build     full implementation
```

### Agents

```
User
  │
  ▼
Hub (Foreground)
  │  DB read/write, orchestration, user communication
  │  No code knowledge. Actively uses AskUserQuestion.
  │
  └─→ Coding Agent (Background)
        Reads .claude/agents/coding.md for instructions.
        Self-serves knowledge from DB (read-only).
        Implements, captures screenshots, reports back.
```

| Aspect | Hub | Coding Agent |
|--------|-----|--------------|
| Role | DB management, orchestration, proposals | Implementation based on act |
| Code knowledge | None | Full |
| User interaction | AskUserQuestion (active) | None |
| Execution | Foreground | Background |
| DB access | Read/write | Read-only |

### Prohibitions (CRITICAL)

**Hub:**

<hub-prohibitions>
- NEVER read or write source code files
- NEVER run system commands (build, test, install, migrate)
- NEVER make judgments about source code implementation details
- NEVER decide outside blueprint scope without user consent
</hub-prohibitions>

Hub SHOULD actively use AskUserQuestion and propose based on specification knowledge.

**Coding Agent:**

<coding-prohibitions>
- NEVER use AskUserQuestion — only Hub communicates with the user
- NEVER write to blueprint.db — read-only access only
- NEVER modify code outside act/blueprint scope
- NEVER add or remove packages unless explicitly instructed in the act
- NEVER change architecture (directory structure, design patterns)
- ALWAYS stop and report when discovering problems or improvement opportunities
</coding-prohibitions>

---

## 2. Database

### Tables

```sql
-- core layer: project foundation
-- overview: app summary, feature list
-- config:   business rules, constants, domain knowledge
-- tech:     tech stack, coding rules, flow definitions
CREATE TABLE cores (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    type       TEXT NOT NULL,          -- overview / config / tech
    slug       TEXT NOT NULL UNIQUE,
    name       TEXT NOT NULL,
    summary    TEXT NOT NULL,           -- 20-40 char summary for Hub context
    content    TEXT NOT NULL,           -- Markdown
    reviewed   BOOLEAN DEFAULT 0,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- blueprint layer: feature definitions (~50% detail)
-- page / partial / action / table / layout / test
CREATE TABLE blueprints (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    type        TEXT NOT NULL,
    slug        TEXT NOT NULL,
    name        TEXT NOT NULL,
    summary     TEXT NOT NULL,
    content     TEXT NOT NULL,           -- Markdown spec with scenarios

    step        TEXT NOT NULL DEFAULT 'define',
    step_status TEXT NOT NULL DEFAULT 'todo'
                CHECK(step_status IN ('todo', 'doing', 'review', 'done')),
    locked_by   TEXT,

    dirty        BOOLEAN DEFAULT 0,
    dirty_reason TEXT,

    parent_id   INTEGER REFERENCES blueprints(id),  -- for type='test'
    test_level  INTEGER,                             -- 1 / 2 / 3

    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(type, slug)
);

-- act layer: implementation instructions + work log (~75% detail)
CREATE TABLE acts (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    blueprint_id INTEGER NOT NULL REFERENCES blueprints(id),
    title        TEXT NOT NULL,
    content      TEXT NOT NULL DEFAULT '',  -- implementation details + Hub notes

    status       TEXT NOT NULL DEFAULT 'todo'
                 CHECK(status IN ('todo', 'doing', 'done', 'failed')),
    locked_by    TEXT,
    result       TEXT,                      -- structured agent report

    created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME
);

-- knowledge sets: blueprint type → rule slug mapping
-- Coding agent uses this to self-serve rules from DB
CREATE TABLE knowledge_sets (
    blueprint_type TEXT NOT NULL,
    rule_slug      TEXT NOT NULL,
    UNIQUE(blueprint_type, rule_slug)
);

-- dependencies between blueprints
CREATE TABLE dependencies (
    source_id INTEGER NOT NULL REFERENCES blueprints(id),
    target_id INTEGER NOT NULL REFERENCES blueprints(id),
    detail    TEXT,                         -- e.g. "users.id, users.role"
    UNIQUE(source_id, target_id)
);
```

### VIEWs

| VIEW | Purpose |
|------|---------|
| `app_snapshot` | Full project picture (Hub reads on every session start) |
| `project_progress` | Step-level aggregation |
| `item_status` | All blueprint statuses |
| `next_actions` | Ready items (dependencies resolved, step_status='done') |
| `attention_needed` | Dirty items + locked items + review-pending |
| `test_coverage` | L1/L2/L3 status per blueprint |
| `dependency_map` | Human-readable dependency display |
| `task_board` | Active acts (not done) |

---

## 3. Core Layer

| type | Content | Example |
|------|---------|---------|
| `strategy` | Market analysis, strategic positioning, moat | WTA evaluation, Do/Don't check |
| `concept` | Target, problem, solution, unique value, catchphrase | Project concept derived from strategy |
| `design` | Visual tone, color, typography, layout | Design direction from axis shuffle |
| `overview` | App summary, feature list | App name, purpose, main features |
| `config` | Business rules, constants, domain knowledge | Status values, permission definitions |
| `tech` | Tech stack, coding rules, flow definitions | Seeded from `rules/*.md` files |

### summary vs content

- **summary** (20-40 chars): Minimal context for Hub via `app_snapshot` VIEW
- **content** (Markdown): Full specification text

### Content Quality (CRITICAL)

1. **Clear intent**: No ambiguity in what to achieve
2. **Codeable**: An LLM agent can start implementing from this alone
3. **Sufficient**: Contains all necessary information, no more
4. **Balanced**: Not so detailed it constrains implementation, not so brief it invites interpretation

---

## 4. Blueprint Layer (~50% detail)

### Types

| type | Description | Depends on |
|------|-------------|-----------|
| `page` | Page definition (route, layout, operations, display) | table, layout, partial |
| `partial` | Reusable component definition | table |
| `action` | Backend logic (Action, Job, Event) | table |
| `table` | Table definition (columns, relations, seeder) | other tables |
| `layout` | Layout definition (header, sidebar, footer) | none |
| `test` | Test definition with specific scenarios | target blueprint (parent_id) |

### Test Binding

```
blueprint (page/todo-index)
  └── test (parent_id=above, test_level=1) "Basic operation tests"
  └── test (parent_id=above, test_level=2) "Extended tests"
  └── test (parent_id=above, test_level=3) "Edge case tests"
```

### Pipeline

Each blueprint tracks progress via `step` × `step_status`:

**step**: Defined per type in core tech flow definitions

**step_status**: State within each step

```
todo → doing → review → done
        ↑         │
   locked_by   user review (can be deferred)
```

- `todo`: Not started
- `doing`: Agent working (`locked_by` set)
- `review`: Work complete, awaiting user review
- `done`: Review passed, ready to advance to next step

### Item Flow (per type)

```
page / partial / action:  define → impl → test_l1 → test_l2 → test_l3 → done
table:                    define → seed → impl → done
layout:                   define → impl → done
test:                     define → done
```

### Impl Step: Test-First Development

The `impl` step includes test-first development by default:

1. Write unit/feature tests from blueprint scenarios (Red)
2. Implement code to pass tests (Green)
3. Run tests, iterate until all pass
4. Verify blueprint-match (spec vs implementation)
5. Capture screenshots (UI types only)

This behavior is defined in `testing` rules and is configurable per project.

### Gates

| Step | Gate condition |
|------|---------------|
| `test_l2` | ALL blueprints' `test_l1` complete |
| `test_l3` | ALL blueprints' `test_l2` complete |

---

## 5. Act Layer (~75% detail)

### Role

Acts bridge blueprint specifications and code implementation:
- **blueprint.content** (~50%): What to build
- **act.content** (~75%): How to build — file paths, component structure, edge cases, past feedback
- **Code** (100%): Full implementation

### act.content

Hub writes implementation-level details:
- Target file paths and component structure
- Specific implementation decisions
- Edge cases to handle
- Past feedback or failure notes (if retry)

### act.result

Coding agent writes a structured report:
```
- status: done | blocked | found_issues
- files: [list of changed files]
- summary: [1-2 line description]
- blueprint-match:
  - ✓ scenario description
  - ✗ scenario description (reason)
- test-results: [X passed, Y failed — details if any failures]
- screenshots: [paths or N/A]
- issues: [problems or improvement ideas]
- notes: [interruption reasons, alternatives]
```

### Knowledge Self-Service

Coding agent queries DB to gather all needed context:

```bash
DB="blueprint/blueprint.db"

# 1. Get act + blueprint
sqlite3 -json $DB "SELECT a.*, b.type as bp_type, b.slug as bp_slug, b.content as bp_content
    FROM acts a JOIN blueprints b ON a.blueprint_id = b.id WHERE a.id = {act_id}"

# 2. Get rules for this blueprint type
sqlite3 -json $DB "SELECT c.slug, c.content FROM cores c
    JOIN knowledge_sets ks ON c.slug = 'rules-' || ks.rule_slug
    WHERE ks.blueprint_type = '{bp_type}'"

# 3. Get dependency content
sqlite3 -json $DB "SELECT b.type, b.slug, b.content FROM blueprints b
    JOIN dependencies d ON d.target_id = b.id WHERE d.source_id = {blueprint_id}"

# 4. Get overview and config
sqlite3 -json $DB "SELECT slug, content FROM cores WHERE type IN ('overview', 'config')"
```

### Knowledge Sets

| blueprint type | rules loaded |
|---------------|-------------|
| `page` | stack, architecture, ui, data, auth, style |
| `partial` | stack, architecture, ui, data, style |
| `action` | stack, data, auth, style |
| `table` | stack, db, data, style |
| `layout` | stack, architecture, ui, style |
| `test` | stack, testing, style |

- All types include `stack` and `style`
- `flow` is Hub-only (not included in acts)
- When in doubt, include more rather than less

### Test Data Strategy

- **Seeder-based** — no Factory pattern (speed priority)
- **Single source**: Same Seeder used for unit/feature tests, E2E tests, and human testing
- Each table blueprint creates a Seeder with `run()` + static helper methods
- Shared test fixtures in `tests/Helpers/` for dependency boundary checks
- In-memory lifecycle: `RefreshDatabase` trait for all automated tests

### Dependency Test Rules

1. **Own-scope only**: Assert only on current blueprint's behavior
2. **Seeder as fixture**: Use dependency Seeders' static helpers for test data
3. **Boundary check**: Verify correct interaction with dependencies via shared fixture helpers

---

## 6. Review Process

### Flow

<flow name="review">
  <step>Coding agent completes → Hub receives Task output</step>
  <step>Hub saves report to act.result</step>
  <step>Hub sets step_status='review'</step>
  <step>Hub presents review via AskUserQuestion</step>
  <step>User chooses: approve / request changes / defer</step>
</flow>

### Review Options

| Option | Action |
|--------|--------|
| **Approve** | `step_status='done'`, advance to next step |
| **Request changes** | Create new act with feedback, `step_status='doing'` |
| **Defer** | `step_status` stays `'review'`, continue other work |

Deferred reviews appear in `attention_needed` VIEW and are reminded on next `/bpf` session.

### Screenshots

For UI work (page, partial, layout), the Coding agent captures screenshots:
- Saved to `blueprint/reviews/{act_id}/`
- `before.png` (for modifications) and `after.png`
- Hub shows screenshot **paths** to user (does NOT read image files)
- Non-UI tasks skip screenshots

---

## 7. Dependencies

### Between Blueprints

```sql
INSERT INTO dependencies (source_id, target_id, detail)
VALUES (3, 1, 'users.id, users.role');
```

### Usage

1. **Execution order**: Don't start until dependencies are complete
2. **Dirty propagation**: Consider dirty flag when dependency changes
3. **Knowledge gathering**: Coding agent reads dependency content

---

## 8. Dirty Flags & Rollback

### Flow

```
Upstream blueprint changes (e.g. table/users columns)
  ↓
Downstream blueprints marked dirty=1 (e.g. page/user-profile)
  ↓
Hub evaluates impact via dependency_map
  ↓
AskUserQuestion: user chooses
  - Clear dirty (impact is minor)
  - Rollback step (re-implement needed)
  - Modify spec
```

---

## 9. Hub Operations

### DB Helper (CRITICAL)

All DB writes MUST use `hub.py` — never raw `sqlite3` commands for inserts/updates.
Hub.py uses parameter binding to prevent SQL escaping issues with markdown content.

```bash
HUB="python3 .blueprint-flow/blueprint/hub.py"

# --- Read ---
$HUB status                              # All blueprints overview
$HUB view app_snapshot                    # Full project picture
$HUB view next_actions                    # Ready items
$HUB view attention_needed               # Issues

# --- Write (content via stdin for markdown safety) ---
echo "content" | $HUB upsert-core <type> <slug> <name> <summary>
echo "content" | $HUB upsert-blueprint <type> <slug> <name> <summary>
$HUB add-dep <source_id> <target_id>

# --- Status transitions ---
$HUB approve <id>                         # step_status → 'done'
$HUB advance <id>                         # step → next step (auto per type)
$HUB lock <id> [locked_by]               # step_status → 'doing'
$HUB review <id>                          # step_status → 'review'

# --- Acts ---
echo "act content" | $HUB create-act <blueprint_id> <title>
echo "report" | $HUB save-result <act_id> [status]

# --- Dirty flags ---
$HUB dirty <id> <reason>
$HUB clear-dirty <id>
```

### Agent Launch

```
Task tool:
  subagent_type: "general-purpose"
  prompt: "Read .claude/agents/coding.md and follow its instructions. act_id={id}"
  run_in_background: true
```

---

## 10. Development Cycle

```
User: "I want to build a task management app"

Hub:
  0. Concept-Making — strategy framework
     a. AskUserQuestion: ビジネスアイデアのヒアリング
     b. 競争構造分析 (WTA, 4つの力, 隙間の特定)
     c. 戦略軸選択 (5つのDo戦略から最適軸)
     d. アンチパターンチェック (5つのDon't検証)
     e. set-strategy → set-concept
  1. Define design direction → set-design
  2. Create core/overview → user review
  3. Create core/config (business rules) → user review
  4. Verify core/tech rules are seeded
  5. Create blueprint table/tasks → user review
  6. Create blueprint layout/main → user review
  7. Create blueprint page/todo-index → user review
  8. Create blueprint test (level=1, parent=page/todo-index) → user review
  9. Create act with 75% detail → launch Coding agent
 10. Coding agent self-serves knowledge → TDD (tests first → impl → verify) → reports
 11. Hub presents review → user approves / requests changes / defers
 12. Advance to next step or iterate
```

---

## 11. Night-Runner (Autonomous Mode)

### Overview

`/night-runner` executes the entire implementation pipeline autonomously after blueprints are defined.
Same DB, same pipeline as `/bpf` — switchable at any time.

### Differences from /bpf

| Aspect | /bpf (Hub) | /night-runner |
|--------|-----------|---------------|
| Review | Human: approve / changes / defer | Auto: quality gate (tests + blueprint-match) |
| Act creation | Hub writes 75% detail | Minimal (coding agent self-serves) |
| Retry | Human creates new act | Auto: structured feedback, max 3 retries |
| Execution order | Human decides | Topological sort from dependency graph |
| Escalation | N/A | `dirty=1` with reason after 3 failures |

### Quality Gate

```
Tier 1: test-results — all tests pass?
Tier 2: blueprint-match — all scenarios ✓?
Tier 3: status — not 'blocked' or 'found_issues'?
```

All pass → advance step. Any fail → retry with feedback.

### Self-Correction Loop

```
Attempt 1 → quality gate FAIL → new act with feedback
Attempt 2 → quality gate FAIL → progress check
Attempt 3 → quality gate FAIL → dirty=1, skip dependents
```

Max 3 retries per blueprint/step. Exhausted retries escalate to human via `dirty` flag.

### Mode Switching

Safe to switch at any time:
- `/night-runner` → `/bpf`: Unlock night-runner items, dirty items appear in attention_needed
- `/bpf` → `/night-runner`: Night-runner picks up from current DB state

---

## 12. Changes from v1

| Aspect | v1 | v2 |
|--------|----|----|
| Spec management | 1 table (specs) + JSON data | 3 layers (cores, blueprints, acts) |
| Content format | JSON | Markdown |
| Agents | 5 types (db-architect, livewire, artisan, tester, blueprint-flow) | 1 type (Coding agent, DB read-only self-serve) |
| Flow definition | Implicit in code | Explicit text in core tech |
| Status | 7-stage linear + 4-stage human_reviewed | step × step_status (4 values) + dirty flag |
| Progress | Complex SQL | VIEWs with 1-line queries |
| Test management | spec + e2e_screenshots table | blueprint test records (level 1-3) |
| Instructions | JSON in spec.data | act (75% detail) + self-serve rules from DB |
| Rollback | Cascading auto-reset | Dirty flag + human decision |
| Review | Undefined | Structured: approve / request changes / defer |
