# Frontend Coding Rules

## Blade Component Patterns

### Anonymous Components

Location: `resources/views/components/`

```html
<!-- resources/views/components/button.blade.php -->
@props([
    'type' => 'button',
    'variant' => 'primary',
])

<button
    type="{{ $type }}"
    {{ $attributes->merge(['class' => "btn btn-{$variant}"]) }}
>
    {{ $slot }}
</button>
```

Usage: `<x-button variant="ghost">Cancel</x-button>`

### Props & Attributes

```html
@props([
    'label' => null,
    'error' => null,
])

<div>
    @if($label)
        <label class="block text-sm font-medium mb-1.5">{{ $label }}</label>
    @endif
    <input {{ $attributes->merge(['class' => 'input input-bordered w-full']) }} />
    @if($error)
        <p class="text-error text-sm mt-1">{{ $error }}</p>
    @endif
</div>
```

### Named Slots

```html
<!-- Component definition -->
<div class="card">
    <div class="card-body">
        @isset($header)
            <div class="card-title">{{ $header }}</div>
        @endisset
        {{ $slot }}
        @isset($footer)
            <div class="card-actions">{{ $footer }}</div>
        @endisset
    </div>
</div>

<!-- Usage -->
<x-card>
    <x-slot:header>Title</x-slot:header>
    Content here
    <x-slot:footer>
        <button class="btn btn-primary">Action</button>
    </x-slot:footer>
</x-card>
```

### Component Organization

<structure>
  <dir name="resources/views/components">
    <file>button.blade.php</file>
    <file>input.blade.php</file>
    <file>modal.blade.php</file>
    <dir name="layouts">
      <file>app.blade.php</file>
    </dir>
    <dir name="form">
      <file>input.blade.php</file>
      <file>select.blade.php</file>
      <file>textarea.blade.php</file>
    </dir>
  </dir>
</structure>

---

## Responsive Design

### Breakpoints (Tailwind CSS)

| Prefix | Min Width | Device |
|--------|-----------|--------|
| (none) | 0px | Mobile (default) |
| `sm:` | 640px | Landscape phone |
| `md:` | 768px | Tablet |
| `lg:` | 1024px | Laptop |
| `xl:` | 1280px | Desktop |

### Mobile-First Principle

**Mandatory**: Write styles mobile-first, add larger breakpoints progressively.

```html
<!-- Correct: mobile-first -->
<div class="p-4 md:p-6 lg:p-8">
<div class="flex flex-col md:flex-row">
<div class="text-base md:text-lg">

<!-- Wrong: desktop-first -->
<div class="p-8 sm:p-4">
```

### Responsive Spacing

| Element | Mobile | Tablet | Desktop | Class |
|---------|--------|--------|---------|-------|
| Page padding | 8px | 16px | 24px | `p-2 sm:p-4 lg:p-6` |
| Card padding | 12px | 16px | 24px | `p-3 sm:p-4 lg:p-6` |
| Section gap | 12px | 16px | 24px | `gap-3 sm:gap-4 lg:gap-6` |
| List gap | 8px | 12px | 16px | `gap-2 sm:gap-3 lg:gap-4` |

### Touch Targets

**Mandatory**: Tappable elements minimum 44x44px.

```html
<!-- Correct -->
<button class="btn min-h-11 min-w-11">
<a class="p-3 min-h-11 inline-flex items-center">

<!-- Wrong: too small -->
<button class="btn btn-xs">
<a class="p-1">
```

### Layout Patterns

**Flex Direction Switch**
```html
<div class="flex flex-col md:flex-row gap-4 md:gap-6">
    <div>...</div>
    <div>...</div>
</div>
```

**Grid Columns**
```html
<!-- 1 → 2 → 3 columns -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-6">
    <div class="card">...</div>
</div>
```

**Page Header**
```html
<div class="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-3 mb-3 sm:mb-4 lg:mb-6">
    <div>
        <h1 class="text-xl md:text-2xl font-bold">Title</h1>
        <p class="text-sm text-base-content/60 mt-1">Description</p>
    </div>
    <button class="btn btn-primary w-full sm:w-auto">Action</button>
</div>
```

### Table Responsiveness

**Strategy by column count:**

| Columns | Strategy |
|---------|----------|
| 1-3 | Keep table |
| 4-5 | Hide columns with `hidden md:table-cell` |
| 6+ | Card transformation or horizontal scroll |

**Column hiding:**
```html
<thead>
    <tr>
        <th>Name</th>
        <th>Status</th>
        <th class="hidden md:table-cell">Created</th>
        <th class="hidden lg:table-cell">Updated</th>
        <th class="text-right">Actions</th>
    </tr>
</thead>
```

