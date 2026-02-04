#!/bin/bash
# Blueprint CLI - Spec Management with Review Workflow
# Usage: ./scripts/blueprint-db-cli.sh <command> [args]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DB_PATH="$PROJECT_ROOT/blueprint/blueprint.db"
SCHEMA_PATH="$PROJECT_ROOT/blueprint/schema.sql"

show_help() {
    cat << 'EOF'
Blueprint CLI Commands:

  Read:
    list [category] [type]       List specs
    get <cat> <type> <slug>      Get single spec with data
    overview                     All specs summary
    progress                     Progress by status

  Status Views:
    list-by-status <status>      List specs by status
    available                    Ready for implementation (wave-based, legacy)
    available-with-deps          Ready with all dependencies resolved
    in-progress                  Currently being worked on
    pending-review               Awaiting human review
    needs-attention              Needs revision or blocked
    e2e-pending                  Specs with pending E2E tests
    blockers <id>                Show what blocks a spec
    review-status                Show human review summary by stage
    needs-review                 Specs not fully reviewed (human_reviewed != test_reviewed)

  Write:
    add <cat> <type> <slug> <name> '<json>'   Add new spec (status: draft)
    update <id> '<json>'         Update spec data
    status <id> <status>         Change status
    review <id> <stage>          Set human review stage (none/spec_reviewed/impl_reviewed/test_reviewed)
    reset-review <id>            Reset review to 'none' and cascade to dependents
    revision <id> '<reason>'     Mark needs_revision with reason
    e2e-status <id> <status>     Set E2E status (pending/passed/failed)
    e2e-level <id> <level>       Set required E2E level (1-3)

  Dependencies:
    add-dep <id> <blocked_by_id> Add dependency (id is blocked by blocked_by_id)
    remove-dep <id> <blocked_by_id>  Remove dependency
    deps <id>                    Show dependencies for a spec

  Lock:
    lock <id> <worker>           Lock for working
    unlock <id>                  Release lock

  Tasks:
    task-add <spec_id> <agent_type> '<content>'   Add task (agent_type: db-agent, livewire-agent, action-agent, test-agent)
    task-get <id>                Get task content
    task-status <id> <status>    Update task status (pending/completed/failed)
    task-list [spec_id]          List tasks

  Admin:
    init                         Initialize database
    reset                        Reset database (WARNING: deletes all)
    sql "<query>"                Raw SQL query

Categories: core, data, ui, action, test

Types:
  - core: overview, const
  - data: tables, seeders
  - ui: pages, partials, layouts
  - action: sync, async, scheduled
  - test: unit, feature, e2e

Test Levels (in spec data.level):
  - 1: Basic (main operations, 20-40% coverage)
  - 2: Standard (forms, modals, 40-60% coverage)
  - 3: Comprehensive (edge cases, errors, 60%+ coverage)

Human Review Stages:
  - none: Not yet reviewed (initial or reset)
  - spec_reviewed: Specification reviewed and approved
  - impl_reviewed: Implementation reviewed and approved
  - test_reviewed: Test reviewed and approved (complete)

Status Flow:
  draft → pending_review → approved → in_progress → impl_review → testing → done
                ↑                          ↓
                └────── needs_revision ←───┘
                              ↑
                          blocked (dependency issue)
EOF
}

# Auto-set e2e_status for ui/pages and ui/layouts
set_e2e_for_ui() {
    local cat="$1"
    local type="$2"
    if [[ "$cat" == "ui" && ("$type" == "pages" || "$type" == "layouts") ]]; then
        echo "pending"
    else
        echo "NULL"
    fi
}

