# Blueprint-Flow 設計書

> tall-daisy スタック向け開発フロー定義

## 全体構成

```
Skills (3つ)               Agents (4つ)
────────────────────       ────────────────────
/blueprint → 仕様策定      db-agent       → DB実装
/coding    → 実装          livewire-agent → UI実装（+依存DB）
/e2e       → E2Eテスト     action-agent   → バックエンド
                           test-agent     → E2Eテスト
```

**注意**: DB設計は `/blueprint` が担当（仕様の一部として管理）

---

## 共通設計原則

### Skill（スキル）の本質

**スキル = メインへのプロンプト注入コマンド**

- よく使うプロンプトを再利用可能にしたもの
- 専門知識を持たない
- 簡潔で一般的な開発フローの定義
- `$ARGUMENTS` でテキスト指示を受け取る

### Agent（エージェント）の本質

**Agent = システムプロンプト注入による専門家**

- 親コンテキストは継承されない
- 各Agentは自己完結型タスクを実行
- 専門知識とコーディングルールを埋め込む

---

## tall-daisy スタック

### バージョン情報（全Agent共通）

```
Laravel 12
Livewire 4
Tailwind CSS 4
daisyUI 5
Alpine.js 3
PHP 8.3+
```

### 共通設計方針（全Agent共通）

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
$this->userService->updateName($user, $name);

// GOOD: 標準のValidation
#[Validate('required|string|max:255')]
public string $name = '';

// AVOID: カスタムバリデータの乱用
$this->customValidator->validateUserName($name);
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

    $tax = (int) ($subtotal * 0.1);
    $total = $subtotal + $tax;

    return $total;
}

// AVOID: 短いが読みにくい
public function calculateTotal(array $items): int
{
    return (int) (array_reduce($items, fn($c, $i) => $c + $i['price'] * $i['quantity'], 0) * 1.1);
}
```

#### 4. 自律定義・自己完結

```php
// GOOD: ファイル内で完結
class CreateUser
{
    public function execute(string $name, string $email): User
    {
        // バリデーション、作成、イベント発火がこのファイル内で完結
        $user = User::create([
            'name' => $name,
            'email' => $email,
        ]);

        event(new UserCreated($user));

        return $user;
    }
}

// AVOID: 過度な抽象化で追跡困難
class CreateUser
{
    public function __construct(
        private ValidatorInterface $validator,
        private UserFactoryInterface $factory,
        private EventDispatcherInterface $events,
    ) {}
}
```

---

## テストレベル定義

### Unit/Feature Test Levels（各Agent が書くテスト）

| Level | Coverage | Content |
|-------|----------|---------|
| 1 | 40-60% | 主要なCRUD操作、基本リレーション |
| 2 | 60-80% | バリデーション、エッジケース |
| 3 | 80%+ | 全パス網羅、例外処理 |

**デフォルト: Level 1**（各Agentは自動でLevel 1を作成）

### E2E Test Levels（test-agent が設計・実行）

| Level | Coverage | Content |
|-------|----------|---------|
| 1 | 20-40% | ページ表示、主要アクション |
| 2 | 40-60% | フォーム、モーダル、フィルター |
| 3 | 60%+ | エラー状態、空状態、バリデーションエラー |

### 専門知識の配分

| Agent | 持つ知識 |
|-------|----------|
| db-agent | Migration, Model, Seeder, Factory |
| livewire-agent | Livewire, Blade, daisyUI, Tailwind, Alpine |
| action-agent | Actions, Jobs, Events, Commands |
| test-agent | E2E設計, Playwright MCP |

---

## データベース定義

### blueprint.db（仕様管理）

```sql
-- specs: 仕様定義
CREATE TABLE specs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL,        -- core, data, ui, action
    type TEXT NOT NULL,            -- overview, tables, pages, sync, etc.
    slug TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'draft',   -- draft → pending_review → approved → in_progress → impl_review → testing → done
    working_by TEXT,               -- ロック中のAgent ID
    branch TEXT,                   -- Git worktree
    human_reviewed INTEGER DEFAULT 0,
    revision_count INTEGER DEFAULT 0,
    revision_reason TEXT,
    e2e_status TEXT,               -- pending, passed, failed (UI系のみ)
    e2e_level INTEGER DEFAULT 1,   -- 1-3
    wave INTEGER DEFAULT 1,        -- Legacy ordering
    data JSON NOT NULL,            -- 仕様の詳細データ
    created_at DATETIME,
    updated_at DATETIME,
    UNIQUE(category, type, slug)
);

