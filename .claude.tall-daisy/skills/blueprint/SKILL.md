# Blueprint Skill

仕様策定・プロジェクト状況把握・開発フロー提案

## サブコマンド

### `/blueprint pull`

blueprint-flowサブモジュールを最新版に更新する。

```bash
cd .blueprint-flow && git pull origin main && cd ..
./.blueprint-flow/scripts/update.sh
```

実行後、変更内容を報告。

### `/blueprint push`

blueprint-flowサブモジュールへの変更をリモートにpushする。

**手順:**

1. サブモジュール内の変更を確認
```bash
git -C .blueprint-flow status
```

2. 変更があればコミット（未コミットの場合）
```bash
git -C .blueprint-flow add -A
git -C .blueprint-flow commit -m "説明"
```

3. リモートにpush
```bash
git -C .blueprint-flow push origin main
```

4. 親リポジトリでサブモジュール参照を更新
```bash
git add .blueprint-flow
git commit -m "Update blueprint-flow submodule"
```

**注意**: pushする前にユーザーに変更内容を確認してもらう。

---

## 引数なしの場合

1. プロジェクト状況を確認
```bash
./scripts/blueprint-db-cli.sh overview
./scripts/blueprint-db-cli.sh progress
```

2. 状況を分析して推奨アクションを提示
   - spec が 0件 → 新規プロジェクト開始フローへ
   - draft が多い → 「仕様策定を続けますか？」
   - pending_review が多い → 「レビュー待ちが N件あります」
   - approved が多い → 「/db または /coding で実装を開始できます」
   - in_progress が多い → 「実装中のspecがN件あります」

## 引数ありの場合

`$ARGUMENTS` を解釈して仕様を策定・更新

1. 既存specの更新 or 新規作成を判定
2. 適切なcategory/typeを判定
3. 情報が足りない場合は**1回のAskUserQuestion**でまとめて取得
4. specを作成/更新

---

## 新規プロジェクト開始フロー

specが0件の場合、以下の手順で開始:

### ステップ1: プロジェクト情報を一括収集

AskUserQuestionで以下を**1回でまとめて**質問:

```
1. アプリの種類は？ (シンプル / 認証あり / チーム共有型)
2. 主要機能は？ (CRUD基本 / +カテゴリ機能 / +検索機能 / カスタム)
```

### ステップ2: overview spec を作成

収集した情報から overview spec を自動生成。

#### 必須項目

overviewには**必ず機能リスト（features）を含める**。

```json
{
  "description": "アプリの概要説明",
  "features": [
    {"id": "F001", "name": "機能名", "description": "機能説明", "priority": "必須/任意"}
  ],
  "requirements": ["要件1", "要件2"],
  "non_goals": ["対象外1", "対象外2"],
  "tech_stack": {
    "backend": "Laravel 12",
    "frontend": "Livewire 4 + Alpine.js",
    "css": "Tailwind CSS 4 + daisyUI 5",
    "database": "SQLite"
  }
}
```

#### 機能リストの粒度ルール

**重要**: 機能アイテムは**ページ単位**で定義する。同一ページでできる操作は1つの機能アイテムにまとめる。

```json
// ✅ 良い例: ページ単位でまとめる
{
  "features": [
    {
      "id": "F001",
      "name": "タスク管理ページ",
      "description": "タスクの一覧表示・作成・完了切替・削除ができる",
      "priority": "必須",
      "page": "/tasks",
      "operations": ["一覧表示", "新規作成", "完了/未完了切替", "削除"]
    }
  ]
}

// ❌ 悪い例: 操作ごとに分割
{
  "features": [
    {"id": "F001", "name": "タスク一覧表示", "description": "..."},
    {"id": "F002", "name": "タスク作成", "description": "..."},
    {"id": "F003", "name": "タスク完了", "description": "..."},
    {"id": "F004", "name": "タスク削除", "description": "..."}
  ]
}
```

**理由**: ページ単位でまとめることで:
- ui/pages specとの1:1対応が明確になる
- 実装の見通しが立てやすい
- 冗長なspec作成を防げる

### ステップ3: レビュー依頼

作成したspecを表形式で表示し、レビューを依頼。
承認後、status を `approved` に更新。

---

## Category/Type 定義

```
Categories: core, data, ui, action

Types:
  - core: overview, const
  - data: tables, seeders
  - ui: pages, partials, layouts
  - action: sync, async, scheduled
```

### 使用例

| Category | Type | 用途 |
|----------|------|------|
| core | overview | プロジェクト概要・機能一覧 |
| core | const | 定数定義・設定値 |
| data | tables | DBテーブル定義 |
| data | seeders | 初期データ・テストデータ |
| ui | pages | フルページLivewireコンポーネント |
| ui | partials | 再利用可能なUIパーツ |
| ui | layouts | レイアウトコンポーネント |
| action | sync | 同期処理（Actionクラス） |
| action | async | 非同期処理（Jobクラス） |
| action | scheduled | スケジュール実行（Command） |

