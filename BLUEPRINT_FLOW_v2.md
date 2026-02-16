# Blueprint-Flow v2 設計書

> 3層構造のドキュメント駆動開発フレームワーク

---

## 1. アーキテクチャ概要

### 3層構造

```
core 層 (基盤)        プロジェクト全体の定義。全層から参照される
blueprint 層 (定義)    機能・テーブル・テストの詳細定義。依存関係を持つ
act 層 (指示書)        完全自己完結の作業指示。core + blueprint の必要情報を内包
```

### エージェント構成

```
ユーザー
  │
  ▼
Hub (メインエージェント)
  │  ・blueprint.db の管理のみ
  │  ・コーディング知識を持たない
  │  ・人間との対話 (AskUserQuestion)
  │
  ├─→ 指示書エージェント
  │     core + blueprint → act 完全自己完結ドキュメントを生成
  │
  └─→ 作業エージェント (1種類)
        act を受け取り実装。全タスクに対応
```

| 項目 | Hub | 指示書エージェント | 作業エージェント |
|------|-----|--------------------|------------------|
| 役割 | DB管理・オーケストレーション | act 指示書の生成 | act に基づく実装 |
| コード知識 | なし | なし | あり |
| ユーザー対話 | AskUserQuestion | なし | なし |
| 実行モード | Foreground | Background | Background |
| DB アクセス | 読み書き | 読み取り | なし |

---

## 2. データベース定義

### テーブル

```sql
-- =========================================
-- core 層: プロジェクト基盤
-- =========================================
-- overview: アプリ概要・機能一覧
-- config:   ビジネスルール・定数・業務知識
-- tech:     技術スタック・コーディングルール・フロー定義
CREATE TABLE cores (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    type       TEXT NOT NULL,          -- overview / config / tech
    slug       TEXT NOT NULL UNIQUE,
    name       TEXT NOT NULL,
    summary    TEXT NOT NULL,           -- 20-40字の要約（Hub の全体把握用）
    content    TEXT NOT NULL,           -- Markdown
    reviewed   BOOLEAN DEFAULT 0,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =========================================
-- blueprint 層: 機能定義
-- =========================================
-- page:    ページ定義
-- partial: 部品定義
-- action:  バックエンド処理定義
-- table:   テーブル定義
-- layout:  レイアウト定義
-- test:    テスト定義 (parent_id で対象 blueprint に紐づけ)
CREATE TABLE blueprints (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    type        TEXT NOT NULL,          -- page / partial / action / table / layout / test
    slug        TEXT NOT NULL,
    name        TEXT NOT NULL,
    summary     TEXT NOT NULL,           -- 20-40字の機能要約（Hub の全体把握用）
    content     TEXT NOT NULL,           -- Markdown（具体シナリオまで含む）

    -- パイプライン（step の有効値は core tech のフロー定義に準拠）
    step        TEXT NOT NULL DEFAULT 'define',
    step_status TEXT NOT NULL DEFAULT 'todo'
                CHECK(step_status IN ('todo', 'doing', 'review', 'done')),
    locked_by   TEXT,                   -- 作業中のエージェント名

    -- 無効化（上流変更時にマーク）
    dirty        BOOLEAN DEFAULT 0,
    dirty_reason TEXT,

    -- テスト用（type = 'test' の場合のみ使用）
    parent_id   INTEGER REFERENCES blueprints(id),
    test_level  INTEGER,                -- 1 / 2 / 3

    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(type, slug)
);

-- =========================================
-- act 層: 指示書（完全自己完結）
-- =========================================
CREATE TABLE acts (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    blueprint_id INTEGER NOT NULL REFERENCES blueprints(id),
    title        TEXT NOT NULL,
    content      TEXT NOT NULL,          -- 全情報を内包した完結ドキュメント

    status       TEXT NOT NULL DEFAULT 'todo'
                 CHECK(status IN ('todo', 'doing', 'done', 'failed')),
    locked_by    TEXT,                   -- 作業中のエージェント名
    result       TEXT,                   -- エージェントの作業報告

    created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME
);

-- =========================================
-- 依存関係（blueprint 間）
-- =========================================
CREATE TABLE dependencies (
    source_id INTEGER NOT NULL REFERENCES blueprints(id),
    target_id INTEGER NOT NULL REFERENCES blueprints(id),
    detail    TEXT,                      -- 例: "users.id, users.role"
    UNIQUE(source_id, target_id)
);
```

