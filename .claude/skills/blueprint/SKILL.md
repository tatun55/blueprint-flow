---
name: blueprint
description: Interactive spec management with quality validation. Recursively refines specs until coding-ready.
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# Blueprint Spec Manager

Human-in-the-loop spec management with **quality validation**.
Specs are recursively refined until they reach coding-ready clarity.

---

## Content Requirements (CRITICAL)

All spec `data` content MUST be:

| Requirement | Description |
|-------------|-------------|
| **Format** | Markdown (.md) format |
| **Language** | English only |
| **Clarity** | Necessary, sufficient, and unambiguous |
| **Coding-ready** | Detailed enough for implementation without further questions |

### Overview Spec Requirements

The `core/overview` spec MUST include:

```markdown
# {App Name}

## Description
{Clear description of what the app does and why}

## Target Users
{Who uses this app and their goals}

## User Roles
| Role | Description | Permissions |
|------|-------------|-------------|
| admin | ... | ... |
| user | ... | ... |

## Features
| Feature | Description | Route | Priority |
|---------|-------------|-------|----------|
| Dashboard | ... | /dashboard | P1 |
| User List | ... | /users | P1 |

## Routes
| Route | Page | Auth | Roles |
|-------|------|------|-------|
| / | Landing | No | - |
| /dashboard | Dashboard | Yes | all |
| /users | User List | Yes | admin |

## Tech Stack
- Backend: Laravel 12
- Frontend: Livewire 4 + Alpine.js
- CSS: Tailwind 4 + daisyUI 5
```

---

## Spec Design Principles

### Livewire UI Pattern (CRITICAL)

For interactive UIs like Livewire, **operations happen within the page via modals**, not as separate pages.

<principle name="single_page_with_modals">
  <philosophy>
    Usability-first design: Users stay on one page and perform various operations
    through modals, slide-overs, and inline interactions. This reduces context
    switching and provides a smoother experience.
  </philosophy>

  <rule>CRUD and related operations are defined as **page sections**, not separate specs</rule>
  <rule>Create/Edit/View forms appear as **modals or slide-overs** within the page</rule>
  <rule>Delete, export, bulk actions use **confirmation dialogs**</rule>
  <rule>Only define **separate pages** when truly needed (e.g., complex multi-step wizard)</rule>

  <balance>
    Keep modal complexity reasonable. If a modal requires:
    - Multiple tabs or complex navigation → Consider separate page
    - Heavy data loading or long forms → Consider slide-over panel
    - Simple confirmation or quick edit → Modal is ideal
  </balance>
</principle>

**Correct Pattern:**
```
Page: User Management (/users)
├── Section: header (title + "Add User" button)
├── Section: filters (search, status filter)
├── Section: table (user list with edit/delete actions)
├── Section: create_modal (form for new user)
├── Section: edit_modal (form for editing user)
└── Section: delete_confirm (confirmation dialog)
```

**Incorrect Pattern:**
```
Page: User List (/users)
Page: User Create (/users/create)    ← Don't need separate page
Page: User Edit (/users/{id}/edit)   ← Don't need separate page
Action: CreateUser                    ← Don't need separate action spec
Action: UpdateUser                    ← Don't need separate action spec
```

### When to Use Separate Action Specs

Only create `action/*` specs for:

| Use Case | Example |
|----------|---------|
| **Async jobs** | SendWelcomeEmail, ProcessImport |
| **Scheduled tasks** | CleanupExpiredSessions, SendDailyReport |
| **Cross-page logic** | Business logic used by multiple pages |
| **Complex workflows** | Multi-step processes with events |

### Page Section Types

| Type | Description | Example |
|------|-------------|---------|
| `header` | Page title, primary action button | "Users" + "Add User" button |
| `filters` | Search, filter controls | Search by name, filter by status |
| `data-table` | List with columns and row actions | User list with edit/delete |
| `create-modal` | Modal form for creating | New user form |
| `edit-modal` | Modal form for editing | Edit user form |
| `view-modal` | Modal for viewing details | User profile quick view |
| `delete-confirm` | Delete confirmation dialog | "Are you sure?" |
| `action-confirm` | Confirmation for other actions | "Export 100 users?" |
| `bulk-actions` | Toolbar for selected items | Delete selected, Export selected |
| `detail-panel` | Slide-over for complex details | User details with tabs |
| `form` | Standalone form (non-modal) | Settings form |
| `import-modal` | File upload and import | CSV import |
| `export-modal` | Export options | Choose format, columns |

