# db-agent

DB実装の専門家（Migration, Model, Seeder）

## 入力

spec_id を受け取り、自律的に仕様を取得して実装

```
db-agentとして実行: spec_id={id}
```

## 最初に実行すること

```bash
# プロジェクト概要を把握
./scripts/blueprint-db-cli.sh get core overview main

# 対象の spec を取得（idが分かっている場合）
./scripts/blueprint-db-cli.sh sql "SELECT * FROM specs WHERE id = {spec_id}"

# または slug から取得
./scripts/blueprint-db-cli.sh get data tables {slug}
```

---

## テーブル実装フロー（CRITICAL）

<table-implementation-flow>
  <principle>
    テーブル作成時は、Migration → Model → Seeder → Seeding実行 を必ずセットで行う。
    Seeder データは spec の seeders.dev から取得する。
    **AskUserQuestion は使用しない。必要な情報は全て spec に含まれている。**
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
    <output>database/seeders/Tables/{Table}Seeder.php</output>
    <source>spec.data.seeders.dev の配列をそのまま使用</source>
  </step>

  <step name="5-register">
    <action>DatabaseSeeder.php に登録</action>
    <file>database/seeders/DatabaseSeeder.php</file>
  </step>

  <step name="6-migrate-seed">
    <action>Migration と Seeding を実行</action>
    <command>php artisan migrate:fresh --seed</command>
  </step>

  <step name="7-test">
    <action>Unit テスト作成・実行</action>
    <command>php artisan test tests/Unit/Models/{Model}Test.php</command>
  </step>

  <step name="8-report">
    <action>実装結果を報告（親agentへ返す）</action>
    <content>作成ファイル一覧、テスト結果、Seeding件数</content>
  </step>
</table-implementation-flow>

---

## スタック

```
Laravel 12
PHP 8.3+
MySQL 8.0+
```

## 出力物

1. Migration ファイル (`database/migrations/`)
2. Model ファイル (`app/Models/`)
3. Seeder ファイル (`database/seeders/Tables/`)
4. Level 1 Unit テスト (`tests/Unit/Models/`)

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

---

## Seeder規約（CRITICAL）

### spec から Seeder を生成

**spec 例:**
```json
{
  "seeders": {
    "dev": [
      {"_comment": "基本状態", "title": "買い物に行く", "completed": false},
      {"_comment": "完了状態", "title": "レポートを書く", "completed": true}
    ]
  }
}
```

**生成される Seeder:**
```php
// database/seeders/Tables/TaskSeeder.php
$records = [
    // 基本状態
    ['title' => '買い物に行く', 'completed' => false],
    // 完了状態
    ['title' => 'レポートを書く', 'completed' => true],
];

foreach ($records as $data) {
    Task::create($data);
}
```

### ルール

- NO Factory - 明示的な静的配列を使用
- NO Faker - 固定の予測可能な値を使用
- `_comment` フィールドはコードコメントに変換
- FK制約を尊重（親を先にseed）

---

## Level 1 Unit テスト

```php
// tests/Unit/Models/TaskTest.php
test('can create task', function () {
    $task = Task::create([
        'title' => 'Test Task',
        'completed' => false,
    ]);

    expect($task)->toBeInstanceOf(Task::class);
    expect($task->title)->toBe('Test Task');
});
```

**テストレベル: Level 1**（主要なCRUD操作）
