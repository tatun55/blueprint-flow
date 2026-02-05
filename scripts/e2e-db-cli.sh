#!/bin/bash
# E2E Test CLI
# Usage: ./scripts/e2e-db-cli.sh <command> [args]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DB_PATH="$PROJECT_ROOT/tests/e2e/e2e.db"
SCHEMA_PATH="$PROJECT_ROOT/tests/e2e/schema.sql"
SCREENSHOT_DIR="$PROJECT_ROOT/tests/e2e/screenshots"

show_help() {
    cat << 'EOF'
E2E Test CLI Commands:

  Test Cases:
    list                         List all test cases
    add <slug> <name> <url> [viewport] [spec_id] [level]   Add test case
    get <slug>                   Get test case details
    update <id> '<json>'         Update test case
    disable <id>                 Disable test case
    enable <id>                  Enable test case
    by-spec <spec_id>            List test cases for a spec
    by-level <level>             List test cases by level

  Test Runs:
    run <slug>                   Record a new test run
    runs <slug>                  List runs for a test case
    result <run_id> <passed|failed> [notes]   Record run result
    reviewed <run_id>            Mark run as human reviewed

  Screenshots:
    screenshot <run_id> <step_order> <description> <type> <path>   Record screenshot with description
    baseline <slug> <path>       Set baseline screenshot

  Reports:
    overview                     All test cases with status
    attention                    Tests needing attention
    pending-review               Tests passed but not reviewed
    spec-summary [spec_id]       Level summary per spec

  Admin:
    init                         Initialize database
    reset                        Reset database
    sql "<query>"                Raw SQL query
EOF
}

case "$1" in
    list)
        sqlite3 -json "$DB_PATH" "SELECT id, slug, name, url, spec_id, level, status FROM test_cases ORDER BY spec_id, level, name;"
        ;;

    add)
        VIEWPORT="${5:-1280x720}"
        WIDTH=$(echo "$VIEWPORT" | cut -d'x' -f1)
        HEIGHT=$(echo "$VIEWPORT" | cut -d'x' -f2)
        SPEC_ID="${6:-NULL}"
        LEVEL="${7:-1}"
        if [[ "$SPEC_ID" == "NULL" ]]; then
            sqlite3 "$DB_PATH" "INSERT INTO test_cases (slug, name, url, viewport_width, viewport_height, spec_id, level) VALUES ('$2', '$3', '$4', $WIDTH, $HEIGHT, NULL, $LEVEL);"
        else
            sqlite3 "$DB_PATH" "INSERT INTO test_cases (slug, name, url, viewport_width, viewport_height, spec_id, level) VALUES ('$2', '$3', '$4', $WIDTH, $HEIGHT, $SPEC_ID, $LEVEL);"
        fi
        echo "{\"success\": true, \"id\": $(sqlite3 "$DB_PATH" "SELECT last_insert_rowid();")}"
        ;;

    get)
        sqlite3 -json "$DB_PATH" "SELECT * FROM test_cases WHERE slug = '$2';"
        ;;

    update)
        sqlite3 "$DB_PATH" "UPDATE test_cases SET name = json_extract('$3', '$.name'), url = json_extract('$3', '$.url') WHERE id = $2;"
        echo '{"success": true}'
        ;;

    disable)
        sqlite3 "$DB_PATH" "UPDATE test_cases SET status = 'disabled' WHERE id = $2;"
        echo '{"success": true}'
        ;;

    enable)
        sqlite3 "$DB_PATH" "UPDATE test_cases SET status = 'active' WHERE id = $2;"
        echo '{"success": true}'
        ;;

    by-spec)
        sqlite3 -json "$DB_PATH" "SELECT * FROM test_cases_with_runs WHERE spec_id = $2 ORDER BY level, name;"
        ;;

    by-level)
        sqlite3 -json "$DB_PATH" "SELECT * FROM test_cases_with_runs WHERE level = $2 ORDER BY spec_id, name;"
        ;;

    run)
        CASE_ID=$(sqlite3 "$DB_PATH" "SELECT id FROM test_cases WHERE slug = '$2';")
        if [[ -z "$CASE_ID" ]]; then
            echo '{"success": false, "message": "Test case not found"}'
            exit 1
        fi
        sqlite3 "$DB_PATH" "INSERT INTO test_runs (test_case_id) VALUES ($CASE_ID);"
        RUN_ID=$(sqlite3 "$DB_PATH" "SELECT last_insert_rowid();")
        echo "{\"success\": true, \"run_id\": $RUN_ID, \"case_id\": $CASE_ID}"
        ;;

    runs)
        sqlite3 -json "$DB_PATH" "SELECT tr.* FROM test_runs tr JOIN test_cases tc ON tr.test_case_id = tc.id WHERE tc.slug = '$2' ORDER BY tr.run_at DESC LIMIT 20;"
        ;;

    result)
        if [[ -n "$4" ]]; then
            sqlite3 "$DB_PATH" "UPDATE test_runs SET result = '$3', notes = '$4' WHERE id = $2;"
        else
            sqlite3 "$DB_PATH" "UPDATE test_runs SET result = '$3' WHERE id = $2;"
        fi
        echo '{"success": true}'
        ;;

    reviewed)
        sqlite3 "$DB_PATH" "UPDATE test_runs SET human_reviewed = 1 WHERE id = $2;"
        echo '{"success": true}'
        ;;

    screenshot)
        sqlite3 "$DB_PATH" "INSERT INTO screenshots (test_run_id, step_order, description, type, file_path) VALUES ($2, $3, '$4', '$5', '$6');"
        echo '{"success": true}'
        ;;

    baseline)
        sqlite3 "$DB_PATH" "UPDATE test_runs SET baseline_path = '$3' WHERE test_case_id = (SELECT id FROM test_cases WHERE slug = '$2') ORDER BY run_at DESC LIMIT 1;"
        echo '{"success": true}'
        ;;

    overview)
        sqlite3 -json "$DB_PATH" "SELECT * FROM test_cases_with_runs ORDER BY spec_id, level, name;"
        ;;

    attention)
        sqlite3 -json "$DB_PATH" "SELECT * FROM tests_needing_attention;"
        ;;

    pending-review)
        sqlite3 -json "$DB_PATH" "SELECT * FROM tests_pending_review;"
        ;;

    spec-summary)
        if [[ -n "$2" ]]; then
            sqlite3 -json "$DB_PATH" "SELECT * FROM spec_level_summary WHERE spec_id = $2;"
        else
            sqlite3 -json "$DB_PATH" "SELECT * FROM spec_level_summary;"
        fi
        ;;

    sql)
        sqlite3 -json "$DB_PATH" "$2"
        ;;

    init)
        mkdir -p "$(dirname "$DB_PATH")"
        mkdir -p "$SCREENSHOT_DIR"
        sqlite3 "$DB_PATH" < "$SCHEMA_PATH"
        echo '{"success": true, "message": "E2E database initialized"}'
        ;;

    reset)
        rm -f "$DB_PATH"
        mkdir -p "$SCREENSHOT_DIR"
        sqlite3 "$DB_PATH" < "$SCHEMA_PATH"
        echo '{"success": true, "message": "E2E database reset"}'
        ;;

    *)
        show_help
        ;;
esac
