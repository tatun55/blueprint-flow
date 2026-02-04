# Blueprint-Flow 設計書

> tall-daisy スタック向け開発フロー定義

## 全体構成

```
Skill (1つ)                 Agents (4つ, 並列実行可能)
────────────────────        ────────────────────
/blueprint                  db-agent       → DB実装
  - 仕様策定                livewire-agent → UI実装
  - テスト設計              action-agent   → バックエンド
  - 実装オーケストレーション  test-agent     → テストコード実行
  - 修正サイクル管理
```

### アーキテクチャ原則

| 項目 | /blueprint | Agents |
|------|-----------|--------|
| 役割 | 上流工程（仕様・設計） | 下流工程（実装・テスト） |
| コード知識 | なし | あり（専門分野） |
| ユーザー対話 | AskUserQuestion | なし |
| 実行モード | Foreground | Background（並列） |

**コンテキスト分離**: /blueprint はコードを一切読まない。spec ID を渡すだけで、各 agent が依存先を含めて仕様を取得・実装する。

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
    human_reviewed INTEGER DEFAULT 0,
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

---

## Skill: `/blueprint`

### ファイル
`skills/blueprint/SKILL.md`

### 目的
仕様策定・テスト設計・実装オーケストレーション・修正サイクル管理

**上流工程のみ担当。コードの知識を一切持たない。**

### 入力

| パターン | 動作 |
|----------|------|
| `/blueprint` | プロジェクト状況を分析し、推奨アクションを提示 |
| `/blueprint pull` | blueprint-flowサブモジュールを最新版に更新 |
| `/blueprint <指示>` | 指示に基づいて仕様策定・実装・テストを実行 |

### オーケストレーションフロー

```
1. ユーザー指示を受け取る
2. 必要な情報が不足 → AskUserQuestion で確認
3. Spec を作成/更新（data, ui, action, test）
4. 依存関係を解決して実装順序を決定
5. Agents を background で並列起動（spec ID を渡す）
6. 結果を確認、失敗があれば修正サイクル
```

### 依存関係と並列実行

```
依存グラフ例:
  data/tables/tasks ←─┬─ ui/pages/todo-index
                      └─ action/sync/create-task

  test/e2e/todo-index ←── ui/pages/todo-index

並列実行:
  Wave 1: db-agent (data/tables/tasks)
  Wave 2: livewire-agent (ui/pages/todo-index) + action-agent (action/sync/create-task)  ← 並列
  Wave 3: test-agent (test/e2e/todo-index)
```

### Agent 起動方法

```
Task tool:
  - subagent_type: "general-purpose"
  - prompt: "{agent-type}として実行: spec_id={id}"
  - run_in_background: true  ← 並列実行のため
```

**Agents は AskUserQuestion を使用しない。必要な情報は全て spec に含める。**

### 使用するCLIコマンド

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
```

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

## Agent 1: `db-agent`

### 役割
DB実装の専門家（Migration, Model, Seeder）

### 入力
spec_id を受け取り、自律的に仕様を取得して実装

### 最初に実行すること
```bash
./scripts/blueprint-db-cli.sh get core overview main
./scripts/blueprint-db-cli.sh get data tables {slug}  # spec_id から取得
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

## Agent 2: `livewire-agent`

### 役割
UI実装の専門家（Livewire Component + Blade）

**Migration/Model/Seeder は作成しない。db-agent の責務。**

### 入力
spec_id を受け取り、自律的に仕様を取得して実装

### 最初に実行すること
```bash
./scripts/blueprint-db-cli.sh get core overview main
./scripts/blueprint-db-cli.sh get ui pages {slug}  # spec_id から取得
# depends_on があれば依存先も取得
```

### 出力物
1. Livewire Component (`app/Livewire/`)
2. Blade テンプレート (`resources/views/livewire/`)
3. ルート追加 (`routes/web.php`)
4. Level1 Feature テスト (`tests/Feature/Livewire/`)

---

## Agent 3: `action-agent`

### 役割
バックエンドロジック実装の専門家（Actions, Jobs, Events, Commands）

### 入力
spec_id を受け取り、自律的に仕様を取得して実装

### 最初に実行すること
```bash
./scripts/blueprint-db-cli.sh get core overview main
./scripts/blueprint-db-cli.sh get action {type} {slug}  # spec_id から取得
# depends_on があれば依存先も取得
```

### 出力物
1. Action クラス (`app/Actions/`)
2. Job クラス (`app/Jobs/`)
3. Event / Listener クラス
4. Command クラス (`app/Console/Commands/`)
5. Level1 Unit テスト

---

## Agent 4: `test-agent`

### 役割
テストコード作成・実行の専門家

**テスト設計は /blueprint が spec として定義済み。test-agent はコード作成と実行のみ。**

### 入力
spec_id (test/unit, test/feature, test/e2e) を受け取り、テストコードを作成・実行

### 最初に実行すること
```bash
./scripts/blueprint-db-cli.sh get test {type} {slug}  # spec_id から取得
# depends_on から対象の ui/pages または action spec を取得
```

### 出力物

| Type | Output |
|------|--------|
| unit | `tests/Unit/{path}/{Name}Test.php` |
| feature | `tests/Feature/{path}/{Name}Test.php` |
| e2e | `tests/e2e/specs/{slug}.spec.ts` |

### E2E テストコードテンプレート

```typescript
// tests/e2e/specs/{slug}.spec.ts
import { test, expect } from '@playwright/test';

const BASE_URL = process.env.APP_URL || 'http://localhost:8000';

test.describe('{ページ名}', () => {
  test('{scenario-name}: {description}', async ({ page }) => {
    await page.goto(BASE_URL + '{path}');

    // assertions from spec.scenarios[].assertions
    await expect(page.locator('h1')).toBeVisible();
  });
});
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

/blueprint:
  1. AskUserQuestion で要件確認
  2. core/overview/main を作成
  3. data/tables/tasks を作成（seeders.dev 含む）
  4. ui/pages/todo-index を作成（depends_on: data/tables/tasks）
  5. test/e2e/todo-index を作成（depends_on: ui/pages/todo-index、scenarios 定義）
  6. 依存順で agents を起動:
     Wave 1: db-agent (spec_id=2) → background
     Wave 2: livewire-agent (spec_id=3) → background
     Wave 3: test-agent (spec_id=4) → background
  7. 結果確認、失敗があれば修正

/blueprint:
  「テストが失敗しました」
  → spec を修正 or agent を再起動
```
