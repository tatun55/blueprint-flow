# Test Skill

テスト実行（E2E + Unit/Feature）

## 引数なしの場合

1. テスト状況を確認
```bash
./tests/e2e/db-cli.sh overview
./tests/e2e/db-cli.sh attention
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
./tests/e2e/db-cli.sh overview
./tests/e2e/db-cli.sh attention
./tests/e2e/db-cli.sh pending-review
./tests/e2e/db-cli.sh spec-summary

# Unit/Feature
php artisan test
php artisan test --filter=<name>
```

## 呼び出す Agent

`test-agent` - E2Eテスト設計・実行専門
