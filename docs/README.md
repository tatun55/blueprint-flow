# Blueprint Flow

A 3-layer agent architecture for Claude Code development workflow.

## Overview

Blueprint Flow provides a structured, human-in-the-loop development workflow:

```
Hub Layer     → Lightweight: routing, flow management, review coordination
Instructor    → Domain experts: create task instructions (with worktree setup)
Coder         → Pure execution: code in isolated worktree, commit, create PR
```

## Architecture

### 3-Layer Design

| Layer | Role | Context Size | Reads |
|-------|------|--------------|-------|
| **Hub** | Orchestrate | ~2k tokens | SKILL.md only |
| **Instructor** | Create tasks | ~3k tokens | embedded patterns + spec |
| **Coder** | Execute | ~2k tokens | task content only |

### Why 3 Layers?

Token efficiency through context isolation:
- Hub doesn't need domain knowledge → minimal context
- Instructors have domain expertise → specialized context
- Coders don't need rules → task is self-contained

### Flow

```
1. Human creates spec (via /blueprint)
2. Human reviews and approves spec
3. Hub checks dependencies (available-with-deps)
4. Hub routes spec to appropriate Instructor
5. Instructor creates detailed task with worktree instructions
6. Hub dispatches task to Coder
7. Coder creates worktree, executes task, commits, creates PR
8. Human reviews PR (impl_review)
9. If approved: Hub merges worktree to main
10. Hub triggers E2E tests (for UI specs)
11. Human reviews test results
12. Spec marked as done
```

## Key Features

### Dependency Management (blockedBy)

Fine-grained dependency control instead of wave-based ordering:

```bash
# Add dependency: spec 5 is blocked by spec 3
./scripts/blueprint-db-cli.sh add-dep 5 3

# Get available specs (only those with all deps resolved)
./scripts/blueprint-db-cli.sh available-with-deps

# Check what blocks a spec
./scripts/blueprint-db-cli.sh blockers 5
```

### Git Worktree Isolation

Each spec executes in its own worktree for parallel, conflict-free development:

```bash
# Create worktree for spec
./scripts/worktree-manager.sh create {spec_id}

# After PR approval, merge to main
./scripts/worktree-manager.sh merge {spec_id}

# If rejected, discard all changes
./scripts/worktree-manager.sh abort {spec_id}
```

Benefits:
- Parallel execution without file conflicts
- Safe rollback (just delete worktree)
- Clean PR-based review workflow
- Conflict detection at merge time

### Error Handling

Coders report errors with structured format:

```json
{
  "status": "blocked",
  "reason": "dependency_missing",
  "detail": "Model Project not found",
  "blocked_by_suggestion": [5]
}
```

Error types: `instruction_unclear`, `technical_error`, `dependency_missing`, `file_conflict`

## Directory Structure

```
blueprint-flow/
├── .claude/
│   ├── agents/
│   │   ├── instructors/     # Domain expert definitions
│   │   │   ├── db.md        # Database layer
│   │   │   ├── frontend.md  # UI layer
│   │   │   ├── backend.md   # Business logic
│   │   │   └── test.md      # E2E testing
│   │   └── coders/          # Executor definitions
│   │       ├── db.md
│   │       ├── frontend.md
│   │       ├── backend.md
│   │       └── test.md
│   └── skills/
│       ├── blueprint/       # Spec management
│       ├── hub/             # Orchestrator
│       └── e2e/             # E2E testing
├── scripts/
│   ├── blueprint-db-cli.sh  # Spec management CLI
│   ├── e2e-db-cli.sh        # E2E test CLI
│   ├── worktree-manager.sh  # Git worktree operations
│   ├── init.sh              # Project initialization
│   └── update.sh            # Update script
├── blueprint/
│   ├── schema.sql           # SQLite schema (specs, dependencies, tasks)
│   └── schema.dbml          # DBML documentation
├── tests/e2e/
│   ├── schema.sql
│   └── schema.dbml
├── stacks/
│   └── tall-daisy/          # TALL + daisyUI stack patterns
│       ├── config.env       # Path/language variables
│       ├── common/
│       │   └── base.md      # Shared patterns (Livewire, daisyUI)
│       └── instructors/
│           ├── db.md        # Migration, Seeder patterns
│           ├── frontend.md  # Responsive, Alpine.js patterns
│           ├── backend.md   # Action, Event, Job patterns
│           └── test.md      # E2E, Pest patterns
└── docs/
    └── README.md            # This file
```

