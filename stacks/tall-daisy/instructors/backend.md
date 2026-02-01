# Backend Instructor Patterns

## Directory Structure

| Type | Path | Example |
|------|------|---------|
| Actions | `app/Actions/` | `CreateUser.php` |
| Events | `app/Events/` | `UserCreated.php` |
| Jobs | `app/Jobs/` | `ProcessImport.php` |
| Commands | `app/Console/Commands/` | `CleanupOldData.php` |

## Action Pattern

### Sync Action

```php
namespace App\Actions;

class CreateUser
{
    public function execute(string $name, string $email): User
    {
        $user = User::create([
            'name' => $name,
            'email' => $email,
        ]);

        event(new UserCreated($user));

        return $user;
    }
}
```

Rules:
- Single public method: `execute()`
- Typed parameters and return
- Dispatch events at end

### Event Naming

| Action | Event |
|--------|-------|
| `CreateUser` | `UserCreated` |
| `UpdateProject` | `ProjectUpdated` |
| `DeleteTask` | `TaskDeleted` |

Pattern: `{Model}{PastTenseAction}`

## Event Pattern

```php
namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class UserCreated
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public readonly User $user
    ) {}
}
```

Rules:
- Readonly properties in constructor
- SerializesModels for Eloquent models
- Keep simple (data containers)

## Job Pattern

```php
namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ProcessImport implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(
        public readonly string $filePath
    ) {}

    public function handle(): void
    {
        // Job logic
    }

    public function failed(\Throwable $exception): void
    {
        // Error handling
    }
}
```

## Command Pattern

```php
namespace App\Console\Commands;

use Illuminate\Console\Command;

class CleanupOldData extends Command
{
    protected $signature = 'app:cleanup-old-data';
    protected $description = 'Remove data older than 30 days';

    public function handle(): int
    {
        $this->info('Starting cleanup...');

        // Command logic

        return Command::SUCCESS;
    }
}
```

Schedule: `Schedule::command('app:cleanup-old-data')->daily();`
