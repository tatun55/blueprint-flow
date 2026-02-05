# Blueprint Skill

仕様策定・テスト設計・実装オーケストレーション・修正サイクル管理

**上流工程のみ担当。コードの知識を一切持たない。**

---

## tall-daisy スタック（CRITICAL）

このスキルは tall-daisy スタック専用。overviewやspec作成時は必ずこのスタックを使用する。

```
Laravel 12
Livewire 4
Tailwind CSS 4
daisyUI 5
Alpine.js 3
PHP 8.3+
MySQL 8.0+  ← SQLiteではない
```

**重要**: データベースは MySQL 8.0+ 固定。SQLite は使用しない。

---

## 開発環境（CRITICAL）

### アプリは Valet で常時起動中

```bash
# APP_URL でアクセス可能（.env で定義）
APP_URL=$(grep APP_URL .env | cut -d '=' -f2)
```

**重要**:
- `php artisan serve` は使用しない（Valetが動作中）
- アプリへのアクセスは常に APP_URL を使用
- E2Eテストも APP_URL でアクセス

### Vite (フロントエンド)

開発時は Vite dev server が必要：
```bash
npm run dev  # Vite dev server 起動
```

Vite が起動していないと CSS/JS が読み込まれない。

---

## サブコマンド

### `/bpf pull`

blueprint-flowサブモジュールを最新版に更新する。

```bash
cd .blueprint-flow && git pull origin main && cd ..
./.blueprint-flow/scripts/update.sh
```

### `/bpf push`

blueprint-flowサブモジュールへの変更をリモートにpushする。

```bash
git -C .blueprint-flow add -A
git -C .blueprint-flow commit -m "説明"
git -C .blueprint-flow push origin main
git add .blueprint-flow && git commit -m "Update blueprint-flow submodule"
```

---

## 引数なしの場合

1. プロジェクト状況を確認
```bash
DB="blueprint/blueprint.db"
sqlite3 -json $DB "SELECT id, category, type, slug, name, status, human_reviewed FROM specs ORDER BY id"
sqlite3 -json $DB "SELECT * FROM progress_summary"
```

2. 状況を分析して推奨アクションを提示
   - spec が 0件 → 新規プロジェクト開始フローへ
   - draft が多い → 「仕様策定を続けますか？」
   - pending_review が多い → 「レビュー待ちが N件あります」
   - approved が多い → 「実装を開始できます」
   - in_progress が多い → 「実装中のspecがN件あります」
   - testing 待ち → 「テストが必要なspecがN件あります」

## 引数ありの場合

`$ARGUMENTS` を解釈して適切なアクションを実行:

1. 仕様策定の指示 → spec作成フローへ
2. 実装の指示 → オーケストレーションフローへ
3. テストの指示 → テストオーケストレーションへ

---

## Category/Type 定義

```
Categories: core, data, ui, action, test

Types:
  - core: overview, const
  - data: tables (シーダー定義を含む)
  - ui: pages, partials, layouts
  - action: sync, async, scheduled
  - test: unit, feature, e2e (level 1-3)
```

### Test Spec 構造（E2E）

```json
{
  "level": 1,
  "depends_on": ["ui/pages/todo-index"],
  "target": {
    "type": "page",
    "url": "/todos",
    "component": "App\\Pages\\TodoIndex"
  },
  "screenshot_prefix": "050-todo",
  "scenarios": [
    {
      "name": "page-load",
      "description": "Todoページが正しく表示される",
      "auth": 3,
      "steps": [
        { "action": "goto", "url": "/todos" },
        { "action": "wait", "state": "networkidle" }
      ],
      "assertions": [
        { "type": "visible", "selector": "h1", "text": "タスク一覧" },
        { "type": "visible", "selector": ".task-list" },
        { "type": "count", "selector": ".task-item", "min": 1 }
      ],
      "screenshots": [
        { "state": "list", "description": "タスク一覧ページ全体", "fullPage": true }
      ]
    },
    {
      "name": "add-task",
      "description": "新しいタスクを追加できる",
      "auth": 3,
      "steps": [
        { "action": "goto", "url": "/todos" },
        { "action": "fill", "selector": "input[wire\\:model='newTask']", "value": "新しいタスク" },
        { "action": "click", "selector": "button:has-text('追加')" },
        { "action": "wait", "state": "networkidle" }
      ],
      "assertions": [
        { "type": "visible", "selector": ".task-item", "text": "新しいタスク" },
        { "type": "value", "selector": "input[wire\\:model='newTask']", "expected": "" }
      ],
      "screenshots": [
        { "state": "added", "description": "タスク追加後の一覧", "fullPage": true }
      ]
    }
  ]
}
```

