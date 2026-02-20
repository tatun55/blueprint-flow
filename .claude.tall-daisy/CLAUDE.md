# Blueprint-Flow Project

Stack: Laravel 12 / Livewire 4 / Tailwind CSS 4 / daisyUI 5 / Alpine.js 3 (PHP 8.3+, MySQL 8.0+)

All user interaction MUST be in Japanese.
All DB writes via `hub.py` — never raw sqlite3.

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
