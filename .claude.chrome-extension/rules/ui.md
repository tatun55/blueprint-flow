# UI Rules
> React components, Tailwind CSS, popup sizing, accessibility

## CSS

- **Tailwind CSS v3 ユーティリティでスタイリング**
- daisyUI は**セマンティックカラークラスとテーマ機能のみ**使用
  - OK: `text-primary`, `bg-base-100`, `border-accent`, テーマ切替（`data-theme`）
  - NG: `btn`, `card`, `modal`, `badge`, `alert` 等のコンポーネントクラス
- No custom CSS

## Popup Sizing

- Popup width: `w-[360px]` or `w-[400px]` (fixed, avoids layout shift)
- Popup min-height: `min-h-[300px]`
- Popup max-height: Chrome limits popup to 600px height
- Scrollable content: `overflow-y-auto` inside popup container

## Component Model

| Type | Method | Location |
|------|--------|----------|
| Page root | React component | `src/popup/Popup.tsx` etc. |
| Shared UI parts | React components | `src/components/` |
| State management | React state / hooks | `src/hooks/` |
| Chrome API wrappers | Custom hooks | `src/hooks/useStorage.ts` etc. |

## React Patterns

- **Functional components** only — no class components
- **Custom hooks** for Chrome API access (`useStorage`, `useTabs`, `useRuntime`)
- Avoid side effects directly in render — use `useEffect`

## State Management

- **Local state**: `useState`, `useReducer` for UI state
- **Persistent state**: `chrome.storage.local` / `.sync` (via custom hook)
- **Cross-context state**: Message passing → background service worker

## Error Display

- Validation errors shown below each field
- Chrome API errors caught and shown as inline error text
- No console.log in production — use proper error boundaries

## Accessibility

- All interactive elements have `aria-label` or visible text
- Tab navigation works within popup
- Keyboard shortcuts documented in UI where applicable

## Theming

- Support `prefers-color-scheme` via daisyUI theme (`data-theme="dark"`)
- Store user theme preference in `chrome.storage.sync`
