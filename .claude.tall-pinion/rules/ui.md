# UI Rules
> pinion-ui 主軸、Theme × Tune、Tailwind CSS 補完、Alpine.js、モーダル、通知、エラー表示

## 構築方針（CRITICAL）

UI は **pinion-ui の Blade コンポーネントを最優先**で組み立てる。pinion-ui に存在しないレイアウトや微調整のみ Tailwind ユーティリティで補う。

```
優先順位:  pinion-ui <x-...>  >  Tailwind utilities  >  daisyUI semantic colors (変数のみ)
```

**コンポーネントの props・slot・gotcha は必ず真実源を参照する**（このファイルは方針のみ。API 一覧は複製しない）:

- `vendor/sparrowhawk-labs/pinion-ui/AGENTS.md` — コードを書く前に読む。呼び出し規約・落とし穴・参照パス
- `vendor/sparrowhawk-labs/pinion-ui/reference/components/index.md` — 46 コンポーネントの索引と個別リファレンス

## 呼び出し規約

- **anonymous がデフォルト**: `<x-button>`, `<x-input>`, `<x-card>`, `<x-modal>`, `<x-tabs>` 等をアプリコードで使う
- **名前空間版 `<x-pn::button>`** は、アプリ側に同名コンポーネントがあって衝突する時だけ
- 旧 `<x-pinion-ui::*>` / `<x-ui::*>` プレフィックスは廃止（v0.2.1 で `pn::` に改称）
- アイコンは `<x-i>`（pinion-icons、hard-require で自動導入）
- **Blade の `:prop="..."` は PHP 式**として評価される。Alpine の `:class`/`@click` を `<x-button>` 等に付けると壊れる → `x-bind:class` / `x-on:click` を使う（詳細は AGENTS.md）

## Theme × Tune

ルートレイアウトの `<html>` に両属性を付与し、ページ単位で切替可能にする:

```html
<html data-theme="light" data-tune="default">
```

- **Theme** (`data-theme`): 色パレット（`light`, `dark`, `cyberpunk`, `dracula` 等 daisyUI テーマ）
- **Tune** (`data-tune`): 形状/余白/フォント/サイジングのトークンセット（11 プリセット）。利用可能なプリセット名は AGENTS.md / reference を参照

Tune トークンは Tailwind 任意値で参照できる:

```html
<div class="rounded-[var(--radius-box)] p-[var(--space-section-inner)] font-[var(--font-heading)]">
```

## CSS

- **pinion-ui コンポーネントでカバーできる UI は pinion-ui を使う**
- 補完用途での Tailwind 直書きは OK
- daisyUI は**セマンティックカラー変数**のみ使用 — `bg-base-100`, `text-base-content`, `border-base-300`, `text-primary`, `bg-error` 等
- daisyUI コンポーネントクラス (`btn`, `card`, `modal`, `badge`, `alert`, `navbar`) の直接使用禁止 — pinion-ui が内部で扱う
- Tailwind 標準色 (`bg-gray-100`, `text-blue-500`) 禁止 → daisyUI セマンティックカラーを使用
- `resources/css/app.css` の pinion-ui プリセット `@import`（`ui:install` が配線）は消さない。`@source` グロブを通してコンポーネント内クラスがビルドに乗る
- No custom CSS

## Components

| Type | Method | 備考 |
|------|--------|------|
| Button / Input / Card / Alert / Tabs / Modal 等 46種 | pinion-ui `<x-...>` | props は AGENTS.md / reference/components/ を参照 |
| Dynamic partial (状態/ロジック持ち) | Livewire | Livewire component で pinion-ui を内包 |
| pinion-ui に無い UI | Tailwind ユーティリティ | 例: 特殊なグリッド、独自装飾 |

### pinion-ui に無いコンポーネントが必要な場合

1. まず reference/components/ を確認（46種あるので大抵ある）
2. 無ければ pinion-ui を Tailwind ユーティリティで補えないか検討（例: `card` を組み合わせる）
3. それでも無理なら Tailwind 直書きで実装し、act に「pinion-ui 未対応のため直書き」と記録
4. 繰り返し必要になる場合は Hub に報告 → pinion-ui への追加を相談

## Alpine.js Role

- **UI state only**: toggle, dropdown, modal open/close
- pinion-ui の modal/tabs 等は内部で Alpine を使用している
- すべてのデータ操作・サーバー通信は Livewire が担当
- Livewire 連携は `$wire` で行う

## Minimize Page Navigation

- **CRUD は同一ページ上の pinion-ui modal で完結**
- 作成・編集・削除はリストページを離れずに行う
- 詳細画面や設定画面など別画面が本当に必要な場合のみ遷移

## Error Display

- バリデーションエラーは **各フィールドの直下** に表示
- pinion-ui `<x-input>` は `:error` prop で表示可能（props 詳細は reference 参照）
- Blade 直書きの場合は `@error` ディレクティブ

## Pagination

- Livewire `WithPagination` trait で動的ページネーション
