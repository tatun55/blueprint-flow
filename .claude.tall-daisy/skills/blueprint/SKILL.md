# Blueprint Skill

仕様策定・プロジェクト状況把握・開発フロー提案

## サブコマンド

### `/blueprint pull`

blueprint-flowサブモジュールを最新版に更新する。

```bash
cd .blueprint-flow && git pull origin main && cd ..
./.blueprint-flow/scripts/update.sh
```

実行後、変更内容を報告。

### `/blueprint push`

blueprint-flowサブモジュールへの変更をリモートにpushする。

**手順:**

1. サブモジュール内の変更を確認
```bash
git -C .blueprint-flow status
```

2. 変更があればコミット（未コミットの場合）
```bash
git -C .blueprint-flow add -A
git -C .blueprint-flow commit -m "説明"
```

3. リモートにpush
```bash
git -C .blueprint-flow push origin main
```

4. 親リポジトリでサブモジュール参照を更新
```bash
git add .blueprint-flow
git commit -m "Update blueprint-flow submodule"
```

**注意**: pushする前にユーザーに変更内容を確認してもらう。

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
   - approved が多い → 「/coding で実装を開始できます」
   - in_progress が多い → 「実装中のspecがN件あります」

## 引数ありの場合

`$ARGUMENTS` を解釈して仕様を策定・更新

1. 既存specの更新 or 新規作成を判定
2. 適切なcategory/typeを判定
3. 情報が足りない場合は**1回のAskUserQuestion**でまとめて取得
4. specを作成/更新

---

## 新規プロジェクト開始フロー

specが0件の場合、以下の手順で開始:

<new-project-flow>
  <principle>
    各specアイテムをDB登録する前に、必ずAskUserQuestionで確認する。
    overviewのfeaturesは概要リストであり、それに基づいて各機能の詳細specを
    1つずつAskUserQuestionで確認しながら作成する。
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
    <content>概要、機能リスト、要件、対象外、技術スタック</content>
  </step>

  <step name="3-confirm-overview">
    <action>AskUserQuestion で overview を確認</action>
    <display>表形式で機能一覧を表示</display>
    <on-approve>DB登録 → approved</on-approve>
    <on-reject>修正して再確認</on-reject>
  </step>

  <step name="4-expand-features">
    <action>featuresに基づいて詳細specを順次作成</action>
    <for-each feature="features">
      <sub-step name="4a-tables">
        <condition>機能にDBテーブルが必要な場合</condition>
        <action>data/tables spec を作成（カラム + シーダー）</action>
        <method>AskUserQuestion でカラム定義とシーダーデータを確認</method>
        <display>カラム一覧表 + シーダーサンプル3-5件</display>
        <on-approve>DB登録</on-approve>
      </sub-step>
      <sub-step name="4b-pages">
        <condition>機能にUIページがある場合</condition>
        <action>ui/pages spec を作成</action>
        <method>AskUserQuestion でASCIIアートレイアウトを確認</method>
        <display>ASCIIアートを表示して確認</display>
        <on-approve>DB登録</on-approve>
      </sub-step>
    </for-each>
  </step>

  <step name="5-complete">
    <action>全spec作成完了を報告</action>
    <next>/coding で実装開始（テーブル・シーダー・UI全て）</next>
  </step>
</new-project-flow>

### ステップ1: プロジェクト情報を収集

AskUserQuestionで質問:

```
1. アプリの種類は？ (シンプル / 認証あり / チーム共有型)
2. 主要機能は？ (CRUD基本 / +カテゴリ機能 / +検索機能 / カスタム)
```

### ステップ2: overview spec を作成

収集した情報から overview spec を生成（**まだDB登録しない**）。

#### 必須項目

overviewには**必ず機能リスト（features）を含める**。

```json
{
  "description": "アプリの概要説明",
  "features": [
    {
      "id": "F001",
      "name": "機能名",
      "description": "機能説明",
      "priority": "必須/任意",
      "depends_on": ["data/tables/tasks"]
    }
  ],
  "tables": [
    {"slug": "tasks", "name": "タスク", "description": "タスク情報を保存"}
  ],
  "requirements": ["要件1", "要件2"],
  "non_goals": ["対象外1", "対象外2"],
  "tech_stack": {
    "backend": "Laravel 12",
    "frontend": "Livewire 4 + Alpine.js",
    "css": "Tailwind CSS 4 + daisyUI 5",
    "database": "SQLite"
  }
}
```