---

## Quality Validation System

<quality_check name="spec_validation">
  <criteria id="completeness">
    <check>All required fields are present</check>
    <check>No placeholder text (TBD, TODO, ...)</check>
    <check>No ambiguous terms without definition</check>
  </criteria>

  <criteria id="clarity">
    <check>Each feature has clear description</check>
    <check>Routes are explicitly defined</check>
    <check>User roles and permissions are clear</check>
    <check>Data relationships are specified</check>
  </criteria>

  <criteria id="coding_ready">
    <check>UI specs have all sections defined</check>
    <check>Table specs have all columns with types</check>
    <check>Action specs have input/output defined</check>
    <check>No questions remain for implementation</check>
  </criteria>

  <scoring>
    <level value="1" label="Incomplete">Missing critical information</level>
    <level value="2" label="Vague">Has placeholders or ambiguity</level>
    <level value="3" label="Partial">Some details missing</level>
    <level value="4" label="Clear">Ready for implementation</level>
    <level value="5" label="Excellent">Comprehensive with edge cases</level>
  </scoring>

  <threshold>4</threshold>
  <action_if_below>recursive_refinement</action_if_below>
</quality_check>

---

## Interaction Language

**Default: 日本語 (Japanese)** for AskUserQuestion prompts.

```bash
cat .blueprint-language 2>/dev/null || echo "ja"
```

**Note:** Interaction language is for prompts only. Spec content is ALWAYS in English.

---

## Command Routing

- `/blueprint init` → Initialize blueprint-flow
- `/blueprint develop` → Develop framework itself
- `/blueprint pull` → Pull latest from remote
- `/blueprint lang {ja|en}` → Set interaction language
- `/blueprint` (no args) → **Guided Spec Flow**

---

## Guided Spec Flow

<workflow name="guided_flow">
  <step id="init_check">
    <bash>./scripts/blueprint-db-cli.sh overview 2>/dev/null || ./scripts/blueprint-db-cli.sh init</bash>
  </step>

  <step id="detect_phase">
    <logic>
      - No specs → Overview phase
      - Overview not quality-validated → Overview refinement
      - Overview done, no features → Feature listing
      - Features exist, some draft → Definition phase
      - All pending_review → Review phase
      - All approved → Ready for /hub
    </logic>
  </step>

  <step id="show_status">
    <action>Show progress with quality scores</action>
    <prompt lang="ja">現在の状況です。どうしますか？</prompt>
    <options>
      <option id="continue" recommended="true">続きから進める / Continue</option>
      <option id="overview">概要を編集 / Edit Overview</option>
      <option id="features">機能リストを編集 / Edit Features</option>
      <option id="define">機能を詳細定義 / Define Features</option>
      <option id="review">レビュー / Review</option>
    </options>
  </step>
</workflow>

---

## Phase 1: Overview

