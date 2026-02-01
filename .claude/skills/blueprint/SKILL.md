---
name: blueprint
description: Interactive spec management with human-in-the-loop workflow. Guides through Overview → Features → Definition → Review flow.
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# Blueprint Spec Manager

Human-in-the-loop spec management. Guides through complete app definition flow.

## Language Setting

**Default: 日本語 (Japanese)**

Check `.blueprint-language` file for current setting:
```bash
cat .blueprint-language 2>/dev/null || echo "ja"
```

To change: `/blueprint lang en` or `/blueprint lang ja`

All AskUserQuestion prompts, labels, and descriptions should use the configured language.

---

## Command Routing

Parse command argument:
- `/blueprint init` → Initialize blueprint-flow in project
- `/blueprint develop` → Develop/improve blueprint-flow framework
- `/blueprint pull` → Pull latest blueprint-flow from remote
- `/blueprint lang {ja|en}` → Set interaction language
- `/blueprint` (no args) → **Guided Spec Flow** (main flow)

---

## Guided Spec Flow (Main Command)

<workflow name="guided_flow">
  <config>
    <language_file>.blueprint-language</language_file>
    <default_language>ja</default_language>
  </config>

  <step id="init_check">
    <bash>./scripts/blueprint-db-cli.sh overview 2>/dev/null || ./scripts/blueprint-db-cli.sh init</bash>
    <action>Load current language setting</action>
  </step>

  <step id="detect_phase">
    <description>Analyze current state to determine which phase to resume</description>
    <bash>./scripts/blueprint-db-cli.sh progress</bash>
    <logic>
      - No specs exist → Start from Overview
      - Overview exists but no features → Feature Listing phase
      - Features exist but some are draft → Definition phase
      - All features defined, some pending_review → Review phase
      - All approved → Ready for /hub
    </logic>
  </step>

  <step id="show_status_and_ask">
    <action>Show current progress summary</action>
    <prompt lang="ja">現在の状況です。どうしますか？</prompt>
    <prompt lang="en">Current status. What would you like to do?</prompt>
    <options>
      <option id="continue">
        <label lang="ja">続きから進める (推奨)</label>
        <label lang="en">Continue from current phase (Recommended)</label>
        <description>Resume the guided flow</description>
      </option>
      <option id="overview">
        <label lang="ja">概要を編集</label>
        <label lang="en">Edit Overview</label>
        <description>Modify app overview</description>
      </option>
      <option id="features">
        <label lang="ja">機能リストを編集</label>
        <label lang="en">Edit Feature List</label>
        <description>Add/modify features</description>
      </option>
      <option id="define">
        <label lang="ja">機能を詳細定義</label>
        <label lang="en">Define Features</label>
        <description>Define spec details</description>
      </option>
      <option id="review">
        <label lang="ja">レビュー</label>
        <label lang="en">Review Specs</label>
        <description>Review pending specs</description>
      </option>
    </options>
  </step>

  <conditional id="route_phase">
    <branch condition="continue">
      <goto>detected_phase</goto>
    </branch>
    <branch condition="overview">
      <goto>overview_phase</goto>
    </branch>
    <branch condition="features">
      <goto>feature_list_phase</goto>
    </branch>
    <branch condition="define">
      <goto>definition_phase</goto>
    </branch>
    <branch condition="review">
      <goto>review_phase</goto>
    </branch>
  </conditional>
</workflow>

---

## Phase 1: Overview (アプリ概要)

