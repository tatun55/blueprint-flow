# Frontend Instructor Patterns

## Directory Structure

| Type | PHP Path | View Path |
|------|----------|-----------|
| Pages | `app/Livewire/Pages/{Feature}/` | `livewire/pages/{feature}/` |
| Partials | `app/Livewire/Partials/` | `livewire/partials/` |
| Layouts | `app/Livewire/Layouts/` | `livewire/layouts/` |

## Responsive Design

### Breakpoints

| Prefix | Min Width | Device |
|--------|-----------|--------|
| (none) | 0px | Mobile (default) |
| `sm:` | 640px | Landscape phone |
| `md:` | 768px | Tablet |
| `lg:` | 1024px | Laptop |
| `xl:` | 1280px | Desktop |

### Mobile-First (Mandatory)

```html
<!-- Correct -->
<div class="p-4 md:p-6 lg:p-8">
<div class="flex flex-col md:flex-row">

<!-- Wrong -->
<div class="p-8 sm:p-4">
```

### Touch Targets

Minimum 44x44px for tappable elements:
```html
<button class="btn min-h-11 min-w-11">
```

## Alpine.js

### Scope

UI interactions only: dropdowns, modals, toggles.
Complex state: use Livewire.

### Default: Inline x-data

```html
<div x-data="{ open: false }">
    <button @click="open = !open">Menu</button>
    <div x-show="open" @click.outside="open = false">...</div>
</div>
```

### Complex (10+ lines): Separate .js

```js
// resources/js/components/data-table.js
export default () => ({
    sortColumn: null,
    sortDirection: 'asc',
    // ...
})
```

## Animation

### Standard Durations

| Type | Duration | Use Case |
|------|----------|----------|
| Fast | 150ms | Hover, focus |
| Normal | 200ms | Dropdowns |
| Slow | 300ms | Modals |

### Transition Pattern

```html
<div x-show="open"
     x-transition:enter="transition ease-out duration-200"
     x-transition:enter-start="opacity-0 -translate-y-2"
     x-transition:enter-end="opacity-100 translate-y-0"
     x-transition:leave="transition ease-in duration-150"
     x-transition:leave-start="opacity-100 translate-y-0"
     x-transition:leave-end="opacity-0 -translate-y-2">
```

## Common UI Patterns

### Page Header

```html
<div class="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-3 mb-6">
    <h1 class="text-xl md:text-2xl font-bold">Title</h1>
    <button class="btn btn-primary w-full sm:w-auto">Action</button>
</div>
```

### Modal

```html
<dialog class="modal" :class="{ 'modal-open': show }">
    <div class="modal-box">
        <h3 class="text-lg font-bold mb-6">Title</h3>
        <form wire:submit="save" class="space-y-5">
            <!-- Fields -->
            <div class="flex justify-end gap-3 pt-4">
                <button type="button" class="btn btn-ghost" @click="show = false">Cancel</button>
                <button type="submit" class="btn btn-primary">Save</button>
            </div>
        </form>
    </div>
    <div class="modal-backdrop" @click="show = false"></div>
</dialog>
```

### Table Responsiveness

| Columns | Strategy |
|---------|----------|
| 1-3 | Keep table |
| 4-5 | Hide columns: `hidden md:table-cell` |
| 6+ | Card transformation on mobile |

## Anti-Patterns (Forbidden)

- `form-control`, `label > label-text` wrappers
- Desktop-first responsive: `flex-row sm:flex-col`
- Small touch targets: `p-1 text-xs`
- Fixed widths causing overflow: `w-[800px]`
