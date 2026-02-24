# Testing Conventions
> Vitest, Testing Library, Chrome API mocking, test levels

## Framework

- **Vitest** (not Jest) — fast, native ESM
- **@testing-library/react** for component tests
- **@testing-library/user-event** for interaction simulation
- `tests/unit/` for unit tests
- `tests/component/` for React component tests
- `tests/e2e/` for E2E tests (Playwright with extension)

## Chrome API Mocking

Chrome APIs don't exist in jsdom — mock them in `tests/setup.ts`:

```typescript
// tests/setup.ts
globalThis.chrome = {
  storage: {
    local: {
      get: vi.fn().mockResolvedValue({}),
      set: vi.fn().mockResolvedValue(undefined),
      onChanged: { addListener: vi.fn(), removeListener: vi.fn() }
    },
    sync: { ... }
  },
  runtime: {
    sendMessage: vi.fn(),
    onMessage: { addListener: vi.fn() }
  },
  tabs: {
    query: vi.fn().mockResolvedValue([])
  }
} as unknown as typeof chrome
```

## Test-First During Implementation

During the `impl` step:

<flow name="impl-tdd">
  <step order="1">Read blueprint scenarios and requirements</step>
  <step order="2">Write unit/component tests for each scenario (tests should fail)</step>
  <step order="3">Implement code to pass the tests</step>
  <step order="4">Run tests, iterate until all pass</step>
  <step order="5">Verify blueprint-match (each spec scenario checked against implementation)</step>
</flow>

## Test Data (Storage Seeds)

Use static seeder helpers — no factory pattern:

```typescript
// tests/helpers/storageSeeds.ts
export const HistorySeeds = {
  defaults(): HistoryItem[] {
    return [
      { url: 'https://example.com', title: 'Example', timestamp: 1700000000000 },
      { url: 'https://test.com', title: 'Test', timestamp: 1700000001000 },
    ]
  }
}
```

## Component Test Pattern

```typescript
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { PopupApp } from '../src/popup/PopupApp'

test('shows history items', async () => {
  vi.mocked(chrome.storage.local.get).mockResolvedValue({
    history: HistorySeeds.defaults()
  })
  render(<PopupApp />)
  await screen.findByText('Example')
})
```

## E2E Testing (Playwright + Extension)

Load extension into Chrome for E2E tests:

```typescript
// playwright.config.ts
const pathToExtension = path.join(__dirname, 'dist')
const userDataDir = '/tmp/test-user-data'

const context = await chromium.launchPersistentContext(userDataDir, {
  headless: false,
  args: [
    `--disable-extensions-except=${pathToExtension}`,
    `--load-extension=${pathToExtension}`,
  ],
})
```

- E2E tests run against built extension (`npm run build`)
- Screenshot popup: navigate to `chrome-extension://{id}/popup/index.html`
- Save screenshots to `blueprint/reviews/{act_id}/`

## Test Levels

| Level | Scope | Gate |
|-------|-------|------|
| **L1** | Basic operations (happy paths) | — |
| **L2** | Extended (validation, error states, permissions) | ALL L1 complete |
| **L3** | Edge cases (storage limits, service worker restart, update) | ALL L2 complete |

## Running Tests

```bash
npx vitest run              # unit + component
npx vitest run --coverage   # with coverage
npx playwright test         # E2E (requires built extension)
```