<workflow name="overview_phase">
  <step id="check_existing">
    <bash>./scripts/blueprint-db-cli.sh get core overview app 2>/dev/null</bash>
    <conditional>
      <branch condition="exists">
        <action>Show current overview</action>
        <prompt lang="ja">概要を更新しますか？</prompt>
        <prompt lang="en">Update the overview?</prompt>
      </branch>
      <branch condition="not_exists">
        <goto>gather_overview</goto>
      </branch>
    </conditional>
  </step>

  <step id="gather_overview">
    <prompt lang="ja">アプリの概要を教えてください</prompt>
    <prompt lang="en">Tell me about your app</prompt>
    <questions>
      <question id="app_name">
        <label lang="ja">アプリ名</label>
        <label lang="en">App Name</label>
      </question>
      <question id="description">
        <label lang="ja">アプリの説明（何をするアプリ？）</label>
        <label lang="en">App Description (What does it do?)</label>
      </question>
      <question id="target_users">
        <label lang="ja">ターゲットユーザー</label>
        <label lang="en">Target Users</label>
      </question>
      <question id="user_roles">
        <label lang="ja">ユーザー種別（例: admin, user, guest）</label>
        <label lang="en">User Roles (e.g., admin, user, guest)</label>
      </question>
      <question id="main_features">
        <label lang="ja">主要な機能（箇条書きで）</label>
        <label lang="en">Main Features (bullet points)</label>
      </question>
    </questions>
  </step>

  <step id="save_overview">
    <action>Generate JSON from answers</action>
    <action>Preview to user</action>
    <bash>./scripts/blueprint-db-cli.sh add core overview app '{app_name}' '{json}'</bash>
    <bash>./scripts/blueprint-db-cli.sh status {id} pending_review</bash>
  </step>

  <step id="next">
    <prompt lang="ja">概要を保存しました。機能リストの作成に進みますか？</prompt>
    <prompt lang="en">Overview saved. Proceed to feature listing?</prompt>
    <options>
      <option>
        <label lang="ja">はい、進める</label>
        <label lang="en">Yes, continue</label>
        <goto>feature_list_phase</goto>
      </option>
      <option>
        <label lang="ja">いいえ、後で</label>
        <label lang="en">No, later</label>
        <action>Exit</action>
      </option>
    </options>
  </step>
</workflow>

---

## Phase 2: Feature Listing (機能リストアップ)

<workflow name="feature_list_phase">
  <step id="load_overview">
    <bash>./scripts/blueprint-db-cli.sh get core overview app</bash>
    <action>Extract main_features from overview</action>
  </step>

  <step id="show_extracted">
    <action>Display features extracted from overview</action>
    <prompt lang="ja">概要から以下の機能を抽出しました。追加・修正はありますか？</prompt>
    <prompt lang="en">Extracted these features from overview. Add or modify?</prompt>
  </step>

  <step id="categorize_features">
    <description>For each feature, determine category and type</description>
    <mapping>
      <pattern match="一覧|リスト|list|index">
        <category>ui</category>
        <type>pages</type>
        <suffix>_list</suffix>
      </pattern>
      <pattern match="詳細|detail|show">
        <category>ui</category>
        <type>pages</type>
        <suffix>_detail</suffix>
      </pattern>
      <pattern match="作成|登録|create|add">
        <category>ui</category>
        <type>pages</type>
        <suffix>_create</suffix>
      </pattern>
      <pattern match="編集|更新|edit|update">
        <category>ui</category>
        <type>pages</type>
        <suffix>_edit</suffix>
      </pattern>
      <pattern match="テーブル|モデル|table|model">
        <category>data</category>
        <type>tables</type>
      </pattern>
      <pattern match="通知|メール|notification|email">
        <category>action</category>
        <type>async</type>
      </pattern>
      <pattern match="定期|スケジュール|cron|scheduled">
        <category>action</category>
        <type>scheduled</type>
      </pattern>
    </mapping>
  </step>

  <step id="confirm_features">
    <action>Show categorized feature list as table</action>
    <prompt lang="ja">この機能リストでよいですか？</prompt>
    <prompt lang="en">Is this feature list correct?</prompt>
    <options>
      <option>
        <label lang="ja">はい、このまま進める</label>
        <label lang="en">Yes, proceed</label>
      </option>
      <option>
        <label lang="ja">機能を追加</label>
        <label lang="en">Add feature</label>
        <goto>add_feature</goto>
      </option>
      <option>
        <label lang="ja">機能を修正</label>
        <label lang="en">Modify feature</label>
        <goto>modify_feature</goto>
      </option>
    </options>
  </step>

  <step id="save_features">
    <loop for_each="features">
      <bash>./scripts/blueprint-db-cli.sh add {category} {type} {slug} '{name}' '{minimal_json}'</bash>
      <note>Save with minimal JSON (just name/description), details added in Definition phase</note>
    </loop>
  </step>

  <step id="setup_dependencies">
    <description>Auto-detect and set dependencies</description>
    <logic>
      - UI pages depend on their data tables
      - Actions depend on related models
      - Detail/Edit pages depend on List page
    </logic>
    <loop for_each="specs_with_deps">
      <bash>./scripts/blueprint-db-cli.sh add-dep {spec_id} {blocked_by_id}</bash>
    </loop>
  </step>

  <step id="next">
    <prompt lang="ja">機能リストを保存しました。詳細定義に進みますか？</prompt>
    <prompt lang="en">Feature list saved. Proceed to detailed definition?</prompt>
    <goto>definition_phase</goto>
  </step>
</workflow>

---

