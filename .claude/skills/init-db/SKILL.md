---
name: init-db
description: Database schema and seeder definition. Creates table and seeder specs from approved overview.
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# Init DB - Database Schema & Seeder Definition

Defines database tables and seeders based on approved `core/overview` spec.
Run AFTER `/blueprint` approves the overview, BEFORE `/hub` implementation.

---

## Workflow Position

```
/blueprint → /init-db → /hub
    ↓           ↓         ↓
  概要・機能   テーブル    実装
  UI specs    シーダー
```

---

## Prerequisites

Before running `/init-db`:
1. `core/overview` spec must exist and be `approved`
2. Features table in overview must list entities needing tables

```bash
# Check prerequisites
./scripts/blueprint-db-cli.sh get core overview app | jq -r '.status'
# Should return: approved
```

---

## Guided Flow

<workflow name="init_db_flow">
  <step id="check_prerequisites">
    <bash>./scripts/blueprint-db-cli.sh get core overview app</bash>
    <validation>
      <check>Overview exists</check>
      <check>Status is approved</check>
    </validation>
    <on_fail>
      <message lang="ja">先に `/blueprint` で概要を作成・承認してください</message>
      <exit/>
    </on_fail>
  </step>

  <step id="extract_entities">
    <description>Extract entities from overview that need tables</description>
    <action>Parse Features table for data entities</action>
    <action>Identify models mentioned in routes/features</action>
    <examples>
      <example>Feature "User Management" → users table</example>
      <example>Feature "Project List" → projects table</example>
      <example>Route "/users/{user}" → users table</example>
    </examples>
  </step>

  <step id="show_entities">
    <prompt lang="ja">以下のテーブルを作成します。追加・修正はありますか？</prompt>
    <action>Display table list with predicted columns</action>
  </step>

  <step id="define_tables">
    <loop for_each="entities">
      <goto>define_table</goto>
    </loop>
  </step>

  <step id="define_seeders">
    <loop for_each="tables">
      <goto>define_seeder</goto>
    </loop>
  </step>

  <step id="review">
    <goto>review_data_specs</goto>
  </step>
</workflow>

---

## Define Table

<workflow name="define_table">
  <step id="gather_info">
    <prompt lang="ja">「{table_name}」テーブルについて教えてください</prompt>
    <questions>
      <question>どんなカラムが必要？ / What columns are needed?</question>
      <question>他テーブルとの関連は？ / Relations to other tables?</question>
      <question>よく検索するカラムは？ / Frequently queried columns?</question>
    </questions>
  </step>

  <step id="generate_spec">
    <action>Generate table spec in required format</action>
  </step>

  <required_content>
    ```markdown
    # Table: {table_name}

    ## Columns
    | Name | Type | Constraints | Description |
    |------|------|-------------|-------------|
    | id | bigint | PK, auto | Primary key |
    | user_id | bigint | FK, required | Owner user |
    | name | string(255) | required | Display name |
    | status | enum | default: active | active, inactive, archived |
    | created_at | timestamp | auto | Created timestamp |
    | updated_at | timestamp | auto | Updated timestamp |

    ## Relations
    | Type | Target | Foreign Key | On Delete |
    |------|--------|-------------|-----------|
    | belongsTo | users | user_id | cascade |
    | hasMany | comments | - | cascade |

    ## Indexes
    - status (for filtering)
    - [user_id, created_at] (for user timeline)

    ## Options
    - timestamps: true
    - soft_delete: false
    ```
  </required_content>

  <step id="quality_check">
    <validation>
      <check>All columns have type and description</check>
      <check>Foreign keys have on_delete behavior</check>
      <check>Indexes are defined for query patterns</check>
      <check>No placeholders (TBD, TODO)</check>
    </validation>
    <on_fail>
      <prompt lang="ja">以下を明確にしてください：</prompt>
      <list_issues/>
      <goto>gather_info</goto>
    </on_fail>
  </step>

  <step id="save">
    <bash>./scripts/blueprint-db-cli.sh add data tables {slug} '{name}' '{content}'</bash>
    <bash>./scripts/blueprint-db-cli.sh status {id} pending_review</bash>
  </step>
</workflow>

---

## Define Seeder

