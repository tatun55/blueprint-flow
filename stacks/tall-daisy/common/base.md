# Common Patterns

Stack: Laravel 12 + Livewire 4 + Tailwind 4 + daisyUI 5 + PHP 8.3+

## Language Settings

- UI text: ${UI_LANGUAGE}
- Code comments: ${COMMENT_LANGUAGE}

## Livewire Basics

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

### Validation

```php
use Livewire\Attributes\Validate;

#[Validate('required|string|max:255')]
public string $name = '';
```

### Data Binding

- Default: `wire:model.blur` (sync on blur)
- Real-time: `wire:model.live` (search, autocomplete only)

### Component Communication

```php
// Dispatch
$this->dispatch('user-selected', id: $userId);

// Listen
#[On('user-selected')]
public function onUserSelected(int $id): void {}
```

## daisyUI Basics

### Form Structure

**Forbidden:** `form-control`, `label > label-text`

```html
<div>
    <label class="block text-sm font-medium mb-1.5">Name</label>
    <input class="input input-bordered w-full @error('name') input-error @enderror" />
    @error('name')
        <p class="text-error text-sm mt-1">{{ $message }}</p>
    @enderror
</div>
```

### Common Classes

| Element | Class |
|---------|-------|
| Button Primary | `btn btn-primary` |
| Button Ghost | `btn btn-ghost` |
| Input | `input input-bordered` |
| Select | `select select-bordered` |
| Alert | `alert alert-{type}` |
| Badge | `badge badge-{type}` |
