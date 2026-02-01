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

# Load stack config
source "$BLUEPRINT_FLOW_DIR/stacks/$STACK/config.env"

# Update instructor files with variable substitution
echo "Updating agent files..."
for file in "$BLUEPRINT_FLOW_DIR/.claude/agents/instructors"/*.md; do
    filename=$(basename "$file")
    envsubst < "$file" > "$TARGET_DIR/.claude/agents/instructors/$filename"
done

# Update coder files
cp "$BLUEPRINT_FLOW_DIR/.claude/agents/coders"/*.md "$TARGET_DIR/.claude/agents/coders/"

# Update skill files
cp "$BLUEPRINT_FLOW_DIR/.claude/skills/blueprint/SKILL.md" "$TARGET_DIR/.claude/skills/blueprint/"
cp "$BLUEPRINT_FLOW_DIR/.claude/skills/hub/SKILL.md" "$TARGET_DIR/.claude/skills/hub/"
cp "$BLUEPRINT_FLOW_DIR/.claude/skills/e2e/SKILL.md" "$TARGET_DIR/.claude/skills/e2e/"

# Update CLI scripts (preserving databases)
cp "$BLUEPRINT_FLOW_DIR/scripts/blueprint-db-cli.sh" "$TARGET_DIR/scripts/"
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.sql" "$TARGET_DIR/blueprint/"
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.dbml" "$TARGET_DIR/blueprint/"
chmod +x "$TARGET_DIR/scripts/blueprint-db-cli.sh"

cp "$BLUEPRINT_FLOW_DIR/scripts/e2e-db-cli.sh" "$TARGET_DIR/scripts/"
# e2e schema files may not exist in all setups
cp "$BLUEPRINT_FLOW_DIR/tests/e2e/schema.sql" "$TARGET_DIR/tests/e2e/" 2>/dev/null || true
cp "$BLUEPRINT_FLOW_DIR/tests/e2e/schema.dbml" "$TARGET_DIR/tests/e2e/" 2>/dev/null || true
chmod +x "$TARGET_DIR/scripts/e2e-db-cli.sh"

# Update stack patterns
mkdir -p "$TARGET_DIR/stacks/$STACK"
cp "$BLUEPRINT_FLOW_DIR/stacks/$STACK"/*.md "$TARGET_DIR/stacks/$STACK/" 2>/dev/null || true
cp "$BLUEPRINT_FLOW_DIR/stacks/$STACK/config.env" "$TARGET_DIR/stacks/$STACK/"

# Update version
NEW_VERSION=$(git -C "$BLUEPRINT_FLOW_DIR" rev-parse HEAD 2>/dev/null || echo "dev")
echo "$NEW_VERSION" > "$TARGET_DIR/.blueprint-flow-version"

echo ""
echo "Blueprint-flow updated successfully!"
echo ""
echo "Old version: $OLD_VERSION"
echo "New version: $NEW_VERSION"
echo ""
echo "Note: Databases (blueprint.db, e2e.db) were preserved."
echo "      If schema changed, you may need to run migrations."