-- spec_dependencies: 依存関係
CREATE TABLE spec_dependencies (
    spec_id INTEGER NOT NULL,
    blocked_by_spec_id INTEGER NOT NULL,  -- spec_idはblocked_by_spec_idが完了するまでブロック
    UNIQUE(spec_id, blocked_by_spec_id)
);

-- tasks: Agent向け指示書
CREATE TABLE tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    spec_id INTEGER NOT NULL,
    agent_type TEXT NOT NULL,  -- db-agent, livewire-agent, action-agent, test-agent
    content TEXT NOT NULL,
    status TEXT DEFAULT 'pending'   -- pending, completed, failed
);
```

**Category/Type構成:**
| Category | Types | 説明 |
|----------|-------|------|
| core | overview, const | プロジェクト概要、定数定義 |
| data | tables | DB設計（seeders定義を含む） |
| ui | pages, partials, layouts | 画面、パーツ、レイアウト |
| action | sync, async, scheduled | Action, Job, Command |

**depends_on**: 各specは他specへの依存を明示可能（ui→data、action→data）

### e2e.db（E2Eテスト管理）

```sql
-- test_cases: テストケース定義
CREATE TABLE test_cases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    spec_id INTEGER,               -- blueprint specとの紐付け
    level INTEGER DEFAULT 1,       -- 1-3
    url TEXT NOT NULL,
    viewport_width INTEGER DEFAULT 1280,
    viewport_height INTEGER DEFAULT 720,
    status TEXT DEFAULT 'defined'  -- defined, active, disabled
);

-- test_runs: テスト実行記録
CREATE TABLE test_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    test_case_id INTEGER NOT NULL,
    run_at DATETIME,
    result TEXT DEFAULT 'pending', -- pending, passed, failed, error
    screenshot_path TEXT,
    baseline_path TEXT,
    diff_percentage REAL,
    human_reviewed INTEGER DEFAULT 0,
    error_message TEXT,
    duration_ms INTEGER,
    executor TEXT DEFAULT 'claude',
    notes TEXT
);

-- screenshots: スクリーンショット
CREATE TABLE screenshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    test_run_id INTEGER NOT NULL,
    type TEXT NOT NULL,            -- baseline, actual, diff
    file_path TEXT NOT NULL
);
```

---

## Skill 1: `/blueprint`

### ファイル
`skills/blueprint/SKILL.md`

### 目的
仕様策定・プロジェクト状況把握・開発フロー提案・Blueprint自体の更新

### 入力
| パターン | 動作 |
|----------|------|
| `/blueprint` | プロジェクト状況を分析し、推奨アクションを提示 |
| `/blueprint pull` | blueprint-flowサブモジュールを最新版に更新 |
| `/blueprint <指示>` | 指示に基づいて仕様を策定・更新 |

### Blueprint仕様の品質基準

Blueprintは以下の要件を満たす必要がある：

1. **コーディング可能** - 実装者が迷わず着手できる
2. **具体的** - 曖昧さがない
3. **詳細** - 必要な情報が揃っている
4. **意図が明確** - なぜこの仕様かが分かる
5. **無駄がない** - 冗長な記述を避ける
6. **正確** - 誤解の余地がない

### 足りない情報の取得

仕様策定時に情報が不足している場合：
1. 不足している情報を特定
2. 提案を含めてAskUserQuestionで確認
3. 回答を反映して仕様を更新
4. 必要に応じて繰り返す

### 使用するCLIコマンド
```bash
./scripts/blueprint-db-cli.sh overview         # 全spec一覧
./scripts/blueprint-db-cli.sh progress         # status別の進捗
./scripts/blueprint-db-cli.sh available        # 実装可能なspec
./scripts/blueprint-db-cli.sh pending-review   # レビュー待ち
./scripts/blueprint-db-cli.sh needs-attention  # 要対応
./scripts/blueprint-db-cli.sh add <cat> <type> <slug> <name> '<json>'  # 追加
./scripts/blueprint-db-cli.sh update <id> '<json>'                      # 更新
./scripts/blueprint-db-cli.sh status <id> <status>                      # ステータス変更
```

### 振る舞いフロー

#### 引数なしの場合
```
1. ./scripts/blueprint-db-cli.sh overview で全spec取得
2. ./scripts/blueprint-db-cli.sh progress で進捗サマリー取得
3. 状況を分析:
   - draft が多い → 「仕様策定を続けますか？」
   - pending_review が多い → 「レビュー待ちが N件あります」
   - approved が多い → 「/db または /coding で実装を開始できます」
   - in_progress が多い → 「実装中のspecがN件あります」