#### 機能リストの粒度ルール

**重要**: 機能アイテムは**ページ単位**で定義する。同一ページでできる操作は1つの機能アイテムにまとめる。

```json
// ✅ 良い例: ページ単位でまとめる
{
  "features": [
    {
      "id": "F001",
      "name": "タスク管理ページ",
      "description": "タスクの一覧表示・作成・完了切替・削除ができる",
      "priority": "必須",
      "page": "/tasks",
      "operations": ["一覧表示", "新規作成", "完了/未完了切替", "削除"]
    }
  ]
}
```

### ステップ3: AskUserQuestion で overview を確認

表形式で表示し、**承認を得てからDB登録**する。

### ステップ4: featuresに基づいて詳細specを作成

overview承認後、featuresの各機能に対して詳細specを**1つずつ**作成する。

#### 4a. data/tables spec（テーブル定義 + シーダー）

```
AskUserQuestion:
「{テーブル名}テーブルを以下の構成で作成します:

【カラム】
| カラム | 型 | 説明 |
|--------|-----|------|
| id | bigint | 主キー |
| title | string(255) | タスク名 |
| completed | boolean | 完了フラグ |
| timestamps | - | 作成・更新日時 |

【開発用シーダー】
- 買い物に行く (未完了)
- レポートを書く (完了)
- ジムに行く (未完了)

よろしいですか？」
```

承認後、DB登録。

#### 4b. ui/pages spec（ページ定義）

**必ずASCIIアートでレイアウトを示してから確認**:

```
AskUserQuestion:
「{ページ名}のレイアウトです:

┌─────────────────────────────────────┐
│  header: Todo App                   │
├─────────────────────────────────────┤
│  [新しいタスクを入力...] [追加]      │
├─────────────────────────────────────┤
│  ☑ タスク1 (打消線)        [削除]   │
│  ☐ タスク2                 [削除]   │
└─────────────────────────────────────┘

このレイアウトでよいですか？」
```

承認後、DB登録。

### ステップ5: 全spec作成完了

全ての詳細spec作成後、次のステップを案内:
- `/coding` で実装開始（DB + シーダー + UI 全て）

---

## Category/Type 定義

```
Categories: core, data, ui, action

Types:
  - core: overview, const
  - data: tables (シーダー定義を含む)
  - ui: pages, partials, layouts
  - action: sync, async, scheduled
```

### 使用例

| Category | Type | 用途 |
|----------|------|------|
| core | overview | プロジェクト概要・機能一覧・テーブル概要 |
| core | const | 定数定義・設定値 |
| data | tables | DBテーブル定義 + シーダー定義 |
| ui | pages | フルページLivewireコンポーネント |
| ui | partials | 再利用可能なUIパーツ |
| ui | layouts | レイアウトコンポーネント |
| action | sync | 同期処理（Actionクラス） |
| action | async | 非同期処理（Jobクラス） |
| action | scheduled | スケジュール実行（Command） |

### 依存関係（depends_on）

各specは `depends_on` で他のspecへの依存を明示できる。

```json
// ui/pages/todo-index
{
  "route": "/",
  "depends_on": ["data/tables/tasks"],
  ...
}

// action/sync/create-task
{
  "depends_on": ["data/tables/tasks"],
  ...
}

// action/async/send-reminder
{
  "depends_on": ["data/tables/tasks", "data/tables/users"],
  ...
}
```

Agentは実装時に `depends_on` のspecを参照して詳細要件を取得する。

**依存関係の方向:**
```
data/tables (依存なし)
    ↑
action/sync, action/async (tables に依存)
    ↑
ui/pages (tables, actions に依存可能)
```

---

## Spec テンプレート

### core/overview テンプレート

```bash
./scripts/blueprint-db-cli.sh add core overview app-overview "アプリ概要" '{
  "description": "...",
  "features": [
    {"id": "F001", "name": "...", "description": "...", "priority": "必須"}
  ],
  "requirements": ["..."],
  "non_goals": ["..."],
  "tech_stack": {...}
}'
```

### data/tables テンプレート

