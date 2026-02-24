# Chrome Extension Stack
> Tech stack and version definitions

## Technologies

| Technology | Version | Purpose |
|-----------|---------|---------|
| TypeScript | 5+ | Language |
| React | 18 | UI framework |
| Vite | 5+ | Build tool |
| @crxjs/vite-plugin | 2+ | MV3 HMR + manifest bundling |
| Tailwind CSS | 3 | Utility-first CSS |
| daisyUI | 4 | セマンティックカラー + テーマ機能のみ（コンポーネントクラス使用禁止） |
| Chrome Extension | MV3 | Extension platform |
| Vitest | 1+ | Unit / component test framework |
| @testing-library/react | - | Component testing |
| Playwright | - | E2E testing (extension mode) |

## Package Managers

- JS: npm (or pnpm)

## Chrome Extension Entry Points

| Entry | File | Purpose |
|-------|------|---------|
| Popup | `src/popup/index.html` | Toolbar icon click UI |
| Options | `src/options/index.html` | Extension settings page |
| Side Panel | `src/sidepanel/index.html` | Side panel UI (if used) |
| Content Script | `src/content/index.ts` | Injected into web pages |
| Background | `src/background/index.ts` | Service worker (MV3) |
