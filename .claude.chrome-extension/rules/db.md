# Storage Schema Conventions
> chrome.storage schema design, migration, seeding (blueprint type: table)

## Schema Definition

Each `table` blueprint defines a `StorageSchema` key — the shape of data stored in `chrome.storage`.

```typescript
// src/storage/index.ts — single source of truth for all storage shapes
export interface StorageSchema {
  // Defined by each table blueprint
  settings: SettingsData
  history: HistoryItem[]
  cache: Record<string, CachedResult>
}
```

## Type Naming Convention

| Convention | Example |
|-----------|---------|
| Data interface | `SettingsData`, `HistoryItem`, `CachedResult` |
| Storage key | `settings`, `history`, `cache` (camelCase) |
| File | `src/storage/{key}.ts` |

## Migration Strategy

- Store `schemaVersion` in `chrome.storage.local`
- On extension startup (background service worker), run migrations if version differs
- Migrations are additive — never delete data without user consent

```typescript
// src/background/migrations.ts
const CURRENT_VERSION = 2

export async function runMigrations(): Promise<void> {
  const { schemaVersion = 0 } = await chrome.storage.local.get('schemaVersion')
  if (schemaVersion < 1) await migrateV1()
  if (schemaVersion < 2) await migrateV2()
  await chrome.storage.local.set({ schemaVersion: CURRENT_VERSION })
}
```

## Seed Data (for tests)

Each `table` blueprint defines static seed helpers — used in both tests and manual dev:

```typescript
// src/storage/history.ts
export const HistorySeeder = {
  defaults(): HistoryItem[] {
    return [
      { url: 'https://example.com', title: 'Example', timestamp: Date.now() },
      { url: 'https://test.com', title: 'Test', timestamp: Date.now() - 1000 },
    ]
  }
}
```

## Storage Limits

- `sync`: 100KB total, 8KB per key — suitable for settings only
- `local`: 10MB — suitable for history, cache, large data
- Check `chrome.storage.local.getBytesInUse()` for quota monitoring

## Data Lifecycle

| Event | Action |
|-------|--------|
| Extension install | Set defaults (`chrome.runtime.onInstalled`) |
| Extension update | Run migrations |
| User uninstall | Data is cleared by Chrome automatically |
| Manual reset | Provide "Reset to defaults" in Options page |