4. AskUserQuestion で推奨アクションを提示
```

#### 引数ありの場合
```
1. $ARGUMENTS を解析
2. 既存specの更新 or 新規作成を判定
3. 適切なcategory/typeを判定:
   - DB関連 → data/tables
   - 画面関連 → ui/pages
   - アクション関連 → action/sync または action/async
4. 情報が足りない場合はAskUserQuestionで取得
5. 必要なspecを作成/更新
6. 依存関係がある場合は add-dep で設定
```

### Status Flow
```
draft → pending_review → approved → in_progress → impl_review → testing → done
              ↑                           ↓
              └────── needs_revision ←────┘
```

### Agentは呼び出さない
人間との対話でspecを詰める

---

## Skill 2: `/coding`

### ファイル
`skills/coding/SKILL.md`

### 目的
実装指示と適切なAgentの選択・起動

### 入力
| パターン | 動作 |
|----------|------|
| `/coding` | blueprint.dbを確認し、実装対象を選択 |
| `/coding <指示>` | 指示を解析して適切なAgentを起動 |

### 振る舞いフロー

#### 引数なしの場合
```
1. ./scripts/blueprint-db-cli.sh available-with-deps で実装可能spec取得
2. specがある場合、AskUserQuestion で選択を促す
3. specがない場合、「approvedのspecがありません」と通知
4. 選択されたspecに応じてAgentを起動:
   - category=ui → livewire-agent
   - category=action → action-agent
```

#### 引数ありの場合
```
1. $ARGUMENTS を解析
2. キーワードで振り分け:
   - ページ, 画面, フォーム, 一覧, モーダル → livewire-agent
   - Action, Job, Event, Command, API → action-agent
   - 両方必要な場合 → 順次起動（livewire → action）
3. Task tool でAgentを起動
```

### 呼び出すAgent
- `livewire-agent` - UI実装（依存テーブルも実装）
- `action-agent` - バックエンド実装

---

## Skill 3: `/e2e`

### ファイル
`skills/e2e/SKILL.md`

### 目的
E2Eテスト設計・コード作成・実行

### 入力
| パターン | 動作 |
|----------|------|
| `/e2e` | e2e.dbを確認し、テスト状況を分析して推奨を提示 |
| `/e2e <指示>` | 指示に基づいてテストを設計・実行 |

### 使用するCLIコマンド
```bash
./scripts/e2e-db-cli.sh overview         # 全テストケース
./scripts/e2e-db-cli.sh attention        # 要対応
./scripts/e2e-db-cli.sh pending-review   # レビュー待ち
./scripts/e2e-db-cli.sh spec-summary     # spec別サマリー
php artisan test                        # Unit/Feature テスト
php artisan test --filter=<name>        # 特定テスト
```

### 振る舞いフロー

#### 引数なしの場合
```
1. ./scripts/e2e-db-cli.sh overview でE2Eテスト状況取得
2. ./scripts/e2e-db-cli.sh attention で要対応テスト確認
3. 分析してAskUserQuestionで提示:
   - 「新しいE2Eテストを作成」→ spec選択 → テストコード作成
   - 「既存テストを実行」→ npx playwright test
   - 「失敗テストを再実行」
