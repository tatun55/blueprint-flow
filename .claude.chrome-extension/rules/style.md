# Code Style
> TypeScript/React naming conventions, readability guidelines

## Naming Conventions

| Target | Convention | Example |
|--------|-----------|---------|
| React component | PascalCase | `PopupApp`, `HistoryList` |
| Hook | camelCase, `use` prefix | `useStorage`, `useActiveTab` |
| TypeScript interface | PascalCase | `StorageSchema`, `HistoryItem` |
| TypeScript type | PascalCase | `ExtensionMessage`, `TabInfo` |
| File (component) | PascalCase | `PopupApp.tsx`, `HistoryList.tsx` |
| File (utility) | camelCase | `messages.ts`, `storage.ts` |
| Storage key | camelCase | `userSettings`, `browsingHistory` |
| CSS class | Tailwind utilities | `flex items-center gap-2` |
| Message type | SCREAMING_SNAKE_CASE | `'GET_TAB_INFO'`, `'PROCESS_PAGE'` |

## Code Style

- **Readability first**: prefer clear, readable code even if longer
- **TypeScript strict mode**: no `any`, no `@ts-ignore` without justification
- **Explicit return types** on public functions and hooks
- **Error handling**: always handle Chrome API errors (APIs return undefined on error)
- Avoid excessive abbreviation — write code with clear intent

## React Patterns

- Prefer named exports over default exports for components
- One component per file
- Keep components small — extract sub-components when JSX exceeds ~50 lines
- Avoid prop drilling > 2 levels — use context or lift state

## TypeScript Patterns

- Discriminated unions for message types
- `satisfies` operator for config objects
- Avoid type assertions (`as T`) — prefer type guards
