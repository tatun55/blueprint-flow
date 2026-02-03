# E2E Skill

E2Eテストの設計・コード作成・実行・結果管理

---

## 開発環境の前提

<dev-environment>
  <server>Laravel Valet（常にAPP_URLでホスティング済み）</server>
  <assets>Vite.js（npm run dev）</assets>
  <url>APP_URL（.env）を使用</url>
</dev-environment>

---

## ディレクトリ構成

```
tests/
├── e2e/
│   ├── specs/                 # Playwrightテストコード
│   │   └── {page-slug}.spec.ts
│   └── screenshots/           # スクリーンショット保存先
├── Feature/                   # Laravel Feature tests
└── Unit/                      # Laravel Unit tests
```

---

## E2Eテストフロー（CRITICAL）

<e2e-test-flow>
  <principle>
    手動操作ではなく、再現可能なテストコードを作成する。
    テストコードなしでE2Eテスト完了としてはならない。
  </principle>

  <step name="1-setup">
    <action>環境セットアップ</action>
    <commands>
      <command>APP_URL=$(grep APP_URL .env | cut -d '=' -f2)</command>
      <command>lsof -i :5173 > /dev/null 2>&1 || (npm run dev &; sleep 3)</command>
    </commands>
  </step>

  <step name="2-design">
    <action>テストシナリオ設計</action>
    <source>ui/pages spec の operations を参照</source>
    <output>テストケース一覧（slug, 目的, 成功条件）</output>
  </step>

  <step name="3-code">
    <action>テストコード作成</action>
    <output>tests/e2e/specs/{page-slug}.spec.ts</output>
    <rules>
      <rule>1ページ = 1ファイル</rule>
      <rule>operationsごとにtestケース作成</rule>
      <rule>expectで自動アサーション</rule>
    </rules>
  </step>

  <step name="4-register">
    <action>e2e.db にシナリオ登録</action>
    <command>./scripts/e2e-db-cli.sh add {slug} {name} {url} desktop {spec_id} {level}</command>
  </step>

  <step name="5-execute">
    <action>テスト実行</action>
    <command>npx playwright test tests/e2e/specs/{page-slug}.spec.ts</command>
  </step>

  <step name="6-record">
    <action>結果をe2e.dbに記録</action>
    <command>./scripts/e2e-db-cli.sh result {run_id} passed|failed [notes]</command>
  </step>
</e2e-test-flow>

---

## 引数なしの場合

1. 状況確認
```bash
./scripts/e2e-db-cli.sh overview
./scripts/e2e-db-cli.sh attention
```

2. AskUserQuestionで選択肢を提示:
   - 「新しいE2Eテストを作成」→ spec選択 → テストコード作成
   - 「既存テストを実行」→ `npx playwright test`
   - 「失敗テストを再実行」

## 引数ありの場合

`$ARGUMENTS` を解釈して適切なアクションを実行

---

## テストコードテンプレート

```typescript
// tests/e2e/specs/{page-slug}.spec.ts
import { test, expect } from '@playwright/test';

const BASE_URL = process.env.APP_URL || 'http://localhost:8000';

test.describe('{ページ名}', () => {

  test('{slug}: {テスト目的}', async ({ page }) => {
    await page.goto(BASE_URL + '{path}');

    // 表示確認
    await expect(page.locator('{selector}')).toBeVisible();

    // 操作
    await page.fill('{input-selector}', '{value}');
    await page.click('{button-selector}');

    // アサーション
    await expect(page.locator('{result-selector}')).toContainText('{expected}');
  });

});
```

### テストコード例（Todoアプリ）

```typescript
// tests/e2e/specs/todo-index.spec.ts
import { test, expect } from '@playwright/test';

const BASE_URL = process.env.APP_URL || 'http://localhost:8000';

test.describe('Todoメインページ', () => {

  test('todo-page-load: ページが正しく表示される', async ({ page }) => {
    await page.goto(BASE_URL);

    await expect(page.locator('h1')).toContainText('Todo');
    await expect(page.locator('input[type="text"]')).toBeVisible();
  });

  test('todo-add-task: タスクを追加できる', async ({ page }) => {
    await page.goto(BASE_URL);

    await page.fill('input[type="text"]', 'E2Eテストタスク');
    await page.click('button:has-text("追加")');

    // Livewire更新を待つ
    await page.waitForResponse(response =>
      response.url().includes('/livewire/update') && response.status() === 200
    );

    await expect(page.locator('text=E2Eテストタスク')).toBeVisible();
  });

  test('todo-complete-task: タスクを完了できる', async ({ page }) => {
    await page.goto(BASE_URL);

    // 完了操作
    await page.click('input[type="checkbox"]:first-of-type');

    // アサーション: 完了スタイルが適用される
    await expect(page.locator('li:first-of-type')).toHaveClass(/line-through|opacity/);
  });

  test('todo-delete-task: タスクを削除できる', async ({ page }) => {
    await page.goto(BASE_URL);

    // 確認ダイアログを自動承認
    page.on('dialog', dialog => dialog.accept());

    const initialCount = await page.locator('li').count();

    // 削除操作
    await page.click('button.btn-ghost:first-of-type');

    // アサーション: タスク数が減る
    await expect(page.locator('li')).toHaveCount(initialCount - 1);
  });

});
```

### セレクタ優先順位

1. `data-testid` 属性（推奨）
2. テキスト内容: `text=Submit`
3. Role: `role=button[name="Submit"]`
4. CSS: `.btn-primary`

### ダイアログ処理

```typescript
page.on('dialog', dialog => dialog.accept());
```

### Livewire待機

```typescript
await page.waitForResponse(response =>
  response.url().includes('/livewire/update') && response.status() === 200
);
```

---

## CLIコマンド

```bash
# シナリオ管理
./scripts/e2e-db-cli.sh add <slug> <name> <url> [viewport] [spec_id] [level]
./scripts/e2e-db-cli.sh overview
./scripts/e2e-db-cli.sh attention

# 実行・結果
./scripts/e2e-db-cli.sh run <slug>           # run_id取得
./scripts/e2e-db-cli.sh result <run_id> <passed|failed> [notes]
./scripts/e2e-db-cli.sh screenshot <run_id> <type> <path>
./scripts/e2e-db-cli.sh reviewed <run_id>

# Playwright実行
npx playwright test                          # 全テスト
npx playwright test tests/e2e/specs/{file}   # 特定ファイル
npx playwright test --headed                 # ブラウザ表示
npx playwright test --ui                     # UIモード
```

---

## e2e.db の役割

| 役割 | 内容 |
|------|------|
| シナリオ定義 | テストの目的・成功条件を記録 |
| 実行履歴 | いつ、どの結果だったかを記録 |
| レビュー管理 | 人間が確認したかどうかのフラグ |
| スクリーンショット管理 | baseline画像との紐付け |

---

## 連携フロー図

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│  e2e.db         │────▶│ Playwright       │────▶│ 結果        │
│  (シナリオ定義)  │     │ テストコード実行  │     │ 自動記録    │
└─────────────────┘     └──────────────────┘     └─────────────┘
                               │
                               ▼
                        失敗時は自動で
                        スクリーンショット保存
```

---

## Playwright MCP（手動確認用）

テストコード作成前のレイアウト確認には `playwright-mcp` を使用可能。

```javascript
mcp__playwright-mcp__playwright_navigate({ url: "{APP_URL}", headless: true })
mcp__playwright-mcp__playwright_screenshot({ name: "preview", savePng: true })
mcp__playwright-mcp__playwright_close()
```

---

## 呼び出す Agent

`test-agent` - E2Eテスト設計・コード作成・実行専門
