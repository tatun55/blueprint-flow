# 認証・認可
> 認証は自作・認可はPolicy+Gate・権限はroleカラム

## 認証

- **自作実装**（Breeze/Jetstream 不使用）

## 認可

- **Policy** (モデル紐づき) + **Gate** (グローバル権限) 併用
- `$this->authorize()` / `Gate::allows()` でチェック

## 権限管理

- `users` テーブルの `role` カラムで管理
- ロール値は core config で定義
