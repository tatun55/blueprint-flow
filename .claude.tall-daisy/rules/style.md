# コードスタイル
> 命名規則・可読性方針

## 命名規則

**Laravel 標準**に準拠:

| 対象 | 規則 | 例 |
|------|------|-----|
| PHP クラス | PascalCase | `TaskIndex`, `CreateTask` |
| メソッド | camelCase | `getTasks()`, `markAsComplete()` |
| 変数 | camelCase | `$taskList`, `$isComplete` |
| DB テーブル | snake_case (複数形) | `users`, `task_items` |
| DB カラム | snake_case | `created_at`, `is_active` |
| Blade ファイル | kebab-case | `task-index.blade.php` |
| ルート名 | dot notation | `tasks.index`, `tasks.store` |
| Config キー | snake_case | `app.max_width` |

## コードスタイル

- **可読性優先**: 長くても分かりやすいコードを好む
- 過度な短縮・抽象化より、意図が明確なコードを書く
