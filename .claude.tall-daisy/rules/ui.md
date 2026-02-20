# UI Rules
> daisyUI, Alpine.js, xylph-ui, modals, notifications, error display

## CSS

- **daisyUI component classes first**
- Use Tailwind utilities for fine-tuning only
- No custom CSS

## Components

| Type | Method | Example |
|------|--------|---------|
| Static UI parts | xylph-ui components | `<x-ui-button>`, `<x-ui-modal>` |
| Dynamic parts (partials) | Livewire components | Only for complex page splits |
| Modal/Drawer | xylph-ui (Alpine.js controlled) | Confirm dialogs, CRUD forms |
| Notification (flash) | xylph-ui notification | Success/failure feedback |

## Alpine.js Role

- **UI state only**: toggle, dropdown, modal open/close
- All data operations and server communication handled by Livewire
- Livewire integration via `$wire`

## Minimize Page Navigation

- **CRUD in modals on the same page**
- Create/edit/delete without leaving the list page
- Navigate only when a separate screen is truly needed (detail view, settings, etc.)

## Error Display

- Validation errors shown **below each field**
- Use `@error` directive

## Pagination

- Livewire `WithPagination` trait for dynamic pagination
