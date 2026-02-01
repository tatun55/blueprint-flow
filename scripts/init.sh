#!/bin/bash
# Initialize blueprint-flow in a project
# Usage: ./scripts/init.sh <stack> [target_dir]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLUEPRINT_FLOW_DIR="$(dirname "$SCRIPT_DIR")"
STACK="${1:-laravel}"
TARGET_DIR="${2:-.}"

echo "Initializing blueprint-flow with stack: $STACK"

# Validate stack exists
if [[ ! -d "$BLUEPRINT_FLOW_DIR/stacks/$STACK" ]]; then
    echo "Error: Stack '$STACK' not found"
    echo "Available stacks:"
    ls -1 "$BLUEPRINT_FLOW_DIR/stacks/"
    exit 1
fi

# Load stack config
source "$BLUEPRINT_FLOW_DIR/stacks/$STACK/config.env"

# Create directories
echo "Creating directories..."
mkdir -p "$TARGET_DIR/.claude/agents/instructors"
mkdir -p "$TARGET_DIR/.claude/agents/coders"
mkdir -p "$TARGET_DIR/.claude/skills/blueprint"
mkdir -p "$TARGET_DIR/.claude/skills/hub"
mkdir -p "$TARGET_DIR/.claude/skills/e2e"
mkdir -p "$TARGET_DIR/blueprint"
mkdir -p "$TARGET_DIR/tests/e2e/screenshots"

# Process and copy instructor files with variable substitution
echo "Generating agent files..."
for file in "$BLUEPRINT_FLOW_DIR/.claude/agents/instructors"/*.md; do
    filename=$(basename "$file")
    envsubst < "$file" > "$TARGET_DIR/.claude/agents/instructors/$filename"
done

# Copy coder files (no substitution needed)
cp "$BLUEPRINT_FLOW_DIR/.claude/agents/coders"/*.md "$TARGET_DIR/.claude/agents/coders/"

# Copy skill files
cp "$BLUEPRINT_FLOW_DIR/.claude/skills/blueprint/SKILL.md" "$TARGET_DIR/.claude/skills/blueprint/"
cp "$BLUEPRINT_FLOW_DIR/.claude/skills/hub/SKILL.md" "$TARGET_DIR/.claude/skills/hub/"
cp "$BLUEPRINT_FLOW_DIR/.claude/skills/e2e/SKILL.md" "$TARGET_DIR/.claude/skills/e2e/"

# Copy blueprint CLI and schema
cp "$BLUEPRINT_FLOW_DIR/blueprint/db-cli.sh" "$TARGET_DIR/blueprint/"
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.sql" "$TARGET_DIR/blueprint/"
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.dbml" "$TARGET_DIR/blueprint/"
chmod +x "$TARGET_DIR/blueprint/db-cli.sh"

# Copy e2e CLI and schema
cp "$BLUEPRINT_FLOW_DIR/tests/e2e/db-cli.sh" "$TARGET_DIR/tests/e2e/"
cp "$BLUEPRINT_FLOW_DIR/tests/e2e/schema.sql" "$TARGET_DIR/tests/e2e/"
cp "$BLUEPRINT_FLOW_DIR/tests/e2e/schema.dbml" "$TARGET_DIR/tests/e2e/"
chmod +x "$TARGET_DIR/tests/e2e/db-cli.sh"

# Copy stack-specific patterns
mkdir -p "$TARGET_DIR/stacks/$STACK"
cp "$BLUEPRINT_FLOW_DIR/stacks/$STACK"/*.md "$TARGET_DIR/stacks/$STACK/" 2>/dev/null || true
cp "$BLUEPRINT_FLOW_DIR/stacks/$STACK/config.env" "$TARGET_DIR/stacks/$STACK/"

# Initialize databases
echo "Initializing databases..."
"$TARGET_DIR/blueprint/db-cli.sh" init
"$TARGET_DIR/tests/e2e/db-cli.sh" init

# Create minimal CLAUDE.md if not exists
if [[ ! -f "$TARGET_DIR/CLAUDE.md" ]]; then
    echo "Creating minimal CLAUDE.md..."
    cat > "$TARGET_DIR/CLAUDE.md" << 'CLAUDE_EOF'
# Project Rules

## Stack

See: stacks/*/patterns.md

## Blueprint Flow

This project uses blueprint-flow for development workflow.

- Skills: .claude/skills/
- Agents: .claude/agents/

## Quick Commands

```bash
/blueprint     # Manage specs
/hub           # Start orchestrator
/e2e           # Run E2E tests
```

## Project-Specific Rules

(Add project-specific rules here)
CLAUDE_EOF
fi

# Store blueprint-flow version
echo "$STACK" > "$TARGET_DIR/.blueprint-flow-stack"
git -C "$BLUEPRINT_FLOW_DIR" rev-parse HEAD 2>/dev/null > "$TARGET_DIR/.blueprint-flow-version" || echo "dev" > "$TARGET_DIR/.blueprint-flow-version"

echo ""
echo "Blueprint-flow initialized successfully!"
echo ""
echo "Stack: $STACK"
echo "Version: $(cat "$TARGET_DIR/.blueprint-flow-version")"
echo ""
echo "Next steps:"
echo "  1. Review/update CLAUDE.md with project-specific rules"
echo "  2. Run /blueprint to create specs"
echo "  3. Run /hub to start development"
