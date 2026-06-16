# Code Style
> Naming conventions, readability guidelines

## Naming Conventions

Follow **Laravel standard**:

| Target | Convention | Example |
|--------|-----------|---------|
| PHP class | PascalCase | `TaskIndex`, `CreateTask` |
| Method | camelCase | `getTasks()`, `markAsComplete()` |
| Variable | camelCase | `$taskList`, `$isComplete` |
| DB table | snake_case (plural) | `users`, `task_items` |
| DB column | snake_case | `created_at`, `is_active` |
| Blade file | kebab-case | `task-index.blade.php` |
| Route name | dot notation | `tasks.index`, `tasks.store` |
| Config key | snake_case | `app.max_width` |

## Code Style

- **Readability first**: prefer clear, readable code even if longer
- Avoid excessive abbreviation or abstraction — write code with clear intent
