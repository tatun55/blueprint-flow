# Blueprint Skill

仕様策定・テスト設計・実装オーケストレーション・修正サイクル管理

**上流工程のみ担当。コードの知識を一切持たない。**

## アーキテクチャ原則

| 項目 | /blueprint | Agents |
|------|-----------|--------|
| 役割 | 上流工程（仕様・設計） | 下流工程（実装・テスト） |
| コード知識 | なし | あり |
| ユーザー対話 | AskUserQuestion | なし |
| 実行モード | Foreground | Background（並列） |

---

## サブコマンド

### `/blueprint pull`

blueprint-flowサブモジュールを最新版に更新する。

```bash
cd .blueprint-flow && git pull origin main && cd ..
./.blueprint-flow/scripts/update.sh
```

### `/blueprint push`

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
./scripts/blueprint-db-cli.sh overview
./scripts/blueprint-db-cli.sh progress
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

### Test Spec 構造

```json
{
  "level": 1,
  "depends_on": ["ui/pages/todo-index"],
  "target": {
    "type": "page",
    "url": "/",
    "component": "App\\Livewire\\Pages\\TodoIndex"
  },
  "scenarios": [
    {
      "name": "page-load",
      "description": "ページが正しく表示される",
      "assertions": ["h1要素が表示される", "タスク一覧が表示される"]
    },
    {
      "name": "add-task",
      "description": "タスクを追加できる",
      "steps": ["入力欄に「新しいタスク」を入力", "追加ボタンをクリック"],
      "assertions": ["新しいタスクが一覧に表示される", "入力欄がクリアされる"]
    }
  ],
  "required_data": [
    {"_comment": "完了状態テスト用", "title": "完了タスク", "completed": true}
  ]
}
```

**Test Levels:**