4. test-agent を起動
```

#### 引数ありの場合
```
$ARGUMENTS を解釈して適切なアクションを実行
```

### 出力物（CRITICAL）
- テストコード: `tests/e2e/specs/{page-slug}.spec.ts`
- e2e.db登録: シナリオ定義
- テスト実行結果: e2e.dbに記録

**テストコードなしでE2Eテスト完了としてはならない**

### 呼び出すAgent
`test-agent`

---

## Agent 1: `db-agent`

### ファイル
`agents/db-agent.md`

### 役割
DB実装の専門家（Migration, Model, Seeder）

### 最初に実行すること
```bash
./scripts/blueprint-db-cli.sh get core overview main
./scripts/blueprint-db-cli.sh list data tables
```
→ プロジェクト概要とテーブル一覧を把握

### 実装フロー
```
1. テーブル spec を取得（seeders.dev 含む）
2. Migration 作成（spec.columns から）
3. Model 作成（spec.relations から）
4. Seeder 作成（spec.seeders.dev から）
5. php artisan migrate:fresh --seed
6. 結果確認
```

### 出力物
1. Migration ファイル (`database/migrations/`)
2. Model ファイル (`app/Models/`)
3. Seeder ファイル (`database/seeders/`) ← spec の seeders.dev から生成
4. Level1 Unit テスト (`tests/Unit/Models/`)

### 埋め込む専門知識

#### Migration規約
```
ファイル名: 0001_01_01_{number}_create_{table}_table.php

番号範囲:
- 000xxx: System (cache, jobs, sessions)
- 010xxx: Users/Auth
- 020xxx: Feature A
- 030xxx: Feature B

カラム順序: id → foreignId → required → optional → timestamps
```

#### Migration構文
```php
Schema::create('users', function (Blueprint $table) {
    $table->id();
    $table->foreignId('project_id')->constrained()->cascadeOnDelete();
    $table->string('name');
    $table->enum('status', ['active', 'inactive'])->default('active');
    $table->boolean('is_verified')->default(false);
    $table->timestamps();

    $table->index('status');
    $table->index(['project_id', 'status']);
});
```

#### Column Type Mapping
| Spec Type | Migration Method |
|-----------|-----------------|
| `id` | `$table->id()` |
| `string` | `$table->string('name')` |
| `text` | `$table->text('name')` |
| `integer` | `$table->integer('name')` |
| `bigint` | `$table->bigInteger('name')` |
| `boolean` | `$table->boolean('name')` |
| `date` | `$table->date('name')` |
| `datetime` | `$table->dateTime('name')` |
| `json` | `$table->json('name')` |
| `enum` | `$table->enum('name', [...])` |

#### Model規約
```php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Project extends Model
{
    protected $fillable = ['name', 'status'];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    public function tasks(): HasMany
    {
        return $this->hasMany(Task::class);
    }
}
```

#### Relation Mapping
| Spec Relation | Model Method |
|--------------|--------------|
| `belongsTo` | `belongsTo(Model::class)` |
| `hasMany` | `hasMany(Model::class)` |
| `hasOne` | `hasOne(Model::class)` |
| `belongsToMany` | `belongsToMany(Model::class)` |

#### Seeder規約（CRITICAL）
```php
// CORRECT: 静的配列で明示的な値
$records = [
    // 管理者ユーザー（承認フローテスト用）
    ['id' => 1, 'name' => 'Admin User', 'email' => 'admin@example.com'],
    // 一般ユーザー（投稿テスト用）
    ['id' => 2, 'name' => 'Test User', 'email' => 'user@example.com'],
];

