# Blueprint Flow 仕様書

フレームワーク理解・アップグレード用。開発時は `.claude/skills/` と `.claude/agents/` を参照。

---

## 1. 設計思想

### 1.1 解決する問題

| 問題 | 従来のアプローチ | Blueprint Flow |
|------|------------------|----------------|
| コンテキスト肥大化 | 全情報を1セッションに | 3層分離で最小化 |
| 品質のばらつき | LLM任せ | 人間レビュー必須 |
| 再現性の欠如 | 暗黙知に依存 | Spec→Task→Code の明示的フロー |
| 並列化困難 | 依存関係が不明確 | Wave による並列実行 |

### 1.2 設計原則

```
1. Context Isolation (コンテキスト分離)
   - 各レイヤーは必要最小限の情報のみ保持
   - 専門知識は Instructor に集約、Coder には伝播しない

2. Human-in-the-Loop (人間介在)
   - 全フェーズ遷移に人間レビュー
   - 自動承認なし、明示的な AskUserQuestion

3. Single Source of Truth (単一情報源)
   - Spec: 何を作るか
   - Task: どう作るか
   - Code: 実装結果

4. Idempotency (冪等性)
   - 同じ Spec から同じ Task が生成される
   - Task からは同じ Code が生成される

5. Explicit State (明示的状態)
   - 全状態は DB に永続化
   - ロック機構で競合防止
```

### 1.3 なぜ 3 層か

```
2層の場合 (Hub + Coder):
┌─────────────────────────────────────────────────┐
│ Hub                                             │
│ ┌─────────────────────────────────────────────┐ │
│ │ routing rules + domain knowledge + patterns │ │
│ │ + all stack-specific details                │ │
│ └─────────────────────────────────────────────┘ │
│ Context: ~50-70k tokens                         │
└─────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────┐
│ Coder                                           │
│ Context: ~2k tokens (task only)                 │
└─────────────────────────────────────────────────┘

問題:
- Hub のコンテキストが肥大化
- ドメイン知識の更新が困難
- 並列実行時に全コンテキストをロード
```

```
3層の場合:
┌─────────────────────────────┐
│ Hub                         │
│ routing + flow management   │
│ Context: ~2k tokens         │
└─────────────────────────────┘
         ↓ (spec)
┌─────────────────────────────┐
│ Instructor                  │
│ domain knowledge + patterns │
│ Context: ~3k tokens         │
└─────────────────────────────┘
         ↓ (task)
┌─────────────────────────────┐
│ Coder                       │
│ task execution only         │
│ Context: ~2k tokens         │
└─────────────────────────────┘

利点:
- 各層のコンテキストが小さい
- ドメイン知識は Instructor のみ更新
- 並列実行時も軽量
- 責務が明確
```

---

## 2. コアコンセプト

### 2.1 Spec (仕様)

**定義**: 何を作るかの宣言的記述

```
Spec = {
  id: int,
  category: 'core' | 'data' | 'ui' | 'action',
  type: string,  // category ごとに異なる
  slug: string,  // 一意識別子
  name: string,  // 人間可読名
  data: JSON,    // 詳細仕様
  status: Status,
  wave: int,     // 並列実行グループ
  e2e_status: 'pending' | 'passed' | 'failed' | null,
  e2e_level: 1 | 2 | 3
}
```

**カテゴリと型の対応**:

| Category | Types | 説明 |
|----------|-------|------|
| `core` | overview, const | プロジェクト全体定義 |
| `data` | tables, seeders | データ層 |
| `ui` | pages, partials, layouts | UI層 |
| `action` | sync, async, scheduled | ビジネスロジック |

### 2.2 Task (タスク)

**定義**: どう作るかの命令的記述

```
Task = {
  id: int,
  spec_id: int,           // 元の Spec
  instructor_type: string, // 生成した Instructor
  content: string,         // Markdown 形式の詳細指示
  status: 'pending' | 'completed' | 'failed'
}
```

**Task Content 構造**:

