---
name: e2e
description: E2E visual regression testing. Create test cases, run tests with screenshots, and manage baselines.
allowed-tools: Bash, Read, Write, AskUserQuestion, mcp__playwright-mcp__playwright_navigate, mcp__playwright-mcp__playwright_screenshot, mcp__playwright-mcp__playwright_close
---

# E2E Visual Regression Testing

Manage screenshot-based E2E tests with Playwright MCP.

## Initial Check

```bash
./scripts/e2e-db-cli.sh overview
```

If not initialized:
```bash
./scripts/e2e-db-cli.sh init
```

## Action Selection

```
AskUserQuestion:
  question: "What would you like to do?"
  header: "Action"
  options:
    - label: "Create Test Case"
      description: "Define a new E2E test"
    - label: "Run Test"
      description: "Execute test and capture screenshot"
    - label: "Review Results"
      description: "Check test results and screenshots"
    - label: "Set Baseline"
      description: "Mark current screenshot as baseline"
```

---

## Create Test Case

Gather via AskUserQuestion:
1. Slug (lowercase, underscores)
2. Name (display name)
3. URL to test
4. Viewport size (default: 1280x720)
5. Related page spec (optional, from blueprint)

```bash
./scripts/e2e-db-cli.sh add {slug} "{name}" "{url}" {width}x{height}
```

Example:
```bash
./scripts/e2e-db-cli.sh add dashboard_main "Dashboard Main View" "/dashboard" 1280x720
```

---

## Run Test

### Step 1: Create Run Record

```bash
./scripts/e2e-db-cli.sh run {slug}
```

Returns: `{"success": true, "run_id": 1, "case_id": 1}`

### Step 2: Get Test Case Details

```bash
./scripts/e2e-db-cli.sh get {slug}
```

### Step 3: Navigate and Screenshot

Use Playwright MCP:

```
mcp__playwright-mcp__playwright_navigate
  url: {full_url}
  headless: true

mcp__playwright-mcp__playwright_screenshot
  name: "{case_index}_{slug}"
  savePng: true
  fullPage: false
  width: {viewport_width}
  height: {viewport_height}
```

### Step 4: Record Screenshot

```bash
./scripts/e2e-db-cli.sh screenshot {run_id} actual "tests/e2e/screenshots/{filename}.png"
```

### Step 5: Record Result

```bash
./scripts/e2e-db-cli.sh result {run_id} passed
# or
./scripts/e2e-db-cli.sh result {run_id} failed "Button misaligned"
```

### Step 6: Close Browser

```
mcp__playwright-mcp__playwright_close
```

---

## Screenshot Naming Convention

```
tests/e2e/screenshots/{run_id}_{slug}_{type}.png
```

Types:
- `actual` - Current screenshot
- `baseline` - Expected screenshot
- `diff` - Visual difference

Example:
```
tests/e2e/screenshots/001_dashboard_main_actual.png
tests/e2e/screenshots/001_dashboard_main_baseline.png
```

---

## Review Results

### List All Tests
```bash
./scripts/e2e-db-cli.sh overview
```

### Tests Needing Attention
```bash
./scripts/e2e-db-cli.sh attention
```

### Specific Test Runs
```bash
./scripts/e2e-db-cli.sh runs {slug}
```

---

## Set Baseline

After confirming a screenshot is correct:

```bash
./scripts/e2e-db-cli.sh baseline {slug} "tests/e2e/screenshots/{filename}.png"
```

---

## Batch Testing Flow

For running multiple tests:

<flow>
  <step>Get active test cases: `./scripts/e2e-db-cli.sh list`</step>
  <step>For each test case:</step>
  <step>  - Create run record</step>
  <step>  - Navigate to URL</step>
  <step>  - Take screenshot</step>
  <step>  - Compare with baseline (if exists)</step>
  <step>  - Record result</step>
  <step>Close browser</step>
  <step>Show summary</step>
</flow>

---

## CLI Reference

| Command | Description |
|---------|-------------|
| `list` | List all test cases |
| `add <slug> <name> <url>` | Create test case |
| `get <slug>` | Get test case details |
| `run <slug>` | Create new test run |
| `runs <slug>` | List runs for test case |
| `result <id> <status>` | Record run result |
| `screenshot <id> <type> <path>` | Record screenshot |
| `baseline <slug> <path>` | Set baseline |
| `overview` | All tests with status |
| `attention` | Tests needing attention |

---

## Important Rules

1. **Always close browser** after testing with `playwright_close`
2. **Use headless: true** for automated runs
3. **Save screenshots** with consistent naming
4. **Record all results** in database
5. **Set baseline** only after visual verification
