-- Blueprint-Flow v2 Schema
-- 3-layer document-driven development framework

PRAGMA foreign_keys = ON;

-- =========================================
-- core 層: プロジェクト基盤
-- =========================================
-- overview: アプリ概要・機能一覧
-- config:   ビジネスルール・定数・業務知識
-- tech:     技術スタック・コーディングルール・フロー定義
CREATE TABLE IF NOT EXISTS cores (
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
CREATE TABLE IF NOT EXISTS blueprints (
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
CREATE TABLE IF NOT EXISTS acts (
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
CREATE TABLE IF NOT EXISTS dependencies (
    source_id INTEGER NOT NULL REFERENCES blueprints(id),
    target_id INTEGER NOT NULL REFERENCES blueprints(id),
    detail    TEXT,                      -- 例: "users.id, users.role"
    UNIQUE(source_id, target_id)
);

-- =========================================
-- Indexes
-- =========================================
CREATE INDEX IF NOT EXISTS idx_cores_type ON cores(type);
CREATE INDEX IF NOT EXISTS idx_blueprints_type ON blueprints(type);
CREATE INDEX IF NOT EXISTS idx_blueprints_step ON blueprints(step);
CREATE INDEX IF NOT EXISTS idx_blueprints_step_status ON blueprints(step_status);
CREATE INDEX IF NOT EXISTS idx_blueprints_parent_id ON blueprints(parent_id);
CREATE INDEX IF NOT EXISTS idx_acts_blueprint_id ON acts(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_acts_status ON acts(status);
CREATE INDEX IF NOT EXISTS idx_deps_source ON dependencies(source_id);
CREATE INDEX IF NOT EXISTS idx_deps_target ON dependencies(target_id);

-- =========================================
-- Triggers
-- =========================================
CREATE TRIGGER IF NOT EXISTS cores_updated_at
AFTER UPDATE ON cores
BEGIN
    UPDATE cores SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS blueprints_updated_at
AFTER UPDATE ON blueprints
BEGIN
    UPDATE blueprints SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- =========================================
-- VIEWs
-- =========================================

-- ★ アプリ全体像（Hub は常にこれを参照してコンテキストを維持する）
CREATE VIEW IF NOT EXISTS app_snapshot AS
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
CREATE VIEW IF NOT EXISTS project_progress AS
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
CREATE VIEW IF NOT EXISTS item_status AS
SELECT
    id, type, slug, name,
    step, step_status, locked_by,
    dirty, dirty_reason
FROM blueprints
ORDER BY type, id;

-- ③ 次にやるべきこと（依存解決済み・完了待ち）
CREATE VIEW IF NOT EXISTS next_actions AS
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
CREATE VIEW IF NOT EXISTS attention_needed AS
SELECT
    id, type, slug, name,
    step, step_status,
    dirty_reason, locked_by
FROM blueprints
WHERE dirty = 1 OR locked_by IS NOT NULL;

-- ⑤ テストカバレッジ
CREATE VIEW IF NOT EXISTS test_coverage AS
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
CREATE VIEW IF NOT EXISTS dependency_map AS
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
CREATE VIEW IF NOT EXISTS task_board AS
SELECT
    a.id, a.title, a.status, a.locked_by,
    b.type as bp_type, b.slug as bp_slug
FROM acts a
JOIN blueprints b ON a.blueprint_id = b.id
WHERE a.status != 'done'
ORDER BY a.created_at;
