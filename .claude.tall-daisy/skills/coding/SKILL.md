# Coding Skill

実装指示と適切な Agent の選択・起動

## 引数なしの場合

1. 実装可能なspecを確認
```bash
./blueprint/db-cli.sh available-with-deps
```

2. specがある場合、AskUserQuestion で選択を促す
3. specがない場合、「approvedのspecがありません」と通知
4. 選択されたspecに応じてAgentを起動:
   - category=ui → livewire-agent
   - category=action → action-agent

## 引数ありの場合

`$ARGUMENTS` を解釈して適切な Agent を起動

- UI系の実装 → livewire-agent
- バックエンド系の実装 → action-agent
- 両方必要な場合 → 順次起動（livewire → action）

## Agent 起動例

```
Task tool:
- subagent_type: "general-purpose"
- prompt: "livewire-agentとして実行: {実装指示}"
- description: "UI実装"
```

## 呼び出す Agent

- `livewire-agent` - UI実装（Livewire Component + Blade）
- `action-agent` - バックエンド実装（Actions, Jobs, Events, Commands）