```markdown
# Task: {spec_id}_{slug}

## Meta
- type: {task_type}
- spec_id: {id}
- priority: {1-5}

## Output Files
- `path/to/file1.php`
- `path/to/file2.blade.php`

## Instructions

### File: path/to/file1.php

<template>
{具体的なコードテンプレート}
</template>

<rules>
- ルール1
- ルール2
</rules>

## Validation
- [ ] チェック項目1
- [ ] チェック項目2
```

### 2.3 Status (状態)

<state_machine name="spec_status">
  <state name="draft" type="initial">
    <description>作成中</description>
    <transition to="pending_review" trigger="human_submits"/>
  </state>

  <state name="pending_review">
    <description>人間レビュー待ち</description>
    <transition to="approved" trigger="human_approves"/>
    <transition to="needs_revision" trigger="human_requests_changes"/>
  </state>

  <state name="approved">
    <description>承認済み、実装待ち</description>
    <transition to="in_progress" trigger="hub_locks"/>
  </state>

  <state name="in_progress">
    <description>実装中（ロック）</description>
    <transition to="impl_review" trigger="coder_completes"/>
    <transition to="blocked" trigger="coder_blocked"/>
  </state>

  <state name="impl_review">
    <description>実装レビュー待ち</description>
    <transition to="testing" trigger="human_approves"/>
    <transition to="needs_revision" trigger="human_requests_changes"/>
  </state>

  <state name="testing">
    <description>E2Eテスト中</description>
    <transition to="done" trigger="tests_pass"/>
    <transition to="needs_revision" trigger="tests_fail"/>
  </state>

  <state name="needs_revision" type="recovery">
    <description>修正必要</description>
    <transition to="pending_review" trigger="spec_updated"/>
  </state>

  <state name="blocked" type="recovery">
    <description>依存関係待ち</description>
    <transition to="approved" trigger="dependency_resolved"/>
  </state>

  <state name="done" type="terminal">
    <description>完了</description>
  </state>
</state_machine>

**状態定義**:

| Status | 意味 | 遷移元 | 遷移先 |
|--------|------|--------|--------|
| `draft` | 作成中 | (新規) | pending_review |
| `pending_review` | 人間レビュー待ち | draft, needs_revision | approved, needs_revision |
| `approved` | 承認済み、実装待ち | pending_review | in_progress |
| `in_progress` | 実装中（ロック） | approved | impl_review |
| `impl_review` | 実装レビュー待ち | in_progress | testing, needs_revision |
| `testing` | E2Eテスト中 | impl_review | done, needs_revision |
| `needs_revision` | 修正必要 | pending_review, impl_review, testing | pending_review |
| `done` | 完了 | testing | (終端) |

---

## 3. データフロー

### 3.1 Spec 作成フロー

<workflow name="spec_creation">
  <participants>
    <participant id="human">Human</participant>
    <participant id="blueprint">Blueprint Skill</participant>
    <participant id="db">Database</participant>
  </participants>

  <step id="invoke">
    <from>human</from>
    <to>blueprint</to>
    <action>/blueprint</action>
  </step>

  <step id="select_type">
    <from>blueprint</from>
    <to>human</to>
    <action>AskUserQuestion: type selection</action>
  </step>

  <step id="type_response">
    <from>human</from>
    <to>blueprint</to>
    <action>"Database Table"</action>
  </step>

  <step id="gather_details">
    <from>blueprint</from>
    <to>human</to>
    <action>AskUserQuestion: columns, relations</action>
  </step>

  <step id="details_response">
    <from>human</from>
    <to>blueprint</to>
    <action>{columns: [...]}</action>
  </step>

  <step id="save_spec">
    <from>blueprint</from>
    <to>db</to>
    <action>blueprint-db-cli.sh add</action>
    <output>{id: 1}</output>
  </step>

  <step id="confirm">
    <from>blueprint</from>
    <to>human</to>
    <action>AskUserQuestion: "Spec created. Submit for review?"</action>
  </step>
</workflow>

### 3.2 実装フロー