## Phase 3: Definition (詳細定義)

<workflow name="definition_phase">
  <step id="get_undefined">
    <bash>./scripts/blueprint-db-cli.sh list-by-status draft</bash>
    <action>Filter specs that need detailed definition</action>
    <output>specs_to_define[]</output>
  </step>

  <step id="show_progress">
    <action>Show definition progress: X/Y specs defined</action>
  </step>

  <loop for_each="specs_to_define" item="spec">
    <step id="show_spec">
      <action>Display current spec: {spec.name}</action>
      <prompt lang="ja">「{spec.name}」を詳細定義します</prompt>
      <prompt lang="en">Defining "{spec.name}" in detail</prompt>
    </step>

    <conditional id="definition_by_type">
      <branch condition="type=tables">
        <goto>define_table</goto>
      </branch>
      <branch condition="type=pages">
        <goto>define_page</goto>
      </branch>
      <branch condition="type=partials">
        <goto>define_partial</goto>
      </branch>
      <branch condition="type=sync|async|scheduled">
        <goto>define_action</goto>
      </branch>
      <branch condition="type=seeders">
        <goto>define_seeder</goto>
      </branch>
    </conditional>

    <step id="confirm_definition">
      <action>Show generated JSON</action>
      <prompt lang="ja">この定義でよいですか？</prompt>
      <prompt lang="en">Is this definition correct?</prompt>
      <options>
        <option>
          <label lang="ja">はい、保存して次へ</label>
          <label lang="en">Yes, save and continue</label>
        </option>
        <option>
          <label lang="ja">修正する</label>
          <label lang="en">Modify</label>
          <goto>definition_by_type</goto>
        </option>
        <option>
          <label lang="ja">スキップ（後で定義）</label>
          <label lang="en">Skip (define later)</label>
        </option>
      </options>
    </step>

    <step id="save_definition">
      <bash>./scripts/blueprint-db-cli.sh update {spec.id} '{detailed_json}'</bash>
      <bash>./scripts/blueprint-db-cli.sh status {spec.id} pending_review</bash>
    </step>
  </loop>

  <step id="all_defined">
    <prompt lang="ja">全ての機能を定義しました。レビューに進みますか？</prompt>
    <prompt lang="en">All features defined. Proceed to review?</prompt>
    <goto>review_phase</goto>
  </step>
</workflow>

---

### Define Table (テーブル定義)

<workflow name="define_table">
  <step id="ask_columns">
    <prompt lang="ja">テーブルのカラムを教えてください</prompt>
    <prompt lang="en">What columns does this table have?</prompt>
    <guide>
      Example: name (string), email (string, unique), status (enum: active/inactive)
    </guide>
  </step>

  <step id="ask_relations">
    <prompt lang="ja">他のテーブルとの関連はありますか？</prompt>
    <prompt lang="en">Are there relationships with other tables?</prompt>
    <options multiSelect="true">
      <option>belongsTo (親テーブル)</option>
      <option>hasMany (子テーブル)</option>
      <option>belongsToMany (多対多)</option>
      <option>なし / None</option>
    </options>
  </step>

  <step id="ask_features">
    <prompt lang="ja">追加機能は？</prompt>
    <prompt lang="en">Additional features?</prompt>
    <options multiSelect="true">
      <option>timestamps (created_at, updated_at)</option>
      <option>soft_delete (deleted_at)</option>
      <option>uuid (ID as UUID)</option>
    </options>
  </step>

  <step id="generate_json">
    <output>
      {
        "columns": [...],
        "relations": [...],
        "timestamps": true/false,
        "soft_delete": true/false
      }
    </output>
  </step>
</workflow>

---

### Define Page (ページ定義)

