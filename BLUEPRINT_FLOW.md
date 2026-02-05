# Blueprint-Flow 設計書

> tall-daisy スタック向け開発フロー定義

## 全体構成

```
Skill (1つ)                 Agents (4つ, 並列実行可能)
────────────────────        ────────────────────
/bpf                        db-architect → DB設計・実装
  - 仕様策定                livewire     → UI実装
  - テスト設計              artisan      → バックエンド
  - 実装オーケストレーション  tester       → テスト実行
  - 修正サイクル管理
```

### アーキテクチャ原則

| 項目 | /bpf | Agents |
|------|------|--------|
| 役割 | 上流工程（仕様・設計） | 下流工程（実装・テスト） |
| コード知識 | なし | あり（専門分野） |
| ユーザー対話 | AskUserQuestion | なし |
| 実行モード | Foreground | Background（並列） |

**コンテキスト分離**: /bpf はコードを一切読まない。spec ID を渡すだけで、各 agent が依存先を含めて仕様を取得・実装する。

---

## データベース定義

### blueprint.db（仕様管理）

```sql
-- specs: 仕様定義
CREATE TABLE specs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL,        -- core, data, ui, action, test
    type TEXT NOT NULL,            -- 下記参照
    slug TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'draft',
    working_by TEXT,
    branch TEXT,
    human_reviewed TEXT DEFAULT 'none',  -- none/spec_reviewed/impl_reviewed/test_reviewed
    revision_count INTEGER DEFAULT 0,
    revision_reason TEXT,
    e2e_status TEXT,
    e2e_level INTEGER DEFAULT 1,
    wave INTEGER DEFAULT 1,
    data JSON NOT NULL,
    created_at DATETIME,
    updated_at DATETIME,
    UNIQUE(category, type, slug)
);

-- spec_dependencies: 依存関係
CREATE TABLE spec_dependencies (
    spec_id INTEGER NOT NULL,
    blocked_by_spec_id INTEGER NOT NULL,
    UNIQUE(spec_id, blocked_by_spec_id)
);
```

**Category/Type構成:**