## Requirements

### Required MCP Servers

| MCP Server | Purpose | Install Command |
|------------|---------|-----------------|
| `playwright-mcp` | E2E screenshots | `claude mcp add playwright-mcp -- npx @executeautomation/playwright-mcp-server` |

```bash
# Verify MCP servers
claude mcp list
# Should show: playwright-mcp: ... - ✓ Connected
```

### Node.js

Node.js 20.19+ or 22.12+ (required for Vite)

```bash
node -v  # Check version
nvm install 22 && nvm use 22  # Upgrade if needed
```

## Installation

### Quick Start (New Project)

```bash
# Setup bpf CLI (one-time)
git clone https://github.com/tatun55/blueprint-flow ~/.blueprint-flow
cp ~/.blueprint-flow/bpf ~/bin/bpf
chmod +x ~/bin/bpf

# Create new project
bpf create-project my-app
```

### As Git Submodule (Existing Project)

```bash
# Add to your project
git submodule add https://github.com/tatun55/blueprint-flow .blueprint-flow

# Initialize with your stack
./.blueprint-flow/scripts/init.sh tall-daisy

# Or use the skill
/blueprint init
```

### Update

```bash
# Pull latest
cd .blueprint-flow && git pull origin main && cd ..

# Apply updates
./.blueprint-flow/scripts/update.sh

# Or use the skill
/blueprint update
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `/blueprint` | Manage specs (create, review, update) |
| `/blueprint init` | Initialize blueprint-flow in project |
| `/blueprint update` | Update to latest blueprint-flow |
| `/hub` | Start orchestrator |
| `/e2e` | Run E2E tests |

### Workflow

1. **Create Specs**: Use `/blueprint` to define what you want to build
2. **Set Dependencies**: Add blockedBy relationships between specs
3. **Review Specs**: Approve or request changes
4. **Run Hub**: Use `/hub` to process approved specs (parallel execution)
5. **Review PRs**: Check generated code in draft PRs
6. **Merge**: Approve to merge worktrees to main
7. **Run E2E**: Test UI components with screenshots

## Spec Categories

| Category | Types | Instructor | E2E |
|----------|-------|------------|-----|
| `core` | overview, const | (Human) | No |
| `data` | tables, seeders | db | No |
| `ui` | pages, partials, layouts | frontend | pages, layouts |
| `action` | sync, async, scheduled | backend | No |

## CLI Quick Reference

```bash
# Progress
./scripts/blueprint-db-cli.sh progress
./scripts/blueprint-db-cli.sh overview

# Available (dependency-aware)
./scripts/blueprint-db-cli.sh available-with-deps
./scripts/blueprint-db-cli.sh pending-review
./scripts/blueprint-db-cli.sh needs-attention

# Dependencies
./scripts/blueprint-db-cli.sh add-dep {spec_id} {blocked_by_id}
./scripts/blueprint-db-cli.sh deps {spec_id}
./scripts/blueprint-db-cli.sh blockers {spec_id}

# Worktree
./scripts/worktree-manager.sh list
./scripts/worktree-manager.sh status {spec_id}
./scripts/worktree-manager.sh merge {spec_id}
./scripts/worktree-manager.sh abort {spec_id}
```

## E2E Test Levels

| Level | Coverage | Content |
|-------|----------|---------|
| 1 | 20-40% | Main use cases |
| 2 | 40-60% | Additional interactions |
| 3 | 60%+ | Edge cases & error states |

## Adding New Stacks

1. Create `stacks/{stack_name}/` directory
2. Add `config.env` with path/language variables
3. Add `common/base.md` with shared patterns
4. Add `instructors/{domain}.md` for each instructor
5. Test with `./scripts/init.sh {stack_name}`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Update relevant files:
   - Agent definitions in `.claude/agents/`
   - Skill definitions in `.claude/skills/`
   - Schemas in `blueprint/` or `tests/e2e/`
4. Test with a sample project
5. Submit a pull request

## License

MIT