case "$1" in
    list)
        WHERE=""
        [[ -n "$2" ]] && WHERE="WHERE category = '$2'"
        [[ -n "$3" ]] && WHERE="${WHERE:+$WHERE AND }${WHERE:-WHERE }type = '$3'"
        sqlite3 -json "$DB_PATH" "SELECT id, category, type, slug, name, status, working_by, wave, human_reviewed, e2e_status, e2e_level FROM specs $WHERE ORDER BY wave, category, type;"
        ;;

    get)
        sqlite3 -json "$DB_PATH" "SELECT * FROM specs WHERE category = '$2' AND type = '$3' AND slug = '$4';"
        ;;

    add)
        E2E_STATUS=$(set_e2e_for_ui "$2" "$3")
        # INSERTとlast_insert_rowid()を同じコネクションで実行してIDを正しく取得
        if [[ "$E2E_STATUS" == "NULL" ]]; then
            NEW_ID=$(sqlite3 "$DB_PATH" "INSERT INTO specs (category, type, slug, name, data, status, e2e_status) VALUES ('$2', '$3', '$4', '$5', '$6', 'draft', NULL); SELECT last_insert_rowid();")
        else
            NEW_ID=$(sqlite3 "$DB_PATH" "INSERT INTO specs (category, type, slug, name, data, status, e2e_status) VALUES ('$2', '$3', '$4', '$5', '$6', 'draft', '$E2E_STATUS'); SELECT last_insert_rowid();")
        fi
        echo "{\"success\": true, \"id\": $NEW_ID}"
        ;;

    update)
        # Update spec data and reset review for this spec and dependents
        sqlite3 "$DB_PATH" "UPDATE specs SET data = '$3', human_reviewed = 'none' WHERE id = $2;"
        # Reset dependents
        sqlite3 "$DB_PATH" "
            WITH RECURSIVE dependents AS (
                SELECT spec_id FROM spec_dependencies WHERE blocked_by_spec_id = $2
                UNION
                SELECT d.spec_id FROM spec_dependencies d
                INNER JOIN dependents ON d.blocked_by_spec_id = dependents.spec_id
            )
            UPDATE specs SET human_reviewed = 'none' WHERE id IN (SELECT spec_id FROM dependents);
        "
        echo '{"success": true}'
        ;;

    status)
        sqlite3 "$DB_PATH" "UPDATE specs SET status = '$3' WHERE id = $2;"
        echo '{"success": true}'
        ;;

    review)
        # Set human review stage: none, spec_reviewed, impl_reviewed, test_reviewed
        sqlite3 "$DB_PATH" "UPDATE specs SET human_reviewed = '$3' WHERE id = $2;"
        echo '{"success": true}'
        ;;

    reset-review)
        # Reset review to 'none' for this spec and all specs that depend on it
        # First, reset the target spec
        sqlite3 "$DB_PATH" "UPDATE specs SET human_reviewed = 'none' WHERE id = $2;"
        # Then, reset all specs that have this spec as a dependency (recursive cascade)
        sqlite3 "$DB_PATH" "
            WITH RECURSIVE dependents AS (
                -- Direct dependents
                SELECT spec_id FROM spec_dependencies WHERE blocked_by_spec_id = $2
                UNION
                -- Recursive dependents
                SELECT d.spec_id FROM spec_dependencies d
                INNER JOIN dependents ON d.blocked_by_spec_id = dependents.spec_id
            )
            UPDATE specs SET human_reviewed = 'none' WHERE id IN (SELECT spec_id FROM dependents);
        "
        # Return count of affected specs
        COUNT=$(sqlite3 "$DB_PATH" "
            WITH RECURSIVE dependents AS (
                SELECT spec_id FROM spec_dependencies WHERE blocked_by_spec_id = $2
                UNION
                SELECT d.spec_id FROM spec_dependencies d
                INNER JOIN dependents ON d.blocked_by_spec_id = dependents.spec_id
            )
            SELECT COUNT(*) + 1 FROM dependents;
        ")
        echo "{\"success\": true, \"reset_count\": $COUNT}"
        ;;

    revision)
        sqlite3 "$DB_PATH" "UPDATE specs SET status = 'needs_revision', revision_reason = '$3', revision_count = revision_count + 1 WHERE id = $2;"
        echo '{"success": true}'
        ;;

    e2e-status)
        sqlite3 "$DB_PATH" "UPDATE specs SET e2e_status = '$3' WHERE id = $2;"
        echo '{"success": true}'
        ;;

    e2e-level)
        sqlite3 "$DB_PATH" "UPDATE specs SET e2e_level = $3 WHERE id = $2;"
        echo '{"success": true}'
        ;;

    delete)
        sqlite3 "$DB_PATH" "DELETE FROM specs WHERE id = $2;"
        echo '{"success": true}'
        ;;

    # Dependency commands
    add-dep)
        sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO spec_dependencies (spec_id, blocked_by_spec_id) VALUES ($2, $3);"
        echo '{"success": true}'
        ;;

    remove-dep)
        sqlite3 "$DB_PATH" "DELETE FROM spec_dependencies WHERE spec_id = $2 AND blocked_by_spec_id = $3;"
        echo '{"success": true}'
        ;;

    deps)
        sqlite3 -json "$DB_PATH" "
            SELECT
                d.blocked_by_spec_id as id,
                s.slug,
                s.status
            FROM spec_dependencies d
            JOIN specs s ON d.blocked_by_spec_id = s.id
            WHERE d.spec_id = $2;
        "
        ;;

    lock)
        sqlite3 "$DB_PATH" "UPDATE specs SET working_by = '$3', status = 'in_progress' WHERE id = $2 AND working_by IS NULL;"
        CHANGED=$(sqlite3 "$DB_PATH" "SELECT changes();")
        [[ "$CHANGED" == "1" ]] && echo '{"success": true}' || echo '{"success": false, "message": "Already locked"}'
        ;;

    unlock)
        sqlite3 "$DB_PATH" "UPDATE specs SET working_by = NULL WHERE id = $2;"
        echo '{"success": true}'
        ;;

    available)
        sqlite3 -json "$DB_PATH" "SELECT * FROM available_specs;"
        ;;

    available-with-deps)
        sqlite3 -json "$DB_PATH" "SELECT * FROM available_with_deps;"
        ;;

    blockers)
        sqlite3 -json "$DB_PATH" "SELECT * FROM spec_blockers WHERE id = $2;"
        ;;

    in-progress)
        sqlite3 -json "$DB_PATH" "SELECT * FROM in_progress_specs;"
        ;;

    pending-review)
        sqlite3 -json "$DB_PATH" "SELECT * FROM pending_review_specs;"
        ;;

    needs-attention)
        sqlite3 -json "$DB_PATH" "SELECT * FROM needs_attention_specs;"
        ;;

    e2e-pending)
        sqlite3 -json "$DB_PATH" "SELECT * FROM e2e_pending_specs;"
        ;;

    review-status)
        sqlite3 -json "$DB_PATH" "SELECT * FROM review_summary;"
        ;;

    needs-review)
        sqlite3 -json "$DB_PATH" "SELECT * FROM needs_review_specs;"
        ;;

    list-by-status)
        sqlite3 -json "$DB_PATH" "SELECT id, category, type, slug, name, status, working_by, wave, human_reviewed, e2e_status, e2e_level FROM specs WHERE status = '$2' ORDER BY wave, category, type;"
        ;;

    overview)
        sqlite3 -json "$DB_PATH" "SELECT id, category, type, slug, name, status, working_by, wave, human_reviewed, revision_count, e2e_status, e2e_level FROM specs ORDER BY wave, category, type;"
        ;;

    progress)
        sqlite3 -json "$DB_PATH" "SELECT * FROM progress_summary;"
        ;;

    e2e-progress)
        sqlite3 -json "$DB_PATH" "SELECT * FROM e2e_level_summary;"
        ;;

    # Task commands
    task-add)
        # INSERTとlast_insert_rowid()を同じコネクションで実行してIDを正しく取得
        NEW_ID=$(sqlite3 "$DB_PATH" "INSERT INTO tasks (spec_id, agent_type, content, status) VALUES ($2, '$3', '$4', 'pending'); SELECT last_insert_rowid();")
        echo "{\"success\": true, \"id\": $NEW_ID}"
        ;;

    task-get)
        sqlite3 -json "$DB_PATH" "SELECT * FROM tasks WHERE id = $2;"
        ;;

    task-status)
        sqlite3 "$DB_PATH" "UPDATE tasks SET status = '$3' WHERE id = $2;"
        echo '{"success": true}'
        ;;

    task-list)
        if [[ -n "$2" ]]; then
            sqlite3 -json "$DB_PATH" "SELECT id, spec_id, agent_type, status, created_at FROM tasks WHERE spec_id = $2 ORDER BY created_at DESC;"
        else
            sqlite3 -json "$DB_PATH" "SELECT id, spec_id, agent_type, status, created_at FROM tasks ORDER BY created_at DESC;"
        fi
        ;;

    task-content)
        sqlite3 "$DB_PATH" "SELECT content FROM tasks WHERE id = $2;"
        ;;

    sql)
        sqlite3 -json "$DB_PATH" "$2"
        ;;

    init)
        mkdir -p "$(dirname "$DB_PATH")"
        sqlite3 "$DB_PATH" < "$SCHEMA_PATH"
        echo '{"success": true, "message": "Database initialized"}'
        ;;

    reset)
        rm -f "$DB_PATH"
        sqlite3 "$DB_PATH" < "$SCHEMA_PATH"
        echo '{"success": true, "message": "Database reset"}'
        ;;

    *)
        show_help
        ;;
esac