<workflow name="implementation">
  <participants>
    <participant id="human">Human</participant>
    <participant id="hub">Hub</participant>
    <participant id="instructor">Instructor</participant>
    <participant id="coder">Coder</participant>
    <participant id="db">Database</participant>
  </participants>

  <step id="invoke">
    <from>human</from>
    <to>hub</to>
    <action>/hub</action>
  </step>

  <step id="get_available">
    <from>hub</from>
    <to>db</to>
    <action>available-with-deps</action>
    <output>[{id:1, cat:'data', type:'tables'}]</output>
  </step>

  <step id="lock_spec">
    <from>hub</from>
    <to>db</to>
    <action>lock(1, db-instructor)</action>
  </step>

  <step id="dispatch_instructor">
    <from>hub</from>
    <to>instructor</to>
    <action>Task(db-instructor)</action>
  </step>

  <step id="instructor_process">
    <agent>instructor</agent>
    <actions>
      <action>Read spec data (patterns embedded)</action>
      <action>Generate task content</action>
    </actions>
  </step>

  <step id="save_task">
    <from>instructor</from>
    <to>db</to>
    <action>task-add</action>
    <output>task_id: 1</output>
  </step>

  <step id="dispatch_coder">
    <from>hub</from>
    <to>coder</to>
    <action>Task(db-coder)</action>
  </step>

  <step id="coder_process">
    <agent>coder</agent>
    <actions>
      <action>task-get(task_id)</action>
      <action>Create worktree</action>
      <action>Write files</action>
      <action>Commit and push</action>
      <action>Create draft PR</action>
      <action>task-status completed</action>
    </actions>
    <output>{status: complete, pr_url: "...", files: [...]}</output>
  </step>

  <step id="update_status">
    <from>hub</from>
    <to>db</to>
    <action>status(1, impl_review)</action>
  </step>

  <step id="request_review">
    <from>hub</from>
    <to>human</to>
    <action>AskUserQuestion: "Implementation complete. Review PR?"</action>
  </step>
</workflow>

### 3.3 E2E テストフロー

<workflow name="e2e_testing">
  <participants>
    <participant id="human">Human</participant>
    <participant id="hub">Hub</participant>
    <participant id="test_instructor">Test Instructor</participant>
    <participant id="test_coder">Test Coder</participant>
    <participant id="e2e_db">e2e.db</participant>
  </participants>

  <step id="invoke">
    <from>human</from>
    <to>hub</to>
    <action>/hub (e2e)</action>
  </step>

  <step id="get_pending">
    <from>hub</from>
    <to>e2e_db</to>
    <action>e2e-pending</action>
    <output>[{id:1, slug:'user_list', e2e_level:1}]</output>
  </step>

  <step id="dispatch_instructor">
    <from>hub</from>
    <to>test_instructor</to>
    <action>Task(test-instructor)</action>
  </step>

  <step id="instructor_process">
    <agent>test_instructor</agent>
    <actions>
      <action>Generate test cases for level 1</action>
      <action>task-add (test)</action>
    </actions>
  </step>

  <step id="dispatch_coder">
    <from>hub</from>
    <to>test_coder</to>
    <action>Task(test-coder)</action>
  </step>

  <step id="coder_process">
    <agent>test_coder</agent>
    <actions>
      <action>add test case to e2e.db</action>
      <action>run (get run_id)</action>
      <action>playwright navigate</action>
      <action>playwright screenshot</action>
      <action>record screenshot</action>
      <action>result passed/failed</action>
    </actions>
    <output>{passed: 3, failed: 0}</output>
  </step>

  <step id="request_review">
    <from>hub</from>
    <to>human</to>
    <action>AskUserQuestion: "E2E tests passed. Review screenshots?"</action>
  </step>
</workflow>

---

## 4. データベーススキーマ

### 4.1 blueprint.db

#### specs テーブル

| Column | Type | Constraints | 説明 |
|--------|------|-------------|------|
| id | INTEGER | PK, AUTO | 一意識別子 |
| category | TEXT | NOT NULL, CHECK | core/data/ui/action |
| type | TEXT | NOT NULL, CHECK | カテゴリ別の型 |
| slug | TEXT | NOT NULL | 識別用スラッグ |
| name | TEXT | NOT NULL | 表示名 |
| data | TEXT | JSON | 詳細仕様 |
| status | TEXT | CHECK | 状態 (8種) |
| working_by | TEXT | NULL | ロック中のワーカー |
| wave | INTEGER | DEFAULT 1 | 並列実行グループ |
| human_reviewed | INTEGER | DEFAULT 0 | レビュー済みフラグ |
| revision_count | INTEGER | DEFAULT 0 | 修正回数 |
| revision_reason | TEXT | NULL | 修正理由 |
| e2e_status | TEXT | NULL, CHECK | pending/passed/failed |
| e2e_level | INTEGER | DEFAULT 1, CHECK 1-3 | E2Eレベル |
| created_at | DATETIME | DEFAULT NOW | 作成日時 |
| updated_at | DATETIME | DEFAULT NOW | 更新日時 |