**Card transformation (6+ columns):**
```html
<!-- Desktop: Table -->
<div class="hidden md:block">
    <table class="table">...</table>
</div>

<!-- Mobile: Cards -->
<div class="md:hidden space-y-3">
    @foreach($items as $item)
        <div class="card bg-base-100 shadow-sm">
            <div class="card-body p-3">...</div>
        </div>
    @endforeach
</div>
```

### Text Overflow

```html
<!-- Single line truncate -->
<td class="truncate max-w-[150px]">{{ $text }}</td>

<!-- Multi-line clamp -->
<p class="line-clamp-2">{{ $description }}</p>

<!-- Flex container (min-w-0 required) -->
<div class="flex items-center gap-2">
    <div class="min-w-0 flex-1">
        <span class="truncate block">{{ $name }}</span>
    </div>
    <span class="badge whitespace-nowrap flex-shrink-0">Status</span>
</div>
```

---

## Animation & Transition

### Standard Durations

| Type | Duration | Easing | Use Case |
|------|----------|--------|----------|
| Fast | 150ms | ease-out | Hover, focus states |
| Normal | 200ms | ease-out | Dropdowns, tooltips |
| Slow | 300ms | ease-in-out | Modals, page transitions |

### Enter/Leave Pattern

```html
<!-- Alpine.js transitions -->
<div x-show="open"
     x-transition:enter="transition ease-out duration-200"
     x-transition:enter-start="opacity-0 scale-95"
     x-transition:enter-end="opacity-100 scale-100"
     x-transition:leave="transition ease-in duration-150"
     x-transition:leave-start="opacity-100 scale-100"
     x-transition:leave-end="opacity-0 scale-95">
    Content
</div>
```

### Common Transitions

**Fade**
```html
<div x-show="visible"
     x-transition:enter="transition ease-out duration-200"
     x-transition:enter-start="opacity-0"
     x-transition:enter-end="opacity-100"
     x-transition:leave="transition ease-in duration-150"
     x-transition:leave-start="opacity-100"
     x-transition:leave-end="opacity-0">
```

**Slide Down (Dropdown)**
```html
<div x-show="open"
     x-transition:enter="transition ease-out duration-200"
     x-transition:enter-start="opacity-0 -translate-y-2"
     x-transition:enter-end="opacity-100 translate-y-0"
     x-transition:leave="transition ease-in duration-150"
     x-transition:leave-start="opacity-100 translate-y-0"
     x-transition:leave-end="opacity-0 -translate-y-2">
```

**Scale (Modal)**
```html
<div x-show="show"
     x-transition:enter="transition ease-out duration-300"
     x-transition:enter-start="opacity-0 scale-90"
     x-transition:enter-end="opacity-100 scale-100"
     x-transition:leave="transition ease-in duration-200"
     x-transition:leave-start="opacity-100 scale-100"
     x-transition:leave-end="opacity-0 scale-90">
```

### Hover Effects

```html
<!-- Scale on hover -->
<button class="transition-transform duration-150 hover:scale-105">

<!-- Background color -->
<div class="transition-colors duration-150 hover:bg-base-200">

<!-- Shadow -->
<div class="transition-shadow duration-200 hover:shadow-lg">
```

### Loading States

```html
<!-- Spinner -->
<span class="loading loading-spinner loading-md"></span>

<!-- Skeleton -->
<div class="skeleton h-4 w-full"></div>

<!-- Button with loading -->
<button class="btn btn-primary" wire:loading.attr="disabled">
    <span wire:loading class="loading loading-spinner loading-sm"></span>
    <span wire:loading.remove>Save</span>
    <span wire:loading>Saving...</span>
</button>

<!-- Section loading overlay -->
<div wire:loading.class="opacity-50 pointer-events-none" class="transition-opacity duration-150">
    Content
</div>
```

---

## Spacing & Typography

### Spacing Scale

| Context | Class | Value |
|---------|-------|-------|
| Form field gap | `space-y-5` | 1.25rem |
| Label → input | `mb-1.5` | 0.375rem |
| Error text | `mt-1` | 0.25rem |
| Before buttons | `pt-4` | 1rem |
| Button gap | `gap-3` | 0.75rem |
| Card padding | `p-6` | 1.5rem |

### Input Width

| Content | Class | Use Case |
|---------|-------|----------|
| Short | `max-w-sm` | Name, title |
| Medium | `max-w-md` | Email, URL |
| Long | `max-w-lg` | Description |
| Full | `w-full` | Modal inputs |
| Number | `w-20` ~ `w-32` | Quantity |

