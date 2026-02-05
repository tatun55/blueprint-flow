-- Generated from schema.dbml
-- Blueprint Schema - Spec Management with Review Workflow

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS specs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL,
    type TEXT NOT NULL,
    slug TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,

    -- Status workflow (added: blocked)
    status TEXT DEFAULT 'draft' CHECK(status IN ('draft', 'pending_review', 'approved', 'in_progress', 'impl_review', 'testing', 'done', 'needs_revision', 'blocked')),

    -- Work assignment
    working_by TEXT,

    -- Git worktree tracking
    branch TEXT,

    -- Review tracking (4-stage: none → spec_reviewed → impl_reviewed → test_reviewed)
    human_reviewed TEXT DEFAULT 'none' CHECK(human_reviewed IN ('none', 'spec_reviewed', 'impl_reviewed', 'test_reviewed')),
    revision_count INTEGER DEFAULT 0,
    revision_reason TEXT,

    -- E2E testing
    e2e_status TEXT DEFAULT NULL CHECK(e2e_status IS NULL OR e2e_status IN ('pending', 'passed', 'failed')),
    e2e_level INTEGER DEFAULT 1 CHECK(e2e_level BETWEEN 1 AND 3),

    -- Ordering (legacy, use spec_dependencies instead)
    wave INTEGER DEFAULT 1,

    -- Spec data
    data JSON NOT NULL,

    -- Timestamps
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(category, type, slug)
);

-- Dependency management (replaces wave for fine-grained control)
CREATE TABLE IF NOT EXISTS spec_dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    spec_id INTEGER NOT NULL,
    blocked_by_spec_id INTEGER NOT NULL,
    FOREIGN KEY (spec_id) REFERENCES specs(id) ON DELETE CASCADE,
    FOREIGN KEY (blocked_by_spec_id) REFERENCES specs(id) ON DELETE CASCADE,
    UNIQUE(spec_id, blocked_by_spec_id)
);

-- Tasks table for storing agent instructions
CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    spec_id INTEGER NOT NULL REFERENCES specs(id) ON DELETE CASCADE,
    agent_type TEXT NOT NULL CHECK(agent_type IN ('db-architect', 'livewire', 'artisan', 'tester')),
    content TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'completed', 'failed')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for specs
CREATE INDEX IF NOT EXISTS idx_specs_category_type ON specs(category, type);
CREATE INDEX IF NOT EXISTS idx_specs_status ON specs(status);
CREATE INDEX IF NOT EXISTS idx_specs_wave ON specs(wave);
CREATE INDEX IF NOT EXISTS idx_specs_working_by ON specs(working_by);
CREATE INDEX IF NOT EXISTS idx_specs_e2e_status ON specs(e2e_status);
CREATE INDEX IF NOT EXISTS idx_specs_branch ON specs(branch);

-- Indexes for tasks
CREATE INDEX IF NOT EXISTS idx_tasks_spec_id ON tasks(spec_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);

-- Indexes for dependencies
CREATE INDEX IF NOT EXISTS idx_deps_spec_id ON spec_dependencies(spec_id);
CREATE INDEX IF NOT EXISTS idx_deps_blocked_by ON spec_dependencies(blocked_by_spec_id);

-- Trigger: update updated_at
CREATE TRIGGER IF NOT EXISTS specs_updated_at
AFTER UPDATE ON specs
BEGIN
    UPDATE specs SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- View: Available for implementation (approved, not locked, legacy wave-based)
CREATE VIEW IF NOT EXISTS available_specs AS
SELECT * FROM specs
WHERE status = 'approved' AND working_by IS NULL
ORDER BY wave, category, type;

-- View: Available with dependencies resolved
-- Returns specs that are approved, unlocked, and all dependencies are done
CREATE VIEW IF NOT EXISTS available_with_deps AS
SELECT s.* FROM specs s
WHERE s.status = 'approved'
  AND s.working_by IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM spec_dependencies d
      JOIN specs blocked ON d.blocked_by_spec_id = blocked.id
      WHERE d.spec_id = s.id AND blocked.status != 'done'
  )
ORDER BY s.id;

-- View: Currently in progress
CREATE VIEW IF NOT EXISTS in_progress_specs AS
SELECT * FROM specs
WHERE status = 'in_progress'
ORDER BY updated_at DESC;

-- View: Awaiting human review
CREATE VIEW IF NOT EXISTS pending_review_specs AS
SELECT * FROM specs
WHERE status IN ('pending_review', 'impl_review')
ORDER BY updated_at ASC;

-- View: Needs attention (revision required or blocked)
CREATE VIEW IF NOT EXISTS needs_attention_specs AS
SELECT * FROM specs
WHERE status IN ('needs_revision', 'blocked')
ORDER BY updated_at DESC;

-- View: Specs with their blocking dependencies
CREATE VIEW IF NOT EXISTS spec_blockers AS
SELECT
    s.id,
    s.slug,
    s.status,
    GROUP_CONCAT(blocked.slug) as blocked_by_slugs,
    GROUP_CONCAT(blocked.id) as blocked_by_ids,
    COUNT(CASE WHEN blocked.status != 'done' THEN 1 END) as pending_blockers
FROM specs s
LEFT JOIN spec_dependencies d ON s.id = d.spec_id
LEFT JOIN specs blocked ON d.blocked_by_spec_id = blocked.id
GROUP BY s.id;

-- View: E2E testing pending
CREATE VIEW IF NOT EXISTS e2e_pending_specs AS
SELECT * FROM specs
WHERE e2e_status = 'pending'
ORDER BY wave, category, type;

-- View: Progress summary
CREATE VIEW IF NOT EXISTS progress_summary AS
SELECT
    status,
    COUNT(*) as count,
    GROUP_CONCAT(slug) as specs
FROM specs
GROUP BY status
ORDER BY
    CASE status
        WHEN 'draft' THEN 1
        WHEN 'pending_review' THEN 2
        WHEN 'approved' THEN 3
        WHEN 'in_progress' THEN 4
        WHEN 'impl_review' THEN 5
        WHEN 'testing' THEN 6
        WHEN 'done' THEN 7
        WHEN 'needs_revision' THEN 8
    END;

-- View: E2E level progress
CREATE VIEW IF NOT EXISTS e2e_level_summary AS
SELECT
    e2e_level as level,
    e2e_status as status,
    COUNT(*) as count
FROM specs
WHERE e2e_status IS NOT NULL
GROUP BY e2e_level, e2e_status
ORDER BY e2e_level, e2e_status;

-- View: Human review status summary
CREATE VIEW IF NOT EXISTS review_summary AS
SELECT
    human_reviewed as stage,
    COUNT(*) as count,
    GROUP_CONCAT(slug) as specs
FROM specs
GROUP BY human_reviewed
ORDER BY
    CASE human_reviewed
        WHEN 'none' THEN 1
        WHEN 'spec_reviewed' THEN 2
        WHEN 'impl_reviewed' THEN 3
        WHEN 'test_reviewed' THEN 4
    END;

-- View: Specs needing review (not fully reviewed)
CREATE VIEW IF NOT EXISTS needs_review_specs AS
SELECT * FROM specs
WHERE human_reviewed != 'test_reviewed'
ORDER BY
    CASE human_reviewed
        WHEN 'none' THEN 1
        WHEN 'spec_reviewed' THEN 2
        WHEN 'impl_reviewed' THEN 3
    END,
    category, type;