**インデックス**:
- `idx_specs_status`: 状態別クエリ高速化
- `idx_specs_category_type`: カテゴリ・型別クエリ
- `idx_specs_wave`: Wave 別並列取得
- UNIQUE(`category`, `type`, `slug`): 重複防止

#### tasks テーブル

| Column | Type | Constraints | 説明 |
|--------|------|-------------|------|
| id | INTEGER | PK, AUTO | 一意識別子 |
| spec_id | INTEGER | FK, NOT NULL | 元の Spec |
| instructor_type | TEXT | NOT NULL, CHECK | db/frontend/backend/test |
| content | TEXT | NOT NULL | Markdown 形式の指示 |
| status | TEXT | CHECK | pending/completed/failed |
| created_at | DATETIME | DEFAULT NOW | 作成日時 |

**インデックス**:
- FK index on `spec_id`

### 4.2 e2e.db

#### test_cases テーブル

| Column | Type | Constraints | 説明 |
|--------|------|-------------|------|
| id | INTEGER | PK, AUTO | 一意識別子 |
| slug | TEXT | UNIQUE, NOT NULL | 識別用スラッグ |
| name | TEXT | NOT NULL | 表示名 |
| description | TEXT | NULL | 説明 |
| spec_id | INTEGER | NULL | 関連 Spec (blueprint.db) |
| level | INTEGER | DEFAULT 1, CHECK 1-3 | E2E レベル |
| url | TEXT | NOT NULL | テスト対象 URL |
| viewport_width | INTEGER | DEFAULT 1280 | ビューポート幅 |
| viewport_height | INTEGER | DEFAULT 720 | ビューポート高さ |
| status | TEXT | CHECK | defined/active/disabled |
| created_at | DATETIME | DEFAULT NOW | 作成日時 |
| updated_at | DATETIME | DEFAULT NOW | 更新日時 |

#### test_runs テーブル

| Column | Type | Constraints | 説明 |
|--------|------|-------------|------|
| id | INTEGER | PK, AUTO | 一意識別子 |
| test_case_id | INTEGER | FK, NOT NULL | テストケース |
| run_at | DATETIME | DEFAULT NOW | 実行日時 |
| result | TEXT | CHECK | pending/passed/failed/error |
| screenshot_path | TEXT | NULL | スクリーンショットパス |
| baseline_path | TEXT | NULL | ベースラインパス |
| diff_percentage | REAL | NULL | 差分パーセント |
| human_reviewed | INTEGER | DEFAULT 0 | 人間レビュー済み |
| error_message | TEXT | NULL | エラーメッセージ |
| duration_ms | INTEGER | NULL | 実行時間 (ms) |
| executor | TEXT | DEFAULT 'claude' | 実行者 |
| notes | TEXT | NULL | メモ |

---

## 5. コンポーネント詳細

### 5.1 Hub (オーケストレーター)

**ファイル**: `.claude/skills/hub/SKILL.md`

**責務**:
- Spec のルーティング (Category → Instructor)
- フロー管理 (Status 遷移)
- 人間レビュー調整 (AskUserQuestion)
- E2E レベル進行提案

**しないこと**:
- 専門知識の適用
- Task 内容の生成
- コード生成

**ルーティングテーブル**:

| Category | Instructor |
|----------|------------|
| data | db-instructor |
| ui | frontend-instructor |
| action | backend-instructor |

**フロー制御**:

```
1. available specs を取得
2. 各 spec を適切な Instructor にルーティング
3. Instructor が task を生成
4. Coder に task を渡す
5. 完了後、impl_review に遷移
6. 人間レビューを依頼 (AskUserQuestion)
```

### 5.2 Instructors (ドメインエキスパート)

