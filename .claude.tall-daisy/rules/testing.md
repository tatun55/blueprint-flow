# Testing Conventions
> Pest framework, TDD during impl, Seeder-based data, test levels

## Framework

- **Pest PHP** (not PHPUnit)
- `tests/Unit/` for unit tests
- `tests/Feature/` for feature tests
- `tests/Helpers/` for shared test fixtures (dependency boundary helpers)

## Test-First During Implementation

During the `impl` step, the coding agent follows test-first development:

<flow name="impl-tdd">
  <step order="1">Read blueprint scenarios and requirements</step>
  <step order="2">Write unit/feature tests for each scenario (tests should fail)</step>
  <step order="3">Implement code to pass the tests</step>
  <step order="4">Run tests, iterate until all pass</step>
  <step order="5">Verify blueprint-match (each spec scenario vs implementation)</step>
</flow>

This flow is defined as a rule — projects can customize by modifying this file.

## Test Data

**Single source principle**: Same Seeder used across all test modes.

| Mode | How |
|------|-----|
| Unit/Feature tests | `RefreshDatabase` + `Seeder::createXxx()` |
| E2E automated tests | Same Seeder methods |
| Human manual testing | `php artisan db:seed` |

### Rules

- **Seeder-based** — no Factory pattern (speed priority)
- **In-memory lifecycle**: `RefreshDatabase` trait for all automated tests
- Each table blueprint creates a Seeder with `run()` + static helper methods
- Seeders are the single source of truth for test data

### Seeder Pattern

```php
// database/seeders/TodoSeeder.php
class TodoSeeder extends Seeder {
    public function run(): void {
        static::createDefaults();
    }

    public static function createDefaults(): array {
        $user = UserSeeder::createDefaultUser();
        return [
            Todo::create(['user_id' => $user->id, 'title' => 'Task 1', 'status' => 'pending']),
            Todo::create(['user_id' => $user->id, 'title' => 'Task 2', 'status' => 'done']),
        ];
    }
}
```

### Shared Test Fixtures

For blueprints with dependencies, shared fixture helpers in `tests/Helpers/`:

```php
// tests/Helpers/TodoFixtures.php
function createTodoWithUser(array $todoAttrs = [], array $userAttrs = []): array {
    $user = UserSeeder::createDefaultUser($userAttrs);
    $todo = Todo::create(array_merge([
        'user_id' => $user->id, 'title' => 'Test Todo',
    ], $todoAttrs));
    return compact('user', 'todo');
}

// Boundary check helper
function assertTodoBelongsToUser(Todo $todo, User $user): void {
    expect($todo->user_id)->toBe($user->id);
    expect($todo->user)->toBeInstanceOf(User::class);
}
```

## Dependency Test Rules

Three principles for testing blueprints with dependencies:

1. **Own-scope only** — Assert only on current blueprint's behavior. Dependency behavior is its own blueprint's responsibility.
2. **Seeder as fixture** — Use dependency Seeders' static helpers for test data. No inline data creation for dependencies.
3. **Boundary check** — Verify correct interaction with dependencies using shared fixture helpers. Test that data is passed/received correctly.

## Test Levels (E2E Verification)

Three levels of E2E verification with screenshots and human review:

| Level | Scope | Gate |
|-------|-------|------|
| **L1** | Basic operations (CRUD happy paths) | — |
| **L2** | Extended (validation, permissions, boundary values) | ALL L1 complete |
| **L3** | Edge cases (error scenarios, concurrency, large datasets) | ALL L2 complete |

- E2E tests use `playwright-cli` (headless) for screenshots
- Same Seeder data as unit/feature tests
- Human review via Hub (screenshot paths displayed)
