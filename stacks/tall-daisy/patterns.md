# Laravel + Livewire Patterns

Stack: Laravel 12 + Livewire 4 + Tailwind 4 + daisyUI 5 + PHP 8.3+

## Livewire Patterns

### Fullpage Component

```php
namespace App\Livewire\Pages\Users;

use Livewire\Attributes\Layout;
use Livewire\Component;

#[Layout('livewire.layouts.app')]
class Index extends Component
{
    public function render()
    {
        return view('livewire.pages.users.index');
    }
}
```

Route: `Route::get('/users', \App\Livewire\Pages\Users\Index::class);`

### Validation (Inline)

```php
use Livewire\Attributes\Validate;

class CreateUser extends Component
{
    #[Validate('required|string|max:255')]
    public string $name = '';

    #[Validate('required|email|unique:users')]
    public string $email = '';

    public function save()
    {
        $this->validate();
        User::create(['name' => $this->name, 'email' => $this->email]);
    }
}
```

### Data Binding

Default: `wire:model.blur` (sync on blur for performance)

```html
<input wire:model.blur="name" class="input input-bordered" />
```

Use `wire:model.live` only for real-time feedback (search, autocomplete).

### Component Communication

```php
// Parent
$this->dispatch('user-selected', id: $userId);

// Child
#[On('user-selected')]
public function onUserSelected(int $id): void
{
    $this->userId = $id;
}
```

---

## daisyUI v5 Patterns

### Form Structure

**Forbidden:** `form-control`, `label > label-text` wrappers

```html
<!-- Correct -->
<div>
    <label class="block text-sm font-medium mb-1.5">Name</label>
    <input wire:model.blur="name"
           class="input input-bordered w-full @error('name') input-error @enderror" />
    @error('name')
        <p class="text-error text-sm mt-1">{{ $message }}</p>
    @enderror
</div>

<!-- Forbidden -->
<div class="form-control">
    <label class="label"><span class="label-text">Name</span></label>
</div>
```

### Common Classes

```html
<!-- Buttons -->
<button class="btn btn-primary">Save</button>
<button class="btn btn-ghost">Cancel</button>
<button class="btn btn-error btn-outline">Delete</button>

<!-- Inputs -->
<input class="input input-bordered" />
<select class="select select-bordered">...</select>
<textarea class="textarea textarea-bordered">...</textarea>

<!-- Feedback -->
<div class="alert alert-success">Success</div>
<span class="badge badge-warning">Pending</span>
```

---

## Alpine.js Patterns

### Scope

UI interactions only: dropdowns, modals, toggles, tooltips.
Complex state/data: use Livewire.

### Definition Style

Use `Alpine.data()` registration in `app.js`:

```js
// resources/js/app.js
import Alpine from 'alpinejs'

Alpine.data('dropdown', () => ({
    open: false,
    toggle() { this.open = !this.open },
    close() { this.open = false }
}))

Alpine.start()
```

```html
<div x-data="dropdown">
    <button x-on:click="toggle">Menu</button>
    <div x-show="open" x-on:click.outside="close">...</div>
</div>
```

**Forbidden:** Inline complex logic, external `<script>` function definitions.

---

## Migration Patterns

### Filename Convention

Numbered system by feature group:

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
- Add `index()` explicitly for frequently queried columns
- Use `comment()` for non-obvious columns

---

## Seeder Patterns

### Structure

```
database/seeders/
├── DatabaseSeeder.php
└── Tables/
    ├── ProjectSeeder.php
    └── UserSeeder.php
```

### Wave Execution (FK constraints)

```php
// DatabaseSeeder.php
public function run(): void
{
    $this->call([
        // Wave 1: Base tables
        Tables\ProjectSeeder::class,

        // Wave 2: Dependent tables
        Tables\UserSeeder::class,
        Tables\SpecificationSeeder::class,

        // Wave 3: Junction tables
        Tables\ProjectUserSeeder::class,
    ]);
}
```
