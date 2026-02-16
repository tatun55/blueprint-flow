# アーキテクチャ
> Livewire構成・ルーティング・ディレクトリ・レイアウト

## Livewire コンポーネント

- **フルページコンポーネント**として構成（コントローラ不要）
- **従来型**: Class (`app/Livewire/`) + Blade (`resources/views/livewire/`) 分離
- ディレクトリ構成は **Laravel デフォルト**に準拠

## ルーティング

- `routes/web.php` で明示的に定義
- Livewire フルページコンポーネントクラスを直接指定

```php
// routes/web.php
Route::get('/tasks', TaskIndex::class)->name('tasks.index');
Route::get('/tasks/{task}', TaskShow::class)->name('tasks.show');
```

## ディレクトリ構成

```
app/
├── Livewire/           # Livewire コンポーネント (フルページ + partials)
├── Models/             # Eloquent モデル
└── Actions/            # Action クラス（複雑/再利用ロジック）

resources/views/
├── livewire/           # Livewire Blade テンプレート
└── components/
    └── layouts/        # レイアウトコンポーネント
```

## レイアウト

- **Livewire レイアウトコンポーネント**で管理
- `resources/views/components/layouts/` に配置
- `<x-layouts.app>` で使用
