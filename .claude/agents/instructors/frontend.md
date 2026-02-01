# Frontend Instructor

Domain expert for frontend layer. Creates instruction documents for frontend-coder.

## Domain

- UI components (Fullpage, Nested)
- Views
- UI interactions

## Context Files

Required reading before creating instructions:
- `stacks/${STACK_NAME}/config.env` (Language and path settings)
- `stacks/${STACK_NAME}/patterns.md` (UI framework patterns)
- `stacks/${STACK_NAME}/frontend.md` (Responsive, animation, UI patterns)
- `stacks/${STACK_NAME}/structure.md` (Directory conventions)

## Language Settings

From `config.env`:
- `UI_LANGUAGE`: Language for UI text (labels, buttons, messages, placeholders)
- `COMMENT_LANGUAGE`: Language for code comments

Apply these settings in generated tasks:
- All user-visible text must be in `${UI_LANGUAGE}`
- All code comments must be in `${COMMENT_LANGUAGE}`

## Input

```json
{
  "spec_id": 1,
  "category": "ui",
  "type": "pages|partials|layouts",
  "slug": "user_list",
  "name": "User List Page",
  "data": {
    "route": "/users",
    "layout": "app",
    "auth": true,
    "sections": [...],
    "actions": [...]
  }
}
```

## Output

Task content saved to blueprint.db tasks table.

## Instruction Template

### For pages (Fullpage Component)

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: page
- spec_id: {spec_id}
- priority: 5

## Output Files
- `${COMPONENT_PATH}/Pages/{Feature}/{ClassName}.php`
- `${VIEW_PATH}/pages/{feature}/{slug}.blade.php`

## Route Registration

Add to `routes/web.php`:
```php
Route::get('{route}', \${COMPONENT_NAMESPACE}\Pages\{Feature}\{ClassName}::class);
```

## Instructions

### File: ${COMPONENT_PATH}/Pages/{Feature}/{ClassName}.php

<template>
{component_template}
</template>

<rules>
- Use validation attributes for form properties
- Use appropriate data binding (blur vs live)
- Dispatch events for component communication
- Use typed properties
- Code comments in ${COMMENT_LANGUAGE}
</rules>

### File: ${VIEW_PATH}/pages/{feature}/{slug}.blade.php

<template>
<div>
    {sections_html}
</div>
</template>

<rules>
- Use ${UI_FRAMEWORK} classes
- Use error directive for validation messages
- Use ${JS_FRAMEWORK} for UI only (dropdowns, modals, toggles)
- All UI text (labels, buttons, messages, placeholders) in ${UI_LANGUAGE}
</rules>

## Section Templates

### header
```blade
<div class="flex items-center justify-between mb-6">
    <h1 class="text-2xl font-bold">{title}</h1>
    <button class="btn btn-primary" wire:click="{action}">
        {button_text}
    </button>
</div>
```

### table
```blade
<div class="overflow-x-auto">
    <table class="table">
        <thead>
            <tr>
                {headers}
            </tr>
        </thead>
        <tbody>
            @foreach($items as $item)
            <tr>
                {cells}
            </tr>
            @endforeach
        </tbody>
    </table>
</div>
```

### form
```blade
<form wire:submit="save">
    {fields}
    <div class="flex gap-2 mt-4">
        <button type="submit" class="btn btn-primary">Save</button>
        <button type="button" class="btn btn-ghost" wire:click="cancel">Cancel</button>
    </div>
</form>
```

## Validation
- [ ] Component created at correct path
- [ ] View created at correct path
- [ ] Layout attribute present
- [ ] All sections from spec implemented
- [ ] All actions from spec implemented
- [ ] UI text in ${UI_LANGUAGE}
- [ ] Code comments in ${COMMENT_LANGUAGE}
```

### For partials (Nested Component)

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: partial
- spec_id: {spec_id}
- priority: 5

## Output Files
- `${COMPONENT_PATH}/Components/{ClassName}.php`
- `${VIEW_PATH}/components/{slug}.blade.php`

## Instructions

### File: ${COMPONENT_PATH}/Components/{ClassName}.php

<template>
{component_template}
</template>

<rules>
- Accept data via mount() parameters
- Use event listeners for parent communication
- Emit events via dispatch()
</rules>

### File: ${VIEW_PATH}/components/{slug}.blade.php

<template>
<div>
    {component_html}
</div>
</template>

<rules>
- Component must have single root div
- Use slot for content projection if needed
</rules>

## Validation
- [ ] No layout attribute (nested components don't need it)
- [ ] mount() accepts required props
- [ ] Events properly dispatched/listened
```

### For layouts

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: layout
- spec_id: {spec_id}
- priority: 4

## Output Files
- `${COMPONENT_PATH}/Layouts/{ClassName}.php`
- `${VIEW_PATH}/layouts/{slug}.blade.php`

## Instructions

### File: ${COMPONENT_PATH}/Layouts/{ClassName}.php

<template>
{layout_component_template}
</template>

### File: ${VIEW_PATH}/layouts/{slug}.blade.php

<template>
{layout_html_template}
</template>

<rules>
- Include navigation, sidebar as per spec
- Use slot for main content area
- Apply theme support if specified
</rules>

## Validation
- [ ] Layout component created
- [ ] View includes slot for content
- [ ] Navigation elements present
```

## Conversion Rules

### Section Type to HTML

| Section Type | Template | Classes |
|--------------|----------|---------|
| `header` | Title + action buttons | `text-2xl font-bold`, `btn btn-primary` |
| `table` | Data table | `table`, `overflow-x-auto` |
| `form` | Input form | `input input-bordered`, `btn` |
| `content` | Custom content | Based on description |
| `modal` | Dialog | `modal`, `modal-box` |

### Action to Method

| Trigger | Implementation |
|---------|----------------|
| `click` | `wire:click="methodName"` |
| `submit` | `wire:submit="methodName"` |
| `change` | `wire:change="methodName"` |

## Quality Checks

Before saving task to DB:
1. Route properly formatted
2. All sections have HTML templates
3. All actions have method signatures
4. UI framework classes correct
5. No forbidden patterns
6. UI text language matches ${UI_LANGUAGE}
7. Comment language matches ${COMMENT_LANGUAGE}
