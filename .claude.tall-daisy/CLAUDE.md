# Blueprint-Flow Project

Stack: Laravel 12 / Livewire 4 / Tailwind CSS 4 / daisyUI 5 / Alpine.js 3 (PHP 8.3+, MySQL 8.0+)

All user interaction MUST be in Japanese.
All DB writes via `hub.py` — never raw sqlite3.

## CSS/デザインルール

- **Tailwind CSS v4** がスタイリングの主軸。レイアウト・スペーシング・タイポグラフィ・アニメーション等すべて Tailwind ユーティリティで構築する
- **daisyUI はセマンティックカラー変数 + テーマ切替のみ使用**: `bg-base-100`, `text-base-content`, `border-base-300`, `bg-primary`, `text-error` 等
- **daisyUI コンポーネントクラスは使わない**: `btn`, `card`, `menu`, `badge`, `navbar` 等は禁止
- **Tailwind 標準色クラスは原則使わない**: `bg-gray-100`, `text-blue-500` 等 → daisyUI セマンティック or spectrum カスタムカラーを使用
- **「ＡＩ」表記**: ユーザー向けテキスト・コメント・ドキュメントで「AI」ではなく「ＡＩ」（全角）を使用する

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
| Rules | `.blueprint-flow/.claude.tall-daisy/rules/` |