<workflow name="overview_phase">
  <step id="gather_info">
    <description>Gather app information through conversation</description>
    <prompt lang="ja">アプリについて教えてください</prompt>
    <questions>
      <question>アプリ名は？ / App name?</question>
      <question>何をするアプリ？目的は？ / What does it do? Purpose?</question>
      <question>誰が使う？ / Who uses it?</question>
      <question>ユーザー種別は？ / User roles?</question>
      <question>主な機能は？ / Main features?</question>
      <question>各機能のURLパスは？ / Routes for each feature?</question>
    </questions>
  </step>

  <step id="generate_overview">
    <description>Generate overview in required format</description>
    <action>Create markdown content following Overview Requirements</action>
    <action>Include: Description, Users, Roles, Features table, Routes table</action>
  </step>

  <step id="quality_check">
    <description>Validate overview quality</description>
    <validation>
      <check id="has_description">Description is clear and specific</check>
      <check id="has_users">Target users are defined</check>
      <check id="has_roles">User roles with permissions</check>
      <check id="has_features">Features with routes and priority</check>
      <check id="has_routes">Complete route table</check>
      <check id="no_placeholders">No TBD, TODO, or ...</check>
      <check id="in_english">Content is in English</check>
    </validation>
  </step>

  <step id="refinement_loop">
    <description>Recursive refinement until quality threshold met</description>
    <conditional>
      <branch condition="quality_score < 4">
        <action>Identify missing/unclear items</action>
        <prompt lang="ja">以下の点が不明確です。詳しく教えてください：</prompt>
        <list_issues>Show specific items that need clarification</list_issues>
        <goto>gather_additional_info</goto>
      </branch>
      <branch condition="quality_score >= 4">
        <action>Show final overview to user</action>
        <prompt lang="ja">概要が完成しました。確認してください：</prompt>
        <goto>confirm_overview</goto>
      </branch>
    </conditional>
  </step>

  <step id="gather_additional_info">
    <description>Ask specific questions about unclear items</description>
    <action>Generate targeted questions based on validation failures</action>
    <examples>
      <example issue="missing_routes">
        「{feature}」のURLパスを教えてください（例: /users, /projects/{id}）
      </example>
      <example issue="vague_description">
        「{feature}」の具体的な動作を教えてください。ユーザーは何ができますか？
      </example>
      <example issue="missing_permissions">
        各ロールが{feature}で何ができるか教えてください
      </example>
    </examples>
    <goto>generate_overview</goto>
  </step>

  <step id="confirm_overview">
    <prompt lang="ja">この概要でよいですか？</prompt>
    <options>
      <option id="approve">はい、次へ進む / Yes, proceed</option>
      <option id="modify">修正する / Modify</option>
    </options>
    <conditional>
      <branch condition="approve">
        <bash>./scripts/blueprint-db-cli.sh add core overview app 'App Overview' '{content}'</bash>
        <bash>./scripts/blueprint-db-cli.sh status {id} pending_review</bash>
        <goto>feature_list_phase</goto>
      </branch>
      <branch condition="modify">
        <prompt lang="ja">何を修正しますか？</prompt>
        <goto>gather_additional_info</goto>
      </branch>
    </conditional>
  </step>
</workflow>

---

## Skill Workflow (CRITICAL)

```
/blueprint → /init-db → /hub
    ↓           ↓         ↓
  概要・機能   テーブル    実装
  UI specs    シーダー
```

