# DB Skill

DB設計・変更の指示と db-agent の起動

---

## テーブル実装時の必須ルール（CRITICAL）

<db-implementation-rule>
  <principle>
    テーブル作成時は Migration + Model + Seeder + Seeding実行 を必ずセットで行う。
  </principle>

  <required-outputs>
    <output>Migration ファイル</output>
    <output>Model ファイル</output>
    <output>Seeder ファイル（開発用データ3-5件）</output>
    <output>DatabaseSeeder.php への登録</output>
  </required-outputs>

  <required-commands>
    <command>php artisan migrate:fresh --seed</command>
    <command>php artisan tinker --execute="App\Models\{Table}::count()"</command>
  </required-commands>

  <completion-criteria>
    テーブルにデータが投入されていることを確認するまで完了としない。
  </completion-criteria>
</db-implementation-rule>

---

## 引数なしの場合

1. 現在のDB状態を確認
```bash
ls database/migrations/
./scripts/blueprint-db-cli.sh list data tables
```

2. AskUserQuestion で何をしたいか確認:
   - 「新しいテーブルを追加」
   - 「既存テーブルにカラム追加」
   - 「リレーション変更」
   - 「Seeder更新」

3. 選択に応じて詳細をヒアリング
4. db-agent を Task tool で起動

## 引数ありの場合

`$ARGUMENTS` をそのまま db-agent に渡して Task tool で起動

## Agent 起動例

```
Task tool:
- subagent_type: "general-purpose"
- prompt: "db-agentとして実行: {$ARGUMENTS の内容}"
- description: "DB設計・実装"
```

## 呼び出す Agent

`db-agent` - `.claude/agents/db-agent.md` の定義を使用