### Scenario フィールド定義

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `name` | Yes | シナリオ識別子（kebab-case） |
| `description` | Yes | 何をテストするか（テスト名になる） |
| `auth` | No | ログインユーザーID（1=superadmin, 2=admin, 3=user1, 4=user2）。省略時=未認証 |
| `steps` | No | 操作手順の配列。action + selector/url/value で記述 |
| `assertions` | Yes | 検証項目の配列。type + selector/text/expected で記述 |
| `screenshots` | No | スクショ定義。state（ファイル名suffix）+ description + fullPage |

### Screenshot パス規則

`tests/e2e/screenshots/{screenshot_prefix}-{state}.png`

例: `screenshot_prefix: "050-todo"`, `state: "list"` → `tests/e2e/screenshots/050-todo-list.png`

**Test Levels:**

| Level | Coverage | Content |
|-------|----------|---------|
| 1 | 20-40% | 基本操作（表示、主要アクション） |
| 2 | 40-60% | 追加操作（フォーム、モーダル） |
| 3 | 60%+ | 全状態・エッジケース（エラー、空状態） |

---

## Spec テンプレート

### data/tables テンプレート

```sql
INSERT INTO specs (category, type, slug, name, data) VALUES (
  'data', 'tables', 'tasks', 'tasksテーブル',
  '{"columns":[{"name":"id","type":"bigint","primary":true},{"name":"title","type":"string","nullable":false,"max":255},{"name":"completed","type":"boolean","default":false},{"name":"timestamps","type":"timestamps"}],"indexes":[],"relations":[],"seeders":{"dev":[{"_comment":"基本状態","title":"買い物に行く","completed":false},{"_comment":"完了状態","title":"レポートを書く","completed":true}]}}'
);
```

### ui/pages テンプレート

```sql
INSERT INTO specs (category, type, slug, name, data, e2e_status) VALUES (
  'ui', 'pages', 'todo-index', 'Todoメインページ',
  '{"route":"/","component":"Pages/TodoIndex","depends_on":["data/tables/tasks"],"layout_ascii":"...","operations":["一覧表示","新規作成","完了切替","削除"]}',
  'pending'
);
-- 依存関係を追加
INSERT INTO spec_dependencies (spec_id, blocked_by_spec_id) VALUES (2, 1);
```

### test/feature テンプレート（CRITICAL: agentにタスクを渡す前に作成）

```sql
INSERT INTO specs (category, type, slug, name, data) VALUES (
  'test', 'feature', 'todo-index', 'Todoページ Featureテスト',
  '{"level":1,"depends_on":["ui/pages/todo-index"],"target":{"component":"App\\Livewire\\Pages\\TodoIndex"},"scenarios":[{"name":"display","description":"コンポーネントが表示される","assertions":["status 200","タスク一覧が表示"]},{"name":"add-task","description":"タスクを追加できる","assertions":["DBに保存される","一覧に表示される"]}]}'
);
```

### test/e2e テンプレート

