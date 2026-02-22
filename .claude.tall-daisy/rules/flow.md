# Flow Definitions
> Project flow, item flow per blueprint type

## Project Flow

<flow name="project">
  <phase order="0">Concept-making (strategy + concept) → review</phase>
  <phase order="1">Definition (design + overview + config) → review</phase>
  <phase order="2">Feature design → review</phase>
  <phase order="3">DB design → review</phase>
  <phase order="4">Implementation (TDD) → review</phase>
  <phase order="5">E2E L1 → review</phase>
  <phase order="6">E2E L2 → review (after ALL L1 complete)</phase>
  <phase order="7">E2E L3 → review (after ALL L2 complete)</phase>
</flow>

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

## Impl Step Behavior

The `impl` step includes test-first development (see `testing` rules for details):

<flow name="impl-step">
  <step>Write unit/feature tests from blueprint scenarios (Red)</step>
  <step>Implement code to pass tests (Green)</step>
  <step>Run tests, iterate until all pass</step>
  <step>Verify blueprint-match</step>
  <step>Capture screenshots (UI types only)</step>
</flow>

This behavior is configurable per project via the `testing` rule file.

## Review Modes

Two review modes share the same pipeline and DB:

| Mode | Trigger | Review method | Retry |
|------|---------|--------------|-------|
| `/bpf` | Human orchestration | Human: approve / changes / defer | Human creates new act |
| `/night-runner` | Autonomous execution | Auto: quality gate (tests + blueprint-match) | Auto: max 3 retries with feedback |

Switching between modes at any time is safe — same step_status values, same pipeline.

## Table Impl Note

For `table` type, the `impl` step creates:
- Migration, Model, Seeder (with static helpers for test data)
- The `seed` step is a separate preceding step for seeder definition review
