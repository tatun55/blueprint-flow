# データ層ルール
> Model・バリデーション・Action・クエリ・データ共有

## Model

- **スリム Model**: リレーション・スコープ・$casts のみ
- ビジネスロジックは Model に書かない

## バリデーション

- **Model 内**にルールを定義

## Action パターン

- 小規模なロジック → Livewire コンポーネント内に直接記述
- 複数箇所で再利用・複雑なロジック → `app/Actions/` に切り出し

## データ共有

- Livewire 標準パターン:
  - 親→子: props 渡し
  - 子→親: dispatch イベント
  - ページ間: URL パラメータ / session

## クエリ

- 基本は **Eloquent** 主体
- 複雑な集計・レポートは **Query Builder** や生 SQL も使用

## Job / Queue / Event

- **最小限の使用**: メール送信など本当に非同期が必要な場合のみ
- Event/Listener は使わず直接呼び出しを基本とする
