# Flow Definitions
> Project flow, item flow per blueprint type (Chrome Extension)

## Project Flow

<flow name="project">
  <phase order="0">Concept-making (strategy + concept) → review</phase>
  <phase order="1">Definition (design + overview + config) → review</phase>
  <phase order="2">Storage design (table blueprints) → review</phase>
  <phase order="3">Architecture design (layout + action blueprints) → review</phase>
  <phase order="4">UI design (page + partial blueprints) → review</phase>
  <phase order="5">Implementation (TDD) → review</phase>
  <phase order="6">E2E L1 → review</phase>
  <phase order="7">E2E L2 → review (after ALL L1 complete)</phase>
  <phase order="8">E2E L3 → review (after ALL L2 complete)</phase>
</flow>

## Blueprint Type Mapping (Chrome Extension)

| Blueprint type | Maps to |
|---------------|---------|
| `page` | Popup, Options, Side Panel pages (React entry points) |
| `partial` | Shared React components, custom hooks |
| `action` | Background service worker handlers, content script logic |
| `table` | chrome.storage schema definition + seeder |
| `layout` | Root providers, ThemeProvider, app shell wrapper |
| `test` | Test definitions |

## Item Flow

<item-flow type="page, partial, action">
define → impl → test_l1 → test_l2 → test_l3 → done
</item-flow>

<item-flow type="table">
define → seed → impl → done
</item-flow>

<item-flow type="layout">
define → impl → done
</item-flow>

<item-flow type="test">
define → done
</item-flow>

## Table (Storage) Seed Step

For `table` type, the `seed` step is a separate review for:
- TypeScript interface definitions (`StorageSchema`)
- Default values and seeder helpers
- Migration strategy (if schema changes expected)

The `impl` step then creates:
- `src/storage/{key}.ts` — typed get/set wrappers
- `tests/helpers/{key}Seeds.ts` — static seed data for tests
- Migration handler (if needed)

## Impl Step Behavior

<flow name="impl-step">
  <step>Write Vitest unit/component tests from blueprint scenarios (Red)</step>
  <step>Implement code to pass the tests (Green)</step>
  <step>Run tests, iterate until all pass</step>
  <step>Verify blueprint-match</step>
  <step>Capture screenshots (popup/options/sidepanel types only)</step>
</flow>

## Screenshots

For UI-related blueprints (page, partial, layout):
- Build extension: `npm run build`
- Load in Chrome via Playwright extension mode
- Screenshot the popup/options page
- Save to `blueprint/reviews/{act_id}/after.png`

## Review Modes

| Mode | Trigger | Review method | Retry |
|------|---------|--------------|-------|
| `/bpf` | Human orchestration | Human: approve / changes / defer | Human creates new act |
| `/night-runner` | Autonomous execution | Auto: quality gate (tests + blueprint-match) | Auto: max 3 retries |
