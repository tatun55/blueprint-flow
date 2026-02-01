# Laravel Project Structure

## Livewire Components

| Type | Path | Example |
|------|------|---------|
| Pages | `app/Livewire/Pages/{Feature}/` | `Pages/Users/Index.php` |
| Partials | `app/Livewire/Components/` | `Components/UserCard.php` |
| Layouts | `app/Livewire/Layouts/` | `Layouts/App.php` |

```
app/Livewire/
├── Pages/
│   ├── Users/
│   │   ├── Index.php
│   │   └── Show.php
│   └── Dashboard.php
├── Components/
│   └── ProjectSelector.php
└── Layouts/
    └── App.php
```

## Blade Views

Follow Livewire default: `resources/views/livewire/{path}/{component}.blade.php`

```
resources/views/livewire/
├── pages/
│   ├── users/
│   │   ├── index.blade.php
│   │   └── show.blade.php
│   └── dashboard.blade.php
├── components/
│   └── project-selector.blade.php
└── layouts/
    └── app.blade.php
```

## Database

```
database/
├── migrations/
│   ├── 0001_01_01_000001_create_users_table.php
│   ├── 0001_01_01_010001_create_projects_table.php
│   └── ...
└── seeders/
    ├── DatabaseSeeder.php
    └── Tables/
        ├── UserSeeder.php
        └── ProjectSeeder.php
```

## Backend

```
app/
├── Actions/
│   └── CreateUser.php
├── Events/
│   └── UserCreated.php
├── Jobs/
│   └── ProcessImport.php
└── Console/
    └── Commands/
        └── CleanupOldData.php
```

## Tests

```
tests/
├── Feature/
│   └── Livewire/
│       └── Pages/
│           └── Users/
│               └── IndexTest.php
└── e2e/
    ├── e2e.db
    ├── schema.sql
    └── screenshots/
```
