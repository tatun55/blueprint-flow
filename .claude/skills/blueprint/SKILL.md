---
name: blueprint
description: Interactive spec management with human-in-the-loop workflow. Also handles blueprint-flow initialization and updates.
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# Blueprint Spec Manager

Human-in-the-loop spec management with blueprint-flow framework support.

## Command Routing

Parse command argument:
- `/blueprint init` → Initialize blueprint-flow
- `/blueprint update` → Update blueprint-flow
- `/blueprint` (no args) → Spec management

---

## Init Flow (`/blueprint init`)

### Step 1: Stack Selection

```
AskUserQuestion:
  question: "Which stack to use?"
  header: "Stack"
  options:
    - label: "Laravel + Livewire (Recommended)"
      description: "Laravel 12, Livewire 4, Tailwind 4, daisyUI 5"
```

### Step 2: Initialize

If blueprint-flow is already a submodule:
```bash
./.blueprint-flow/scripts/init.sh {stack}
```

If not yet added:
```bash
git submodule add https://github.com/tatun55/blueprint-flow .blueprint-flow
./.blueprint-flow/scripts/init.sh {stack}
```

### Step 3: Report Success

Show initialized files and next steps.

---

## Update Flow (`/blueprint update`)

### Step 1: Check Current Version

```bash
cat .blueprint-flow-version
```

### Step 2: Update Submodule

```bash
cd .blueprint-flow && git pull origin main && cd ..
```

### Step 3: Run Update Script

```bash
./.blueprint-flow/scripts/update.sh
```

### Step 4: Report Changes

Show old vs new version and any notable changes.

---

## Spec Management Flow (no args)

### Initial Check

```bash
./blueprint/db-cli.sh overview
```

If DB not initialized:
```bash
./blueprint/db-cli.sh init
```

### Action Selection

```
AskUserQuestion:
  question: "What would you like to do?"
  header: "Action"
  options:
    - label: "Create New Spec"
      description: "Add a new spec (draft status)"
    - label: "Review Pending"
      description: "Review specs awaiting approval"
    - label: "Update Existing"
      description: "Modify an existing spec"
    - label: "Change Status"
      description: "Move spec through workflow"
    - label: "View Progress"
      description: "Check overall progress"
```

---

## Status Workflow

```
draft → pending_review → approved → in_progress → impl_review → testing → done
                ↑                         ↓
                └──── needs_revision ←────┘
```

### Status Commands

```bash
./blueprint/db-cli.sh status {id} pending_review  # Request review
./blueprint/db-cli.sh status {id} approved        # Human approves
./blueprint/db-cli.sh status {id} needs_revision  # Request changes
./blueprint/db-cli.sh revision {id} 'reason'      # With reason
./blueprint/db-cli.sh lock {id} {agent}           # Start work
./blueprint/db-cli.sh unlock {id}                 # Release lock
```

---

## Create Flow

### Type Selection

```
AskUserQuestion:
  question: "What type of spec to create?"
  header: "Type"
  options:
    - label: "Project Overview"
      description: "App name, features, user roles (core/overview)"
    - label: "Database Table"
      description: "Table with columns and relations (data/tables)"
    - label: "Page Spec"
      description: "UI page definition (ui/pages)"
    - label: "Partial"
      description: "Reusable component (ui/partials)"
    - label: "Layout"
      description: "Page layout (ui/layouts)"
    - label: "Action"
      description: "Business logic (action/sync, async, scheduled)"
    - label: "Seeder Definition"
      description: "Dummy data spec (data/seeders)"
```

### After Creating

New specs start as `draft`. Ask user:

```
AskUserQuestion:
  question: "Spec created. What next?"
  header: "Next"
  options:
    - label: "Submit for Review"
      description: "Set status to pending_review"
    - label: "Continue Editing"
      description: "Make more changes first"
    - label: "Done"
      description: "Leave as draft"
```

