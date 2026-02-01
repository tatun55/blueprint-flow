#!/bin/bash
# Initialize blueprint-flow in a project
# Usage: ./scripts/init.sh <stack> [target_dir]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLUEPRINT_FLOW_DIR="$(dirname "$SCRIPT_DIR")"
STACK="${1:-tall-daisy}"
TARGET_DIR="${2:-.}"

echo "Initializing blueprint-flow with stack: $STACK"

# Validate stack exists
if [[ ! -d "$BLUEPRINT_FLOW_DIR/stacks/$STACK" ]]; then
    echo "Error: Stack '$STACK' not found"
    echo "Available stacks:"
    ls -1 "$BLUEPRINT_FLOW_DIR/stacks/"
    exit 1
fi

# Load stack config and export for envsubst
set -a
source "$BLUEPRINT_FLOW_DIR/stacks/$STACK/config.env"
set +a

# Create directories
echo "Creating directories..."
mkdir -p "$TARGET_DIR/.claude/agents/instructors"
mkdir -p "$TARGET_DIR/.claude/agents/coders"
mkdir -p "$TARGET_DIR/.claude/skills/blueprint"
mkdir -p "$TARGET_DIR/.claude/skills/hub"
mkdir -p "$TARGET_DIR/.claude/skills/e2e"
mkdir -p "$TARGET_DIR/blueprint"
mkdir -p "$TARGET_DIR/tests/e2e/screenshots"
mkdir -p "$TARGET_DIR/scripts"

# Create temp files for patterns
COMMON_FILE=$(mktemp)
INSTRUCTOR_FILE=$(mktemp)
trap "rm -f $COMMON_FILE $INSTRUCTOR_FILE" EXIT

# Read common patterns
if [[ -f "$BLUEPRINT_FLOW_DIR/stacks/$STACK/common/base.md" ]]; then
    cat "$BLUEPRINT_FLOW_DIR/stacks/$STACK/common/base.md" > "$COMMON_FILE"
else
    echo "" > "$COMMON_FILE"
fi

# Function to generate instructor file with embedded patterns
generate_instructor() {
    local instructor_name="$1"
    local template_file="$BLUEPRINT_FLOW_DIR/.claude/agents/instructors/${instructor_name}.md"
    local patterns_file="$BLUEPRINT_FLOW_DIR/stacks/$STACK/instructors/${instructor_name}.md"
    local output_file="$TARGET_DIR/.claude/agents/instructors/${instructor_name}.md"

    # Read instructor-specific patterns if exists
    if [[ -f "$patterns_file" ]]; then
        cat "$patterns_file" > "$INSTRUCTOR_FILE"
    else
        echo "" > "$INSTRUCTOR_FILE"
    fi

    # Process template: replace placeholders, then envsubst for variables
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "<!-- COMMON_PATTERNS -->" ]]; then
            cat "$COMMON_FILE"
        elif [[ "$line" == "<!-- INSTRUCTOR_PATTERNS -->" ]]; then
            cat "$INSTRUCTOR_FILE"
        else
            echo "$line"
        fi
    done < "$template_file" | envsubst > "$output_file"
}

# Generate instructor files with embedded patterns
echo "Generating agent files..."
for file in "$BLUEPRINT_FLOW_DIR/.claude/agents/instructors"/*.md; do
    filename=$(basename "$file" .md)
    generate_instructor "$filename"
done

# Copy coder files (no substitution needed)
cp "$BLUEPRINT_FLOW_DIR/.claude/agents/coders"/*.md "$TARGET_DIR/.claude/agents/coders/"

# Copy skill files
cp "$BLUEPRINT_FLOW_DIR/.claude/skills/blueprint/SKILL.md" "$TARGET_DIR/.claude/skills/blueprint/"
cp "$BLUEPRINT_FLOW_DIR/.claude/skills/hub/SKILL.md" "$TARGET_DIR/.claude/skills/hub/"
cp "$BLUEPRINT_FLOW_DIR/.claude/skills/e2e/SKILL.md" "$TARGET_DIR/.claude/skills/e2e/"

# Copy CLI scripts
cp "$BLUEPRINT_FLOW_DIR/scripts/blueprint-db-cli.sh" "$TARGET_DIR/scripts/"
cp "$BLUEPRINT_FLOW_DIR/scripts/e2e-db-cli.sh" "$TARGET_DIR/scripts/"
chmod +x "$TARGET_DIR/scripts/blueprint-db-cli.sh"
chmod +x "$TARGET_DIR/scripts/e2e-db-cli.sh"

# Copy blueprint schema
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.sql" "$TARGET_DIR/blueprint/"
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.dbml" "$TARGET_DIR/blueprint/"

# Copy e2e schema
cp "$BLUEPRINT_FLOW_DIR/tests/e2e/schema.sql" "$TARGET_DIR/tests/e2e/"
cp "$BLUEPRINT_FLOW_DIR/tests/e2e/schema.dbml" "$TARGET_DIR/tests/e2e/"

# Initialize databases
echo "Initializing databases..."
"$TARGET_DIR/scripts/blueprint-db-cli.sh" init
"$TARGET_DIR/scripts/e2e-db-cli.sh" init

# Create minimal CLAUDE.md if not exists
if [[ ! -f "$TARGET_DIR/CLAUDE.md" ]]; then
    echo "Creating minimal CLAUDE.md..."
    cat > "$TARGET_DIR/CLAUDE.md" << 'CLAUDE_EOF'
# Project Rules

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
