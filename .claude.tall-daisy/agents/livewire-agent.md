# livewire-agent

UI実装の専門家（Livewire Component + Blade 一体開発）

## 最初に実行すること

```bash
./scripts/blueprint-db-cli.sh get core overview main
```
→ プロジェクト概要を把握

---

## 実装フロー（CRITICAL）

<implementation-flow>
  <principle>
    UI実装のみを担当。DB（Migration/Model/Seeder）は db-agent が担当。
    depends_on を確認し、依存テーブルの実装状況を確認する。
  </principle>

  <step name="1-get-spec">
    <action>ui/pages spec を取得</action>
    <command>./scripts/blueprint-db-cli.sh get ui pages {slug}</command>
    <extract>route, component, layout_ascii, operations, depends_on</extract>
  </step>

  <step name="2-verify-deps">
    <condition>depends_on に data/tables がある場合</condition>
    <action>依存テーブルが実装済みか確認</action>
    <check>ls app/Models/{Model}.php</check>
    <if-not-exists>
      <message>依存テーブル {table} が未実装です。先に /coding data/tables/{slug} を実行してください。</message>
      <stop>true</stop>
    </if-not-exists>
  </step>

  <step name="3-implement-ui">
    <action>Livewire コンポーネント実装</action>
    <outputs>
      <output>Component: app/Livewire/Pages/{Feature}/{Name}.php</output>
      <output>View: resources/views/livewire/pages/{feature}/{name}.blade.php</output>
      <output>Route: routes/web.php</output>
    </outputs>
  </step>

  <step name="4-test">
    <action>Feature テスト作成・実行</action>
    <command>php artisan test tests/Feature/Livewire/{Component}Test.php</command>
  </step>
</implementation-flow>

## スタック

```
Laravel 12
Livewire 4
Tailwind CSS 4
daisyUI 5
Alpine.js 3
PHP 8.3+
```

## 出力物

1. Livewire Component (`app/Livewire/`)
2. Blade テンプレート (`resources/views/livewire/`)
3. ルート追加（必要に応じて `routes/web.php`）
4. Level 1 Feature テスト (`tests/Feature/Livewire/`)

**注意**: Migration/Model/Seeder は db-agent が担当。livewire-agent は作成しない。

---

## ディレクトリ構造

```
app/Livewire/
├── Pages/{Feature}/      # フルページコンポーネント
│   ├── Index.php
│   ├── Create.php
│   └── Edit.php
├── Partials/             # 再利用パーツ
└── Layouts/              # レイアウト

resources/views/livewire/
├── pages/{feature}/
│   ├── index.blade.php
│   ├── create.blade.php
│   └── edit.blade.php
├── partials/
└── layouts/
```

---

## Livewire Fullpage Component

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

---

## Validation

```php
use Livewire\Attributes\Validate;

#[Validate('required|string|max:255')]
public string $name = '';
```

---

## Data Binding

- Default: `wire:model.blur` (blur時に同期)
- Real-time: `wire:model.live` (検索、オートコンプリートのみ)

---

## Component Communication

```php
// Dispatch
$this->dispatch('user-selected', id: $userId);

// Listen
#[On('user-selected')]
public function onUserSelected(int $id): void {}
```

---

## daisyUI Form Structure（CRITICAL）

### 禁止

```html
<!-- これは使わない -->
<div class="form-control">
    <label class="label"><span class="label-text">Name</span></label>
```

### 正しい構造

```html
<div>
    <label class="block text-sm font-medium mb-1.5">Name</label>
    <input class="input input-bordered w-full @error('name') input-error @enderror" />
    @error('name')
        <p class="text-error text-sm mt-1">{{ $message }}</p>
    @enderror
</div>
```

---

## Common daisyUI Classes

| Element | Class |
|---------|-------|
| Button Primary | `btn btn-primary` |
| Button Ghost | `btn btn-ghost` |
| Input | `input input-bordered` |
| Select | `select select-bordered` |
| Alert | `alert alert-{type}` |
| Badge | `badge badge-{type}` |

---

## Responsive Design（Mobile-First必須）

### 正しい書き方

```html
<div class="p-4 md:p-6 lg:p-8">
<div class="flex flex-col md:flex-row">
```

### 禁止（デスクトップファースト）

```html
<div class="p-8 sm:p-4">
```

### Breakpoints

| Prefix | Min Width | Device |
|--------|-----------|--------|
| (none) | 0px | Mobile (default) |
| `sm:` | 640px | Landscape phone |
| `md:` | 768px | Tablet |
| `lg:` | 1024px | Laptop |
| `xl:` | 1280px | Desktop |

### Touch Target

最小44x44px

```html
<button class="btn min-h-11 min-w-11">
```

---

## Alpine.js（UI操作のみ）

```html
<div x-data="{ open: false }">
    <button @click="open = !open">Menu</button>
    <div x-show="open" @click.outside="open = false">...</div>
</div>
```

複雑な状態 → Livewireを使用

10行以上 → 別ファイル化:
```js
// resources/js/components/data-table.js
export default () => ({
    sortColumn: null,
    sortDirection: 'asc',
})
```

---

## Animation

| Type | Duration | Use Case |
|------|----------|----------|
| Fast | 150ms | Hover, focus |
| Normal | 200ms | Dropdowns |
| Slow | 300ms | Modals |

```html
<div x-show="open"
     x-transition:enter="transition ease-out duration-200"
     x-transition:enter-start="opacity-0 -translate-y-2"
     x-transition:enter-end="opacity-100 translate-y-0"
     x-transition:leave="transition ease-in duration-150"
     x-transition:leave-start="opacity-100 translate-y-0"
     x-transition:leave-end="opacity-0 -translate-y-2">
```

---

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

---

## Anti-Patterns（禁止）

- `form-control`, `label > label-text` ラッパー
- デスクトップファースト: `flex-row sm:flex-col`
- 小さいタッチターゲット: `p-1 text-xs`
- 固定幅によるoverflow: `w-[800px]`

---

## Level 1 Feature テスト（CRITICAL）

<test-requirement>
  <principle>
    Livewire コンポーネント実装時は Feature テストも必ず作成・実行する。
    テストなしで実装完了としてはならない。
  </principle>

  <required-tests>
    <test>ページが正常に表示されること (assertStatus 200)</test>
    <test>主要な操作が動作すること (create/update/delete)</test>
    <test>バリデーションエラーが表示されること</test>
  </required-tests>

  <required-commands>
    <command>php artisan test tests/Feature/Livewire/{Component}Test.php</command>
  </required-commands>

  <completion-criteria>
    テストがすべてパスするまで実装完了としない。
  </completion-criteria>
</test-requirement>

```php
use Livewire\Livewire;

test('can display user list', function () {
    Livewire::test(\App\Livewire\Pages\Users\Index::class)
        ->assertStatus(200)
        ->assertSee('Users');
});

test('can create user', function () {
    Livewire::test(\App\Livewire\Pages\Users\Create::class)
        ->set('name', 'John Doe')
        ->set('email', 'john@example.com')
        ->call('save')
        ->assertHasNoErrors();

    expect(User::where('email', 'john@example.com')->exists())->toBeTrue();
});
```

**テストレベル: Level 1**（表示とメインアクション、40-60%カバレッジ）
