-- Blueprint-Flow v3 Schema
-- UX 完成度ステージモデル + クローン進化 + Review Scoring Rubric
-- 仕様: BLUEPRINT_FLOW_v3.md

PRAGMA foreign_keys = ON;

-- =========================================
-- core 層: プロジェクト基盤
-- =========================================
-- overview: アプリ概要・機能一覧（"## UX Rubric" 節を content に含む）
-- config:   ビジネスルール・定数・業務知識
-- tech:     技術スタック・コーディングルール
-- concept:  プロジェクトコンセプト
-- design:   デザイン指針
CREATE TABLE IF NOT EXISTS cores (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    type        TEXT NOT NULL,
    slug        TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    summary     TEXT NOT NULL,
    content     TEXT NOT NULL,
    reviewed    BOOLEAN DEFAULT 0,

    -- v3: UX 完成度ステージ
    stage       TEXT NOT NULL DEFAULT 'proto'
                CHECK(stage IN ('proto','mvp','beta','prod','prod_reviewed')),
    stage_dirty INTEGER NOT NULL DEFAULT 0,

    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =========================================
-- blueprint 層: 機能定義
-- =========================================
-- type: page / partial / action / table / layout / test
-- step_status: define → impl → test → done (v3 で 4 段化)
-- stage: クローン進化で前 stage を frozen=1 として履歴保存
CREATE TABLE IF NOT EXISTS blueprints (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    type                TEXT NOT NULL,
    slug                TEXT NOT NULL,
    name                TEXT NOT NULL,
    summary             TEXT NOT NULL,
    content             TEXT NOT NULL,

    step_status         TEXT NOT NULL DEFAULT 'define'
                        CHECK(step_status IN ('define','impl','test','done')),

    -- v3: stage + クローン履歴
    stage               TEXT NOT NULL DEFAULT 'proto'
                        CHECK(stage IN ('proto','mvp','beta','prod')),
    parent_blueprint_id INTEGER REFERENCES blueprints(id),
    frozen              INTEGER NOT NULL DEFAULT 0,

    reviewed            BOOLEAN DEFAULT 0,
    locked_by           TEXT,
    dirty               BOOLEAN DEFAULT 0,
    dirty_reason        TEXT,

    updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP,

    -- v3: 同じ stage で frozen 状態が同一なら type+slug は一意
    UNIQUE(type, stage, slug, frozen)
);

-- =========================================
-- act 層: 実装指示 + 作業記録
-- =========================================
CREATE TABLE IF NOT EXISTS acts (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    blueprint_id INTEGER NOT NULL REFERENCES blueprints(id),
    title        TEXT NOT NULL,
    content      TEXT NOT NULL DEFAULT '',

    status       TEXT NOT NULL DEFAULT 'todo'
                 CHECK(status IN ('todo', 'doing', 'done', 'failed')),
    locked_by    TEXT,
    result       TEXT,

    created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME
);

-- =========================================
-- 依存関係（blueprint 間）
-- =========================================
-- dep_gate: target がどの step_status まで進めば依存解決か
CREATE TABLE IF NOT EXISTS dependencies (
    source_id INTEGER NOT NULL REFERENCES blueprints(id),
    target_id INTEGER NOT NULL REFERENCES blueprints(id),
    detail    TEXT,
    dep_gate  TEXT NOT NULL DEFAULT 'done'
              CHECK(dep_gate IN ('define','impl','test','done')),
    UNIQUE(source_id, target_id)
);

-- =========================================
-- stage 遷移履歴（v3 新設）
-- =========================================
CREATE TABLE IF NOT EXISTS stage_transitions (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    core_id     INTEGER NOT NULL REFERENCES cores(id),
    from_stage  TEXT NOT NULL,
    to_stage    TEXT NOT NULL,
    reviewed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes       TEXT
);

-- =========================================
-- レビュー判定ログ（v3 新設、Review Scoring Rubric の監査）
-- =========================================
-- runner:        'bpf' / 'night-runner'
-- decision_type: 'pre_action' / 'post_complete' / 'stage_gate'
-- trigger:       'F1'..'F11' / 'default' / 'cleanup' / 'mechanical' / 'uncertain'
-- mode:          'L' / 'K' / 'D' / 'G' (複数は 'L+K' 等)
-- outcome:       'approved' / 'rejected' / 'skipped' / 'queued'
CREATE TABLE IF NOT EXISTS review_decisions (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    act_id        INTEGER,
    blueprint_id  INTEGER,
    runner        TEXT NOT NULL,
    decision_type TEXT NOT NULL,
    trigger       TEXT NOT NULL,
    mode          TEXT,
    score         INTEGER NOT NULL,
    threshold     INTEGER NOT NULL,
    asked_human   INTEGER NOT NULL,
    outcome       TEXT NOT NULL,
    reason        TEXT NOT NULL,
    raw_emit      TEXT,
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =========================================
-- Indexes
-- =========================================
CREATE INDEX IF NOT EXISTS idx_cores_type             ON cores(type);
CREATE INDEX IF NOT EXISTS idx_blueprints_type        ON blueprints(type);
CREATE INDEX IF NOT EXISTS idx_blueprints_stage       ON blueprints(stage);
CREATE INDEX IF NOT EXISTS idx_blueprints_step_status ON blueprints(step_status);
CREATE INDEX IF NOT EXISTS idx_blueprints_frozen      ON blueprints(frozen);
CREATE INDEX IF NOT EXISTS idx_blueprints_parent      ON blueprints(parent_blueprint_id);
CREATE INDEX IF NOT EXISTS idx_acts_blueprint_id      ON acts(blueprint_id);
CREATE INDEX IF NOT EXISTS idx_acts_status            ON acts(status);
CREATE INDEX IF NOT EXISTS idx_deps_source            ON dependencies(source_id);
CREATE INDEX IF NOT EXISTS idx_deps_target            ON dependencies(target_id);
CREATE INDEX IF NOT EXISTS idx_review_decisions_act   ON review_decisions(act_id);
CREATE INDEX IF NOT EXISTS idx_review_decisions_runner_score
                                                       ON review_decisions(runner, score);

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

-- ★ active_blueprints: 現 stage かつ frozen=0 の blueprint のみ
-- hub.py の SELECT はデフォルトでこの view を経由する
CREATE VIEW IF NOT EXISTS active_blueprints AS
SELECT b.*
FROM blueprints b
JOIN cores c ON c.type = 'overview'
WHERE b.frozen = 0
  AND b.stage = c.stage;

-- ★ app_snapshot: Hub の全体把握用（v2 から継承）
CREATE VIEW IF NOT EXISTS app_snapshot AS
SELECT 0 as sort, 'concept' as layer, type, slug, name, summary
FROM cores WHERE type = 'concept'
UNION ALL
SELECT 1 as sort, 'design' as layer, type, slug, name, summary
FROM cores WHERE type = 'design'
UNION ALL
SELECT 2 as sort, 'core' as layer, type, slug, name, summary
FROM cores WHERE type NOT IN ('concept', 'design')
UNION ALL
SELECT 3 as sort, type as layer, type, slug, name, summary
FROM active_blueprints WHERE type != 'test'
UNION ALL
SELECT 4 as sort, 'test' as layer, type, slug, name, summary
FROM active_blueprints WHERE type = 'test'
ORDER BY sort, layer, slug;

-- project_progress: 現 stage の step_status 別集計
CREATE VIEW IF NOT EXISTS project_progress AS
SELECT
    step_status,
    COUNT(*)                              as total,
    SUM(step_status = 'done')             as completed,
    SUM(dirty = 1)                        as dirty_count
FROM active_blueprints
WHERE type != 'test'
GROUP BY step_status
ORDER BY CASE step_status
    WHEN 'define' THEN 1 WHEN 'impl' THEN 2 WHEN 'test' THEN 3 WHEN 'done' THEN 4
END;

-- item_status: 現 stage の全 blueprint 一覧
CREATE VIEW IF NOT EXISTS item_status AS
SELECT id, type, slug, name, step_status, locked_by, dirty, dirty_reason
FROM active_blueprints
ORDER BY type, id;

-- next_actions: 依存解決済みで step_status='done' 直前まで進めたもの
-- (v3 では step が消えたので、step_status='done' でない && deps 解決済みが候補)
CREATE VIEW IF NOT EXISTS next_actions AS
SELECT b.id, b.type, b.slug, b.name, b.step_status
FROM active_blueprints b
WHERE b.step_status != 'done'
  AND b.dirty = 0
  AND NOT EXISTS (
    SELECT 1 FROM dependencies dep
    JOIN blueprints blocker ON dep.target_id = blocker.id
    WHERE dep.source_id = b.id
      AND (
        blocker.dirty = 1
        OR NOT (
          (CASE blocker.step_status WHEN 'define' THEN 1 WHEN 'impl' THEN 2 WHEN 'test' THEN 3 WHEN 'done' THEN 4 END)
          >=
          (CASE dep.dep_gate     WHEN 'define' THEN 1 WHEN 'impl' THEN 2 WHEN 'test' THEN 3 WHEN 'done' THEN 4 END)
        )
      )
  );

-- attention_needed: dirty または作業中
CREATE VIEW IF NOT EXISTS attention_needed AS
SELECT id, type, slug, name, step_status, dirty_reason, locked_by
FROM active_blueprints
WHERE dirty = 1 OR locked_by IS NOT NULL;

-- dependency_map: 可読表示
CREATE VIEW IF NOT EXISTS dependency_map AS
SELECT
    s.type || '/' || s.slug as item,
    t.type || '/' || t.slug as depends_on,
    dep.dep_gate,
    t.step_status           as dep_status,
    dep.detail
FROM dependencies dep
JOIN blueprints s ON dep.source_id = s.id
JOIN blueprints t ON dep.target_id = t.id;

-- task_board: 未完了 act
CREATE VIEW IF NOT EXISTS task_board AS
SELECT
    a.id, a.title, a.status, a.locked_by,
    b.type as bp_type, b.slug as bp_slug
FROM acts a
JOIN blueprints b ON a.blueprint_id = b.id
WHERE a.status != 'done'
ORDER BY a.created_at;