| Category | Types | 説明 |
|----------|-------|------|
| core | overview, const | プロジェクト概要、定数定義 |
| data | tables | DB設計（seeders.dev を含む） |
| ui | pages, partials, layouts | 画面、パーツ、レイアウト |
| action | sync, async, scheduled | Action, Job, Command |
| test | unit, feature, e2e | テスト設計（level 1-3） |

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
      "assertions": [
        "h1要素が表示される",
        "タスク一覧が表示される"
      ]
    },
    {
      "name": "add-task",
      "description": "タスクを追加できる",
      "steps": [
        "入力欄に「新しいタスク」を入力",
        "追加ボタンをクリック"
      ],
      "assertions": [
        "新しいタスクが一覧に表示される",
        "入力欄がクリアされる"
      ]
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

### Human Review Stages

段階的なレビュー管理。各specは4段階のレビュー状態を持つ。

| Stage | 説明 | タイミング |
|-------|------|-----------|
| `none` | 未レビュー | 新規作成時、または変更によるリセット時 |
| `spec_reviewed` | 仕様レビュー完了 | spec定義が承認された時点 |
| `impl_reviewed` | 実装レビュー完了 | 実装コードが承認された時点 |
| `test_reviewed` | テストレビュー完了 | テストが通過し承認された時点 |

**変更時の自動リセット:**
- specが更新されると、そのspecの`human_reviewed`は`none`にリセット
- 依存先（そのspecに`depends_on`しているspec）も全て`none`にリセット
- これにより、変更の影響範囲を追跡し、必要なレビューを強制

---

## SQLパターン集

blueprint.db への直接アクセス。CLIラッパーは不要。

```bash
# DB パス（プロジェクトルートから）
DB="blueprint/blueprint.db"

# 初期化・リセット（スクリプト使用）
./scripts/blueprint-db-cli.sh init
./scripts/blueprint-db-cli.sh reset
```

### 読み取り

```bash
# 全spec一覧
sqlite3 -json $DB "SELECT id, category, type, slug, name, status, human_reviewed FROM specs ORDER BY id"

# 特定のspec取得
sqlite3 -json $DB "SELECT * FROM specs WHERE id = 1"
sqlite3 -json $DB "SELECT * FROM specs WHERE category = 'ui' AND type = 'pages' AND slug = 'todo-index'"

# ビュー使用
sqlite3 -json $DB "SELECT * FROM available_with_deps"      # 実装可能（依存解決済み）
sqlite3 -json $DB "SELECT * FROM progress_summary"          # ステータス別集計
sqlite3 -json $DB "SELECT * FROM review_summary"            # レビュー段階別集計
sqlite3 -json $DB "SELECT * FROM needs_review_specs"        # 未完了レビュー
sqlite3 -json $DB "SELECT * FROM spec_blockers WHERE id=3"  # 依存関係確認
```

### 書き込み

```bash
# Spec追加
sqlite3 $DB "INSERT INTO specs (category, type, slug, name, data) VALUES ('data', 'tables', 'tasks', 'Tasks', '{\"columns\":[\"id\",\"title\"]}')"

# ステータス更新
sqlite3 $DB "UPDATE specs SET status = 'approved' WHERE id = 1"

# レビュー段階更新
sqlite3 $DB "UPDATE specs SET human_reviewed = 'spec_reviewed' WHERE id = 1"

# 依存関係追加（id=2 は id=1 に依存）
sqlite3 $DB "INSERT INTO spec_dependencies (spec_id, blocked_by_spec_id) VALUES (2, 1)"
```

### カスケードリセット

spec更新時に依存先のレビューもリセット:

```bash
# 対象ID
ID=1

# 自身と全依存先をリセット
sqlite3 $DB "
WITH RECURSIVE deps AS (
  SELECT $ID as id
  UNION
  SELECT d.spec_id FROM spec_dependencies d
  JOIN deps ON d.blocked_by_spec_id = deps.id
)
UPDATE specs SET human_reviewed = 'none' WHERE id IN (SELECT id FROM deps)
"
```

---

## Skill: `/bpf`

### ファイル
`skills/bpf/SKILL.md`

### 目的
仕様策定・テスト設計・実装オーケストレーション・修正サイクル管理

**上流工程のみ担当。コードの知識を一切持たない。**

### 入力

| パターン | 動作 |
|----------|------|
| `/bpf` | プロジェクト状況を分析し、推奨アクションを提示 |
| `/bpf pull` | blueprint-flowサブモジュールを最新版に更新 |
| `/bpf <指示>` | 指示に基づいて仕様策定・実装・テストを実行 |

### オーケストレーションフロー

```
1. ユーザー指示を受け取る
2. 必要な情報が不足 → AskUserQuestion で確認
3. Spec を作成/更新（data, ui, action, test）
4. 依存関係を解決して実装順序を決定
5. 対象 spec の status を 'in_progress'、working_by を agent 名に更新
6. Agents を background で並列起動（spec ID を渡す）
7. Agent 結果を確認し、status を更新:
   - 成功 → 'impl_review', working_by = NULL
   - 失敗 → 'needs_revision', working_by = NULL, revision_count++, revision_reason 記録
   - 対応する test spec も同様に更新
8. 失敗があれば修正サイクル
```

### Status 管理責務（CRITICAL）

**status 更新は /bpf のみが行う。agent は結果を報告するのみ。**

```bash
DB="blueprint/blueprint.db"

# Agent 起動前: lock
sqlite3 $DB "UPDATE specs SET status = 'in_progress', working_by = '{agent-type}' WHERE id = {spec_id}"

# Agent 成功後: unlock + advance
sqlite3 $DB "UPDATE specs SET status = 'impl_review', working_by = NULL WHERE id = {spec_id}"

# Agent 失敗後: unlock + revision
sqlite3 $DB "UPDATE specs SET status = 'needs_revision', working_by = NULL, revision_count = revision_count + 1, revision_reason = '{reason}' WHERE id = {spec_id}"

# Agent クラッシュ時: unlock（リカバリ）
sqlite3 $DB "UPDATE specs SET status = 'approved', working_by = NULL WHERE id = {spec_id} AND working_by IS NOT NULL"
```

### 依存関係と並列実行

```
依存グラフ例:
  data/tables/tasks ←─┬─ ui/pages/todo-index
                      └─ action/sync/create-task

  test/e2e/todo-index ←── ui/pages/todo-index

並列実行:
  Wave 1: db-architect (data/tables/tasks)
  Wave 2: livewire (ui/pages/todo-index) + artisan (action/sync/create-task)  ← 並列
  Wave 3: tester (test/e2e/todo-index)
```

### Agent 起動方法

```
Task tool:
  - subagent_type: "general-purpose"
  - prompt: "{agent-type}として実行: spec_id={id}"
  - run_in_background: true  ← 並列実行のため
```

**Agents は AskUserQuestion を使用しない。必要な情報は全て spec に含める。**

---

## 共通設計原則

### tall-daisy スタック

```
Laravel 12
Livewire 4
Tailwind CSS 4
daisyUI 5
Alpine.js 3
PHP 8.3+
MySQL 8.0+
```

### 共通設計方針

| 項目 | 方針 |
|------|------|
| UI言語 | 日本語 |
| コードコメント | 日本語 |
| アーキテクチャ | Livewire フルページコンポーネント |
| ビジネスロジック | Action クラスに分離 |
| 非同期処理 | Job クラス |
| イベント駆動 | Event / Listener |
| テスト | Pest PHP |

### コーディング原則（CRITICAL）

#### 1. シンプルさ優先

```php
// GOOD: 明示的で分かりやすい
$users = User::where('status', 'active')->get();
foreach ($users as $user) {
    $user->notify(new WelcomeNotification());
}

// AVOID: 過度にチェーン化
User::active()->each->notify(new WelcomeNotification());
```

#### 2. Laravel基本機能の活用

```php
// GOOD: 標準のEloquent
$user = User::find($id);
$user->update(['name' => $name]);

// AVOID: 不要なRepository/Service層
$this->userRepository->findById($id);
```

#### 3. 可読性 > 簡潔さ

```php
// GOOD: 長くても意図が明確
public function calculateTotal(array $items): int
{
    $subtotal = 0;
    foreach ($items as $item) {
        $subtotal += $item['price'] * $item['quantity'];
    }
    return $subtotal + (int) ($subtotal * 0.1);
}

// AVOID: 短いが読みにくい
public function calculateTotal(array $items): int
{
    return (int) (array_reduce($items, fn($c, $i) => $c + $i['price'] * $i['quantity'], 0) * 1.1);
}
```

---

## Agent 1: `db-architect`

### 役割
DB実装の専門家（Migration, Model, Seeder）

### 入力
spec_id を受け取り、自律的に仕様を取得して実装

### 最初に実行すること
```bash
DB="blueprint/blueprint.db"
sqlite3 -json $DB "SELECT * FROM specs WHERE category='core' AND type='overview'"
sqlite3 -json $DB "SELECT * FROM specs WHERE id = {spec_id}"
```

### 出力物
1. Migration (`database/migrations/`)
2. Model (`app/Models/`)
3. Seeder (`database/seeders/`) ← spec.seeders.dev から生成
4. Level1 Unit テスト (`tests/Unit/Models/`)

### 専門知識（抜粋）

#### Seeder規約（CRITICAL）
```php
// CORRECT: 静的配列で明示的な値
$records = [
    // 管理者ユーザー（承認フローテスト用）
    ['id' => 1, 'name' => 'Admin User', 'email' => 'admin@example.com'],
];

// FORBIDDEN: Factory, Faker
User::factory()->count(10)->create();  // NG
```

---

## Agent 2: `livewire`

### 役割
UI実装の専門家（Livewire Component + Blade）

**Migration/Model/Seeder は作成しない。db-architect の責務。**

### 入力
spec_id を受け取り、自律的に仕様を取得して実装

### 最初に実行すること
```bash
DB="blueprint/blueprint.db"
sqlite3 -json $DB "SELECT * FROM specs WHERE category='core' AND type='overview'"
sqlite3 -json $DB "SELECT * FROM specs WHERE id = {spec_id}"
# depends_on があれば依存先も取得
```

### 出力物
1. Livewire Component (`app/Livewire/`)
2. Blade テンプレート (`resources/views/livewire/`)
3. ルート追加 (`routes/web.php`)
4. Level1 Feature テスト (`tests/Feature/Livewire/`)

---

## Agent 3: `artisan`

### 役割
バックエンドロジック実装の専門家（Actions, Jobs, Events, Commands）

### 入力
spec_id を受け取り、自律的に仕様を取得して実装

### 最初に実行すること
```bash
DB="blueprint/blueprint.db"
sqlite3 -json $DB "SELECT * FROM specs WHERE category='core' AND type='overview'"
sqlite3 -json $DB "SELECT * FROM specs WHERE id = {spec_id}"
# depends_on があれば依存先も取得
```

### 出力物
1. Action クラス (`app/Actions/`)
2. Job クラス (`app/Jobs/`)
3. Event / Listener クラス
4. Command クラス (`app/Console/Commands/`)
5. Level1 Unit テスト

---

## Agent 4: `tester`

### 役割
テストコード作成・実行の専門家

**テスト設計は /bpf が spec として定義済み。tester はコード作成と実行のみ。**

### 入力
spec_id (test/unit, test/feature, test/e2e) を受け取り、テストコードを作成・実行

### 最初に実行すること
```bash
DB="blueprint/blueprint.db"
sqlite3 -json $DB "SELECT * FROM specs WHERE id = {spec_id}"
# depends_on から対象の ui/pages または action spec を取得
```

### 出力物

| Type | Output |
|------|--------|
| unit | `tests/Unit/{path}/{Name}Test.php` |
| feature | `tests/Feature/{path}/{Name}Test.php` |
| e2e | playwright-mcp で実行 + `e2e.db` にスクショ＋description を登録 |

### E2E テスト方式

テストコードファイルは作成しない。playwright-mcp でブラウザ操作し、各状態でスクリーンショットを撮影。
スクショは `e2e.db` の `screenshots` テーブルに description（状態の説明）と step_order（順序）をセットで保存。

```bash
# スクショ登録: screenshot <run_id> <step_order> <description> <type> <path>
./scripts/e2e-db-cli.sh screenshot $RUN_ID 0 'ページロード直後' actual tests/e2e/screenshots/{slug}/00-initial.png
./scripts/e2e-db-cli.sh screenshot $RUN_ID 1 'タスク追加後の一覧' actual tests/e2e/screenshots/{slug}/01-add-task-after.png
```

---

## Status Flow

```
draft → pending_review → approved → in_progress → impl_review → testing → done
              ↑                           ↓
              └────── needs_revision ←────┘
```

---

## 開発サイクル例

```
User: 「タスク管理アプリを作りたい」

/bpf:
  1. AskUserQuestion で要件確認
  2. core/overview/main を作成
  3. data/tables/tasks を作成（seeders.dev 含む）
  4. ui/pages/todo-index を作成（depends_on: data/tables/tasks）
  5. test/e2e/todo-index を作成（depends_on: ui/pages/todo-index、scenarios 定義）
  6. 依存順で agents を起動:
     Wave 1: db-architect (spec_id=2) → background
     Wave 2: livewire (spec_id=3) → background
     Wave 3: tester (spec_id=4) → background
  7. 結果確認、失敗があれば修正

/bpf:
  「テストが失敗しました」
  → spec を修正 or agent を再起動
```