<workflow name="define_seeder">
  <note>Seeders use static data (NO factory, NO faker). Same seeder for dev and test.</note>

  <step id="gather_info">
    <prompt lang="ja">「{table_name}」のダミーデータについて教えてください</prompt>
    <questions>
      <question>どんな種類のデータが必要？ / What types of records?</question>
      <question>Admin/通常ユーザーなど役割別に必要？ / Need different roles?</question>
      <question>何件くらい？ / How many records?</question>
    </questions>
  </step>

  <step id="generate_spec">
    <action>Generate seeder spec in required format</action>
  </step>

  <required_content>
    ```markdown
    # Seeder: {table_name}

    ## Target Table
    - Table: {table_name}
    - Model: {ModelName}
    - Depends on: [list of parent seeders that must run first]

    ## Records
    | ID | Purpose | Key Fields |
    |----|---------|------------|
    | 1 | Admin user for testing admin features | name: "Admin", role: "admin" |
    | 2 | Regular user for testing user flows | name: "User", role: "user" |
    | 3 | Inactive user for edge case testing | is_active: false |

    ## Record Details

    ### Record 1: Admin
    ```php
    [
        'id' => 1,
        'name' => 'Admin',
        'email' => 'admin@example.com',
        'password' => Hash::make('password'),
        'role' => 'admin',
        'is_active' => true,
    ]
    ```

    ### Record 2: Regular User
    ```php
    [
        'id' => 2,
        'name' => 'Test User',
        'email' => 'user@example.com',
        'password' => Hash::make('password'),
        'role' => 'user',
        'is_active' => true,
    ]
    ```

    ## Wave
    - Wave number: {n} (based on FK dependencies)

    ## Notes
    - Development: `php artisan db:seed`
    - Testing: Same seeder used in test setup
    ```
  </required_content>

  <rules>
    <rule>NO factory() - all records explicitly defined</rule>
    <rule>NO faker() - all values are static</rule>
    <rule>Fixed IDs required when other seeders reference this table</rule>
    <rule>Each record needs a clear purpose comment</rule>
    <rule>Minimal but sufficient records for dev/test scenarios</rule>
  </rules>

  <step id="quality_check">
    <validation>
      <check>Target table and model specified</check>
      <check>Dependencies (parent seeders) listed</check>
      <check>Each record has ID, purpose, and key fields</check>
      <check>Record details show exact PHP array</check>
      <check>Wave number assigned based on dependencies</check>
      <check>No factory() or fake() in record details</check>
    </validation>
    <on_fail>
      <prompt lang="ja">以下を明確にしてください：</prompt>
      <list_issues/>
      <goto>gather_info</goto>
    </on_fail>
  </step>

  <step id="save">
    <bash>./scripts/blueprint-db-cli.sh add data seeders {slug} '{name}' '{content}'</bash>
    <bash>./scripts/blueprint-db-cli.sh status {id} pending_review</bash>
    <!-- Set dependency: seeder depends on its table -->
    <bash>./scripts/blueprint-db-cli.sh add-dep {seeder_id} {table_id}</bash>
  </step>
</workflow>

---

## Review Data Specs

<workflow name="review_data_specs">
  <step id="get_pending">
    <bash>./scripts/blueprint-db-cli.sh sql "SELECT * FROM specs WHERE category='data' AND status='pending_review'"</bash>
  </step>

  <loop for_each="pending_specs" item="spec">
    <step id="show_spec">
      <action>Display full spec content</action>
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

  <step id="completion">
    <conditional>
      <branch condition="all_data_approved">
        <message lang="ja">
データベース定義が完了しました！

次のステップ:
- UI仕様を追加: `/blueprint` で ui/pages を定義
- 実装開始: `/hub` でコード生成
        </message>
      </branch>
    </conditional>
  </step>
</workflow>

---

## CLI Reference

```bash
# Check data specs
./scripts/blueprint-db-cli.sh list data
./scripts/blueprint-db-cli.sh list data tables
./scripts/blueprint-db-cli.sh list data seeders

# Get specific spec
./scripts/blueprint-db-cli.sh get data tables users
./scripts/blueprint-db-cli.sh get data seeders users

# Progress
./scripts/blueprint-db-cli.sh sql "SELECT type, status, COUNT(*) FROM specs WHERE category='data' GROUP BY type, status"
```

---

## Interaction Language

Same as `/blueprint`: Default Japanese, configurable via `.blueprint-language`.

```bash
cat .blueprint-language 2>/dev/null || echo "ja"
```

Spec content is ALWAYS in English.
