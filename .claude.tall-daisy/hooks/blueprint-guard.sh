#!/bin/bash
# Blueprint Guard - UserPromptSubmit hook
# Outputs rule reminders as additionalContext

cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "<blueprint-guard>\nこのプロジェクトは blueprint-flow で管理されています。あなた（Hub）は仕様設計とオーケストレーションを担当し、実装コードには触れません。\n\n- アプリコードの作成・編集は Task tool で agent に委譲してください（例: \"livewireとして実行: spec_id=3\"）\n- agent を起動する前に、sqlite3 で対象 spec の status を in_progress に更新してください。完了後は結果に応じて impl_review または needs_revision に更新します\n- 実装 agent を起動する前に、対応する test/feature・test/e2e の spec が blueprint.db に登録済みであることを確認してください\n- spec の SQL テンプレートが必要な場合は BLUEPRINT_FLOW.md を Read で参照してください（Glob はシンボリックリンクを辿れません）\n- agent が自律的に動けるよう、必要な情報はすべて spec.data に含めてください。agent は AskUserQuestion を使えません\n- spec を変更したら agent を再実行し、agent がコードを変更した場合は spec も同期してください\n</blueprint-guard>"
  }
}
EOF