### VIEW（進捗可視化）

```sql
-- ★ アプリ全体像（Hub は常にこれを参照してコンテキストを維持する）
CREATE VIEW app_snapshot AS
-- core 層: アプリ概要・ビジネスルール・技術情報
SELECT 1 as sort, 'core' as layer, type, slug, name, summary
FROM cores
UNION ALL
-- blueprint 層: 機能一覧（テスト除く）
SELECT 2 as sort, type as layer, type, slug, name, summary
FROM blueprints WHERE type != 'test'
UNION ALL
-- blueprint 層: テスト定義
SELECT 3 as sort, 'test' as layer, type,
    slug, name, summary
FROM blueprints WHERE type = 'test'
ORDER BY sort, layer, slug;

-- ① プロジェクト全体の進捗（step 別の集計）
CREATE VIEW project_progress AS
SELECT
    step,
    COUNT(*) as total,
    SUM(step_status = 'done') as completed,
    SUM(step_status = 'doing') as in_progress,
    SUM(step_status = 'review') as in_review,
    SUM(dirty = 1) as dirty_count
FROM blueprints
WHERE type != 'test'
GROUP BY step
ORDER BY MIN(id);

-- ② 全アイテムのステータス一覧
CREATE VIEW item_status AS
SELECT
    id, type, slug, name,
    step, step_status, locked_by,
    dirty, dirty_reason
FROM blueprints
ORDER BY type, id;

-- ③ 次にやるべきこと（依存解決済み・完了待ち）
CREATE VIEW next_actions AS
SELECT b.id, b.type, b.slug, b.name, b.step, b.step_status
FROM blueprints b
WHERE b.step_status = 'done'
  AND b.dirty = 0
  AND b.step != 'done'
  AND NOT EXISTS (
    SELECT 1 FROM dependencies dep
    JOIN blueprints blocker ON dep.target_id = blocker.id
    WHERE dep.source_id = b.id
      AND (blocker.step_status != 'done' OR blocker.dirty = 1)
  );

-- ④ 要注意アイテム（dirty または作業中）
CREATE VIEW attention_needed AS
SELECT
    id, type, slug, name,
    step, step_status,
    dirty_reason, locked_by
FROM blueprints
WHERE dirty = 1 OR locked_by IS NOT NULL;

-- ⑤ テストカバレッジ
CREATE VIEW test_coverage AS
SELECT
    b.id, b.type, b.slug, b.name,
    MAX(CASE WHEN t.test_level = 1 THEN t.step_status END) as l1,
    MAX(CASE WHEN t.test_level = 2 THEN t.step_status END) as l2,
    MAX(CASE WHEN t.test_level = 3 THEN t.step_status END) as l3
FROM blueprints b
LEFT JOIN blueprints t ON t.parent_id = b.id AND t.type = 'test'
WHERE b.type != 'test'
GROUP BY b.id;

-- ⑥ 依存関係マップ（可読表示）
CREATE VIEW dependency_map AS
SELECT
    s.type || '/' || s.slug as item,
    t.type || '/' || t.slug as depends_on,
    t.step as dep_step,
    t.step_status as dep_status,
    dep.detail
FROM dependencies dep
JOIN blueprints s ON dep.source_id = s.id
JOIN blueprints t ON dep.target_id = t.id;

-- ⑦ act タスクボード（未完了タスク）
CREATE VIEW task_board AS
SELECT
    a.id, a.title, a.status, a.locked_by,
    b.type as bp_type, b.slug as bp_slug
FROM acts a
JOIN blueprints b ON a.blueprint_id = b.id
WHERE a.status != 'done'
ORDER BY a.created_at;
```

