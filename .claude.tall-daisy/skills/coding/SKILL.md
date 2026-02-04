# Coding Skill

実装指示と適切な Agent の選択・起動

## 引数なしの場合

1. 実装可能なspecを確認
```bash
./scripts/blueprint-db-cli.sh available-with-deps
```

2. specがある場合、AskUserQuestion で選択を促す
3. specがない場合、「approvedのspecがありません」と通知
4. 選択されたspecに応じてAgentを起動:
   - category=data → db-agent
   - category=ui → livewire-agent
   - category=action → action-agent

## 引数ありの場合

`$ARGUMENTS` を解釈して適切な Agent を起動

- DB/テーブル系 → db-agent
- UI系の実装 → livewire-agent
- バックエンド系の実装 → action-agent

## 実装順序（CRITICAL）

依存関係に基づいて実装順序を守る:

```
1. data/tables → db-agent (Migration, Model, Seeder)
2. action/* → action-agent (Actions, Jobs, Commands)
3. ui/pages → livewire-agent (Livewire, Blade)
```

**UI実装前にDB実装が完了していること**を確認する。

## Agent 起動例

```
Task tool:
- subagent_type: "general-purpose"
- prompt: "db-agentとして実行: {実装指示}"
- description: "DB実装"
```

## 呼び出す Agent

- `db-agent` - DB実装（Migration, Model, Seeder）
- `livewire-agent` - UI実装（Livewire Component + Blade）
- `action-agent` - バックエンド実装（Actions, Jobs, Events, Commands）