foreach ($records as $data) {
    User::create($data);
}

// FORBIDDEN: Factory, Faker
User::factory()->count(10)->create();  // NG
['name' => fake()->name()]             // NG
```

ルール:
- NO Factory - 明示的な静的配列を使用
- NO Faker - 固定の予測可能な値を使用
- 固定IDを使用（他のSeederから参照される場合）
- 各レコードの役割をコメントで説明
- FK制約を尊重（親を先にseed）

#### Seeder Directory Structure
```
database/seeders/
├── DatabaseSeeder.php
└── Tables/
    ├── ProjectSeeder.php
    └── UserSeeder.php
```

#### Wave Execution
```php
public function run(): void
{
    $this->call([
        // Wave 1: Base tables (no FK)
        Tables\ProjectSeeder::class,

        // Wave 2: Dependent tables
        Tables\UserSeeder::class,

        // Wave 3: Junction tables
        Tables\ProjectUserSeeder::class,
    ]);
}
```

#### Level1 Unit テスト
```php
// tests/Unit/Models/UserTest.php
test('can create user', function () {
    $user = User::create([
        'name' => 'Test',
        'email' => 'test@example.com',
    ]);

    expect($user)->toBeInstanceOf(User::class);
    expect($user->name)->toBe('Test');
});

test('user belongs to project', function () {
    $project = Project::factory()->create();
    $user = User::create([
        'name' => 'Test',
        'email' => 'test@example.com',
        'project_id' => $project->id,
    ]);

    expect($user->project)->toBeInstanceOf(Project::class);
});
```

**テストレベル: Level 1**（主要なリレーションとCRUD操作）

---

## Agent 2: `livewire-agent`

### ファイル
`agents/livewire-agent.md`

### 役割
UI実装の専門家（Livewire Component + Blade + 依存DB実装）

### 最初に実行すること
```bash
./scripts/blueprint-db-cli.sh get core overview main
```
→ プロジェクト概要を把握

### 実装フロー（depends_on 活用）
```
1. ui/pages spec を取得して depends_on を確認
2. depends_on に data/tables がある場合:
   - テーブル spec を取得（seeders.dev 含む）
   - Migration, Model, Seeder を作成
   - php artisan migrate:fresh --seed
3. Livewire コンポーネント実装
4. Feature テスト作成・実行
```

### 出力物
1. **依存テーブル**（depends_on にある場合）
   - Migration, Model, Seeder（spec.seeders.dev から）
2. Livewire Component (`app/Livewire/`)
3. Blade テンプレート (`resources/views/livewire/`)
4. ルート追加（必要に応じて `routes/web.php`）
5. Level1 Feature テスト (`tests/Feature/Livewire/`)

### ディレクトリ構造
```
app/Livewire/
├── Pages/{Feature}/      # フルページコンポーネント
│   ├── Index.php
│   ├── Create.php
│   └── Edit.php
├── Partials/             # 再利用パーツ
└── Layouts/              # レイアウト

resources/views/livewire/
├── pages/{feature}/
│   ├── index.blade.php
│   ├── create.blade.php
│   └── edit.blade.php
├── partials/
└── layouts/
```

### 埋め込む専門知識

#### Livewire Fullpage Component
```php
namespace App\Livewire\Pages\Users;

use Livewire\Attributes\Layout;
use Livewire\Component;

#[Layout('livewire.layouts.app')]
class Index extends Component
{
    public function render()
    {
        return view('livewire.pages.users.index');
    }
}
```

Route: `Route::get('/users', \App\Livewire\Pages\Users\Index::class);`

#### Validation
```php
use Livewire\Attributes\Validate;

#[Validate('required|string|max:255')]
public string $name = '';
```

#### Data Binding
- Default: `wire:model.blur` (blur時に同期)
- Real-time: `wire:model.live` (検索、オートコンプリートのみ)

#### Component Communication
```php
// Dispatch
$this->dispatch('user-selected', id: $userId);