---

## 3. core 層: プロジェクト基盤

### セクション構成

| type | 内容 | 例 |
|------|------|-----|
| `overview` | アプリ概要・機能一覧 | アプリ名、目的、主要機能リスト |
| `config` | ビジネスルール・定数・業務知識 | ステータス値、権限定義、バリデーション規則 |
| `tech` | 技術スタック・コーディングルール・フロー定義 | 使用技術、命名規則、プロジェクトフロー、アイテムフロー |

### summary と content

**summary** (20-40字): Hub がアプリ全体像を最小トークンで把握するための要約。
`app_snapshot` VIEW 経由で常時参照される。

```
例: "ユーザーの認証・権限管理を行うマスタテーブル"
例: "タスクの一覧表示・作成・完了切替・削除を行うメインページ"
```

**content** (Markdown): 全て Markdown テキスト。人間が読み書きしやすく、LLM も解釈しやすい。

### content 品質ルール（CRITICAL）

content は以下の基準を満たすこと:

1. **意図が明確**: 何を実現したいかが曖昧さなく伝わる
2. **コーディング可能**: LLM エージェントがこれだけ読めば迷わず実装に着手できる
3. **必要十分**: 不要な背景説明や冗長な記述を排除し、判断に必要な情報だけを含む
4. **過不足なし**: 詳細すぎて実装の自由度を奪わず、簡略すぎて解釈が分かれることもない

```
GOOD: "ログインフォーム。email + password。バリデーション失敗時は
      フィールド直下にエラー表示。成功時は /dashboard にリダイレクト"

BAD (詳細すぎ): "emailフィールドはinput type=emailでname属性は'email'、
      classは'form-input'で、placeholderは'メールアドレス'で..."

BAD (簡略すぎ): "ログイン画面を作る"
```

### tech セクションのフロー定義

`tech` セクションの content 内に、以下の2つのフローを定義する:

**プロジェクトフロー**（全体のマイルストーン）:

```markdown
## プロジェクトフロー

1. 概要定義 → レビュー
2. 機能設計 → レビュー
3. DB設計 → レビュー
4. 実装 → レビュー
5. テストL1 → レビュー
6. テストL2 → レビュー（全L1完了後）
7. テストL3 → レビュー（全L2完了後）
```

**アイテムフロー**（blueprint タイプ別のステップ定義）:

```markdown
## アイテムフロー

### page / partial / action
define → impl → test_l1 → test_l2 → test_l3 → done

### table
define → seed → impl → done

### layout
define → impl → done

### test
define → done
```

---

## 4. blueprint 層: 機能定義

### タイプ一覧

| type | 説明 | 依存先の例 |
|------|------|-----------|
| `page` | ページ定義（ルート・レイアウト・操作・表示要素） | table, layout, partial |
| `partial` | 再利用可能な部品定義 | table |
| `action` | バックエンド処理定義（Action, Job, Event） | table |
| `table` | テーブル定義（カラム・リレーション・シーダー） | 他の table |
| `layout` | レイアウト定義（ヘッダー・サイドバー・フッター構成） | なし |
| `test` | テスト定義（具体シナリオ含む） | 対象の blueprint (parent_id) |

### content の記述方針

- **Markdown テキスト**で記述
- LLM エージェントが迷わない程度に詳細
- 過剰な情報は省き、意図が明確な必要十分の記述
- テスト定義（type='test'）には具体的なテストシナリオまで含む

### テスト定義の紐づけ

```
blueprint (page/todo-index)
  └── blueprint test (parent_id=上記, test_level=1) "基本操作テスト"
  └── blueprint test (parent_id=上記, test_level=2) "追加操作テスト"
  └── blueprint test (parent_id=上記, test_level=3) "エッジケーステスト"
```

