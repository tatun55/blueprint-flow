# UI ルール
> daisyUI・Alpine.js・xylph-ui・モーダル・通知・エラー表示

## CSS

- **daisyUI コンポーネントクラス優先**
- 微調整に Tailwind utility を使用
- カスタム CSS は書かない

## コンポーネント

| 種類 | 方式 | 例 |
|------|------|-----|
| 静的 UI 部品 | xylph-ui コンポーネント | `<x-ui-button>`, `<x-ui-modal>` |
| 動的部品 (partials) | Livewire コンポーネント | 複雑なページの分割時のみ |
| モーダル/ドロワー | xylph-ui (Alpine.js 制御) | 確認ダイアログ、CRUD フォーム |
| 通知 (flash) | xylph-ui notification | 操作成功/失敗のフィードバック |

## Alpine.js の役割

- **UI 状態のみ**: toggle, dropdown, modal の開閉等
- データ操作・サーバー通信は全て Livewire が担当
- Livewire との連携は `$wire` 経由

## ページ遷移の最小化

- **CRUD はモーダルで同一ページ内完結**
- 一覧ページから離れずに作成・編集・削除を行う
- ページ遷移は本当に別画面が必要な場合のみ（詳細表示、設定画面等）

## エラー表示

- バリデーションエラーは**フィールド直下**にメッセージ表示
- `@error` ディレクティブを使用

## ページネーション

- Livewire の `WithPagination` trait で動的ページネーション
