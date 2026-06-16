# Blueprint-Flow Project

Stack: Laravel 12 / Livewire 4 / Tailwind CSS 4 / daisyUI 5 / Alpine.js 3 / pinion-ui ^0.4 (PHP 8.3+, MySQL 8.0+)

All user interaction MUST be in Japanese.
All DB writes via `hub.py` — never raw sqlite3.

## CSS/デザインルール

- **pinion-ui の Blade コンポーネントが UI 構築の主軸**: anonymous の `<x-button>`, `<x-input>`, `<x-card>`, `<x-alert>`, `<x-tabs>`, `<x-modal>` 等を優先利用（衝突時のみ `<x-pn::button>`）。props・gotcha は `vendor/sparrowhawk-labs/pinion-ui/AGENTS.md` と `reference/components/` を真実源として都度参照
- **Theme × Tune × Component の3レイヤー**: `<html data-theme="..." data-tune="...">` でパレットとトークンを切替。コンポーネント単位の調整は Blade props (`variant`, `size` 等)
- **Tailwind CSS v4** は pinion-ui に無い要素のレイアウト・スペーシング・微調整に使用
- **daisyUI はセマンティックカラー変数 + テーマ切替のみ**: `bg-base-100`, `text-base-content`, `border-base-300`, `bg-primary`, `text-error` 等。コンポーネントクラス (`btn`, `card`, `modal` 等) は pinion-ui が内部で扱うので直接使用しない
- **Tailwind 標準色クラスは原則使わない**: `bg-gray-100`, `text-blue-500` 等 → daisyUI セマンティックカラーを使用
- **Tune トークンの直接参照は可**: `var(--radius-box)`, `var(--space-section)`, `var(--font-heading)` 等を Tailwind 任意値 `[var(...)]` で参照できる
- **「ＡＩ」表記**: ユーザー向けテキスト・コメント・ドキュメントで「AI」ではなく「ＡＩ」（全角）を使用する

## メール列挙攻撃の防止ルール

メールアドレスの存在有無を外部から判別できてはならない。以下を全エンドポイントで徹底する。

1. **リアルタイムバリデーションで `unique` を使わない** — blur/keyup 時の `validateOnly` に `unique:users,email` を含めると、存在の有無が即座に漏洩する
2. **送信系は常に同じ応答を返す** — 登録確認メール・パスワードリセット等、メールアドレスが存在してもしなくても同一の画面・メッセージを表示する（実際の送信は存在時のみでよい）
3. **ログインエラーは汎用メッセージ** — 「メールアドレスまたはパスワードが正しくありません」のみ。「このメールは登録されていません」は禁止
4. **メール送信エンドポイントにレート制限** — IP 単位で `RateLimiter` を適用し、総当たりを抑止する

## テスト実行ルール

Unit/Feature テストを実行する際は、必ず `/run-tests` スキルを使用すること。
`php artisan test` を直接 Bash で実行してはならない。
`/run-tests` はサブエージェント内でテストを実行し、要旨のみを返すため親コンテキストを汚さない。

```
/run-tests              # 全テスト
/run-tests Feature      # Feature テストのみ
/run-tests Unit         # Unit テストのみ
/run-tests tests/Feature/FooTest.php  # 特定ファイル
```

## 会話開始時の初期化（CRITICAL）

会話の最初のターンで、必ず overview spec を読み込んでアプリ全体像を把握する:

```bash
# $HUB = shorthand in docs. Expand to full path in each Bash call:
python3 .blueprint-flow/blueprint/hub.py <command> [args]
```

## Orchestration

Use `/bpf` for blueprint-flow orchestration.
Use `/night-runner` for autonomous development mode.

## Reference

| Item | Path |
|------|------|
| Design doc | @.blueprint-flow/BLUEPRINT_FLOW_v2.md |
| DB helper | `.blueprint-flow/blueprint/hub.py` |
| DB | `blueprint/blueprint.db` |
| Schema | `blueprint/schema.sql` |
| Rules | `.blueprint-flow/.claude.tall-pinion/rules/` |
| pinion-ui AGENTS (真実源) | `vendor/sparrowhawk-labs/pinion-ui/AGENTS.md` |
| pinion-ui component reference | `vendor/sparrowhawk-labs/pinion-ui/reference/components/index.md` |
