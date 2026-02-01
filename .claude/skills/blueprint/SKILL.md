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

## Phase 2: Feature Listing

<workflow name="feature_list_phase">
  <step id="extract_features">
    <description>Extract features from overview</description>
    <bash>./scripts/blueprint-db-cli.sh get core overview app</bash>
    <action>Parse Features table from overview content</action>
  </step>

  <step id="categorize">
    <description>Auto-categorize each feature</description>
    <mapping>
      <rule pattern="list|index|一覧" category="ui" type="pages"/>
      <rule pattern="detail|show|詳細" category="ui" type="pages"/>
      <rule pattern="create|add|作成" category="ui" type="pages"/>
      <rule pattern="edit|update|編集" category="ui" type="pages"/>
      <rule pattern="table|model" category="data" type="tables"/>
      <rule pattern="notify|email|通知" category="action" type="async"/>
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

## Phase 3: Definition

<workflow name="definition_phase">
  <step id="get_draft_specs">
    <bash>./scripts/blueprint-db-cli.sh list-by-status draft</bash>
  </step>

  <loop for_each="draft_specs" item="spec">
    <step id="define_spec">
      <conditional>
        <branch condition="type=tables">
          <goto>define_table</goto>
        </branch>
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

### Define Table

<workflow name="define_table">
  <required_content>
    ```markdown
    # Table: {table_name}

    ## Columns
    | Name | Type | Constraints | Description |
    |------|------|-------------|-------------|
    | id | bigint | PK, auto | Primary key |
    | name | string(255) | required | ... |

    ## Relations
    | Type | Target | Foreign Key | On Delete |
    |------|--------|-------------|-----------|
    | belongsTo | users | user_id | cascade |

    ## Indexes
    - status (for filtering)
    - [user_id, created_at] (for user timeline)

    ## Options
    - timestamps: true
    - soft_delete: false
    ```
  </required_content>

  <quality_checks>
    <check>All columns have type and description</check>
    <check>Foreign keys have on_delete behavior</check>
    <check>Indexes are defined for query patterns</check>
  </quality_checks>
</workflow>

---

### Define Page

<workflow name="define_page">
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
    | filters | form | Search by name, filter by status |
    | table | data-table | Columns: name, email, status, actions |

    ## Actions
    | Action | Trigger | Behavior |
    |--------|---------|----------|
    | create | click button | Open modal with form |
    | edit | click row | Navigate to /users/{id}/edit |
    | delete | click icon | Confirm dialog, then delete |

    ## Data
    - Source: User model
    - Pagination: 20 per page
    - Default sort: created_at desc
    ```
  </required_content>

  <quality_checks>
    <check>Route is fully specified</check>
    <check>All sections have clear description</check>
    <check>Actions have complete behavior</check>
    <check>Data source and pagination defined</check>
  </quality_checks>
</workflow>

---

### Define Action

<workflow name="define_action">
  <required_content>
    ```markdown
    # Action: {action_name}

    ## Purpose
    {Clear description of what this action does}

    ## Input
    | Parameter | Type | Required | Validation |
    |-----------|------|----------|------------|
    | name | string | yes | max:255 |
    | email | string | yes | email, unique:users |

    ## Process
    1. Validate input
    2. Create user record
    3. Send welcome email
    4. Dispatch UserCreated event

    ## Output
    - Success: User model instance
    - Failure: ValidationException

    ## Events
    - UserCreated: dispatched after creation

    ## Side Effects
    - Sends welcome email via queue
    ```
  </required_content>

  <quality_checks>
    <check>Input parameters fully typed</check>
    <check>Process steps are clear</check>
    <check>Output and errors defined</check>
    <check>Side effects documented</check>
  </quality_checks>
</workflow>

---

## Phase 4: Review

<workflow name="review_phase">
  <step id="get_pending">
    <bash>./scripts/blueprint-db-cli.sh pending-review</bash>
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
    <conditional>
      <branch condition="all_approved">
        <message lang="ja">全てのスペックが承認されました！ `/hub` で開発を開始できます</message>
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

## Rules Summary

1. **Content Language**: Always English in specs
2. **Interaction Language**: Configurable (default: Japanese)
3. **Quality Threshold**: Score >= 4 to proceed
4. **Recursive Refinement**: Keep asking until clear
5. **No Placeholders**: TBD, TODO, ... are rejected
6. **Complete Routes**: Every feature needs a route
7. **Coding-Ready**: Implementable without questions
