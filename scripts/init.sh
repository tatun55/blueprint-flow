#!/bin/bash
# Blueprint-Flow v2 - Project Initializer
# Usage: ./scripts/init.sh [stack] [target_dir]
#
# Stack defaults to "tall-daisy"
# Initializes .claude symlinks, blueprint DB, and seed data

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve symlinks to get actual blueprint-flow directory
BLUEPRINT_FLOW_DIR="$(cd "$(dirname "$SCRIPT_DIR")" && pwd -P)"
STACK="${1:-tall-daisy}"
TARGET_DIR="${2:-.}"

echo "Initializing blueprint-flow v2 with stack: $STACK"
echo "Blueprint-flow location: $BLUEPRINT_FLOW_DIR"

# Validate stack exists
STACK_DIR="$BLUEPRINT_FLOW_DIR/.claude.$STACK"
if [[ ! -d "$STACK_DIR" ]]; then
    echo "Error: Stack '$STACK' not found"
    echo "Available stacks:"
    ls -1 "$BLUEPRINT_FLOW_DIR" | grep "^\.claude\." | sed 's/^\.claude\./  /'
    exit 1
fi

RELATIVE_BPF=".blueprint-flow"

# ============================================
# Step 1: Create .claude directory with symlinks
# ============================================
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

# ============================================
# Step 2: Create project directories and copy schema
# ============================================
echo "Creating project directories..."
mkdir -p "$TARGET_DIR/blueprint"

echo "Copying schema..."
cp "$BLUEPRINT_FLOW_DIR/blueprint/schema.sql" "$TARGET_DIR/blueprint/"

# ============================================
# Step 3: Store stack info (needed before DB init for seed resolution)
# ============================================
echo "$STACK" > "$TARGET_DIR/.blueprint-flow-stack"
git -C "$BLUEPRINT_FLOW_DIR" rev-parse HEAD 2>/dev/null > "$TARGET_DIR/.blueprint-flow-version" || echo "dev" > "$TARGET_DIR/.blueprint-flow-version"

# ============================================
# Step 4: Initialize database + seed rules
# ============================================
echo "Initializing database..."
(cd "$TARGET_DIR" && bpf db init)

# ============================================
# Step 6: Create minimal CLAUDE.md if not exists
# ============================================
if [[ ! -f "$TARGET_DIR/CLAUDE.md" ]]; then
    echo "Creating CLAUDE.md..."
    cat > "$TARGET_DIR/CLAUDE.md" << 'CLAUDE_EOF'
# Project Rules

## Blueprint Flow

このプロジェクトは blueprint-flow v2 を使用。
核心ルールは `.claude/CLAUDE.md` に定義済み（常時適用）。

/bpf でオーケストレーションを実行可能。

## Project-Specific Rules

(プロジェクト固有ルールをここに追加)
CLAUDE_EOF
fi

# ============================================
# Complete
# ============================================
echo ""
echo "Blueprint-flow v2 initialized successfully!"
echo ""
echo "Stack: $STACK"
echo "Version: $(cat "$TARGET_DIR/.blueprint-flow-version" | head -c 7)"
echo "Database: blueprint/blueprint.db"
echo ""
echo ".claude/ -> .blueprint-flow/.claude.$STACK/* (internal symlinks)"
echo ""
echo "Next steps:"
echo "  1. Review/update CLAUDE.md with project-specific rules"
echo "  2. Run /bpf to start development"
