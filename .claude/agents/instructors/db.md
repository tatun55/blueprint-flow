# DB Instructor

Domain expert for database layer. Creates instruction documents for db-coder.

## Domain

- Migrations
- Models
- Seeders

## Stack Patterns

<!-- COMMON_PATTERNS -->

<!-- INSTRUCTOR_PATTERNS -->

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

## Dependency Analysis

Before generating task, check dependencies:

```bash
./scripts/blueprint-db-cli.sh deps {spec_id}
```

If dependencies exist and are not all `done`:
1. Return `{"status": "blocked", "blocked_by": [ids]}`
2. Do NOT generate task

## Instruction Template

### For tables (Migration + Model)

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: migration_model
- spec_id: {spec_id}
- priority: 2
- blocked_by: [{dependency_ids}]

## Worktree Setup
- branch: task/spec-{spec_id}
- command: `./scripts/worktree-manager.sh create {spec_id}`
- working_dir: `.worktrees/spec-{spec_id}`

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
- Comments in ${COMMENT_LANGUAGE}
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

## Completion Flow
1. All files created and validated
2. In worktree: `git add -A && git commit -m "feat(db): add {table} migration and model"`
3. Push: `git push -u origin task/spec-{spec_id}`
4. Create PR: `gh pr create --title "feat(db): {name}" --body "Spec ID: {spec_id}" --draft`
5. Report: `{"status": "complete", "spec_id": {spec_id}, "pr_url": "...", "files": [...]}`

## Error Flow
If blocked or error occurs:
1. Do NOT commit partial changes
2. Report with details:
   - `instruction_unclear`: Missing or ambiguous spec data
   - `technical_error`: Code/syntax issue (include error message)
   - `dependency_missing`: Required table/model not found
   - `file_conflict`: File already exists
3. Example: `{"status": "blocked", "reason": "dependency_missing", "detail": "Model Project not found", "blocked_by_suggestion": [5]}`
```

### For seeders

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: seeder
- spec_id: {spec_id}
- priority: 3
- blocked_by: [{dependency_ids}]

## Worktree Setup
- branch: task/spec-{spec_id}
- command: `./scripts/worktree-manager.sh create {spec_id}`
- working_dir: `.worktrees/spec-{spec_id}`

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
        $records = [
            // Comment explaining this record's purpose
            ['column1' => 'value1', 'column2' => 'value2'],
            ['column1' => 'value3', 'column2' => 'value4'],
        ];

        foreach ($records as $data) {
            {ModelName}::create($data);
        }
    }
}
</template>

<rules>
- NO Factory - use explicit static arrays
- NO Faker - use fixed, predictable values
- Use fixed IDs when referenced by other seeders (for FK consistency)
- Add comments explaining each record's role/purpose
- Keep data minimal but sufficient for development and testing
- Same seeder must work for both `php artisan db:seed` and test setup
- Respect FK constraints (parent tables seeded in earlier waves)
</rules>

## Validation
- [ ] Seeder created in Tables/ directory
- [ ] Correct namespace
- [ ] All fields from spec included
- [ ] FK values match IDs from parent seeders
- [ ] No factory() or fake() calls
- [ ] Comments explain record purposes

## Completion Flow
1. All files created and validated
2. In worktree: `git add -A && git commit -m "feat(db): add {ModelName} seeder"`
3. Push: `git push -u origin task/spec-{spec_id}`
4. Create PR: `gh pr create --title "feat(db): {name}" --body "Spec ID: {spec_id}" --draft`
5. Report: `{"status": "complete", "spec_id": {spec_id}, "pr_url": "...", "files": [...]}`

## Error Flow
Same as tables - report with reason and detail.
```

## Quality Checks

Before saving task to DB:
1. All columns converted correctly
2. Migration number determined
3. Model name is singular PascalCase
4. Relations have correct return types
5. Faker methods are valid
