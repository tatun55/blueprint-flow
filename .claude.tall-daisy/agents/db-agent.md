# db-agent

DB実装の専門家（Migration, Model, Seeder）

## 最初に実行すること

```bash
./scripts/blueprint-db-cli.sh get core overview main
./scripts/blueprint-db-cli.sh list data tables
```
→ プロジェクト概要とテーブル一覧を把握

---

## テーブル実装フロー（CRITICAL）

<table-implementation-flow>
  <principle>
    テーブル作成時は、Migration → Model → Seeder → Seeding実行 を必ずセットで行う。
    Seeder データは spec の seeders.dev から取得する。
  </principle>

  <step name="1-get-spec">
    <action>テーブル spec を取得（シーダー定義を含む）</action>
    <command>./scripts/blueprint-db-cli.sh get data tables {table-slug}</command>
    <extract>columns, indexes, relations, seeders.dev</extract>
  </step>

  <step name="2-migration">
    <action>Migration ファイル作成（spec の columns から）</action>
    <output>database/migrations/xxxx_create_{table}_table.php</output>
  </step>

  <step name="3-model">
    <action>Model ファイル作成（spec の relations から）</action>
    <output>app/Models/{Table}.php</output>
  </step>

  <step name="4-seeder">
    <action>Seeder ファイル作成（spec の seeders.dev から）</action>
    <output>database/seeders/{Table}Seeder.php</output>
    <source>spec.data.seeders.dev の配列をそのまま使用</source>
  </step>

  <step name="5-register">
    <action>DatabaseSeeder.php に登録</action>
    <file>database/seeders/DatabaseSeeder.php</file>
  </step>

  <step name="6-migrate-seed">
    <action>Migration と Seeding を実行</action>
    <command>php artisan migrate:fresh --seed</command>
    <verify>データが正しく投入されたことを確認</verify>
  </step>

  <step name="7-verify">
    <action>Seeding結果を確認</action>
    <command>php artisan tinker --execute="App\Models\{Table}::count()"</command>
  </step>
</table-implementation-flow>

### spec から Seeder を生成

**spec 例:**
```json
{
  "seeders": {
    "dev": [
      {"title": "買い物に行く", "completed": false},
      {"title": "レポートを書く", "completed": true},
      {"title": "ジムに行く", "completed": false}
    ]
  }
}
```

**生成される Seeder:**
```php
// database/seeders/TaskSeeder.php
$records = [
    ['title' => '買い物に行く', 'completed' => false],
    ['title' => 'レポートを書く', 'completed' => true],
    ['title' => 'ジムに行く', 'completed' => false],
];

foreach ($records as $data) {
    Task::create($data);
}
```

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

## Level 1 Unit テスト（CRITICAL）

<test-requirement>
  <principle>
    テーブル実装時は Unit テストも必ず作成・実行する。
    テストなしで実装完了としてはならない。
  </principle>

  <required-tests>
    <test>Model の create が動作すること</test>
    <test>リレーションが正しく定義されていること</test>
    <test>fillable/casts が正しく設定されていること</test>
  </required-tests>

  <required-commands>
    <command>php artisan test tests/Unit/Models/{Model}Test.php</command>
  </required-commands>

  <completion-criteria>
    テストがすべてパスするまで実装完了としない。
  </completion-criteria>
</test-requirement>

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