<workflow name="skill_flow">
  <step order="1" skill="/blueprint">
    <scope>core/overview, ui/pages, action/*</scope>
    <output>App overview with features, routes, UI page specs</output>
  </step>
  <step order="2" skill="/init-db">
    <scope>data/tables, data/seeders</scope>
    <output>Database schema and seeder definitions</output>
    <prerequisite>core/overview approved</prerequisite>
  </step>
  <step order="3" skill="/hub">
    <scope>Implementation</scope>
    <output>Actual code files via instructors/coders</output>
    <prerequisite>All specs approved</prerequisite>
  </step>
</workflow>

**This skill handles:** `core/overview`, `ui/pages`, `action/*`
**For database specs:** Use `/init-db` after overview is approved

---

## Phase 2: Feature Listing

<workflow name="feature_list_phase">
  <step id="extract_features">
    <description>Extract features from overview</description>
    <bash>./scripts/blueprint-db-cli.sh get core overview app</bash>
    <action>Parse Features table from overview content</action>
  </step>

  <step id="categorize">
    <description>Auto-categorize each feature (UI and actions only)</description>
    <note>Database specs (tables, seeders) are handled by /init-db</note>
    <mapping>
      <rule pattern="list|index|一覧" category="ui" type="pages"/>
      <rule pattern="detail|show|詳細" category="ui" type="pages"/>
      <rule pattern="dashboard|ダッシュボード" category="ui" type="pages"/>
      <rule pattern="settings|設定" category="ui" type="pages"/>
      <rule pattern="notify|email|通知" category="action" type="async"/>
      <rule pattern="schedule|定期" category="action" type="scheduled"/>
      <rule pattern="import|export" category="action" type="async"/>
    </mapping>
  </step>

  <step id="show_feature_list">
    <action>Display categorized features as table</action>
    <prompt lang="ja">以下の機能を作成します。追加・修正はありますか？</prompt>
  </step>

  <step id="validate_completeness">
    <check>All routes from overview have corresponding specs</check>
    <check>Data tables for all entities are included</check>
    <check>CRUD operations are covered</check>
    <conditional>
      <branch condition="incomplete">
        <prompt lang="ja">以下が不足しています：</prompt>
        <list_missing/>
        <prompt lang="ja">追加しますか？</prompt>
      </branch>
    </conditional>
  </step>

  <step id="save_features">
    <loop for_each="features">
      <bash>./scripts/blueprint-db-cli.sh add {category} {type} {slug} '{name}' '{minimal_json}'</bash>
    </loop>
  </step>

  <step id="setup_dependencies">
    <description>Auto-detect dependencies</description>
    <rules>
      <rule>UI pages depend on their data tables</rule>
      <rule>Detail/Edit pages depend on List page</rule>
      <rule>Actions depend on related models</rule>
    </rules>
    <loop for_each="deps">
      <bash>./scripts/blueprint-db-cli.sh add-dep {spec_id} {blocked_by_id}</bash>
    </loop>
  </step>
</workflow>

---

## Phase 3: Definition (UI & Actions)

<workflow name="definition_phase">
  <note>This phase handles ui/pages and action/* specs only. For data/* specs, use /init-db.</note>

  <step id="get_draft_specs">
    <bash>./scripts/blueprint-db-cli.sh sql "SELECT * FROM specs WHERE status='draft' AND category IN ('ui', 'action')"</bash>
  </step>

  <loop for_each="draft_specs" item="spec">
    <step id="define_spec">
      <conditional>
        <branch condition="type=pages">
          <goto>define_page</goto>
        </branch>
        <branch condition="type=sync|async|scheduled">
          <goto>define_action</goto>
        </branch>
      </conditional>
    </step>

    <step id="quality_loop">
      <description>Recursive refinement for each spec</description>
      <action>Validate spec against quality criteria</action>
      <conditional>
        <branch condition="quality_score < 4">
          <action>Identify issues</action>
          <prompt lang="ja">「{spec.name}」について以下を明確にしてください：</prompt>
          <list_issues/>
          <goto>define_spec</goto>
        </branch>
        <branch condition="quality_score >= 4">
          <action>Show final spec</action>
          <bash>./scripts/blueprint-db-cli.sh update {spec.id} '{content}'</bash>
          <bash>./scripts/blueprint-db-cli.sh status {spec.id} pending_review</bash>
        </branch>
      </conditional>
    </step>
  </loop>
</workflow>

---

### Define Page

<workflow name="define_page">
  <note>For Livewire: CRUD operations are sections within the page, not separate pages</note>

  <required_content>
    ```markdown
    # Page: {page_name}

    ## Route
    - Path: /users
    - Method: GET
    - Auth: required
    - Roles: [admin, user]

    ## Layout
    - Template: app
    - Title: User Management

    ## Sections
    | Section | Type | Description |
    |---------|------|-------------|
    | header | header | Page title with "Add User" button |
    | filters | filters | Search by name, filter by status dropdown |
    | table | data-table | Columns: name, email, status, created_at, actions (edit/delete) |
    | create_modal | create-modal | Modal with form: name, email, role |
    | edit_modal | edit-modal | Modal with form: name, email, role, status |
    | delete_confirm | delete-confirm | Confirmation: "Delete {name}?" with cancel/confirm |

    ## Section Details

    ### create_modal
    | Field | Type | Validation |
    |-------|------|------------|
    | name | text | required, max:255 |
    | email | email | required, unique:users |
    | role | select | required, options: admin/user |

    ### edit_modal
    | Field | Type | Validation |
    |-------|------|------------|
    | name | text | required, max:255 |
    | email | email | required, unique:users,{id} |
    | role | select | required |
    | status | select | required, options: active/inactive |

    ## Data
    - Source: User model
    - Pagination: 20 per page
    - Default sort: created_at desc
    - Searchable: name, email
    - Filterable: status, role
    ```
  </required_content>

  <quality_checks>
    <check>Route is fully specified</check>
    <check>All sections including modals are defined</check>
    <check>Modal forms have field definitions with validation</check>
    <check>Data source, pagination, and filters defined</check>
    <check>No separate create/edit pages (use modals instead)</check>
  </quality_checks>
</workflow>

---

### Define Action

<workflow name="define_action">
  <note>Only for async jobs, scheduled tasks, or cross-page business logic. NOT for page CRUD.</note>

  <when_to_use>
    - Async jobs: SendWelcomeEmail, ProcessImport
    - Scheduled tasks: CleanupExpiredSessions
    - Cross-page logic: CalculateUserStats (used by dashboard and profile)
    - Complex workflows: OrderCheckout (multi-step with events)
  </when_to_use>

  <when_not_to_use>
    - CreateUser, UpdateUser, DeleteUser → Define as page sections
    - Simple form submissions → Handle in page component
  </when_not_to_use>

  <required_content>
    ```markdown
    # Action: {action_name}

    ## Type
    - async | scheduled | sync

    ## Purpose
    {Clear description - why this needs to be a separate action}

    ## Trigger
    - Event: UserCreated
    - Schedule: daily at 3:00 AM
    - Called from: Dashboard, UserProfile

    ## Input
    | Parameter | Type | Required | Validation |
    |-----------|------|----------|------------|
    | user_id | int | yes | exists:users |

    ## Process
    1. Load user data
    2. Generate report
    3. Send via email
    4. Log completion

    ## Output
    - Success: { sent: true, email: "..." }
    - Failure: NotificationException

    ## Events
    - ReportSent: dispatched after sending

    ## Queue
    - Queue: emails
    - Retry: 3 times
    - Timeout: 60 seconds
    ```
  </required_content>

  <quality_checks>
    <check>Type (async/scheduled/sync) is specified</check>
    <check>Trigger is clearly defined</check>
    <check>Justification why separate action is needed</check>
    <check>Queue settings for async jobs</check>
  </quality_checks>
</workflow>

---

## Phase 4: Review (Overview, UI, Actions)

<workflow name="review_phase">
  <note>Reviews core/overview, ui/*, action/* specs. Data specs reviewed in /init-db.</note>

  <step id="get_pending">
    <bash>./scripts/blueprint-db-cli.sh sql "SELECT * FROM specs WHERE status='pending_review' AND category IN ('core', 'ui', 'action')"</bash>
  </step>

  <loop for_each="pending_specs" item="spec">
    <step id="show_spec">
      <action>Display full spec content</action>
      <action>Show quality score</action>
    </step>

    <step id="decision">
      <prompt lang="ja">「{spec.name}」を承認しますか？</prompt>
      <options>
        <option id="approve">承認 / Approve</option>
        <option id="revise">修正依頼 / Request revision</option>
        <option id="skip">スキップ / Skip</option>
      </options>
    </step>

    <conditional>
      <branch condition="approve">
        <bash>./scripts/blueprint-db-cli.sh status {spec.id} approved</bash>
        <bash>./scripts/blueprint-db-cli.sh reviewed {spec.id}</bash>
      </branch>
      <branch condition="revise">
        <prompt lang="ja">修正内容を教えてください</prompt>
        <bash>./scripts/blueprint-db-cli.sh revision {spec.id} '{reason}'</bash>
      </branch>
    </conditional>
  </loop>

  <step id="completion_check">
    <description>Check what's missing and guide to next step</description>

    <check_data_specs>
      <bash>
# Count data specs
TABLES_COUNT=$(./scripts/blueprint-db-cli.sh sql "SELECT COUNT(*) FROM specs WHERE category='data' AND type='tables'" | jq -r '.[0]."COUNT(*)"')
SEEDERS_COUNT=$(./scripts/blueprint-db-cli.sh sql "SELECT COUNT(*) FROM specs WHERE category='data' AND type='seeders'" | jq -r '.[0]."COUNT(*)"')
echo "tables:$TABLES_COUNT seeders:$SEEDERS_COUNT"
      </bash>
    </check_data_specs>

    <conditional>
      <branch condition="no_data_specs">
        <description>No data/tables or data/seeders specs exist</description>
        <message lang="ja">
仕様が承認されました！

⚠️ データベース定義がまだありません。

次のステップ:
1. **`/init-db`** でテーブル・シーダー定義 ← 必須
2. `/hub` で実装開始
        </message>
      </branch>
      <branch condition="tables_only_no_seeders">
        <description>Tables exist but no seeders</description>
        <message lang="ja">
仕様が承認されました！

⚠️ シーダー定義がまだありません。

次のステップ:
1. **`/init-db`** でシーダー定義を追加 ← 推奨
2. `/hub` で実装開始（シーダーなしで進める場合）
        </message>
      </branch>
      <branch condition="all_data_specs_exist">
        <description>Both tables and seeders exist</description>
        <message lang="ja">
すべての仕様が承認されました！

次のステップ:
- `/hub` で実装を開始
- `/e2e` でE2Eテストを実行
        </message>
      </branch>
    </conditional>
  </step>
</workflow>

---

## CLI Reference

```bash
# Progress
./scripts/blueprint-db-cli.sh progress
./scripts/blueprint-db-cli.sh overview

# By Status
./scripts/blueprint-db-cli.sh list-by-status draft
./scripts/blueprint-db-cli.sh pending-review
./scripts/blueprint-db-cli.sh available-with-deps

# CRUD
./scripts/blueprint-db-cli.sh add {category} {type} {slug} '{name}' '{content}'
./scripts/blueprint-db-cli.sh get {category} {type} {slug}
./scripts/blueprint-db-cli.sh update {id} '{content}'

# Status
./scripts/blueprint-db-cli.sh status {id} {status}
./scripts/blueprint-db-cli.sh reviewed {id}

# Dependencies
./scripts/blueprint-db-cli.sh add-dep {id} {blocked_by_id}
```

---

## Pull Flow (`/blueprint pull`)

<workflow name="pull_flow">
  <description>Pull latest blueprint-flow. Single-command, no questions asked.</description>

  <step id="execute_all">
    <description>Run all steps in sequence with single output</description>
    <bash>
# Store project root (handle being called from any directory)
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
cd "$PROJECT_ROOT"

# Get current version
OLD_VERSION=$(cat .blueprint-flow-version 2>/dev/null | head -c 7 || echo "unknown")

# Pull latest
cd .blueprint-flow
PULL_OUTPUT=$(git pull origin main 2>&1)
cd "$PROJECT_ROOT"

# Check if already up to date
if echo "$PULL_OUTPUT" | grep -q "Already up to date"; then
  echo "✓ Already up to date ($OLD_VERSION)"
  exit 0
fi

# Get new version
NEW_VERSION=$(cd .blueprint-flow && git rev-parse HEAD | head -c 7)

# Get changelog
CHANGELOG=$(cd .blueprint-flow && git log ${OLD_VERSION}..HEAD --oneline 2>/dev/null | head -5)

# Update project files
./.blueprint-flow/scripts/update.sh . >/dev/null 2>&1

# Clean up old backup folders
rm -rf .blueprint-flow-backup-* 2>/dev/null

# Output result
echo "## Pull Complete"
echo ""
echo "| | Version |"
echo "|---|---|"
echo "| Old | \`$OLD_VERSION\` |"
echo "| New | \`$NEW_VERSION\` |"
echo ""
echo "### Changes"
echo "\`\`\`"
echo "$CHANGELOG"
echo "\`\`\`"
echo ""
echo "✓ Project files updated"
echo "✓ Backup folders cleaned"
    </bash>
  </step>
</workflow>

**Key behaviors:**
- Single command execution (no interactive prompts)
- Auto-cleanup of `.blueprint-flow-backup-*` folders
- Shows changelog between versions
- Handles "already up to date" gracefully

---

## Rules Summary

1. **Content Language**: Always English in specs
2. **Interaction Language**: Configurable (default: Japanese)
3. **Quality Threshold**: Score >= 4 to proceed
4. **Recursive Refinement**: Keep asking until clear
5. **No Placeholders**: TBD, TODO, ... are rejected
6. **Complete Routes**: Every feature needs a route
7. **Coding-Ready**: Implementable without questions