<workflow name="define_page">
  <step id="ask_route">
    <prompt lang="ja">ルート（URL）は？</prompt>
    <prompt lang="en">What is the route (URL)?</prompt>
    <example>/users, /projects/{project}/tasks</example>
  </step>

  <step id="ask_auth">
    <prompt lang="ja">認証は必要ですか？</prompt>
    <prompt lang="en">Does it require authentication?</prompt>
    <options>
      <option>
        <label lang="ja">はい、ログイン必須</label>
        <label lang="en">Yes, login required</label>
      </option>
      <option>
        <label lang="ja">いいえ、公開ページ</label>
        <label lang="en">No, public page</label>
      </option>
    </options>
  </step>

  <step id="ask_roles" condition="auth=true">
    <prompt lang="ja">アクセス可能なロールは？</prompt>
    <prompt lang="en">Which roles can access?</prompt>
    <options multiSelect="true">
      <option>admin</option>
      <option>user</option>
      <option>guest</option>
    </options>
  </step>

  <step id="ask_sections">
    <prompt lang="ja">ページの構成要素は？（セクション）</prompt>
    <prompt lang="en">What sections does the page have?</prompt>
    <guide>
      Examples:
      - header: Page title and actions
      - filter: Search/filter form
      - table: Data table with pagination
      - form: Input form
      - card_grid: Grid of cards
    </guide>
  </step>

  <step id="ask_actions">
    <prompt lang="ja">ユーザーアクションは？</prompt>
    <prompt lang="en">What user actions are available?</prompt>
    <guide>
      Examples:
      - create: Open create modal
      - edit: Edit item
      - delete: Delete with confirmation
      - export: Export to CSV
    </guide>
  </step>

  <step id="generate_json">
    <output>
      {
        "route": "...",
        "layout": "app",
        "auth": true/false,
        "roles": [...],
        "sections": [...],
        "actions": [...]
      }
    </output>
  </step>
</workflow>

---

### Define Action (アクション定義)

<workflow name="define_action">
  <step id="ask_purpose">
    <prompt lang="ja">このアクションは何をしますか？</prompt>
    <prompt lang="en">What does this action do?</prompt>
  </step>

  <step id="ask_input">
    <prompt lang="ja">入力パラメータは？</prompt>
    <prompt lang="en">What are the input parameters?</prompt>
    <guide>name (string, required), email (string, required), age (int, optional)</guide>
  </step>

  <step id="ask_output">
    <prompt lang="ja">戻り値は？</prompt>
    <prompt lang="en">What is the return value?</prompt>
    <options>
      <option>Model instance</option>
      <option>Boolean (success/failure)</option>
      <option>Array/Collection</option>
      <option>void (nothing)</option>
    </options>
  </step>

  <step id="ask_events">
    <prompt lang="ja">発火するイベントは？</prompt>
    <prompt lang="en">What events should be dispatched?</prompt>
    <example>UserCreated, OrderPlaced</example>
  </step>

  <step id="generate_json">
    <output>
      {
        "name": "...",
        "description": "...",
        "input": [...],
        "output": {...},
        "events": [...]
      }
    </output>
  </step>
</workflow>

---

## Phase 4: Review (レビュー)

<workflow name="review_phase">
  <step id="get_pending">
    <bash>./scripts/blueprint-db-cli.sh pending-review</bash>
    <output>pending_specs[]</output>
  </step>

  <step id="show_summary">
    <action>Show pending specs count and list</action>
    <prompt lang="ja">{count}件のスペックがレビュー待ちです</prompt>
    <prompt lang="en">{count} specs pending review</prompt>
  </step>

  <loop for_each="pending_specs" item="spec">
    <step id="show_spec_detail">
      <bash>./scripts/blueprint-db-cli.sh get {spec.category} {spec.type} {spec.slug}</bash>
      <action>Display formatted spec data</action>
    </step>

    <step id="ask_decision">
      <prompt lang="ja">「{spec.name}」のレビュー結果は？</prompt>
      <prompt lang="en">Review decision for "{spec.name}"?</prompt>
      <options>
        <option id="approve">
          <label lang="ja">承認 → 実装可能に</label>
          <label lang="en">Approve → Ready for implementation</label>
        </option>
        <option id="revise">
          <label lang="ja">修正依頼</label>
          <label lang="en">Request revision</label>
        </option>
        <option id="skip">
          <label lang="ja">スキップ</label>
          <label lang="en">Skip</label>
        </option>
      </options>
    </step>

    <conditional id="handle_decision">
      <branch condition="approve">
        <bash>./scripts/blueprint-db-cli.sh status {spec.id} approved</bash>
        <bash>./scripts/blueprint-db-cli.sh reviewed {spec.id}</bash>
      </branch>
      <branch condition="revise">
        <prompt lang="ja">修正内容を教えてください</prompt>
        <prompt lang="en">What needs to be changed?</prompt>
        <bash>./scripts/blueprint-db-cli.sh revision {spec.id} '{reason}'</bash>
        <bash>./scripts/blueprint-db-cli.sh status {spec.id} needs_revision</bash>
      </branch>
      <branch condition="skip">
        <action>Continue to next</action>
      </branch>
    </conditional>
  </loop>

  <step id="review_complete">
    <bash>./scripts/blueprint-db-cli.sh progress</bash>
    <conditional>
      <branch condition="all_approved">
        <prompt lang="ja">全てのスペックが承認されました！ /hub で開発を開始できます</prompt>
        <prompt lang="en">All specs approved! You can start development with /hub</prompt>
      </branch>
      <branch condition="has_pending">
        <action>Show remaining pending/needs_revision specs</action>
      </branch>
    </conditional>
  </step>
