# TALL-pinion Stack
> Tech stack and version definitions

## Technologies

| Technology | Version | Purpose |
|-----------|---------|---------|
| PHP | 8.3+ | Server-side language |
| MySQL | 8.0+ | Database |
| Laravel | 12 | PHP framework |
| Livewire | 4 | Full-page components |
| Tailwind CSS | 4 | Utility-first CSS (pinion-ui 非対応部分の補完) |
| daisyUI | 5 | セマンティックカラー変数 + テーマ機能のみ（コンポーネントクラス直接使用禁止） |
| Alpine.js | 3 | Lightweight JS (UI state only) |
| **pinion-ui** | **^0.4** | **UI 構築の主軸。Laravel Blade コンポーネント `<x-...>` + Theme × Tune トークンシステム** |
| pinion-icons | ^1.0 | アイコン (`<x-i>`)。pinion-ui が hard-require で自動導入 |
| Vite | - | Build tool |
| Pest | - | Test framework |

## pinion-ui の位置づけ

pinion-ui は `composer require sparrowhawk-labs/pinion-ui` でインストールする Laravel 向け Blade UI コンポーネント集（Packagist 公開・パッケージ名 `sparrowhawk-labs/pinion-ui`、開発元 Sparrowhawk Labs）。

- インストールは `composer require sparrowhawk-labs/pinion-ui` → `php artisan ui:install`（npm 依存 daisyUI5 / alpinejs3 / @alpinejs/focus を追加し、`resources/css/app.css` に pinion-ui プリセットの単一 `@import` を、`resources/js/app.js` に Alpine + focus を配線）→ `npm install && npm run build`。
- `data-theme` で色パレット、`data-tune` でシェイプ/スペーシング/フォント/サイジングを制御。
- コンポーネントは Blade props (`variant`, `size` 等) で挙動指定。レンダリング結果は標準 Tailwind + daisyUI セマンティッククラス + Alpine ディレクティブ。
- 46 コンポーネント + 11 プリセットの Tune トークンシステム。pinion-icons を hard-require（自動で入る）。
- **呼び出しは anonymous がデフォルト**: `<x-button>`, `<x-modal>`, `<x-tabs>` 等。アプリ側に同名コンポーネントがあり衝突する時だけ名前空間版 `<x-pn::button>`。旧 `<x-pinion-ui::*>` / `<x-ui::*>` プレフィックスは廃止。
- **真実源**: コンポーネントの props・gotcha は `vendor/sparrowhawk-labs/pinion-ui/AGENTS.md` と `vendor/sparrowhawk-labs/pinion-ui/reference/components/` を都度参照する（このファイルに API 一覧を複製しない）。

## Package Managers

- PHP: Composer
- JS: npm