**シーダー定義を必ず含める**（開発・テスト用のダミーデータ）

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
      {"title": "買い物に行く", "completed": false},
      {"title": "レポートを書く", "completed": true},
      {"title": "ジムに行く", "completed": false}
    ]
  }
}'
```

#### シーダー定義ルール

**目的**: 開発・手動テスト・E2Eテストすべてで使用する単一データソース

- `dev`: 開発・テスト・確認すべてに使える包括的データ
- 各テーブルに必ず `seeders.dev` を含める
- **各レコードの役割をコメントで明示**（テスト設計の意図が分かるように）

```json
{
  "seeders": {
    "dev": [
      {"_comment": "基本状態（一覧表示テスト用）", "title": "買い物に行く", "completed": false},
      {"_comment": "完了状態（完了表示テスト用）", "title": "レポートを書く", "completed": true},
      {"_comment": "長いタイトル（レイアウト確認用）", "title": "これは非常に長いタスク名でレイアウトが崩れないか確認", "completed": false},
      {"_comment": "最小データ（エッジケース）", "title": "a", "completed": false}
    ]
  }
}
```

**重要**: 人間もE2Eも同じ `php artisan migrate:fresh --seed` で同じデータを使用

### ui/pages テンプレート

**必須**: アスキーアートでレイアウトを示す + depends_on

```bash
./scripts/blueprint-db-cli.sh add ui pages todo-index "Todoメインページ" '{
  "route": "/",
  "component": "Pages/TodoIndex",
  "depends_on": ["data/tables/tasks"],
  "layout_ascii": "┌─────────────────────────────────────┐\n│  header: Todo App                   │\n├─────────────────────────────────────┤\n│  [新しいタスクを入力...] [追加]      │\n├─────────────────────────────────────┤\n│  ☑ タスク1 (打消線)        [削除]   │\n│  ☐ タスク2                 [削除]   │\n└─────────────────────────────────────┘",
  "modals": [],
  "operations": ["一覧表示", "新規作成", "完了切替", "削除"],
  "wireModel": ["tasks", "newTaskTitle"],
  "methods": ["mount", "addTask", "toggleComplete", "deleteTask"]
}'
```

#### アスキーアートガイドライン

1. **全体レイアウト**: ページの構造を示す
```
┌───────────────────────────────────────────────────┐
│  Logo                  Search...           Avatar  │  ← fixed top bar
├───────────────┬───────────────────────────────────┤
│  Sidebar      │               Main Content        │
│  w-64         │                                   │
│  - Item 1     │  ┌─────────────────────────────┐  │
│  - Item 2     │  │ Content Area               │  │
│  - Item 3     │  └─────────────────────────────┘  │
└───────────────┴───────────────────────────────────┘
```

2. **モーダル**: 別途アスキーアートで示す
```
┌─────────────────────────────────┐
│  Modal Title              [×]  │
├─────────────────────────────────┤
│  Form content here             │
│  [Input field               ]  │
│                                │
│         [Cancel] [Save]        │
└─────────────────────────────────┘
```

3. **レスポンシブ**: モバイル/デスクトップの違いがある場合は両方示す

### action/sync テンプレート（同期Action）

```bash
./scripts/blueprint-db-cli.sh add action sync create-task "タスク作成アクション" '{
  "depends_on": ["data/tables/tasks"],
  "description": "新しいタスクを作成する",
  "input": {
    "title": {"type": "string", "required": true, "max": 255}
  },
  "output": "Task",
  "events": ["TaskCreated"],
  "class": "App\\Actions\\CreateTask"
}'
```

### action/async テンプレート（非同期Job）

```bash
./scripts/blueprint-db-cli.sh add action async send-reminder "リマインダー送信Job" '{
  "depends_on": ["data/tables/tasks", "data/tables/users"],
  "description": "期限が近いタスクのリマインダーを送信",
  "trigger": "TaskDueSoon event",
  "input": {
    "task_id": {"type": "int", "required": true}
  },
  "queue": "notifications",
  "class": "App\\Jobs\\SendReminder"
}'
```

### action/scheduled テンプレート（スケジュールCommand）

```bash
./scripts/blueprint-db-cli.sh add action scheduled cleanup-old-tasks "古いタスク削除Command" '{
  "depends_on": ["data/tables/tasks"],
  "description": "30日以上前の完了タスクを削除",
  "schedule": "daily",
  "signature": "app:cleanup-old-tasks",
  "class": "App\\Console\\Commands\\CleanupOldTasks"
}'
```

---

## CLIコマンド

```bash
./scripts/blueprint-db-cli.sh overview         # 全spec一覧
./scripts/blueprint-db-cli.sh progress         # status別の進捗
./scripts/blueprint-db-cli.sh available        # 実装可能なspec
./scripts/blueprint-db-cli.sh pending-review   # レビュー待ち
./scripts/blueprint-db-cli.sh needs-attention  # 要対応
./scripts/blueprint-db-cli.sh add <cat> <type> <slug> <name> '<json>'
./scripts/blueprint-db-cli.sh update <id> '<json>'
./scripts/blueprint-db-cli.sh status <id> <status>
./scripts/blueprint-db-cli.sh reviewed <id>    # レビュー完了マーク
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

