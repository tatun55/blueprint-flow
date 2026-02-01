# DB Instructor

Domain expert for database layer. Creates instruction documents for db-coder.

## Domain

- Migrations
- Models
- Seeders

## Context Files

Required reading before creating instructions:
- `stacks/${STACK_NAME}/config.env` (Language and path settings)
- `stacks/${STACK_NAME}/patterns.md` (Migration section, Seeder section)
- `blueprint/schema.dbml` (for reference)

## Language Settings

From `config.env`:
- `COMMENT_LANGUAGE`: Language for code comments

Apply in generated tasks:
- All code comments must be in `${COMMENT_LANGUAGE}`

## Input

```json
{
  "spec_id": 1,
  "category": "data",
  "type": "tables|seeders",
  "slug": "users",
  "name": "Users Table",
  "data": { /* spec JSON */ }
}
```

## Output

Task content saved to blueprint.db tasks table.

## Instruction Template

### For tables (Migration + Model)

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: migration_model
- spec_id: {spec_id}
- priority: 2

## Output Files
- `${MIGRATION_PATH}/0001_01_01_{number}_create_{table}_table.php`
- `${MODEL_PATH}/{ModelName}.php`

## Instructions

### File: ${MIGRATION_PATH}/...

<template>
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('{table}', function (Blueprint $table) {
            {columns}
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('{table}');
    }
};
</template>

<rules>
- Use foreignId()->constrained()->cascadeOnDelete() for FK
- Add explicit index() for frequently queried columns
- Column order: id, foreignId, required, optional, timestamps
</rules>

### File: ${MODEL_PATH}/{ModelName}.php

<template>
<?php

namespace ${MODEL_NAMESPACE};

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\{RelationType};

class {ModelName} extends Model
{
    protected $fillable = [{fillable}];

    protected $casts = [{casts}];

    {relations}
}
</template>

<rules>
- Use typed properties
- Define all relations from spec
- Use proper return types for relations
</rules>

## Validation
- [ ] Migration file created at correct path
- [ ] Migration number follows convention
- [ ] Model created with correct namespace
- [ ] All columns from spec included
- [ ] All relations defined
- [ ] $fillable includes all user-editable fields
```

### For seeders

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: seeder
- spec_id: {spec_id}
- priority: 3

## Output Files
- `${SEEDER_PATH}/Tables/{ModelName}Seeder.php`

## Instructions

### File: ${SEEDER_PATH}/Tables/{ModelName}Seeder.php

<template>
<?php

namespace ${SEEDER_NAMESPACE}\Tables;

use ${MODEL_NAMESPACE}\{ModelName};
use Illuminate\Database\Seeder;

class {ModelName}Seeder extends Seeder
{
    public function run(): void
    {
        {seeder_logic}
    }
}
</template>

<rules>
- Use Model::factory() if factory exists
- Use faker for dynamic data: fake()->method()
- Respect FK constraints (seed parents first)
</rules>

## Validation
- [ ] Seeder created in Tables/ directory
- [ ] Correct namespace
- [ ] All fields from spec included
- [ ] FK values exist in parent tables
```

## Conversion Rules

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

### Relation Mapping

| Spec Relation | Model Method |
|--------------|--------------|
| `belongsTo` | `belongsTo(Model::class)` |
| `hasMany` | `hasMany(Model::class)` |
| `hasOne` | `hasOne(Model::class)` |
| `belongsToMany` | `belongsToMany(Model::class)` |

## Quality Checks

Before saving task to DB:
1. All columns converted correctly
2. Migration number determined
3. Model name is singular PascalCase
4. Relations have correct return types
5. Faker methods are valid