**ファイル**: `.claude/agents/instructors/*.md`

| Instructor | パターン (埋め込み済み) | 生成する Task |
|------------|------------------------|--------------|
| db | common + db patterns | migration, model, seeder |
| frontend | common + frontend patterns | component, view, route |
| backend | common + backend patterns | action, job, command, event |
| test | common + test patterns | e2e test cases |

**Task 生成プロセス**:

```
1. Spec を受け取る
2. Spec.data を解析 (パターンは定義に埋め込み済み)
3. Task content を生成
4. blueprint.db に task-add
```

**品質チェック**:
- 全出力ファイルパスが正しい
- テンプレートが完全
- ルールが明確
- バリデーション項目がある

### 5.3 Coders (実行者)

**ファイル**: `.claude/agents/coders/*.md`

**責務**:
- Task content のみを読む
- 指示通りにファイル生成
- バリデーション項目をチェック

**しないこと**:
- CLAUDE.md を読む
- 設計判断
- 指示にない機能追加
- ルール変更

**エラーハンドリング**:

```
指示が不明確な場合:
1. 推測しない
2. task を blocked にマーク
3. {status: "blocked", reason: "..."} を返す
```

---

## 6. 拡張ポイント

### 6.1 新しい Stack の追加

```bash
# 1. ディレクトリ作成
mkdir -p stacks/{stack_name}

# 2. 設定ファイル作成
cat > stacks/{stack_name}/config.env << 'EOF'
STACK_NAME="{stack_name}"
COMPONENT_PATH="..."
COMPONENT_NAMESPACE="..."
VIEW_PATH="..."
MODEL_PATH="..."
MODEL_NAMESPACE="..."
MIGRATION_PATH="..."
SEEDER_PATH="..."
SEEDER_NAMESPACE="..."
ACTION_PATH="..."
ACTION_NAMESPACE="..."
EVENT_PATH="..."
EVENT_NAMESPACE="..."
JOB_PATH="..."
JOB_NAMESPACE="..."
COMMAND_PATH="..."
COMMAND_NAMESPACE="..."
SCHEDULE_FILE="..."
TEST_PATH="..."
UI_FRAMEWORK="..."
JS_FRAMEWORK="..."
UI_LANGUAGE="ja"        # UI text language (ja, en, etc.)
COMMENT_LANGUAGE="ja"   # Code comment language (ja, en, etc.)
EOF

# 3. パターンファイル作成
# stacks/{stack_name}/common/base.md (共通パターン)
# stacks/{stack_name}/instructors/db.md
# stacks/{stack_name}/instructors/frontend.md
# stacks/{stack_name}/instructors/backend.md
# stacks/{stack_name}/instructors/test.md

# 4. テスト
./scripts/init.sh {stack_name} /tmp/test-project
```

### 6.2 新しい Instructor の追加

```markdown
# {domain}-instructor

## Domain
- 担当範囲1
- 担当範囲2

## Stack Patterns

<!-- COMMON_PATTERNS -->

<!-- INSTRUCTOR_PATTERNS -->

## Input
{Spec JSON 形式}

## Output
Task content saved to blueprint.db tasks table.

## Task Content Format
{Markdown テンプレート}

## Conversion Rules
{変換ルール表}

## Quality Checks
{品質チェックリスト}
```

### 6.3 新しい Coder の追加

```markdown
# {domain}-coder

## Role
Pure execution. No design decisions.

## Input
Read ONLY: task content from blueprint.db

## Output
{生成するファイルの種類}

## Execution Rules
1. Read task content
2. Create files as specified
3. Follow templates exactly
4. Apply rules
5. Check validation items

## Constraints
- Do NOT read context files
- Do NOT make design decisions
- Do NOT add unspecified features

## Error Handling
{エラー時の振る舞い}

## Completion
{完了時のレスポンス形式}
```

### 6.4 新しい Spec Category の追加

```sql
-- 1. specs テーブルの CHECK 制約を更新
-- schema.sql の category CHECK を拡張

-- 2. Spec Type を定義
-- schema.dbml に追加

-- 3. ルーティングを Hub に追加
-- .claude/skills/hub/SKILL.md の Routing Flow を更新

-- 4. Instructor と Coder を作成
```