---

## Spec テンプレート

### core/overview テンプレート

```bash
./scripts/blueprint-db-cli.sh add core overview app-overview "アプリ概要" '{
  "description": "...",
  "features": [
    {"id": "F001", "name": "...", "description": "...", "priority": "必須"}
  ],
  "requirements": ["..."],
  "non_goals": ["..."],
  "tech_stack": {...}
}'
```

### data/tables テンプレート

```bash
./scripts/blueprint-db-cli.sh add data tables tasks "tasksテーブル" '{
  "columns": [
    {"name": "id", "type": "bigint", "primary": true},
    {"name": "title", "type": "string", "nullable": false},
    {"name": "completed", "type": "boolean", "default": false},
    {"name": "timestamps", "type": "timestamps"}
  ],
  "indexes": [],
  "relations": []
}'
```

### ui/pages テンプレート

**必須**: アスキーアートでレイアウトを示す

```bash
./scripts/blueprint-db-cli.sh add ui pages todo-index "Todoメインページ" '{
  "route": "/",
  "component": "Pages/TodoIndex",
  "layout_ascii": "┌─────────────────────────────────────┐\n│  header: Todo App                   │\n├─────────────────────────────────────┤\n│  [新しいタスクを入力...] [追加]      │\n├─────────────────────────────────────┤\n│  ☑ タスク1 (打消線)        [削除]   │\n│  ☐ タスク2                 [削除]   │\n└─────────────────────────────────────┘",
  "modals": [],
  "operations": ["一覧表示", "新規作成", "完了切替", "削除"],
  "wireModel": ["tasks", "newTaskTitle"],
  "methods": ["mount", "addTask", "toggleComplete", "deleteTask"]
}'
```

#### アスキーアートガイドライン

1. **全体レイアウト**: ページの構造を示す
```
┌───────────────────────────────────────────────────┐
│  Logo                  Search...           Avatar  │  ← fixed top bar
├───────────────┬───────────────────────────────────┤
│  Sidebar      │               Main Content        │
│  w-64         │                                   │
│  - Item 1     │  ┌─────────────────────────────┐  │
│  - Item 2     │  │ Content Area               │  │
│  - Item 3     │  └─────────────────────────────┘  │
└───────────────┴───────────────────────────────────┘
```

2. **モーダル**: 別途アスキーアートで示す
```
┌─────────────────────────────────┐
│  Modal Title              [×]  │
├─────────────────────────────────┤
│  Form content here             │
│  [Input field               ]  │
│                                │
│         [Cancel] [Save]        │
└─────────────────────────────────┘
```

3. **レスポンシブ**: モバイル/デスクトップの違いがある場合は両方示す

---

## CLIコマンド

```bash
./scripts/blueprint-db-cli.sh overview         # 全spec一覧
./scripts/blueprint-db-cli.sh progress         # status別の進捗
./scripts/blueprint-db-cli.sh available        # 実装可能なspec
./scripts/blueprint-db-cli.sh pending-review   # レビュー待ち
./scripts/blueprint-db-cli.sh needs-attention  # 要対応
./scripts/blueprint-db-cli.sh add <cat> <type> <slug> <name> '<json>'
./scripts/blueprint-db-cli.sh update <id> '<json>'
./scripts/blueprint-db-cli.sh status <id> <status>
./scripts/blueprint-db-cli.sh reviewed <id>    # レビュー完了マーク
```

---

## Blueprint仕様の品質基準

1. **コーディング可能** - 実装者が迷わず着手できる
2. **具体的** - 曖昧さがない
3. **詳細** - 必要な情報が揃っている
4. **意図が明確** - なぜこの仕様かが分かる
5. **無駄がない** - 冗長な記述を避ける
6. **正確** - 誤解の余地がない

---

## Status Flow

```
draft → pending_review → approved → in_progress → impl_review → testing → done
              ↑                           ↓
              └────── needs_revision ←────┘
```

| Status | 説明 | 次のアクション |
|--------|------|---------------|
| draft | 作成中 | 内容を確定して pending_review へ |
| pending_review | レビュー待ち | 人間がレビューして approved/needs_revision へ |
| approved | 承認済み | /coding で実装開始 |
| in_progress | 実装中 | 完了後 impl_review へ |
| impl_review | 実装レビュー待ち | レビュー後 testing へ |
| testing | テスト中 | テスト完了後 done へ |
| done | 完了 | - |
| needs_revision | 修正必要 | 修正後 pending_review へ |

---

## 効率的なワークフローのコツ

1. **情報収集は1回でまとめる** - 複数回のAskUserQuestionを避ける
2. **テンプレートを活用** - 必須項目の漏れを防ぐ
3. **具体例を示す** - 抽象的な質問を避ける
4. **レビュー前にチェック** - 品質基準を満たしているか確認
