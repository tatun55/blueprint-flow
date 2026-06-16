# Architecture
> Livewire structure, routing, directories, layouts

## Livewire Components

- **Full-page components** (no controllers needed)
- **Traditional separation**: Class (`app/Livewire/`) + Blade (`resources/views/livewire/`)
- Follow **Laravel default** directory structure

## Routing

- Explicit routes in `routes/web.php`
- Point directly to Livewire full-page component classes

```php
Route::get('/tasks', TaskIndex::class)->name('tasks.index');
Route::get('/tasks/{task}', TaskShow::class)->name('tasks.show');
```

## Directory Structure

```
app/
├── Livewire/           # Livewire components (full-page + partials)
├── Models/             # Eloquent models
└── Actions/            # Action classes (complex/reusable logic)

resources/views/
├── livewire/           # Livewire Blade templates
└── components/
    └── layouts/        # Layout components
```

## Layouts

- Managed via **Livewire layout components**
- Placed in `resources/views/components/layouts/`
- Used as `<x-layouts.app>`