テスト定義は対象 blueprint ごと・レベルごとに別レコードとして作成する。

### パイプライン

各 blueprint は `step` と `step_status` で進捗を追跡する。

**step**: core tech のアイテムフローに定義された値（タイプ別に異なる）

**step_status**: 各ステップ内での状態

```
todo → doing → review → done
        ↑         │
   locked_by   人間レビュー
```

- `todo`: まだ着手していない
- `doing`: エージェントが作業中（`locked_by` にエージェント名）
- `review`: 作業完了、人間レビュー待ち
- `done`: レビュー完了、次のステップへ進める

`step_status = 'done'` になったら、Hub が次の `step` に遷移させる。

### ゲート条件

一部のステップには全体ゲートがある:

| ステップ | ゲート条件 |
|----------|-----------|
| `test_l2` | 全 blueprint の `test_l1` が完了済み |
| `test_l3` | 全 blueprint の `test_l2` が完了済み |

---

## 5. act 層: 指示書

### 設計原則

- **完全自己完結**: act だけでエージェントが作業可能。core/blueprint の参照不要
- **1タスク = 1ファイル**: 全情報が1つのドキュメントに集約
- **重複は許容**: core/blueprint の情報を意図的にコピー・埋め込み

### 生成フロー

```
Hub が blueprint の step を進める
  ↓
Hub が「指示書エージェント」を起動
  ↓
指示書エージェントが core + blueprint + 依存先 blueprint を読み込み
  ↓
act (完全自己完結ドキュメント) を生成して DB に保存
  ↓
Hub が「作業エージェント」を act で起動
```

### content の構成例

```markdown
# タスク: TodoIndex ページ実装

## コンテキスト
（core overview から抜粋）
（core tech からスタック・コーディングルール）
（core config からビジネスルール・定数）

## 対象定義
（blueprint page/todo-index の content）

## 依存情報
（blueprint table/tasks の content）
（blueprint layout/main の content）

## 作業指示
- 具体的な実装指示
- ファイルパス・命名規則
- 注意事項

## テスト方針
（blueprint test の content から、このタスクに関連する部分）

## 成果物
- 作成すべきファイル一覧
- 完了条件
```

---

## 6. 依存関係

### blueprint 間の依存

```sql
-- source_id が target_id に依存する
INSERT INTO dependencies (source_id, target_id, detail)
VALUES (3, 1, 'users.id, users.role');
```

`detail` には、具体的にどの部分に依存しているかを記述可能（カラム名など）。

### 依存の用途

1. **実行順序の制御**: 依存先が完了するまで着手しない
2. **無効化の伝播**: 依存先が変更されたら dirty フラグを検討
3. **act 生成時の情報収集**: 依存先の content も act に埋め込む

### 確認方法

```bash
# 依存関係の全体像
SELECT * FROM dependency_map;

# 特定アイテムのブロッカー確認
SELECT * FROM dependency_map WHERE item = 'page/todo-index';
```

---

## 7. 無効化と巻き戻し

### dirty フラグ

上流の blueprint が変更された場合、下流の blueprint に `dirty = 1` をマークする。

```
table/users のカラムを変更
  ↓
page/user-profile (depends_on: table/users) → dirty = 1
  ↓
Hub が影響を評価
  ↓
AskUserQuestion で人間に判断を仰ぐ:
  - dirty のまま進める（影響軽微）
  - step を巻き戻す（再実装が必要）
  - 仕様を変更する
```

### Hub の判断フロー

1. `dirty_reason` に変更内容を記録
2. 依存の `detail` を参照して影響範囲を評価
3. `AskUserQuestion` で人間に選択肢を提示
4. 人間の判断に基づき、step の巻き戻しまたは dirty 解除を実行

---

## 8. Hub の操作パターン

