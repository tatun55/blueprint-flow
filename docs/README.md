# Blueprint Flow

A 3-layer agent architecture for Claude Code development workflow.

## Overview

Blueprint Flow provides a structured, human-in-the-loop development workflow:

```
Hub Layer     → Lightweight: routing, flow management, review coordination
Instructor    → Domain experts: create task instructions
Coder         → Pure execution: code based on task instructions only
```

## Architecture

### 3-Layer Design

| Layer | Role | Context Size | Reads |
|-------|------|--------------|-------|
| **Hub** | Orchestrate | ~2k tokens | SKILL.md only |
| **Instructor** | Create tasks | ~3k tokens | patterns.md + spec |
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
3. Hub routes spec to appropriate Instructor
4. Instructor creates detailed task (saved to DB)
5. Hub dispatches task to Coder
6. Coder executes task
7. Human reviews implementation
8. Hub triggers E2E tests (for UI specs)
9. Human reviews test results
10. Spec marked as done
```

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
│   └── init.sh              # Project initialization
├── blueprint/
│   ├── schema.sql           # SQLite schema
│   └── schema.dbml          # DBML documentation
├── tests/e2e/
│   ├── schema.sql
│   └── schema.dbml
├── stacks/
│   └── tall-daisy/          # TALL + daisyUI stack patterns
│       ├── config.env       # Path variables
│       ├── patterns.md      # Code patterns
│       └── structure.md     # Directory conventions
└── docs/
    └── README.md            # This file
```

## Installation

### As Git Submodule (Recommended)

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
2. **Review Specs**: Approve or request changes
3. **Run Hub**: Use `/hub` to process approved specs
4. **Review Implementation**: Check generated code
5. **Run E2E**: Test UI components with screenshots

## Spec Categories

| Category | Types | Instructor | E2E |
|----------|-------|------------|-----|
| `core` | overview, const | (Human) | No |
| `data` | tables, seeders | db | No |
| `ui` | pages, partials, layouts | frontend | pages, layouts |
| `action` | sync, async, scheduled | backend | No |

## E2E Test Levels

| Level | Coverage | Content |
|-------|----------|---------|
| 1 | 20-40% | Main use cases |
| 2 | 40-60% | Additional interactions |
| 3 | 60%+ | Edge cases & error states |

## Adding New Stacks

1. Create `stacks/{stack_name}/` directory
2. Add `config.env` with path variables
3. Add `patterns.md` with code patterns
4. Add `structure.md` with directory conventions
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
