# Blueprint-Flow Project

Stack: Chrome Extension MV3 / TypeScript / React 18 / Vite / Tailwind CSS 3

All user interaction MUST be in Japanese.
All DB writes via `hub.py` — never raw sqlite3.

## CSS/デザインルール

- **Tailwind CSS v3** がスタイリングの主軸
- daisyUI はセマンティックカラー変数 + テーマ切替のみ使用（コンポーネントクラス禁止）
- No custom CSS — Tailwind utilities only
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
| Rules | `.blueprint-flow/.claude.chrome-extension/rules/` |