```sql
INSERT INTO specs (category, type, slug, name, data) VALUES (
  'test', 'e2e', 'todo-index', 'Todoページ E2Eテスト',
  json('{
    "level": 1,
    "depends_on": ["ui/pages/todo-index"],
    "target": {"type": "page", "url": "/todos", "component": "App\\Pages\\TodoIndex"},
    "screenshot_prefix": "050-todo",
    "scenarios": [
      {
        "name": "page-load",
        "description": "Todoページが正しく表示される",
        "auth": 3,
        "steps": [
          {"action": "goto", "url": "/todos"},
          {"action": "wait", "state": "networkidle"}
        ],
        "assertions": [
          {"type": "visible", "selector": "h1", "text": "タスク一覧"},
          {"type": "visible", "selector": ".task-list"}
        ],
        "screenshots": [
          {"state": "list", "description": "タスク一覧ページ全体", "fullPage": true}
        ]
      },
      {
        "name": "add-task",
        "description": "新しいタスクを追加できる",
        "auth": 3,
        "steps": [
          {"action": "goto", "url": "/todos"},
          {"action": "fill", "selector": "input[wire\\\\:model=newTask]", "value": "新しいタスク"},
          {"action": "click", "selector": "button:has-text(追加)"},
          {"action": "wait", "state": "networkidle"}
        ],
        "assertions": [
          {"type": "visible", "selector": ".task-item", "text": "新しいタスク"}
        ],
        "screenshots": [
          {"state": "added", "description": "タスク追加後の一覧", "fullPage": true}
        ]
      }
    ]
  }')
);
```

### test/unit テンプレート（action spec がある場合に作成）

```sql
INSERT INTO specs (category, type, slug, name, data) VALUES (
  'test', 'unit', 'create-task', 'CreateTask Unitテスト',
  '{"level":1,"depends_on":["action/sync/create-task"],"target":{"class":"App\\Actions\\CreateTask"},"scenarios":[{"name":"execute","description":"タスクを作成できる","assertions":["Task が作成される","イベントが発火する"]},{"name":"validation","description":"バリデーションが機能する","assertions":["空のtitleでエラー"]}]}'
);
```

**重要**: /bpf は agentにタスクを渡す前に、対応する test/feature または test/unit の spec を作成すること。agentはこの spec を参照してテストコードを作成する。

---

## 新規プロジェクト開始フロー

specが0件の場合:

<new-project-flow>
  <principle>
    各specアイテムをDB登録する前に、必ずAskUserQuestionで確認する。
  </principle>

  <step name="1-collect-info">
    <action>プロジェクト情報を収集</action>
    <method>AskUserQuestion</method>
    <questions>
      <question>アプリの種類は？（シンプル / 認証あり / チーム共有型）</question>
      <question>主要機能は？（CRUD基本 / +カテゴリ機能 / +検索機能 / カスタム）</question>
    </questions>
  </step>

  <step name="2-create-overview">
    <action>overview spec を作成（まだDB登録しない）</action>
  </step>

  <step name="3-confirm-overview">
    <action>AskUserQuestion で overview を確認</action>
    <on-approve>DB登録 → approved</on-approve>
  </step>

  <step name="4-expand-features">
    <action>featuresに基づいて詳細specを順次作成</action>
    <for-each feature="features">
      <sub-step name="4a-tables">
        <action>data/tables spec を作成（カラム + シーダー）</action>
        <method>AskUserQuestion でカラム定義とシーダーデータを確認</method>
      </sub-step>
      <sub-step name="4b-pages">
        <action>ui/pages spec を作成</action>
        <method>AskUserQuestion でASCIIアートレイアウトを確認</method>
      </sub-step>
      <sub-step name="4c-feature-tests">
        <action>test/feature spec を作成（Level 1: 基本操作テスト）</action>
        <note>ui/pages に対応するFeatureテストの設計</note>
        <method>AskUserQuestion でテストシナリオを確認</method>
      </sub-step>
      <sub-step name="4d-unit-tests">
        <condition>action spec がある場合</condition>
        <action>test/unit spec を作成（Level 1: 基本ロジックテスト）</action>
        <note>action に対応するUnitテストの設計</note>
      </sub-step>
      <sub-step name="4e-e2e-tests">
        <action>test/e2e spec を作成（Level 1: 基本シナリオ）</action>
        <method>AskUserQuestion でE2Eシナリオを確認</method>
      </sub-step>
    </for-each>
  </step>

  <step name="5-orchestrate">
    <action>依存順でAgentsをbackground起動</action>
  </step>