| Level | Coverage | Content |
|-------|----------|---------|
| 1 | 20-40% | 基本操作（表示、主要アクション） |
| 2 | 40-60% | 追加操作（フォーム、モーダル） |
| 3 | 60%+ | 全状態・エッジケース（エラー、空状態） |

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
      <sub-step name="4c-tests">
        <action>test/e2e spec を作成</action>
        <method>AskUserQuestion でテストシナリオを確認</method>
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
    <command>./scripts/blueprint-db-cli.sh available-with-deps</command>
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
      <map category="data" type="tables" agent="db-agent" />
      <map category="ui" type="*" agent="livewire-agent" />
      <map category="action" type="*" agent="action-agent" />
      <map category="test" type="*" agent="test-agent" />
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
Task(subagent_type="general-purpose", prompt="livewire-agentとして実行: spec_id=3", run_in_background=true)
Task(subagent_type="general-purpose", prompt="action-agentとして実行: spec_id=4", run_in_background=true)
```

---

## テストオーケストレーション

<test-orchestration>
  <step name="1-check-test-specs">
    <command>./scripts/blueprint-db-cli.sh list test</command>
  </step>

  <step name="2-verify-dependencies">
    <action>depends_on の spec が実装済み（done）か確認</action>
    <if-not-done>依存先の実装を先に完了</if-not-done>
  </step>

  <step name="3-launch-test-agent">
    <action>test-agent を background で起動</action>
    <prompt>test-agentとして実行: spec_id={id}</prompt>
  </step>

  <step name="4-review-results">
    <action>テスト結果を確認</action>
    <on-failure>
      <sub-action>失敗原因を分析</sub-action>
      <sub-action>spec 修正 or 実装修正が必要か判断</sub-action>
      <sub-action>修正後、再実行</sub-action>
    </on-failure>
  </step>
</test-orchestration>

---

## Spec テンプレート

### data/tables テンプレート

```bash
./scripts/blueprint-db-cli.sh add data tables tasks "tasksテーブル" '{
  "columns": [
    {"name": "id", "type": "bigint", "primary": true},
    {"name": "title", "type": "string", "nullable": false, "max": 255},
    {"name": "completed", "type": "boolean", "default": false},
    {"name": "timestamps", "type": "timestamps"}
  ],
  "indexes": [],
  "relations": [],
  "seeders": {
    "dev": [
      {"_comment": "基本状態（一覧表示テスト用）", "title": "買い物に行く", "completed": false},
      {"_comment": "完了状態（完了表示テスト用）", "title": "レポートを書く", "completed": true}
    ]
  }
}'
```

### ui/pages テンプレート

```bash
./scripts/blueprint-db-cli.sh add ui pages todo-index "Todoメインページ" '{
  "route": "/",
  "component": "Pages/TodoIndex",
  "depends_on": ["data/tables/tasks"],
  "layout_ascii": "...",
  "operations": ["一覧表示", "新規作成", "完了切替", "削除"]
}'
```

### test/e2e テンプレート

```bash
./scripts/blueprint-db-cli.sh add test e2e todo-index "Todoページ E2Eテスト" '{
  "level": 1,
  "depends_on": ["ui/pages/todo-index"],
  "target": {
    "type": "page",
    "url": "/",
    "component": "App\\Livewire\\Pages\\TodoIndex"
  },
  "scenarios": [
    {
      "name": "page-load",
      "description": "ページが正しく表示される",
      "assertions": ["h1要素が表示される", "タスク一覧が表示される"]
    },
    {
      "name": "add-task",
      "description": "タスクを追加できる",
      "steps": ["入力欄に「新しいタスク」を入力", "追加ボタンをクリック"],
      "assertions": ["新しいタスクが一覧に表示される"]
    }
  ],
  "required_data": []
}'
```

### test/feature テンプレート

```bash
./scripts/blueprint-db-cli.sh add test feature todo-index "Todoページ Featureテスト" '{
  "level": 1,
  "depends_on": ["ui/pages/todo-index"],
  "target": {
    "component": "App\\Livewire\\Pages\\TodoIndex"
  },
  "scenarios": [
    {
      "name": "display",
      "description": "コンポーネントが表示される",
      "assertions": ["status 200", "タスク一覧が表示"]
    },
    {
      "name": "add-task",
      "description": "タスクを追加できる",
      "assertions": ["DBに保存される", "一覧に表示される"]
    }
  ]
}'
```

---

## 修正サイクル

<revision-cycle>
  <trigger>テスト失敗 / 実装エラー / レビュー指摘</trigger>

  <step name="1-analyze">
    <action>失敗原因を分析</action>
    <categories>
      <category name="spec-issue">仕様の問題 → spec を修正</category>
      <category name="impl-issue">実装の問題 → agent を再実行</category>
      <category name="test-issue">テストの問題 → test spec を修正</category>
    </categories>
  </step>

  <step name="2-fix">
    <action>問題に応じて修正</action>
    <spec-fix>
      <command>./scripts/blueprint-db-cli.sh update {id} '{...}'</command>
      <command>./scripts/blueprint-db-cli.sh status {id} approved</command>
    </spec-fix>
  </step>

  <step name="3-re-execute">
    <action>該当 agent を再実行</action>
  </step>
</revision-cycle>

---

## CLIコマンド

```bash
# 状況確認
./scripts/blueprint-db-cli.sh overview
./scripts/blueprint-db-cli.sh progress
./scripts/blueprint-db-cli.sh available-with-deps

# Spec 管理
./scripts/blueprint-db-cli.sh add <cat> <type> <slug> <name> '<json>'
./scripts/blueprint-db-cli.sh update <id> '<json>'
./scripts/blueprint-db-cli.sh status <id> <status>
./scripts/blueprint-db-cli.sh add-dep <id> <blocked_by_id>
./scripts/blueprint-db-cli.sh reviewed <id>

# Test管理
./scripts/blueprint-db-cli.sh list test
./scripts/blueprint-db-cli.sh list test e2e
./scripts/e2e-db-cli.sh overview
```

---

## Blueprint仕様の品質基準

1. **コーディング可能** - 実装者が迷わず着手できる
2. **具体的** - 曖昧さがない
3. **詳細** - 必要な情報が揃っている
4. **意図が明確** - なぜこの仕様かが分かる
5. **無駄がない** - 冗長な記述を避ける
6. **正確** - 誤解の余地がない

---

## Status Flow

```
draft → pending_review → approved → in_progress → impl_review → testing → done
              ↑                           ↓
              └────── needs_revision ←────┘
```

---

## playwright-mcp スクリーンショット（UI確認用）

```javascript
mcp__playwright-mcp__playwright_navigate({ url: "...", headless: true })
mcp__playwright-mcp__playwright_screenshot({ name: "...", savePng: true })
mcp__playwright-mcp__playwright_close()
```
