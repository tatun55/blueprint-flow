#!/bin/bash
# Initialize blueprint-flow in a project
# Usage: ./scripts/init.sh [stack] [target_dir]
#
# Stack defaults to "tall-daisy"
# Can be called from either:
#   - $BPF_HOME/scripts/init.sh (symlink mode)
#   - .blueprint-flow/scripts/init.sh (submodule mode)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve symlinks to get actual blueprint-flow directory
BLUEPRINT_FLOW_DIR="$(cd "$(dirname "$SCRIPT_DIR")" && pwd -P)"
STACK="${1:-tall-daisy}"
TARGET_DIR="${2:-.}"

echo "Initializing blueprint-flow with stack: $STACK"
echo "Blueprint-flow location: $BLUEPRINT_FLOW_DIR"

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

# Create .claude directory with internal symlinks
# (real directory required for Claude Code to read settings.json/hooks)
echo "Creating .claude directory..."
if [[ -L "$TARGET_DIR/.claude" ]]; then
    rm "$TARGET_DIR/.claude"
elif [[ -d "$TARGET_DIR/.claude" ]]; then
    echo "Warning: .claude directory exists, backing up to .claude.bak"
    mv "$TARGET_DIR/.claude" "$TARGET_DIR/.claude.bak"
fi
mkdir -p "$TARGET_DIR/.claude"
ln -sf "../$RELATIVE_BPF/.claude.$STACK/skills" "$TARGET_DIR/.claude/skills"
ln -sf "../$RELATIVE_BPF/.claude.$STACK/agents" "$TARGET_DIR/.claude/agents"
ln -sf "../$RELATIVE_BPF/.claude.$STACK/hooks" "$TARGET_DIR/.claude/hooks"
ln -sf "../$RELATIVE_BPF/.claude.$STACK/CLAUDE.md" "$TARGET_DIR/.claude/CLAUDE.md"
ln -sf "../$RELATIVE_BPF/.claude.$STACK/settings.json" "$TARGET_DIR/.claude/settings.json"

# Create project directories
echo "Creating project directories..."
mkdir -p "$TARGET_DIR/blueprint"
mkdir -p "$TARGET_DIR/scripts"

# Copy CLI scripts
echo "Copying CLI scripts..."
cp "$BLUEPRINT_FLOW_DIR/scripts/blueprint-db-cli.sh" "$TARGET_DIR/scripts/"
chmod +x "$TARGET_DIR/scripts/blueprint-db-cli.sh"

# Copy schema files
echo "Copying schema files..."
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.sql" "$TARGET_DIR/blueprint/"
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.dbml" "$TARGET_DIR/blueprint/"

# Initialize databases
echo "Initializing databases..."
"$TARGET_DIR/scripts/blueprint-db-cli.sh" init

# Create minimal CLAUDE.md if not exists
if [[ ! -f "$TARGET_DIR/CLAUDE.md" ]]; then
    echo "Creating CLAUDE.md..."
    cat > "$TARGET_DIR/CLAUDE.md" << 'CLAUDE_EOF'
# Project Rules

## Blueprint Flow

このプロジェクトは blueprint-flow を使用。
核心ルールは `.claude/CLAUDE.md` に定義済み（常時適用）。

/bpf でオーケストレーションを実行可能。

## Project-Specific Rules

(プロジェクト固有ルールをここに追加)
CLAUDE_EOF
fi

# Fix Tailwind CSS config path for tall-daisy stack
CSS_FILE="$TARGET_DIR/resources/css/app.css"
if [[ "$STACK" == "tall-daisy" && -f "$CSS_FILE" ]]; then
    if grep -q '@config "\.\./tailwind\.config\.js"' "$CSS_FILE"; then
        echo "Fixing Tailwind @config path in app.css..."
        sed -i '' 's|@config "\.\./tailwind\.config\.js"|@config "../../tailwind.config.js"|' "$CSS_FILE"
    fi
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
echo ".claude/ -> .blueprint-flow/.claude.$STACK/* (internal symlinks)"
echo ""
echo "Next steps:"
echo "  1. Review/update CLAUDE.md with project-specific rules"
echo "  2. Run /bpf to start development"
