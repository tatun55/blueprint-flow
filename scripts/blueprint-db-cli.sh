#!/bin/bash
# Blueprint DB - Minimal CLI (init/reset only)
# 通常のクエリは直接 sqlite3 を使用

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DB_PATH="$PROJECT_ROOT/blueprint/blueprint.db"
SCHEMA_PATH="$PROJECT_ROOT/blueprint/schema.sql"

case "$1" in
    init)
        mkdir -p "$(dirname "$DB_PATH")"
        sqlite3 "$DB_PATH" < "$SCHEMA_PATH"
        echo "Database initialized: $DB_PATH"
        ;;

    reset)
        rm -f "$DB_PATH"
        sqlite3 "$DB_PATH" < "$SCHEMA_PATH"
        echo "Database reset: $DB_PATH"
        ;;

    path)
        echo "$DB_PATH"
        ;;

    *)
        cat << EOF
Blueprint DB CLI

Usage:
  ./scripts/blueprint-db-cli.sh init   # Initialize database
  ./scripts/blueprint-db-cli.sh reset  # Reset database (WARNING: deletes all)
  ./scripts/blueprint-db-cli.sh path   # Show database path

Direct SQLite usage:
  sqlite3 -json .blueprint-flow/blueprint/blueprint.db "SELECT * FROM specs"

See BLUEPRINT_FLOW.md for SQL patterns.
EOF
        ;;
esac
