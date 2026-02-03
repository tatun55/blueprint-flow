#!/bin/bash
# Update blueprint-flow in a project
# Usage: ./scripts/update.sh [target_dir]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLUEPRINT_FLOW_DIR="$(dirname "$SCRIPT_DIR")"
TARGET_DIR="${1:-.}"

# Check if project is initialized
if [[ ! -f "$TARGET_DIR/.blueprint-flow-stack" ]]; then
    echo "Error: Project not initialized with blueprint-flow"
    echo "Run init.sh first"
    exit 1
fi

STACK=$(cat "$TARGET_DIR/.blueprint-flow-stack")
OLD_VERSION=$(cat "$TARGET_DIR/.blueprint-flow-version" 2>/dev/null || echo "unknown")

echo "Updating blueprint-flow..."
echo "Stack: $STACK"
echo "Current version: $OLD_VERSION"

# Validate stack exists
STACK_DIR="$BLUEPRINT_FLOW_DIR/.claude.$STACK"
if [[ ! -d "$STACK_DIR" ]]; then
    echo "Error: Stack '$STACK' not found in blueprint-flow"
    exit 1
fi

# Update .claude symlink
echo "Updating .claude symlink..."
if [[ -L "$TARGET_DIR/.claude" ]]; then
    rm "$TARGET_DIR/.claude"
fi
ln -sf ".blueprint-flow/.claude.$STACK" "$TARGET_DIR/.claude"

# Update CLI scripts
echo "Updating CLI scripts..."
cp "$BLUEPRINT_FLOW_DIR/scripts/blueprint-db-cli.sh" "$TARGET_DIR/scripts/"
cp "$BLUEPRINT_FLOW_DIR/scripts/e2e-db-cli.sh" "$TARGET_DIR/scripts/"
chmod +x "$TARGET_DIR/scripts/blueprint-db-cli.sh"
chmod +x "$TARGET_DIR/scripts/e2e-db-cli.sh"

# Update schema files (preserving databases)
echo "Updating schema files..."
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.sql" "$TARGET_DIR/blueprint/"
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.dbml" "$TARGET_DIR/blueprint/"
cp "$BLUEPRINT_FLOW_DIR/tests/e2e/schema.sql" "$TARGET_DIR/tests/e2e/"
cp "$BLUEPRINT_FLOW_DIR/tests/e2e/schema.dbml" "$TARGET_DIR/tests/e2e/"

# Update version
NEW_VERSION=$(git -C "$BLUEPRINT_FLOW_DIR" rev-parse HEAD 2>/dev/null || echo "dev")
echo "$NEW_VERSION" > "$TARGET_DIR/.blueprint-flow-version"

echo ""
echo "Blueprint-flow updated successfully!"
echo ""
echo "Old version: $OLD_VERSION"
echo "New version: $(echo $NEW_VERSION | head -c 7)"
echo ""
echo "Note: Databases (blueprint.db, e2e.db) were preserved."
echo "      If schema changed, you may need to run migrations."
