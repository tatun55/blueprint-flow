#!/bin/bash
# Initialize blueprint-flow in a project
# Usage: ./scripts/init.sh [stack] [target_dir]
#
# Stack defaults to "tall-daisy"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLUEPRINT_FLOW_DIR="$(dirname "$SCRIPT_DIR")"
STACK="${1:-tall-daisy}"
TARGET_DIR="${2:-.}"

echo "Initializing blueprint-flow with stack: $STACK"

# Validate stack exists
STACK_DIR="$BLUEPRINT_FLOW_DIR/.claude.$STACK"
if [[ ! -d "$STACK_DIR" ]]; then
    echo "Error: Stack '$STACK' not found"
    echo "Available stacks:"
    ls -1 "$BLUEPRINT_FLOW_DIR" | grep "^\.claude\." | sed 's/^\.claude\./  /'
    exit 1
fi

# Get relative path
if [[ "$TARGET_DIR" == "." ]]; then
    RELATIVE_BPF=".blueprint-flow"
else
    RELATIVE_BPF=".blueprint-flow"
fi

# Create .claude symlink
echo "Creating .claude symlink..."
if [[ -L "$TARGET_DIR/.claude" ]]; then
    rm "$TARGET_DIR/.claude"
elif [[ -d "$TARGET_DIR/.claude" ]]; then
    echo "Warning: .claude directory exists, backing up to .claude.bak"
    mv "$TARGET_DIR/.claude" "$TARGET_DIR/.claude.bak"
fi
ln -sf "$RELATIVE_BPF/.claude.$STACK" "$TARGET_DIR/.claude"

# Create project directories
echo "Creating project directories..."
mkdir -p "$TARGET_DIR/blueprint"
mkdir -p "$TARGET_DIR/tests/e2e/screenshots"
mkdir -p "$TARGET_DIR/scripts"

# Copy CLI scripts
echo "Copying CLI scripts..."
cp "$BLUEPRINT_FLOW_DIR/scripts/blueprint-db-cli.sh" "$TARGET_DIR/scripts/"
cp "$BLUEPRINT_FLOW_DIR/scripts/e2e-db-cli.sh" "$TARGET_DIR/scripts/"
chmod +x "$TARGET_DIR/scripts/blueprint-db-cli.sh"
chmod +x "$TARGET_DIR/scripts/e2e-db-cli.sh"

# Copy schema files
echo "Copying schema files..."
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.sql" "$TARGET_DIR/blueprint/"
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.dbml" "$TARGET_DIR/blueprint/"
cp "$BLUEPRINT_FLOW_DIR/tests/e2e/schema.sql" "$TARGET_DIR/tests/e2e/"
cp "$BLUEPRINT_FLOW_DIR/tests/e2e/schema.dbml" "$TARGET_DIR/tests/e2e/"

# Initialize databases
echo "Initializing databases..."
"$TARGET_DIR/scripts/blueprint-db-cli.sh" init
"$TARGET_DIR/scripts/e2e-db-cli.sh" init

# Create minimal CLAUDE.md if not exists
if [[ ! -f "$TARGET_DIR/CLAUDE.md" ]]; then
    echo "Creating CLAUDE.md..."
    cat > "$TARGET_DIR/CLAUDE.md" << 'CLAUDE_EOF'
# Project Rules

## Blueprint Flow

This project uses blueprint-flow for development workflow.

- Skills: .claude/skills/
- Agents: .claude/agents/

## Quick Commands

```bash
/blueprint     # Manage specs
/db            # DB design
/coding        # Implementation
/test          # Testing
```

## Project-Specific Rules

(Add project-specific rules here)
CLAUDE_EOF
fi

# Store stack and version info
echo "$STACK" > "$TARGET_DIR/.blueprint-flow-stack"
git -C "$BLUEPRINT_FLOW_DIR" rev-parse HEAD 2>/dev/null > "$TARGET_DIR/.blueprint-flow-version" || echo "dev" > "$TARGET_DIR/.blueprint-flow-version"

echo ""
echo "Blueprint-flow initialized successfully!"
echo ""
echo "Stack: $STACK"
echo "Version: $(cat "$TARGET_DIR/.blueprint-flow-version" | head -c 7)"
echo ""
echo ".claude -> .blueprint-flow/.claude.$STACK (symlink)"
echo ""
echo "Next steps:"
echo "  1. Review/update CLAUDE.md with project-specific rules"
echo "  2. Run /blueprint to create specs"
echo "  3. Run /db, /coding, /test for development"