// Listen
#[On('user-selected')]
public function onUserSelected(int $id): void {}
```

#### daisyUI Form Structure（CRITICAL）
```html
<!-- 禁止: form-control, label > label-text -->

<!-- 正しい構造 -->
<div>
    <label class="block text-sm font-medium mb-1.5">Name</label>
    <input class="input input-bordered w-full @error('name') input-error @enderror" />
    @error('name')
        <p class="text-error text-sm mt-1">{{ $message }}</p>
    @enderror
</div>
```

#### Common daisyUI Classes
| Element | Class |
|---------|-------|
| Button Primary | `btn btn-primary` |
| Button Ghost | `btn btn-ghost` |
| Input | `input input-bordered` |
| Select | `select select-bordered` |
| Alert | `alert alert-{type}` |
| Badge | `badge badge-{type}` |

#### Responsive Design（Mobile-First必須）
```html
<!-- 正しい: モバイルファースト -->
<div class="p-4 md:p-6 lg:p-8">
<div class="flex flex-col md:flex-row">

<!-- 禁止: デスクトップファースト -->
<div class="p-8 sm:p-4">
```

Breakpoints:
| Prefix | Min Width | Device |
|--------|-----------|--------|
| (none) | 0px | Mobile (default) |
| `sm:` | 640px | Landscape phone |
| `md:` | 768px | Tablet |
| `lg:` | 1024px | Laptop |
| `xl:` | 1280px | Desktop |

Touch Target: 最小44x44px
```html
<button class="btn min-h-11 min-w-11">
```

#### Alpine.js（UI操作のみ）
```html
<div x-data="{ open: false }">
    <button @click="open = !open">Menu</button>
    <div x-show="open" @click.outside="open = false">...</div>
</div>
```

複雑な状態 → Livewireを使用

10行以上 → 別ファイル化:
```js
// resources/js/components/data-table.js
export default () => ({
    sortColumn: null,
    sortDirection: 'asc',
    // ...
})
```

#### Animation
| Type | Duration | Use Case |
|------|----------|----------|
| Fast | 150ms | Hover, focus |
| Normal | 200ms | Dropdowns |
| Slow | 300ms | Modals |

```html
<div x-show="open"
     x-transition:enter="transition ease-out duration-200"
     x-transition:enter-start="opacity-0 -translate-y-2"
     x-transition:enter-end="opacity-100 translate-y-0"
     x-transition:leave="transition ease-in duration-150"
     x-transition:leave-start="opacity-100 translate-y-0"
     x-transition:leave-end="opacity-0 -translate-y-2">
```

#### Common UI Patterns

**Page Header**
```html
<div class="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-3 mb-6">
    <h1 class="text-xl md:text-2xl font-bold">Title</h1>
    <button class="btn btn-primary w-full sm:w-auto">Action</button>
</div>
```

**Modal**
```html
<dialog class="modal" :class="{ 'modal-open': show }">
    <div class="modal-box">
        <h3 class="text-lg font-bold mb-6">Title</h3>
        <form wire:submit="save" class="space-y-5">
            <!-- Fields -->
            <div class="flex justify-end gap-3 pt-4">
                <button type="button" class="btn btn-ghost" @click="show = false">Cancel</button>
                <button type="submit" class="btn btn-primary">Save</button>
            </div>
        </form>
    </div>
    <div class="modal-backdrop" @click="show = false"></div>
</dialog>
```

**Table Responsiveness**
| Columns | Strategy |
|---------|----------|
| 1-3 | Keep table |
| 4-5 | Hide columns: `hidden md:table-cell` |
| 6+ | Card transformation on mobile |

#### Anti-Patterns（禁止）
- `form-control`, `label > label-text` ラッパー
- デスクトップファースト: `flex-row sm:flex-col`
- 小さいタッチターゲット: `p-1 text-xs`
- 固定幅によるoverflow: `w-[800px]`

#### Level1 Feature テスト
```php
use Livewire\Livewire;

