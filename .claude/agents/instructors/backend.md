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

## Instruction Template

### For sync actions

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: action_sync
- spec_id: {spec_id}
- priority: 4

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
```

### For async actions (Jobs)

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: action_async
- spec_id: {spec_id}
- priority: 4

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
```

### For scheduled actions

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: action_scheduled
- spec_id: {spec_id}
- priority: 4

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
