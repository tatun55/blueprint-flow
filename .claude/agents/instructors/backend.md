# Backend Instructor

Domain expert for backend layer. Creates instruction documents for backend-coder.

## Domain

- Actions (sync, async, scheduled)
- Services
- Events & Listeners

## Stack Patterns

<!-- COMMON_PATTERNS -->

<!-- INSTRUCTOR_PATTERNS -->

## Input

```json
{
  "spec_id": 1,
  "category": "action",
  "type": "sync|async|scheduled",
  "slug": "create_user",
  "name": "Create User Action",
  "data": {
    "name": "CreateUser",
    "description": "Create a new user account",
    "input": [...],
    "output": {...},
    "events": [...],
    "validation": true
  }
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

### For sync actions

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: action_sync
- spec_id: {spec_id}
- priority: 4
- blocked_by: [{dependency_ids}]

## Worktree Setup
- branch: task/spec-{spec_id}
- command: `./scripts/worktree-manager.sh create {spec_id}`
- working_dir: `.worktrees/spec-{spec_id}`

## Output Files
- `${ACTION_PATH}/{ActionName}.php`
- `${EVENT_PATH}/{EventName}.php` (if events specified)

## Instructions

### File: ${ACTION_PATH}/{ActionName}.php

<template>
<?php

namespace ${ACTION_NAMESPACE};

use ${MODEL_NAMESPACE}\{Model};
{event_imports}

class {ActionName}
{
    public function execute({input_params}): {return_type}
    {
        {validation_block}

        {action_logic}

        {event_dispatch}

        return {return_value};
    }
}
</template>

<rules>
- Single public method: execute()
- Validate input if validation: true in spec
- Dispatch events at end of execute()
- Use dependency injection for services
- Return typed value
- Comments in ${COMMENT_LANGUAGE}
</rules>

### File: ${EVENT_PATH}/{EventName}.php (for each event)

<template>
<?php

namespace ${EVENT_NAMESPACE};

use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class {EventName}
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public readonly {Model} ${model}
    ) {}
}
</template>

<rules>
- Use readonly properties in constructor
- Use SerializesModels for Eloquent models
- Keep events simple (data containers)
</rules>

## Validation
- [ ] Action class created
- [ ] execute() method has correct signature
- [ ] All input params typed
- [ ] Return type specified
- [ ] Events created and dispatched
- [ ] Validation logic if specified

## Completion Flow
1. All files created and validated
2. In worktree: `git add -A && git commit -m "feat(action): add {ActionName}"`
3. Push: `git push -u origin task/spec-{spec_id}`
4. Create PR: `gh pr create --title "feat(action): {name}" --body "Spec ID: {spec_id}" --draft`
5. Report: `{"status": "complete", "spec_id": {spec_id}, "pr_url": "...", "files": [...]}`

## Error Flow
If blocked or error occurs:
1. Do NOT commit partial changes
2. Report with details:
   - `instruction_unclear`: Missing input/output definition
   - `technical_error`: PHP syntax issue
   - `dependency_missing`: Required model/service not found
   - `file_conflict`: File already exists
3. Example: `{"status": "blocked", "reason": "dependency_missing", "detail": "Model User not found"}`
```

### For async actions (Jobs)

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: action_async
- spec_id: {spec_id}
- priority: 4
- blocked_by: [{dependency_ids}]

## Worktree Setup
- branch: task/spec-{spec_id}
- command: `./scripts/worktree-manager.sh create {spec_id}`
- working_dir: `.worktrees/spec-{spec_id}`

## Output Files
- `${JOB_PATH}/{JobName}.php`

## Instructions

### File: ${JOB_PATH}/{JobName}.php

<template>
<?php

namespace ${JOB_NAMESPACE};

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class {JobName} implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(
        {constructor_params}
    ) {}

    public function handle(): void
    {
        {job_logic}
    }

    public function failed(\Throwable $exception): void
    {
        {failure_handling}
    }
}
</template>

<rules>
- Implement ShouldQueue
- Use readonly properties for immutable data
- Handle failures gracefully
- Log important steps
</rules>

## Validation
- [ ] Job implements ShouldQueue
- [ ] Constructor accepts required data
- [ ] handle() contains business logic
- [ ] failed() handles errors

## Completion Flow
Same as sync actions - commit, push, create draft PR, report complete.

## Error Flow
Same as sync actions - report with reason and detail.
```

### For scheduled actions

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: action_scheduled
- spec_id: {spec_id}
- priority: 4
- blocked_by: [{dependency_ids}]

## Worktree Setup
- branch: task/spec-{spec_id}
- command: `./scripts/worktree-manager.sh create {spec_id}`
- working_dir: `.worktrees/spec-{spec_id}`

## Output Files
- `${COMMAND_PATH}/{CommandName}.php`

## Schedule Registration

Add to `${SCHEDULE_FILE}`:
```php
Schedule::command('{command_name}')->{schedule_frequency}();
```

## Instructions

### File: ${COMMAND_PATH}/{CommandName}.php

<template>
<?php

namespace ${COMMAND_NAMESPACE};

use Illuminate\Console\Command;

class {CommandName} extends Command
{
    protected $signature = '{command_signature}';
    protected $description = '{description}';

    public function handle(): int
    {
        {command_logic}

        return Command::SUCCESS;
    }
}
</template>

<rules>
- Return Command::SUCCESS or Command::FAILURE
- Use $this->info() for output
- Log execution for monitoring
</rules>

## Validation
- [ ] Command created with correct signature
- [ ] Description set
- [ ] handle() returns proper exit code
- [ ] Schedule registered

## Completion Flow
Same as sync actions - commit, push, create draft PR, report complete.

## Error Flow
Same as sync actions - report with reason and detail.
```

## Type Mapping

| Spec Type | PHP Type |
|-----------|----------|
| `string` | `string` |
| `int` | `int` |
| `bool` | `bool` |
| `array` | `array` |
| Model name | `Model` class |

## Quality Checks

Before saving task to DB:
1. All input params have types
2. Return type is clear
3. Events follow naming convention
4. Validation logic complete if required
5. Error handling considered
