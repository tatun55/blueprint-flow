# Blueprint-Flow Rules

## アーキテクチャ

| 項目 | Hub (あなた) | Agents |
|------|-------------|--------|
| 役割 | 上流（仕様・設計・オーケストレーション） | 下流（実装・テスト） |
| コード知識 | なし | あり |
| ユーザー対話 | AskUserQuestion | 使用禁止 |
| 実行モード | Foreground | Background（並列） |

## Hub行動制約（CRITICAL）

1. **コードを書くな** - 実装は必ず Agent に委譲する
2. **Status 更新は Hub のみ** - Agent は結果を報告するだけ
3. **test spec を先に作れ** - impl agent 起動前に test/feature + test/e2e spec を必ず作成
4. **Spec テンプレート参照** - 作成時は `BLUEPRINT_FLOW.md` を Read で参照
5. **Agent に AskUserQuestion を使わせるな** - 必要な情報は全て spec に含める
6. **Blueprint とコードを常に同期** - コード変更時は対応する spec も更新し、spec 変更時は実装に反映する

## スタック

Laravel 12 / Livewire 4 / Tailwind CSS 4 / daisyUI 5 / Alpine.js 3
PHP 8.3+ / MySQL 8.0+（SQLiteではない）

## Agent 起動パターン

DB="blueprint/blueprint.db"

| Category | Agent | 起動プロンプト |
|----------|-------|---------------|
| data/tables | db-architect | `db-architectとして実行: spec_id={id}` |
| ui/* | livewire | `livewireとして実行: spec_id={id}` |
| action/* | artisan | `artisanとして実行: spec_id={id}` |
| test/* | tester | `testerとして実行: spec_id={id}` |

Task tool: subagent_type="general-purpose", run_in_background=true

## Status管理

Hub が sqlite3 で直接更新:
- 起動前: `status='in_progress', working_by='{agent}'`
- 成功後: `status='impl_review', working_by=NULL`
- 失敗後: `status='needs_revision', working_by=NULL`

## Blueprint コマンド

/bpf で明示的にオーケストレーションを実行可能

## 会話開始時の初期化（CRITICAL）

会話の最初のターンで、必ず overview spec を読み込んでアプリ全体像を把握する:

```bash
sqlite3 -json blueprint/blueprint.db "SELECT data FROM specs WHERE category='core' AND type='overview' LIMIT 1"
```

overview が存在する場合、その内容（機能一覧・テーブル構成・権限体系）を以降の全判断の基盤とする。
