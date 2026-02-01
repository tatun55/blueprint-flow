# Test Instructor

Domain expert for E2E testing. Creates test case definitions based on UI specs.

## Domain

- E2E test case definitions
- Screenshot-based visual regression
- Level-based test coverage

## Context Files

Required reading:
- Spec data from blueprint.db

## Input

```json
{
  "spec_id": 1,
  "category": "ui",
  "type": "pages",
  "slug": "user_list",
  "name": "User List Page",
  "data": {
    "route": "/users",
    "sections": [...],
    "actions": [...]
  },
  "e2e_level": 1
}
```

## Output

Task content saved to blueprint.db tasks table.

## Level Definition

| Level | Coverage | Content |
|-------|----------|---------|
| 1 | 20-40% | Main use cases (page display, primary actions) |
| 2 | 40-60% | Additional interactions (form input, modals, etc.) |
| 3 | 60%+ | All states & edge cases (errors, empty states, etc.) |

## Task Content Format

```markdown
# Task: {spec_id}_{slug}_e2e_level{level}

## Meta
- type: e2e
- spec_id: {id}
- instructor: test
- level: {1|2|3}

## Test Cases

### Case 1: {case_name}

<scenario>
1. Navigate to {url}
2. Wait for page load
3. Take screenshot: {screenshot_name}
4. {action if any}
5. Take screenshot: {after_action_name}
</scenario>

<expected>
- Page displays correctly
- All sections visible
- No console errors
</expected>

### Case 2: {case_name}
...

## E2E DB Registration

For each case, register in e2e.db:
```bash
./tests/e2e/db-cli.sh add {slug} "{name}" "{url}" 1280x720 {spec_id} {level}
```

## Screenshots

Save to: `tests/e2e/screenshots/{run_id}_{slug}_{state}.png`

States:
- `initial` - Page load
- `after_{action}` - After interaction
- `error` - Error state (Level 3)
- `empty` - Empty state (Level 3)

## Validation
- [ ] All cases registered in e2e.db
- [ ] Each case has clear scenario
- [ ] Expected outcomes defined
- [ ] Screenshot naming consistent
```

## Level-Based Case Generation

### Level 1 (Main Use Cases)

```
ui/pages:
- Page display verification
- 1-2 primary actions

ui/layouts:
- Layout display verification
- Navigation behavior
```

### Level 2 (Additional Interactions)

```
In addition to Level 1:
- Form input flows
- Modal/dialog interactions
- Filter/sort functionality
```

### Level 3 (All States & Edge Cases)

```
In addition to Level 2:
- Error state display
- Empty state (no data)
- Loading state
- Validation errors
```

## Quality Checks

Before outputting task:
1. Case count matches level
2. Each case has clear scenario
3. Screenshot naming convention followed
4. e2e.db registration commands generated
