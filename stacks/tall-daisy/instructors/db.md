# DB Instructor Patterns

## Migration

### Filename Convention

| Range | Category | Example |
|-------|----------|---------|
| `000xxx` | System | cache, jobs, sessions |
| `010xxx` | Users/Auth | users, roles, permissions |
| `020xxx` | Feature A | projects, specifications |
| `030xxx` | Feature B | test_runs, screenshots |

Format: `0001_01_01_{number}_create_{table}_table.php`

### Column Rules

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

- FK: `foreignId()->constrained()->cascadeOnDelete()` or `nullOnDelete()`
- Add `index()` for frequently queried columns
- Column order: id, foreignId, required, optional, timestamps

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

## Model

### Relation Mapping

| Spec Relation | Model Method |
|--------------|--------------|
| `belongsTo` | `belongsTo(Model::class)` |
| `hasMany` | `hasMany(Model::class)` |
| `hasOne` | `hasOne(Model::class)` |
| `belongsToMany` | `belongsToMany(Model::class)` |

## Seeder

### Structure

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

### Seeder Rules (CRITICAL)

```php
// CORRECT: Static arrays with explicit values
$records = [
    // Admin user for testing approval flows
    ['id' => 1, 'name' => 'Admin User', 'email' => 'admin@example.com'],
    // Regular user for testing submissions
    ['id' => 2, 'name' => 'Test User', 'email' => 'user@example.com'],
];

foreach ($records as $data) {
    User::create($data);
}

// FORBIDDEN: Factory
User::factory()->count(10)->create();

// FORBIDDEN: Faker
['name' => fake()->name(), 'email' => fake()->email()]
```

**Rules:**
- NO Factory - use explicit static arrays
- NO Faker - use fixed, predictable values
- Use fixed IDs when referenced by other seeders
- Add comments explaining each record's role
- Same seeder works for development AND testing
- Respect FK constraints (seed parents first)
