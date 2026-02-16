#!/bin/bash
# Blueprint-Flow v2 - Update in a project
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

echo "Updating blueprint-flow v2..."
echo "Stack: $STACK"
echo "Current version: $OLD_VERSION"

# Validate stack exists
STACK_DIR="$BLUEPRINT_FLOW_DIR/.claude.$STACK"
if [[ ! -d "$STACK_DIR" ]]; then
    echo "Error: Stack '$STACK' not found in blueprint-flow"
    exit 1
fi

# Update .claude directory (real dir + internal symlinks)
echo "Updating .claude directory..."
RELATIVE_BPF=".blueprint-flow"
if [[ -L "$TARGET_DIR/.claude" ]]; then
    rm "$TARGET_DIR/.claude"
    mkdir -p "$TARGET_DIR/.claude"
fi
ln -sf "../$RELATIVE_BPF/.claude.$STACK/skills" "$TARGET_DIR/.claude/skills"
ln -sf "../$RELATIVE_BPF/.claude.$STACK/agents" "$TARGET_DIR/.claude/agents"
ln -sf "../$RELATIVE_BPF/.claude.$STACK/hooks" "$TARGET_DIR/.claude/hooks"
ln -sf "../$RELATIVE_BPF/.claude.$STACK/CLAUDE.md" "$TARGET_DIR/.claude/CLAUDE.md"
ln -sf "../$RELATIVE_BPF/.claude.$STACK/settings.json" "$TARGET_DIR/.claude/settings.json"

# Update CLI scripts
echo "Updating CLI scripts..."
cp "$BLUEPRINT_FLOW_DIR/scripts/blueprint-db-cli.sh" "$TARGET_DIR/scripts/"
chmod +x "$TARGET_DIR/scripts/blueprint-db-cli.sh"

# Update schema file (preserving database)
echo "Updating schema..."
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.sql" "$TARGET_DIR/blueprint/"

# Update version
NEW_VERSION=$(git -C "$BLUEPRINT_FLOW_DIR" rev-parse HEAD 2>/dev/null || echo "dev")
echo "$NEW_VERSION" > "$TARGET_DIR/.blueprint-flow-version"

echo ""
echo "Blueprint-flow v2 updated successfully!"
echo ""
echo "Old version: $OLD_VERSION"
echo "New version: $(echo $NEW_VERSION | head -c 7)"
echo ""
echo "Note: Database (blueprint.db) was preserved."
echo "      If schema changed, you may need to reset: ./scripts/blueprint-db-cli.sh reset"