</workflow>

---

## Language Setting Flow

<workflow name="set_language">
  <step id="save">
    <bash>echo "{lang}" > .blueprint-language</bash>
  </step>
  <step id="confirm">
    <message lang="ja">言語を日本語に設定しました</message>
    <message lang="en">Language set to English</message>
  </step>
</workflow>

---

## Status State Machine

<state_machine name="spec_status">
  <state name="draft" type="initial">
    <description>Created, needs definition</description>
    <transition to="pending_review" trigger="definition_complete"/>
  </state>

  <state name="pending_review">
    <description>Awaiting human review</description>
    <transition to="approved" trigger="human_approves"/>
    <transition to="needs_revision" trigger="human_requests_changes"/>
  </state>

  <state name="approved">
    <description>Ready for implementation</description>
    <transition to="in_progress" trigger="hub_locks"/>
  </state>

  <state name="in_progress">
    <description>Being implemented</description>
    <transition to="impl_review" trigger="coder_completes"/>
    <transition to="blocked" trigger="coder_blocked"/>
  </state>

  <state name="impl_review">
    <description>Implementation review</description>
    <transition to="testing" trigger="human_approves"/>
    <transition to="needs_revision" trigger="human_requests_changes"/>
  </state>

  <state name="testing">
    <description>E2E testing</description>
    <transition to="done" trigger="tests_pass"/>
    <transition to="needs_revision" trigger="tests_fail"/>
  </state>

  <state name="needs_revision" type="recovery">
    <description>Needs changes</description>
    <transition to="pending_review" trigger="spec_updated"/>
  </state>

  <state name="blocked" type="recovery">
    <description>Blocked by dependency</description>
    <transition to="approved" trigger="dependency_resolved"/>
  </state>

  <state name="done" type="terminal">
    <description>Complete</description>
  </state>
</state_machine>

---

## Init/Develop/Pull Flows

### Init Flow (`/blueprint init`)

<workflow name="init">
  <step id="select_stack">
    <prompt>Which stack to use?</prompt>
    <options>
      - Laravel + Livewire (Recommended): Laravel 12, Livewire 4, Tailwind 4, daisyUI 5
    </options>
  </step>

  <conditional id="check_submodule">
    <branch condition="submodule_exists">
      <bash>./.blueprint-flow/scripts/init.sh {stack}</bash>
    </branch>
    <branch condition="not_exists">
      <bash>git submodule add https://github.com/tatun55/blueprint-flow .blueprint-flow</bash>
      <bash>./.blueprint-flow/scripts/init.sh {stack}</bash>
    </branch>
  </conditional>
</workflow>

### Develop Flow (`/blueprint develop`)

For improving blueprint-flow framework itself. See SPECIFICATION.md.

### Pull Flow (`/blueprint pull`)

```bash
cd .blueprint-flow && git pull origin main && cd ..
./.blueprint-flow/scripts/update.sh
```

---

## CLI Quick Reference

```bash
# Progress & Overview
./scripts/blueprint-db-cli.sh progress
./scripts/blueprint-db-cli.sh overview

# By Status
./scripts/blueprint-db-cli.sh list-by-status draft
./scripts/blueprint-db-cli.sh pending-review
./scripts/blueprint-db-cli.sh available-with-deps

# CRUD
./scripts/blueprint-db-cli.sh add {category} {type} {slug} '{name}' '{json}'
./scripts/blueprint-db-cli.sh get {category} {type} {slug}
./scripts/blueprint-db-cli.sh update {id} '{json}'

# Status
./scripts/blueprint-db-cli.sh status {id} {status}
./scripts/blueprint-db-cli.sh reviewed {id}
./scripts/blueprint-db-cli.sh revision {id} '{reason}'

# Dependencies
./scripts/blueprint-db-cli.sh add-dep {id} {blocked_by_id}
./scripts/blueprint-db-cli.sh deps {id}
```

---

## Rules

1. **Language**: Use configured language for all prompts
2. **Resume**: Always detect current phase and offer to continue
3. **AskUserQuestion**: Use at every decision point
4. **Preview**: Show generated JSON before saving
5. **Dependencies**: Auto-detect and set during feature listing
6. **Validation**: Slugs must be lowercase with underscores only
