-- Generated from schema.dbml
-- E2E Test Schema - Visual Regression Testing

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS test_cases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,

    -- Blueprint integration
    spec_id INTEGER,
    level INTEGER DEFAULT 1 CHECK(level BETWEEN 1 AND 3),

    -- Test definition
    url TEXT NOT NULL,
    viewport_width INTEGER DEFAULT 1280,
    viewport_height INTEGER DEFAULT 720,
    status TEXT DEFAULT 'defined' CHECK(status IN ('defined', 'active', 'disabled')),

    -- Timestamps
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS test_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    test_case_id INTEGER NOT NULL,
    run_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    result TEXT DEFAULT 'pending' CHECK(result IN ('pending', 'passed', 'failed', 'error')),

    -- Screenshot paths
    screenshot_path TEXT,
    baseline_path TEXT,
    diff_percentage REAL,

    -- Human review
    human_reviewed INTEGER DEFAULT 0,

    -- Execution info
    error_message TEXT,
    duration_ms INTEGER,
    executor TEXT DEFAULT 'claude',
    notes TEXT,

    FOREIGN KEY (test_case_id) REFERENCES test_cases(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS screenshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    test_run_id INTEGER NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('baseline', 'actual', 'diff')),
    file_path TEXT NOT NULL,
    width INTEGER,
    height INTEGER,
    file_size INTEGER,
    captured_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (test_run_id) REFERENCES test_runs(id) ON DELETE CASCADE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_test_cases_spec_id ON test_cases(spec_id);
CREATE INDEX IF NOT EXISTS idx_test_cases_level ON test_cases(level);
CREATE INDEX IF NOT EXISTS idx_test_cases_status ON test_cases(status);
CREATE INDEX IF NOT EXISTS idx_test_runs_case_id ON test_runs(test_case_id);
CREATE INDEX IF NOT EXISTS idx_test_runs_result ON test_runs(result);
CREATE INDEX IF NOT EXISTS idx_test_runs_reviewed ON test_runs(human_reviewed);
CREATE INDEX IF NOT EXISTS idx_screenshots_run_id ON screenshots(test_run_id);

-- Triggers
CREATE TRIGGER IF NOT EXISTS test_cases_updated_at
AFTER UPDATE ON test_cases
BEGIN
    UPDATE test_cases SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- View: Test cases with latest run info
CREATE VIEW IF NOT EXISTS test_cases_with_runs AS
SELECT
    tc.*,
    tr.result AS latest_result,
    tr.run_at AS latest_run_at,
    tr.screenshot_path AS latest_screenshot,
    tr.human_reviewed AS latest_reviewed
FROM test_cases tc
LEFT JOIN (
    SELECT test_case_id, result, run_at, screenshot_path, human_reviewed,
           ROW_NUMBER() OVER (PARTITION BY test_case_id ORDER BY run_at DESC) AS rn
    FROM test_runs
) tr ON tc.id = tr.test_case_id AND tr.rn = 1;

-- View: Tests needing attention
CREATE VIEW IF NOT EXISTS tests_needing_attention AS
SELECT * FROM test_cases_with_runs
WHERE latest_result IN ('pending', 'failed', 'error') OR latest_result IS NULL
ORDER BY updated_at DESC;

-- View: Tests pending human review
CREATE VIEW IF NOT EXISTS tests_pending_review AS
SELECT * FROM test_cases_with_runs
WHERE latest_result = 'passed' AND latest_reviewed = 0
ORDER BY level, updated_at;

-- View: Level summary per spec
CREATE VIEW IF NOT EXISTS spec_level_summary AS
SELECT
    spec_id,
    level,
    COUNT(*) as total_cases,
    SUM(CASE WHEN latest_result = 'passed' AND latest_reviewed = 1 THEN 1 ELSE 0 END) as completed,
    SUM(CASE WHEN latest_result = 'passed' AND latest_reviewed = 0 THEN 1 ELSE 0 END) as pending_review,
    SUM(CASE WHEN latest_result IN ('failed', 'error') THEN 1 ELSE 0 END) as failed
FROM test_cases_with_runs
WHERE spec_id IS NOT NULL
GROUP BY spec_id, level
ORDER BY spec_id, level;