| Status | 説明 | 次のアクション |
|--------|------|---------------|
| draft | 作成中 | 内容を確定して pending_review へ |
| pending_review | レビュー待ち | 人間がレビューして approved/needs_revision へ |
| approved | 承認済み | /coding で実装開始 |
| in_progress | 実装中 | 完了後 impl_review へ |
| impl_review | 実装レビュー待ち | レビュー後 testing へ |
| testing | テスト中 | テスト完了後 done へ |
| done | 完了 | - |
| needs_revision | 修正必要 | 修正後 pending_review へ |

---

## 効率的なワークフローのコツ

1. **情報収集は1回でまとめる** - 複数回のAskUserQuestionを避ける
2. **テンプレートを活用** - 必須項目の漏れを防ぐ
3. **具体例を示す** - 抽象的な質問を避ける
4. **レビュー前にチェック** - 品質基準を満たしているか確認

---

## 人間コラボレーションガイドライン

適切な頻度で人間の判断を取り入れながら開発を進める。

<collaboration-flow>
  <principle>
    人間との協働を重視し、重要な判断ポイントでAskUserQuestionを使用する。
    ただし、過度な確認は避け、効率とのバランスを取る。
  </principle>

  <checkpoint name="spec-creation">
    <description>仕様作成時の確認ポイント</description>
    <timing>spec作成後、status変更前</timing>
    <method>AskUserQuestion</method>
    <content>作成したspecの内容を表形式で提示し、承認を求める</content>
  </checkpoint>

  <checkpoint name="ui-implementation">
    <description>UI実装の確認</description>
    <condition>ui/pages または ui/layouts のspec</condition>
    <method>playwright-mcp screenshot</method>
    <flow>
      <step>playwright_navigate で該当ページに遷移 (headless: true)</step>
      <step>playwright_screenshot でスクリーンショット取得</step>
      <step>スクリーンショットをユーザーに提示</step>
      <step>AskUserQuestion で確認（レイアウト・デザインの意図通りか）</step>
      <step>playwright_close で終了</step>
    </flow>
  </checkpoint>

  <checkpoint name="non-ui-confirmation">
    <description>非UI（data, action, core）の確認</description>
    <method>簡潔な説明文</method>
    <rules>
      <rule>無駄のない必要十分な説明</rule>
      <rule>技術的詳細は箇条書きで簡潔に</rule>
      <rule>変更の影響範囲を明示</rule>
    </rules>
    <example>
      tasksテーブルを作成します:
      - カラム: id, title, completed, timestamps
      - インデックス: なし
      よろしいですか？
    </example>
  </checkpoint>

  <checkpoint name="status-transition">
    <description>重要なステータス変更時</description>
    <transitions>
      <transition from="draft" to="pending_review">確認必須</transition>
      <transition from="pending_review" to="approved">人間の承認必須</transition>
      <transition from="in_progress" to="impl_review">実装完了報告</transition>
    </transitions>
  </checkpoint>
</collaboration-flow>

### AskUserQuestion使用タイミング

| タイミング | 必須/推奨 | 内容 |
|-----------|----------|------|
| spec作成後 | 必須 | 内容の承認 |
| UI実装後 | 必須 | スクショ付きで確認 |
| status変更 | 推奨 | 次のフェーズへの移行確認 |
| 曖昧な要件 | 必須 | 詳細の確認 |
| 複数選択肢 | 推奨 | 方針決定 |

### playwright-mcp スクリーンショット

UI確認には `playwright-mcp` を積極的に使用する。

```javascript
// 1. ページに遷移
mcp__playwright-mcp__playwright_navigate({
  url: "http://localhost:8000/path",
  headless: true
})

// 2. スクリーンショット取得
mcp__playwright-mcp__playwright_screenshot({
  name: "page-name_state",
  savePng: true,
  fullPage: true
})

// 3. 終了（必須）
mcp__playwright-mcp__playwright_close()
```

**命名規則**: `{page-slug}_{state}.png`
- `todo-index_initial.png`
- `todo-index_after-add.png`
- `task-modal_open.png`