### Typography

| Element | Classes |
|---------|---------|
| Page title | `text-2xl font-bold` |
| Section title | `text-lg font-semibold` |
| Card title | `text-base font-medium` |
| Label | `text-sm font-medium` |
| Body | `text-sm` or `text-base` |
| Muted | `text-sm text-base-content/60` |
| Error | `text-sm text-error` |

---

## Common UI Patterns

### Filter Bar

```html
<div class="flex flex-col sm:flex-row sm:items-center gap-3 mb-6">
    <!-- Search (fixed width) -->
    <div class="relative w-full sm:w-72">
        <svg class="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/40">...</svg>
        <input wire:model.live.debounce.300ms="search"
               class="input input-bordered w-full pl-10 h-10"
               placeholder="Search..." />
    </div>

    <!-- Filters -->
    <div class="flex gap-3">
        <select wire:model.live="status" class="select select-bordered h-10">
            <option value="">Status: All</option>
            <option value="active">Active</option>
        </select>
    </div>
</div>
```

### Empty State

```html
<div class="text-center py-12">
    <svg class="mx-auto h-12 w-12 text-base-content/40">...</svg>
    <h3 class="mt-2 text-sm font-semibold">No items</h3>
    <p class="mt-1 text-sm text-base-content/60">Get started by creating a new item.</p>
    <div class="mt-6">
        <button class="btn btn-primary btn-sm">Create</button>
    </div>
</div>
```

### Modal

```html
<dialog class="modal" :class="{ 'modal-open': show }">
    <div class="modal-box w-full max-w-lg">
        <h3 class="text-lg font-bold mb-6">Title</h3>
        <form wire:submit="save" class="space-y-5">
            <!-- Fields -->
            <div class="flex flex-col-reverse sm:flex-row justify-end gap-3 pt-4">
                <button type="button" class="btn btn-ghost" wire:click="$set('show', false)">
                    Cancel
                </button>
                <button type="submit" class="btn btn-primary">Save</button>
            </div>
        </form>
    </div>
    <div class="modal-backdrop" wire:click="$set('show', false)"></div>
</dialog>
```

---

## Alpine.js

### Scope

UI interactions only: dropdowns, modals, toggles, tooltips.
Complex state/data: use Livewire.

### Default: Inline x-data

Use inline `x-data` for simple interactions:

```html
<!-- Dropdown -->
<div x-data="{ open: false }">
    <button @click="open = !open">Menu</button>
    <div x-show="open" @click.outside="open = false">
        ...
    </div>
</div>

<!-- Toggle -->
<div x-data="{ expanded: false }">
    <button @click="expanded = !expanded">
        <span x-text="expanded ? 'Hide' : 'Show'"></span>
    </button>
    <div x-show="expanded" x-collapse>...</div>
</div>

<!-- Modal trigger -->
<div x-data="{ show: false }">
    <button @click="show = true">Open</button>
    <dialog :class="{ 'modal-open': show }">...</dialog>
</div>
```

### Complex Logic: Separate JS File

Only for very complex interactions (10+ lines of logic):

```js
// resources/js/components/data-table.js
export default () => ({
    sortColumn: null,
    sortDirection: 'asc',
    filters: {},

    sort(column) {
        if (this.sortColumn === column) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortColumn = column;
            this.sortDirection = 'asc';
        }
    },

    // ... more complex logic
})
```

```js
// resources/js/app.js
import Alpine from 'alpinejs'
import dataTable from './components/data-table.js'

Alpine.data('dataTable', dataTable)
Alpine.start()
```

```html
<div x-data="dataTable">...</div>
```

### Forbidden

- External `<script>` function definitions
- Complex logic inline (10+ lines)
- State that should be in Livewire

---

## Anti-Patterns

### Forbidden

```html
<!-- form-control wrapper -->
<div class="form-control">
    <label class="label"><span class="label-text">Name</span></label>
</div>

<!-- flex-1 on search field (makes it expand) -->
<input class="flex-1 min-w-[200px]" />

<!-- Fixed width causing overflow -->
<div class="w-[800px]">

<!-- Desktop-first responsive -->
<div class="flex-row sm:flex-col">

<!-- Small touch targets -->
<button class="p-1 text-xs">
```

### Checklist

- [ ] Mobile horizontal scroll: none
- [ ] Touch targets: 44x44px minimum
- [ ] Text overflow: handled
- [ ] Mobile padding: appropriately smaller
- [ ] Tables: mobile-friendly
- [ ] Modals: work on mobile
- [ ] Buttons: easy to tap on mobile
