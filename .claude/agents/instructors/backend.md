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

<task_template name="base" abstract="true">
  <section name="meta">
    <field name="type">{task_type}</field>
    <field name="spec_id">{spec_id}</field>
    <field name="priority">4</field>
    <field name="blocked_by">[{dependency_ids}]</field>
  </section>

  <section name="worktree">
    <field name="branch">task/spec-{spec_id}</field>
    <field name="command">./scripts/worktree-manager.sh create {spec_id}</field>
    <field name="working_dir">.worktrees/spec-{spec_id}</field>
  </section>

  <section name="completion_flow">
    <step>All files created and validated</step>
    <step>In worktree: git add -A && git commit -m "feat(action): add {Name}"</step>
    <step>Push: git push -u origin task/spec-{spec_id}</step>
    <step>Create PR: gh pr create --title "feat(action): {name}" --body "Spec ID: {spec_id}" --draft</step>
    <step>Report: {"status": "complete", "spec_id": {spec_id}, "pr_url": "...", "files": [...]}</step>
  </section>

  <section name="error_flow">
    <rule>Do NOT commit partial changes</rule>
    <error_types>
      <type name="instruction_unclear">Missing input/output definition</type>
      <type name="technical_error">PHP syntax issue</type>
      <type name="dependency_missing">Required model/service not found</type>
      <type name="file_conflict">File already exists</type>
    </error_types>
    <example>{"status": "blocked", "reason": "dependency_missing", "detail": "Model User not found"}</example>
  </section>
</task_template>

---

### For sync actions

<task_template name="action_sync" extends="base">
  <output_files>
    <file>${ACTION_PATH}/{ActionName}.php</file>
    <file condition="events_specified">${EVENT_PATH}/{EventName}.php</file>
  </output_files>

  <file_template path="${ACTION_PATH}/{ActionName}.php">
    <code lang="php">
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
    </code>
    <rules>
      <rule>Single public method: execute()</rule>
      <rule>Validate input if validation: true in spec</rule>
      <rule>Dispatch events at end of execute()</rule>
      <rule>Use dependency injection for services</rule>
      <rule>Return typed value</rule>
      <rule>Comments in ${COMMENT_LANGUAGE}</rule>
    </rules>
  </file_template>

  <file_template path="${EVENT_PATH}/{EventName}.php" for_each="events">
    <code lang="php">
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
    </code>
    <rules>
      <rule>Use readonly properties in constructor</rule>
      <rule>Use SerializesModels for Eloquent models</rule>
      <rule>Keep events simple (data containers)</rule>
    </rules>
  </file_template>

  <validation>
    <check>Action class created</check>
    <check>execute() method has correct signature</check>
    <check>All input params typed</check>
    <check>Return type specified</check>
    <check>Events created and dispatched</check>
    <check>Validation logic if specified</check>
  </validation>
</task_template>

---

### For async actions (Jobs)

<task_template name="action_async" extends="base">
  <output_files>
    <file>${JOB_PATH}/{JobName}.php</file>
  </output_files>

  <file_template path="${JOB_PATH}/{JobName}.php">
    <code lang="php">
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
    </code>
    <rules>
      <rule>Implement ShouldQueue</rule>
      <rule>Use readonly properties for immutable data</rule>
      <rule>Handle failures gracefully</rule>
      <rule>Log important steps</rule>
    </rules>
  </file_template>

  <validation>
    <check>Job implements ShouldQueue</check>
    <check>Constructor accepts required data</check>
    <check>handle() contains business logic</check>
    <check>failed() handles errors</check>
  </validation>
</task_template>

---

### For scheduled actions

<task_template name="action_scheduled" extends="base">
  <output_files>
    <file>${COMMAND_PATH}/{CommandName}.php</file>
  </output_files>

  <schedule_registration>
    <file>${SCHEDULE_FILE}</file>
    <code>Schedule::command('{command_name}')->{schedule_frequency}();</code>
  </schedule_registration>

  <file_template path="${COMMAND_PATH}/{CommandName}.php">
    <code lang="php">
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
    </code>
    <rules>
      <rule>Return Command::SUCCESS or Command::FAILURE</rule>
      <rule>Use $this->info() for output</rule>
      <rule>Log execution for monitoring</rule>
    </rules>
  </file_template>

  <validation>
    <check>Command created with correct signature</check>
    <check>Description set</check>
    <check>handle() returns proper exit code</check>
    <check>Schedule registered</check>
  </validation>
</task_template>

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