test('can display user list', function () {
    Livewire::test(\App\Livewire\Pages\Users\Index::class)
        ->assertStatus(200)
        ->assertSee('Users');
});

test('can create user', function () {
    Livewire::test(\App\Livewire\Pages\Users\Create::class)
        ->set('name', 'John Doe')
        ->set('email', 'john@example.com')
        ->call('save')
        ->assertHasNoErrors();

    expect(User::where('email', 'john@example.com')->exists())->toBeTrue();
});
```

**テストレベル: Level 1**（表示とメインアクション）

---

## Agent 3: `action-agent`

### ファイル
`agents/action-agent.md`

### 役割
バックエンドロジック実装の専門家（Actions, Jobs, Events, Commands）

### 最初に実行すること
```bash
./scripts/blueprint-db-cli.sh get core overview main
```
→ プロジェクト概要を把握

### 実装フロー（depends_on 活用）
```
1. action spec を取得して depends_on を確認
2. depends_on に data/tables がある場合:
   - テーブル spec を取得してModel構造を把握
3. Action/Job/Command クラスを実装
4. Unit テスト作成・実行
```

### 出力物
1. Action クラス (`app/Actions/`)
2. Job クラス (`app/Jobs/`)
3. Event クラス (`app/Events/`)
4. Listener クラス (`app/Listeners/`)
5. Command クラス (`app/Console/Commands/`)
6. Level1 Unit テスト (`tests/Unit/Actions/`, etc.)

### ディレクトリ構造
```
app/
├── Actions/              # 同期アクション
│   └── CreateUser.php
├── Jobs/                 # 非同期処理
│   └── ProcessImport.php
├── Events/               # イベント
│   └── UserCreated.php
├── Listeners/            # リスナー
│   └── SendWelcomeEmail.php
└── Console/Commands/     # Artisanコマンド
    └── CleanupOldData.php
```

### 埋め込む専門知識

#### Action Pattern（同期）
```php
namespace App\Actions;

class CreateUser
{
    public function execute(string $name, string $email): User
    {
        $user = User::create([
            'name' => $name,
            'email' => $email,
        ]);

        event(new UserCreated($user));

        return $user;
    }
}
```

ルール:
- 単一のpublicメソッド: `execute()`
- 型付きパラメータと戻り値
- 処理完了後にイベントをdispatch

#### Event Naming Convention
| Action | Event |
|--------|-------|
| `CreateUser` | `UserCreated` |
| `UpdateProject` | `ProjectUpdated` |
| `DeleteTask` | `TaskDeleted` |

パターン: `{Model}{PastTenseAction}`

#### Event Pattern
```php
namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class UserCreated
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public readonly User $user
    ) {}
}
```

ルール:
- コンストラクタでreadonly properties
- Eloquentモデルには SerializesModels
- シンプルに保つ（データコンテナ）

#### Job Pattern（非同期）
```php
namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ProcessImport implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(
        public readonly string $filePath
    ) {}

    public function handle(): void
    {
        // Job logic
    }

    public function failed(\Throwable $exception): void
    {
        // Error handling
    }
}
```

#### Command Pattern
```php
namespace App\Console\Commands;

use Illuminate\Console\Command;

class CleanupOldData extends Command
{
    protected $signature = 'app:cleanup-old-data';
    protected $description = 'Remove data older than 30 days';