---

## 7. 不変条件 (Invariants)

### 7.1 状態不変条件

```
INV-1: in_progress 状態の Spec は必ず working_by が設定されている
INV-2: working_by が設定されている Spec は in_progress 状態である
INV-3: done 状態の Spec は status 変更不可
INV-4: e2e_status が設定されるのは ui/pages と ui/layouts のみ
```

### 7.2 データ不変条件

```
INV-5: (category, type, slug) の組み合わせは一意
INV-6: Task は必ず有効な spec_id を持つ
INV-7: test_run は必ず有効な test_case_id を持つ
INV-8: wave 番号は 1 以上の整数
INV-9: e2e_level は 1, 2, 3 のいずれか
```

### 7.3 フロー不変条件

```
INV-10: Instructor は Task 生成後に必ず task-add を呼ぶ
INV-11: Coder は完了後に必ず task-status を更新する
INV-12: Hub は impl_review 前に必ず unlock する
INV-13: E2E テストは passed + human_reviewed で完了
```

---

## 8. エラーハンドリング

### 8.1 エラー分類

| エラー種別 | 発生箇所 | 処理 |
|-----------|----------|------|
| Spec 不正 | Blueprint Skill | 人間に修正依頼 |
| Task 生成失敗 | Instructor | spec を needs_revision に |
| 実行失敗 | Coder | task を failed に、spec を needs_revision に |
| E2E 失敗 | Test Coder | run を failed に、spec の e2e_status を failed に |

### 8.2 リカバリーフロー

```
Coder がブロックされた場合:
1. Coder が {status: "blocked", reason: "..."} を返す
2. Hub が task-status を failed に更新
3. Hub が spec を needs_revision に更新
4. Hub が AskUserQuestion で人間に通知
5. 人間が Spec または Task を修正
6. フローを再開
```

---

## 9. バージョン互換性

### 9.1 セマンティックバージョニング

```
MAJOR.MINOR.PATCH

MAJOR: 破壊的変更
  - DB スキーマ変更
  - SKILL/Agent ファイル形式変更
  - 状態遷移ルール変更

MINOR: 後方互換の機能追加
  - 新しい Category/Type
  - 新しい Instructor/Coder
  - 新しい CLI コマンド

PATCH: バグ修正
  - ドキュメント修正
  - 軽微な修正
```

### 9.2 マイグレーション

```bash
# スキーマ変更がある場合
# 1. 新スキーマを適用
sqlite3 blueprint.db < migration_v2.sql

# 2. データ移行
./scripts/migrate.sh v1 v2

# 3. 検証
./scripts/validate.sh
```

### 9.3 下位互換性

```
保証:
- CLI コマンドの引数順序
- Spec JSON の既存フィールド
- Status 遷移の既存パス

非保証:
- 内部実装詳細
- エラーメッセージの文言
- ログ出力形式
```

---

## 10. トラブルシューティング

### 10.1 よくある問題

| 症状 | 原因 | 解決 |
|------|------|------|
| 変数が展開されない | init.sh で export されていない | `set -a` で auto-export |
| ロックが解除されない | Hub がクラッシュ | 手動で `unlock` |
| E2E がタイムアウト | ブラウザが起動しない | Playwright を再インストール |
| Task が生成されない | Instructor がエラー | ログを確認、Instructor 定義をチェック |

### 10.2 デバッグコマンド

```bash
# 状態確認
./scripts/blueprint-db-cli.sh sql "SELECT * FROM specs WHERE status != 'done'"
./scripts/e2e-db-cli.sh sql "SELECT * FROM test_runs WHERE result = 'failed'"

# ロック解除
./scripts/blueprint-db-cli.sh unlock {id}

# 状態リセット
./scripts/blueprint-db-cli.sh status {id} approved

# 全リセット (危険)
./scripts/blueprint-db-cli.sh reset
./scripts/e2e-db-cli.sh reset
```

---

## 11. 変更履歴

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-01 | Initial release |

---

## 12. 参考リンク

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [SQLite Documentation](https://sqlite.org/docs.html)
- [Playwright MCP](https://github.com/anthropics/mcp-playwright)
