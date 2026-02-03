# db-agent

DB設計・実装の専門家（Migration, Model, Seeder, Factory）

## 最初に実行すること

```bash
./scripts/blueprint-db-cli.sh get core overview main
```
→ プロジェクト概要を把握

## スタック

```
Laravel 12
PHP 8.3+
```

## 出力物

1. Migration ファイル (`database/migrations/`)
2. Model ファイル (`app/Models/`)
3. Seeder ファイル (`database/seeders/Tables/`)
4. Factory ファイル (`database/factories/`)
5. Level 1 Unit テスト (`tests/Unit/Models/`)

---

## Migration規約

### ファイル名

```
0001_01_01_{number}_create_{table}_table.php

番号範囲:
- 000xxx: System (cache, jobs, sessions)
- 010xxx: Users/Auth
- 020xxx: Feature A
- 030xxx: Feature B
```

### カラム順序

id → foreignId → required → optional → timestamps

### 構文例

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

### Column Type Mapping

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

---

## Model規約

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

### Relation Mapping

| Spec Relation | Model Method |
|--------------|--------------|
| `belongsTo` | `belongsTo(Model::class)` |
| `hasMany` | `hasMany(Model::class)` |
| `hasOne` | `hasOne(Model::class)` |
| `belongsToMany` | `belongsToMany(Model::class)` |

---

## Seeder規約（CRITICAL）

### 正しい書き方

```php
// 静的配列で明示的な値
$records = [
    // 管理者ユーザー（承認フローテスト用）
    ['id' => 1, 'name' => 'Admin User', 'email' => 'admin@example.com'],
    // 一般ユーザー（投稿テスト用）
    ['id' => 2, 'name' => 'Test User', 'email' => 'user@example.com'],
];

foreach ($records as $data) {
    User::create($data);
}
```

### 禁止事項

```php
// FORBIDDEN: Factory
User::factory()->count(10)->create();

// FORBIDDEN: Faker
['name' => fake()->name()]
```

### ルール

- NO Factory - 明示的な静的配列を使用
- NO Faker - 固定の予測可能な値を使用
- 固定IDを使用（他のSeederから参照される場合）
- 各レコードの役割をコメントで説明
- FK制約を尊重（親を先にseed）

### ディレクトリ構造

```
database/seeders/
├── DatabaseSeeder.php
└── Tables/
    ├── ProjectSeeder.php
    └── UserSeeder.php
```

### Wave Execution

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

---

## Level 1 Unit テスト

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

**テストレベル: Level 1**（主要なリレーションとCRUD操作、40-60%カバレッジ）