If "Submit for Review":
```bash
./blueprint/db-cli.sh status {id} pending_review
```

---

## Review Pending Flow

### Step 1: List Pending

```bash
./blueprint/db-cli.sh pending-review
```

Show specs awaiting review.

### Step 2: Get Spec Details

```bash
./blueprint/db-cli.sh get {category} {type} {slug}
```

Display full spec data to user.

### Step 3: Review Decision

```
AskUserQuestion:
  question: "Review decision for this spec?"
  header: "Decision"
  options:
    - label: "Approve"
      description: "Ready for implementation"
    - label: "Request Changes"
      description: "Needs revision before approval"
    - label: "Skip"
      description: "Review later"
```

If "Approve":
```bash
./blueprint/db-cli.sh status {id} approved
./blueprint/db-cli.sh reviewed {id}
```

If "Request Changes":
```
AskUserQuestion:
  question: "What changes are needed?"
  header: "Reason"
```
Then:
```bash
./blueprint/db-cli.sh revision {id} '{reason}'
```

---

## Update Spec Flow

### Step 1: List and Select

```bash
./blueprint/db-cli.sh overview
```

```
AskUserQuestion:
  question: "Which spec to update? (provide ID)"
  header: "Select"
```

### Step 2: Get Current Data

```bash
./blueprint/db-cli.sh get {category} {type} {slug}
```

### Step 3: Ask What to Update

For tables:
```
AskUserQuestion:
  question: "What to update?"
  header: "Update"
  multiSelect: true
  options:
    - label: "Add columns"
    - label: "Modify columns"
    - label: "Remove columns"
    - label: "Add relations"
```

For pages:
```
AskUserQuestion:
  question: "What to update?"
  header: "Update"
  multiSelect: true
  options:
    - label: "Change route"
    - label: "Add/modify sections"
    - label: "Add/modify actions"
    - label: "Change auth/roles"
```

### Step 4: Merge and Save

```bash
./blueprint/db-cli.sh update {id} '{...merged json...}'
```

Note: Updating resets `human_reviewed` to false.

---

## View Progress Flow

```bash
# Overall progress
./blueprint/db-cli.sh progress

# By status
./blueprint/db-cli.sh available        # Ready to work
./blueprint/db-cli.sh in-progress      # Being worked on
./blueprint/db-cli.sh pending-review   # Awaiting review
./blueprint/db-cli.sh needs-attention  # Needs revision
```

---

## Categories & Types

| Category | Types | Instructor |
|----------|-------|------------|
| `core` | overview, const | (Human) |
| `data` | tables, seeders | db-instructor |
| `ui` | pages, partials, layouts | frontend-instructor |
| `action` | sync, async, scheduled | backend-instructor |

---

## JSON Schemas

### data/tables
```json
{
  "columns": [
    {"name": "id", "type": "id"},
    {"name": "name", "type": "string"},
    {"name": "status", "type": "enum", "enum_values": ["active", "inactive"]}
  ],
  "relations": [
    {"type": "belongsTo", "target": "projects"}
  ],
  "timestamps": true,
  "soft_delete": false
}
```

### ui/pages
```json
{
  "route": "/users",
  "layout": "app",
  "auth": true,
  "roles": ["admin"],
  "sections": [
    {"name": "header", "type": "header", "description": "Title + create button"}
  ],
  "actions": [
    {"name": "create", "trigger": "click"}
  ]
}
```

### action/sync
```json
{
  "name": "CreateUser",
  "description": "Create a new user",
  "input": [
    {"name": "name", "type": "string", "required": true}
  ],
  "output": {"type": "User"},
  "events": ["UserCreated"]
}
```

---

## Rules

1. **Always use AskUserQuestion** at review checkpoints
2. **Show current state** before updates
3. **Validate slugs**: lowercase, underscores only
4. **Preview JSON** before saving
5. **Update status** after each phase change
6. **Human approval required** before implementation starts
