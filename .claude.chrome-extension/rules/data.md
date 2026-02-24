# Data Layer Rules
> chrome.storage patterns, message passing, typed API wrappers

## Storage Strategy

| Storage | Use case | Limit |
|---------|----------|-------|
| `chrome.storage.local` | Large data, device-specific | 10MB |
| `chrome.storage.sync` | Small user preferences, cross-device | 100KB total, 8KB per item |
| `chrome.storage.session` | Ephemeral (cleared on browser close) | 10MB |

**Default**: Use `local` unless data must sync across devices.

## Type-Safe Storage Wrapper

Define storage schema once — share across all extension contexts:

```typescript
// src/storage/index.ts
export interface StorageSchema {
  settings: { theme: 'light' | 'dark'; autoEnable: boolean }
  history: Array<{ url: string; timestamp: number }>
}

export async function getStorage<K extends keyof StorageSchema>(
  key: K
): Promise<StorageSchema[K] | undefined> {
  const result = await chrome.storage.local.get(key)
  return result[key]
}

export async function setStorage<K extends keyof StorageSchema>(
  key: K,
  value: StorageSchema[K]
): Promise<void> {
  await chrome.storage.local.set({ [key]: value })
}
```

## Custom Hook for Storage

```typescript
// src/hooks/useStorage.ts
export function useStorage<K extends keyof StorageSchema>(key: K) {
  const [value, setValue] = useState<StorageSchema[K] | undefined>()

  useEffect(() => {
    getStorage(key).then(setValue)
    const listener = (changes: Record<string, chrome.storage.StorageChange>) => {
      if (key in changes) setValue(changes[key].newValue)
    }
    chrome.storage.local.onChanged.addListener(listener)
    return () => chrome.storage.local.onChanged.removeListener(listener)
  }, [key])

  const set = useCallback((val: StorageSchema[K]) => setStorage(key, val), [key])
  return [value, set] as const
}
```

## Message Passing

- Define all message types in `src/lib/messages.ts`
- Use discriminated union for type safety
- Background handles messages — popup/content send messages

```typescript
// src/lib/messages.ts
export type ExtensionMessage =
  | { type: 'PING' }
  | { type: 'GET_TAB_INFO' }
  | { type: 'PROCESS_PAGE'; payload: { url: string } }

export type ExtensionResponse =
  | { type: 'PONG' }
  | { type: 'TAB_INFO'; payload: chrome.tabs.Tab }
  | { type: 'PROCESS_RESULT'; payload: { success: boolean } }
```

## Action Pattern

- Small logic → directly in component / hook
- Background logic → service worker handlers in `src/background/index.ts`
- Complex reusable logic → `src/lib/` utility functions

## Querying the Active Tab

```typescript
const [tab] = await chrome.tabs.query({ active: true, currentWindow: true })
```

Always handle the case where `tab` is undefined (no active tab).