    public function handle(): int
    {
        $this->info('Starting cleanup...');

        // Command logic

        return Command::SUCCESS;
    }
}
```

Schedule: `Schedule::command('app:cleanup-old-data')->daily();`

#### Level1 Unit テスト
```php
test('CreateUser action creates user and dispatches event', function () {
    Event::fake();

    $action = new CreateUser();
    $user = $action->execute('John', 'john@example.com');

    expect($user->name)->toBe('John');
    Event::assertDispatched(UserCreated::class);
});
```

**テストレベル: Level 1**（メインロジックとイベント発火）

---

## Agent 4: `test-agent`

### ファイル
`agents/test-agent.md`

### 役割
E2Eテスト設計・コード作成・実行の専門家

### 重要な原則
- **再現可能なテストコードを作成する**（手動操作ではなく自動化）
- 仕様ベースでテスト設計（ui/pages spec の operations を参照）
- ユーザー視点でテスト

### 最初に実行すること
```bash
APP_URL=$(grep APP_URL .env | cut -d '=' -f2)
lsof -i :5173 > /dev/null 2>&1 || (npm run dev &; sleep 3)
./scripts/blueprint-db-cli.sh get core overview main
./scripts/e2e-db-cli.sh overview
```
→ 環境確認、プロジェクト概要とE2Eテスト状況を把握

### E2Eテスト作成フロー（depends_on 活用）
```
1. ui/pages spec を取得（operations, depends_on 含む）
2. depends_on からテスト対象のデータ構造を把握
3. operationsごとにテストケース設計
4. テストコード作成: tests/e2e/specs/{page-slug}.spec.ts
5. テスト実行: npx playwright test
6. 結果を e2e.db に記録
```

### 出力物（CRITICAL）
1. **テストコード**: `tests/e2e/specs/{page-slug}.spec.ts`
2. e2e.db登録: シナリオ定義
3. テスト実行結果
4. スクリーンショット (`tests/e2e/screenshots/`)

**テストコードなしでE2Eテスト完了としてはならない**

### 使用するCLIコマンド
```bash
./scripts/e2e-db-cli.sh add <slug> <name> <url> [viewport] [spec_id] [level]
./scripts/e2e-db-cli.sh run <slug>
./scripts/e2e-db-cli.sh result <run_id> <passed|failed> [notes]
./scripts/e2e-db-cli.sh screenshot <run_id> <type> <path>
./scripts/e2e-db-cli.sh reviewed <run_id>
```

### 埋め込む専門知識

#### E2E Test Levels
「テストレベル定義」セクションを参照

#### Screenshot Naming
```
tests/e2e/screenshots/{run_id}_{slug}_{state}.png
```

States:
- `initial` - ページ読み込み
- `after_{action}` - 操作後
- `error` - エラー状態
- `empty` - 空状態

#### Playwright MCP使用法
```
mcp__playwright-mcp__playwright_navigate   # headless: true
mcp__playwright-mcp__playwright_screenshot # savePng: true
mcp__playwright-mcp__playwright_close      # 必ず閉じる
```

### テスト実行フロー
```
1. ./scripts/e2e-db-cli.sh run <slug> でrun_id取得
2. playwright_navigate でページ遷移
3. playwright_screenshot で初期状態を保存
4. 操作を実行
5. playwright_screenshot で操作後状態を保存
6. ./scripts/e2e-db-cli.sh result <run_id> passed|failed
7. ./scripts/e2e-db-cli.sh screenshot <run_id> <type> <path>
8. playwright_close で終了
```

---

## 追加提案

### 1. overview specの自動作成
`/blueprint` 初回実行時に `core/overview/main` specが存在しない場合、対話的に作成を促す。

### 2. spec間の依存関係可視化
`/blueprint deps` サブコマンドで依存関係グラフを表示。

### 3. 実装進捗ダッシュボード
`/blueprint` 引数なし実行時に、視覚的な進捗バーを表示。

```
Progress:
  draft          ████████░░░░░░░░ 50% (5/10)
  approved       ████░░░░░░░░░░░░ 20% (2/10)
  in_progress    ██░░░░░░░░░░░░░░ 10% (1/10)
  done           ██░░░░░░░░░░░░░░ 10% (1/10)
```

### 4. 自動テスト実行
各Agent完了時に自動で `php artisan test` を実行し、失敗があれば報告。

### 5. db-agentの変更検知
既存のmigration/modelがある場合、差分を検知して「追加migration」か「rollback & 再作成」かを提案。
