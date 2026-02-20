# DB Conventions
> Migration naming, Seeder rules

## Migration

- Filename prefix: `0001_01_01_XXXXXX` (6-digit sequential grouping)

| Range | Purpose | Example |
|-------|---------|---------|
| `000000-009999` | Framework | cache, sessions, jobs |
| `010000-019999` | Master/Core | users, roles |
| `020000-029999` | Domain | feature tables |
| `030000-039999` | System utilities | audit_logs, notifications |
| `040000+` | Additional groups | feature extensions |

- Number in **increments of 10** within groups (leave room for insertion)
- During development, **edit create files directly** (avoid file proliferation)

## Seeder

- **No Factory pattern** — simple `Model::create()` calls (speed priority)
- Call each table seeder from `DatabaseSeeder`

### Seeder Structure

Each table blueprint creates a Seeder with two responsibilities:

```php
class TodoSeeder extends Seeder {
    // 1. Standard seeder method (called by DatabaseSeeder)
    public function run(): void {
        static::createDefaults();
    }

    // 2. Static helpers (called by tests and other seeders)
    public static function createDefaults(): array {
        $user = UserSeeder::createDefaultUser();
        return [
            Todo::create(['user_id' => $user->id, 'title' => 'Task 1', 'status' => 'pending']),
            Todo::create(['user_id' => $user->id, 'title' => 'Task 2', 'status' => 'done']),
        ];
    }
}
```

### Usage Across Test Modes

| Mode | How | Data lifecycle |
|------|-----|---------------|
| Unit/Feature tests | `RefreshDatabase` + `Seeder::createXxx()` | Auto-rollback per test |
| E2E automated tests | Same Seeder methods | Refreshed per test |
| Human manual testing | `php artisan db:seed` | Persistent until reset |

Same Seeder, same data — single source of truth.