### 初動クエリ（CRITICAL: 毎回の会話開始時に必ず実行）

```bash
DB="blueprint/blueprint.db"

# アプリ全体像（最小トークンで全体把握）
sqlite3 -json $DB "SELECT * FROM app_snapshot"
```

Hub はこの結果を常に頭に置き、全ての判断の基盤とする。

### 日常クエリ

```bash
# プロジェクト全体の進捗
sqlite3 -json $DB "SELECT * FROM project_progress"

# 全アイテムの状況
sqlite3 -json $DB "SELECT * FROM item_status"

# 次にやるべきこと
sqlite3 -json $DB "SELECT * FROM next_actions"

# 問題のあるアイテム
sqlite3 -json $DB "SELECT * FROM attention_needed"

# テストカバレッジ
sqlite3 -json $DB "SELECT * FROM test_coverage"

# 進行中タスク
sqlite3 -json $DB "SELECT * FROM task_board"
```

### ステータス更新

```bash
# 作業開始（ロック）
sqlite3 $DB "UPDATE blueprints SET step_status = 'doing', locked_by = 'worker' WHERE id = {id}"

# 作業完了 → レビュー待ち
sqlite3 $DB "UPDATE blueprints SET step_status = 'review', locked_by = NULL WHERE id = {id}"

# レビュー完了 → 次のステップへ
sqlite3 $DB "UPDATE blueprints SET step = '{next_step}', step_status = 'todo' WHERE id = {id}"

# dirty マーク
sqlite3 $DB "UPDATE blueprints SET dirty = 1, dirty_reason = '{reason}' WHERE id = {id}"

# dirty 解除
sqlite3 $DB "UPDATE blueprints SET dirty = 0, dirty_reason = NULL WHERE id = {id}"
```

### エージェント起動

```
Task tool:
  - subagent_type: "general-purpose"
  - prompt: "指示書エージェントとして実行: blueprint_id={id}"
  - run_in_background: true

Task tool:
  - subagent_type: "general-purpose"
  - prompt: "作業エージェントとして実行: act_id={id}"
  - run_in_background: true
```

---

## 9. 開発サイクル例

```
User: 「タスク管理アプリを作りたい」

Hub:
  1. AskUserQuestion で要件確認
  2. core overview を作成 → ユーザーレビュー
  3. core config を作成（ビジネスルール・定数）→ ユーザーレビュー
  4. core tech を作成（スタック・ルール・フロー定義）→ ユーザーレビュー
  5. blueprint table/tasks を作成 → ユーザーレビュー
  6. blueprint layout/main を作成 → ユーザーレビュー
  7. blueprint page/todo-index を作成 → ユーザーレビュー
  8. blueprint test (level=1, parent=page/todo-index) を作成 → ユーザーレビュー
  9. 指示書エージェント起動 → act 生成
 10. 作業エージェント起動 → 実装
 11. レビュー → 次のステップへ
```

---

## 10. v1 からの主な変更点

| 項目 | v1 | v2 |
|------|----|----|
| 仕様管理 | 1テーブル (specs) + JSON data | 3層 (cores, blueprints, acts) |
| content 形式 | JSON | Markdown |
| エージェント | 5種類 (db-architect, livewire, artisan, tester, blueprint-flow) | 2種類 (指示書エージェント, 作業エージェント) |
| フロー定義 | コード内に暗黙的 | core tech にテキストで明示 |
| ステータス | 7段階の線形フロー + human_reviewed 4段階 | step × step_status (4値) + dirty フラグ |
| 進捗確認 | 複雑な SQL | VIEW で1行クエリ |
| テスト管理 | test category の spec + e2e_screenshots テーブル | blueprint test レコード (level 1-3) |
| 指示書 | spec.data の JSON に全情報 | act 完全自己完結 Markdown ドキュメント |
| 巻き戻し | カスケードリセット（自動） | dirty フラグ + 人間判断 |
