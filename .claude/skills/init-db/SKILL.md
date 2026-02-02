---
name: init-db
description: Database schema hub. Creates specs, analyzes FK dependencies, orchestrates parallel implementation.
allowed-tools: Bash, Read, Write, AskUserQuestion, Task
---

# Init DB - Database Schema Hub

**Hub agent for database layer.** Defines tables/seeders, analyzes dependencies, orchestrates parallel implementation.

---

## Role: DB Hub (like /hub for database)

```
/init-db (this skill)
├── Phase 1: Spec Creation (tables + seeders)
├── Phase 2: FK Dependency Analysis → Wave Assignment
└── Phase 3: Parallel Implementation via db-impl agents
```

---

## Workflow Position

```
/blueprint → /init-db → /hub
    ↓           ↓         ↓
  概要・機能   DB実装      UI実装
  UI specs    (並列)
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
  <step id="analyze_overview">
    <description>Analyze overview spec for entity information</description>
    <action>Extract entity from Features/Routes tables</action>
    <action>Identify implied columns from feature descriptions</action>
    <action>Detect relations from route patterns (e.g., /users/{user}/projects)</action>
  </step>

  <step id="detect_ambiguity">
    <description>Check if overview provides enough detail for table design</description>
    <checks>
      <check id="has_fields">Are required fields clear from feature description?</check>
      <check id="has_status">Does entity need status/state management?</check>
      <check id="has_relations">Are relations to other entities clear?</check>
      <check id="has_constraints">Are uniqueness/validation rules implied?</check>
    </checks>
  </step>

  <step id="clarify_ambiguity">
    <description>If overview is ambiguous, ask targeted questions to refine spec</description>
    <conditional>
      <branch condition="ambiguity_found">
        <prompt lang="ja">
「{table_name}」テーブルの設計にあたり、概要から読み取れない点があります：
        </prompt>
        <ask_specific_questions>
          <example issue="unclear_fields">
「{feature_name}」機能で、{entity}にはどんな情報を保存しますか？
例: 名前、メール、ステータス、作成日時など
          </example>
          <example issue="unclear_status">
「{entity}」には状態管理が必要ですか？
例: active/inactive、draft/published/archived など
          </example>
          <example issue="unclear_relation">
「{entity}」と「{other_entity}」の関係は？
- 1対多（1つの{other}に複数の{entity}）
- 多対多（中間テーブルが必要）
- 1対1
          </example>
          <example issue="unclear_ownership">
「{entity}」は誰が所有しますか？
- ユーザーごと（user_id が必要）
- 組織ごと（organisation_id が必要）
- グローバル（所有者なし）
          </example>
          <example issue="unclear_uniqueness">
「{entity}」で一意にすべき項目は？
例: メールアドレス、スラッグ、[user_id, name]の組み合わせ
          </example>
        </ask_specific_questions>
        <action>Update understanding based on user response</action>
        <goto>detect_ambiguity</goto>
      </branch>
    </conditional>
  </step>

  <step id="update_overview_if_needed">
    <description>If significant details were clarified, offer to update overview spec</description>
    <conditional>
      <branch condition="significant_new_info">
        <prompt lang="ja">
新しい情報が得られました。概要（core/overview）も更新しますか？
- 機能説明に詳細を追加
- ルート定義を修正
        </prompt>
        <options>
          <option id="update">はい、概要も更新 / Yes, update overview</option>
          <option id="skip">いいえ、テーブル定義のみ / No, table spec only</option>
        </options>
        <on_update>
          <bash>./scripts/blueprint-db-cli.sh get core overview app</bash>
          <action>Merge new details into overview</action>
          <bash>./scripts/blueprint-db-cli.sh update {overview_id} '{updated_content}'</bash>
        </on_update>
      </branch>
    </conditional>
  </step>

  <step id="generate_spec">
    <action>Generate table spec in required format with all clarified details</action>
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
      <prompt lang="ja">テーブル定義に不足があります：</prompt>
      <list_issues/>
      <goto>clarify_ambiguity</goto>
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

  <step id="analyze_table_and_overview">
    <description>Analyze table spec and overview to determine seeder needs</description>
    <action>Read table spec for columns and relations</action>
    <action>Check overview for user roles and test scenarios</action>
    <action>Identify FK dependencies (which seeders must run first)</action>
  </step>

  <step id="infer_records">
    <description>Infer necessary records from context</description>
    <inferences>
      <inference context="user_roles_in_overview">
        If overview defines admin/user roles → need admin and regular user records
      </inference>
      <inference context="status_column">
        If table has status column → need records for each status value
      </inference>
      <inference context="feature_scenarios">
        If feature mentions "approval flow" → need approver and submitter records
      </inference>
      <inference context="fk_relations">
        If table has user_id FK → records need valid user IDs from UserSeeder
      </inference>
    </inferences>
  </step>

  <step id="clarify_seeder_needs">
    <description>Ask targeted questions if test scenarios are unclear</description>
    <conditional>
      <branch condition="unclear_scenarios">
        <prompt lang="ja">
「{table_name}」のテストデータについて確認させてください：
        </prompt>
        <ask_specific_questions>
          <example issue="unclear_user_types">
どんな種類の{entity}が必要ですか？
例: 管理者用、一般ユーザー用、テスト用の無効データ
          </example>
          <example issue="unclear_test_scenarios">
この機能のテストでどんなケースを試しますか？
例: 正常系、権限エラー、バリデーションエラー
          </example>
          <example issue="unclear_relations">
{parent_entity}との関連で、どの{parent}に紐づけますか？
（{ParentSeeder}のID: 1=Admin, 2=User を参照）
          </example>
          <example issue="unclear_quantity">
何件くらいのデータが開発・テストに必要ですか？
最小限（2-3件）で十分か、一覧ページのテスト用に多め（10件以上）か
          </example>
        </ask_specific_questions>
        <action>Update understanding based on user response</action>
      </branch>
    </conditional>
  </step>

  <step id="generate_spec">
    <action>Generate seeder spec with all clarified details</action>
    <action>Ensure FK references match actual IDs from parent seeders</action>
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
      <check>FK values reference valid IDs from parent seeders</check>
    </validation>
    <on_fail>
      <prompt lang="ja">シーダー定義に不足があります：</prompt>
      <list_issues/>
      <goto>clarify_seeder_needs</goto>
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
        <goto>analyze_dependencies</goto>
      </branch>
    </conditional>
  </step>
</workflow>

---

## Phase 2: FK Dependency Analysis

<workflow name="analyze_dependencies">
  <step id="extract_fk_relations">
    <description>Parse all table specs for foreign key relationships</description>
    <bash>./scripts/blueprint-db-cli.sh list data tables</bash>
    <action>For each table spec, extract Relations section</action>
    <action>Build dependency graph: table → [depends_on_tables]</action>
  </step>

  <step id="assign_waves">
    <description>Topological sort to determine execution order</description>
    <logic>
      Wave 1: Tables with no FK dependencies (independent)
      Wave 2: Tables depending only on Wave 1 tables
      Wave 3: Tables depending on Wave 1 or 2 tables
      ... and so on
    </logic>
    <example>
      categories: no FK → Wave 1
      users: no FK → Wave 1
      todos: FK to categories, users → Wave 2
      comments: FK to todos, users → Wave 3
    </example>
  </step>

  <step id="show_execution_plan">
    <prompt lang="ja">
以下の順序で実装します：

Wave 1 (並列実行):
- {table1}: 依存なし
- {table2}: 依存なし

Wave 2 (Wave 1完了後、並列実行):
- {table3}: {table1}, {table2} に依存

実装を開始しますか？
    </prompt>
    <options>
      <option id="execute">実行 / Execute</option>
      <option id="cancel">キャンセル / Cancel</option>
    </options>
  </step>

  <conditional>
    <branch condition="execute">
      <goto>parallel_implementation</goto>
    </branch>
  </conditional>
</workflow>

---

## Phase 3: Parallel Implementation

<workflow name="parallel_implementation">
  <step id="execute_waves">
    <loop for_each="waves" item="wave">
      <step id="spawn_agents">
        <description>Spawn db-impl agent for each table in wave (PARALLEL)</description>
        <action>
          For each table in wave.tables:
            Task(
              subagent_type: "general-purpose",
              prompt: "You are db-impl agent. Read .claude/agents/db-impl.md and execute for table: {table}, table_spec_id: {id}, seeder_spec_id: {seeder_id}",
              run_in_background: false  // Wait for wave completion
            )
        </action>
        <note>Use single message with multiple Task tool calls for parallelism</note>
      </step>

      <step id="wait_for_wave">
        <description>All agents in wave must complete before next wave</description>
        <validation>
          <check>All agents returned success</check>
          <check>All files created</check>
        </validation>
        <on_fail>
          <action>Log failed tables</action>
          <action>Skip dependent tables in later waves</action>
        </on_fail>
      </step>
    </loop>
  </step>

  <step id="run_migrations">
    <bash>php artisan migrate:fresh</bash>
    <on_fail>
      <prompt lang="ja">マイグレーションが失敗しました。エラーを確認してください。</prompt>
    </on_fail>
  </step>

  <step id="update_database_seeder">
    <description>Add all seeders to DatabaseSeeder.php in wave order</description>
    <action>Edit database/seeders/DatabaseSeeder.php</action>
    <action>Add $this->call([...]) with seeders in dependency order</action>
  </step>

  <step id="run_seeders">
    <bash>php artisan db:seed</bash>
    <on_fail>
      <prompt lang="ja">シーダーが失敗しました。エラーを確認してください。</prompt>
    </on_fail>
  </step>

  <step id="completion">
    <message lang="ja">
✅ データベース実装が完了しました！

作成されたファイル:
{list_created_files}

次のステップ:
- `/hub` でUI実装を開始
- `/e2e` でテストを実行
    </message>
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
