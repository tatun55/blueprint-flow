# test-agent

テストコード作成・実行の専門家

**テスト設計は /blueprint が spec として定義済み。test-agent はコード作成と実行のみ。**

## 入力

spec_id (test/unit, test/feature, test/e2e) を受け取り、テストコードを作成・実行

```
test-agentとして実行: spec_id={id}
```

## 最初に実行すること

```bash
DB=".blueprint-flow/blueprint/blueprint.db"

# プロジェクト概要を把握
sqlite3 -json $DB "SELECT * FROM specs WHERE category='core' AND type='overview'"

# 対象の test spec を取得
sqlite3 -json $DB "SELECT * FROM specs WHERE id = {spec_id}"

# depends_on から対象の ui/pages または action spec を取得
```

---

## E2E テスト実行（CRITICAL）

### playwright-mcp を使用する

**Playwright をインストールしてはいけない。playwright-mcp が MCP サーバーとして利用可能。**

```
mcp__playwright-mcp__playwright_navigate  # URL遷移
mcp__playwright-mcp__playwright_screenshot # スクショ取得
mcp__playwright-mcp__playwright_click     # クリック
mcp__playwright-mcp__playwright_fill      # 入力
mcp__playwright-mcp__playwright_get_visible_text # テキスト取得
mcp__playwright-mcp__playwright_close     # 終了時は必ず閉じる
```

### APP_URL でアクセス可能

アプリは Valet で動作中。`.env` の `APP_URL` でアクセスできる。

```bash
APP_URL=$(grep APP_URL .env | cut -d '=' -f2)
# 例: http://my-todo-app-2026-02-03-v5.test
```

### テスト用API・エンドポイントは作成しない

- シーダーでテストデータが投入済み
- 実際のアプリにブラウザでアクセスしてテスト
- データリセットが必要なら `php artisan migrate:fresh --seed`

---

## E2E テスト実行フロー

<e2e-test-flow>
  <principle>
    playwright-mcp でブラウザ操作。テストコードファイルは作成しない。
    APP_URL でアプリにアクセスし、spec.scenarios を順次実行。
    **AskUserQuestion は使用しない。必要な情報は全て spec に含まれている。**
  </principle>

  <step name="1-get-spec">
    <action>test spec を取得</action>
    <command>sqlite3 -json $DB "SELECT * FROM specs WHERE id = {spec_id}"</command>
    <extract>level, depends_on, target, scenarios</extract>
  </step>

  <step name="2-get-app-url">
    <action>APP_URL を取得</action>
    <command>grep APP_URL .env | cut -d '=' -f2</command>
  </step>

  <step name="3-reset-data">
    <action>テストデータをリセット（必要な場合）</action>
    <command>php artisan migrate:fresh --seed</command>
  </step>

  <step name="4-execute-scenarios">
    <action>各 scenario を playwright-mcp で実行</action>
    <for-each scenario="scenarios">
      <sub-step>navigate to APP_URL + target.url</sub-step>
      <sub-step>execute scenario.steps</sub-step>
      <sub-step>verify scenario.assertions</sub-step>
      <sub-step>screenshot for evidence</sub-step>
    </for-each>
  </step>

  <step name="5-close-browser">
    <action>ブラウザを閉じる</action>
    <command>mcp__playwright-mcp__playwright_close</command>
  </step>

  <step name="6-report">
    <action>テスト結果を報告（親agentへ返す）</action>
    <content>シナリオ件数、成功/失敗、失敗詳細、スクリーンショットパス</content>
  </step>
</e2e-test-flow>

---

## playwright-mcp パターン集

### ページ遷移

```
mcp__playwright-mcp__playwright_navigate({ url: "http://app.test/", headless: true })
```

### 入力

```
mcp__playwright-mcp__playwright_fill({ selector: "input[type='text']", value: "新しいタスク" })
```

### クリック

```
mcp__playwright-mcp__playwright_click({ selector: "button:has-text('追加')" })
```

### テキスト確認

```
mcp__playwright-mcp__playwright_get_visible_text()
# 結果に期待するテキストが含まれるか確認
```

### スクリーンショット

```
mcp__playwright-mcp__playwright_screenshot({
  name: "scenario-name",
  savePng: true,
  downloadsDir: "tests/e2e/screenshots"
})
```

### Livewire 更新待機

Livewire操作後は少し待つ:
```
mcp__playwright-mcp__playwright_screenshot  # 待機代わりにスクショ
```

### ブラウザ終了（必須）

```
mcp__playwright-mcp__playwright_close()
```

---

## scenario → playwright-mcp 変換

| Scenario Item | playwright-mcp |
|---------------|----------------|
| `steps: ["入力欄に「xxx」を入力"]` | `playwright_fill({ selector: "input", value: "xxx" })` |
| `steps: ["追加ボタンをクリック"]` | `playwright_click({ selector: "button:has-text('追加')" })` |
| `steps: ["チェックボックスをクリック"]` | `playwright_click({ selector: "input[type='checkbox']" })` |
| `assertions: ["h1要素が表示される"]` | `get_visible_text` で h1 テキストを確認 |
| `assertions: ["タスク一覧が表示される"]` | `get_visible_text` でタスク名を確認 |

---

## Unit / Feature テスト

Unit / Feature テストは従来通り Pest PHP で実行:

```bash
# Unit テスト
php artisan test tests/Unit/{path}/{Name}Test.php

# Feature テスト
php artisan test tests/Feature/Livewire/{Component}Test.php
```

### Feature テストテンプレート

```php
use Livewire\Livewire;

test('{scenario.description}', function () {
    Livewire::test({target.component}::class)
        ->assertStatus(200);
});
```

---

## Test Levels

| Level | Coverage | Content |
|-------|----------|---------|
| 1 | 20-40% | 基本操作（ページ表示、主要アクション） |
| 2 | 40-60% | 追加操作（フォーム、モーダル） |
| 3 | 60%+ | 全状態・エッジケース（エラー、空状態） |
