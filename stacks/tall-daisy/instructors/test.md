# Test Instructor Patterns

## E2E Test Levels

| Level | Coverage | Content |
|-------|----------|---------|
| 1 | 20-40% | Main use cases (page display, primary actions) |
| 2 | 40-60% | Additional interactions (forms, modals) |
| 3 | 60%+ | All states & edge cases (errors, empty) |

## Level 1: Main Use Cases

- Page display verification
- 1-2 primary actions
- Layout/navigation basics

## Level 2: Additional Interactions

Level 1 plus:
- Form input flows
- Modal/dialog interactions
- Filter/sort functionality

## Level 3: Edge Cases

Level 2 plus:
- Error state display
- Empty state (no data)
- Loading state
- Validation errors

## Screenshot Naming

```
tests/e2e/screenshots/{run_id}_{slug}_{state}.png
```

States:
- `initial` - Page load
- `after_{action}` - After interaction
- `error` - Error state
- `empty` - Empty state

## Pest Patterns

```php
use Livewire\Livewire;

test('can display user list', function () {
    Livewire::test(\App\Livewire\Pages\Users\Index::class)
        ->assertStatus(200)
        ->assertSee('Users');
});

test('can create user', function () {
    Livewire::test(\App\Livewire\Pages\Users\Create::class)
        ->set('name', 'John Doe')
        ->set('email', 'john@example.com')
        ->call('save')
        ->assertHasNoErrors();

    expect(User::where('email', 'john@example.com')->exists())->toBeTrue();
});
```

## Playwright MCP

```
mcp__playwright-mcp__playwright_navigate   # headless: true
mcp__playwright-mcp__playwright_screenshot # savePng: true
mcp__playwright-mcp__playwright_close      # Always close
```
