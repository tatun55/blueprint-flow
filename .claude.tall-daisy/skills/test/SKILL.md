# Test Skill

テスト実行（E2E + Unit/Feature）

## 引数なしの場合

1. テスト状況を確認
```bash
./scripts/e2e-db-cli.sh overview
./scripts/e2e-db-cli.sh attention
```

2. 分析してAskUserQuestionで推奨を提示:
   - 「未実行のE2Eテストが N件あります。実行しますか？」
   - 「失敗したテストが N件あります。再実行しますか？」
   - 「Unit/Featureテストを実行しますか？」

3. 選択に応じて実行:
   - E2E → test-agent を起動
   - Unit → `php artisan test` を実行

## 引数ありの場合

`$ARGUMENTS` を柔軟に解釈して適切なテストを実行

## CLIコマンド

```bash
# E2E
./scripts/e2e-db-cli.sh overview
./scripts/e2e-db-cli.sh attention
./scripts/e2e-db-cli.sh pending-review
./scripts/e2e-db-cli.sh spec-summary

# Unit/Feature
php artisan test
php artisan test --filter=<name>
```

---

## Playwright MCP でスクリーンショット

レイアウト確認やE2Eテストには `playwright-mcp` を使用する。

### 基本手順

```
1. playwright_navigate で URL に遷移 (headless: true)
2. playwright_screenshot でスクショ取得
3. playwright_close で終了（必須）
```

### デフォルト設定

- `headless: true` (Chrome)
- `savePng: true`
- `downloadsDir`: プロジェクトルート

### 使用例

```javascript
// 1. ページに遷移
mcp__playwright-mcp__playwright_navigate({
  url: "http://localhost:8000",
  headless: true
})

// 2. スクリーンショット取得
mcp__playwright-mcp__playwright_screenshot({
  name: "todo-index-initial",
  savePng: true,
  fullPage: true
})

// 3. 操作を実行（例: タスク追加）
mcp__playwright-mcp__playwright_fill({
  selector: "input[wire\\:model='newTaskTitle']",
  value: "テストタスク"
})
mcp__playwright-mcp__playwright_click({
  selector: "button[wire\\:click='addTask']"
})

// 4. 操作後のスクリーンショット
mcp__playwright-mcp__playwright_screenshot({
  name: "todo-index-after-add",
  savePng: true
})

// 5. 終了（必須）
mcp__playwright-mcp__playwright_close()
```

### スクリーンショット命名規則

```
{page-slug}_{state}.png

例:
- todo-index_initial.png
- todo-index_after-add.png
- todo-index_completed.png
- task-modal_open.png
```

### ビューポートサイズ

```javascript
// デスクトップ（デフォルト）
{ width: 1280, height: 720 }

// モバイル
mcp__playwright-mcp__playwright_resize({
  device: "iPhone 13"
})
```

---

## 呼び出す Agent

`test-agent` - E2Eテスト設計・実行専門