</new-project-flow>

---

## オーケストレーションフロー（実装）

approved の spec がある場合、依存関係を解決して Agents を起動。

<orchestration-flow>
  <step name="1-get-ready-specs">
    <command>sqlite3 -json $DB "SELECT * FROM available_with_deps"</command>
    <output>依存が解決済みの approved specs</output>
  </step>

  <step name="2-group-by-wave">
    <action>依存関係に基づいて Wave に分類</action>
    <example>
      Wave 1: data/tables/* (依存なし)
      Wave 2: ui/pages/*, action/* (data に依存)
      Wave 3: test/* (ui, action に依存)
    </example>
  </step>

  <step name="3-launch-agents">
    <action>Wave ごとに Agents を background で並列起動</action>
    <method>Task tool with run_in_background: true</method>
    <mapping>
      <map category="data" type="tables" agent="db-architect" />
      <map category="ui" type="*" agent="livewire" />
      <map category="action" type="*" agent="artisan" />
      <map category="test" type="*" agent="tester" />
    </mapping>
  </step>

  <step name="4-monitor-results">
    <action>TaskOutput で結果を確認</action>
    <on-success>spec status を更新</on-success>
    <on-failure>エラー内容を分析し、修正サイクルへ</on-failure>
  </step>
</orchestration-flow>

### Agent 起動方法

```
Task tool:
  - subagent_type: "general-purpose"
  - prompt: "{agent-type}として実行: spec_id={id}"
  - run_in_background: true
  - description: "{agent-type}: {spec-slug}"
```

**例: Wave 2 を並列実行**
```
// 単一メッセージで複数の Task tool を呼び出す
Task(subagent_type="general-purpose", prompt="livewireとして実行: spec_id=3", run_in_background=true)
Task(subagent_type="general-purpose", prompt="artisanとして実行: spec_id=4", run_in_background=true)
```

---

## テストオーケストレーション

<test-orchestration>
  <step name="1-check-test-specs">
    <command>sqlite3 -json $DB "SELECT * FROM specs WHERE category='test'"</command>
  </step>

  <step name="2-verify-dependencies">
    <action>depends_on の spec が実装済み（done）か確認</action>
    <if-not-done>依存先の実装を先に完了</if-not-done>
  </step>

  <step name="3-launch-tester">
    <action>tester を background で起動（コード作成のみ、実行しない）</action>
    <prompt>testerとして実行: spec_id={id}</prompt>
    <note>tester はテストコードを作成して報告する。テストは実行しない。</note>
  </step>

  <step name="4-batch-execute">
    <action>Hub が npx playwright test で一括実行</action>
    <commands>
      npx playwright test --reporter=line            # 全テスト
      npx playwright test tests/e2e/{slug}.spec.ts   # 単一ファイル
    </commands>
    <note>
      全テストを一括実行するため、テスト間の干渉を検出しやすい。
      per-worker DB分離により各 worker が独立した DB を持つ。
    </note>
  </step>

  <step name="5-review-results">
    <action>テスト結果を確認し、失敗があれば修正サイクルへ</action>
    <on-success>spec status を impl_review に更新</on-success>
    <on-failure>
      Hub がエラー出力を分析して修正ルートを判断:
      - selector/content/timing の問題 → revision_context を test spec に書き込み → tester 再起動
      - element_missing/server_error → revision_context を impl spec に書き込み → livewire/artisan 起動
      - 判断困難 → ユーザーにエラー内容を提示して判断を仰ぐ
    </on-failure>
  </step>
</test-orchestration>

---

## 修正サイクル

Hub がテスト実行結果を分析し、失敗の原因に基づいてルーティングする。

<revision-cycle>
  <trigger>npx playwright test で失敗が発生</trigger>

  <route name="test-fix" label="テストコード修正">
    <condition>selector 不一致、content 不一致、timing 問題</condition>
    <action>
      1. 失敗内容を revision_context として test spec の data に書き込む
      2. tester を再起動してテストコードを修正させる
    </action>
    <hub-command>
      sqlite3 $DB "UPDATE specs SET
        data = json_set(data, '$.revision_context', json('{
          \"attempt\": 2,
          \"previous_failures\": [{エラー内容}]
        }')),
        status = 'in_progress',
        working_by = 'tester'
        WHERE id = {test_spec_id}"
    </hub-command>
  </route>

  <route name="impl-fix" label="実装コード修正">
    <condition>要素が Blade に存在しない、サーバーエラー、ロジック不整合</condition>
    <action>
      1. 失敗内容を revision_context として impl spec の data に書き込む
      2. livewire/artisan を起動して実装を修正させる
    </action>
    <hub-command>
      sqlite3 $DB "UPDATE specs SET
        data = json_set(data, '$.revision_context', json('{
          \"source_test_spec_id\": {test_spec_id},
          \"failures\": [{エラー内容}]
        }')),
        status = 'in_progress',
        working_by = 'livewire'
        WHERE id = {impl_spec_id}"
    </hub-command>
  </route>

  <route name="user-judgment" label="ユーザー判断">
    <condition>原因が判断困難、または修正サイクル2回以上失敗</condition>
    <action>
      ユーザーにエラー内容を提示して判断を仰ぐ:
      AskUserQuestion で「テスト修正 / アプリ修正 / 仕様変更」を選択させる
    </action>
  </route>
</revision-cycle>

### revision_context の構造

impl agent（livewire/artisan）に渡す場合:
```json
{
  "revision_context": {
    "source_test_spec_id": 84,
    "failures": [
      {
        "scenario": "login-validation",
        "error": "Locator('.validation-errors') not found",
        "app_files": ["resources/pages/auth/login.blade.php"],
        "suggested_fix": "バリデーションエラー表示に .validation-errors クラスを追加"
      }
    ]
  }
}
```

tester に再渡しする場合:
```json
{
  "revision_context": {
    "attempt": 2,
    "previous_failures": [
      {
        "scenario": "login-validation",
        "error": "Locator('.text-error') not found — actual class is .alert.alert-error",
        "suggested_fix": "セレクタを .alert.alert-error に変更"
      }
    ]
  }
}
```

---

## SQLパターン

```bash
DB="blueprint/blueprint.db"

# 状況確認
sqlite3 -json $DB "SELECT id, category, type, slug, name, status, human_reviewed FROM specs ORDER BY id"
sqlite3 -json $DB "SELECT * FROM progress_summary"
sqlite3 -json $DB "SELECT * FROM available_with_deps"
sqlite3 -json $DB "SELECT * FROM review_summary"

# Spec 追加
sqlite3 $DB "INSERT INTO specs (category, type, slug, name, data) VALUES ('data', 'tables', 'tasks', 'Tasks', '{...}')"

# Spec 更新（依存先もレビューリセット）
sqlite3 $DB "UPDATE specs SET data = '{...}', human_reviewed = 'none' WHERE id = 1"
sqlite3 $DB "WITH RECURSIVE deps AS (SELECT 1 as id UNION SELECT d.spec_id FROM spec_dependencies d JOIN deps ON d.blocked_by_spec_id = deps.id) UPDATE specs SET human_reviewed = 'none' WHERE id IN (SELECT id FROM deps)"

# ステータス更新
sqlite3 $DB "UPDATE specs SET status = 'approved' WHERE id = 1"

# レビュー更新
sqlite3 $DB "UPDATE specs SET human_reviewed = 'spec_reviewed' WHERE id = 1"

# 依存関係追加
sqlite3 $DB "INSERT INTO spec_dependencies (spec_id, blocked_by_spec_id) VALUES (2, 1)"
```

---

## Status Flow

```
draft → pending_review → approved → in_progress → impl_review → testing → done
              ↑                           ↓
              └────── needs_revision ←────┘
```
