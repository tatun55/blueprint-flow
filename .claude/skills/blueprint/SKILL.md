---
name: blueprint
description: Interactive spec management with human-in-the-loop workflow. Also handles blueprint-flow initialization and updates.
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# Blueprint Spec Manager

Human-in-the-loop spec management with blueprint-flow framework support.

## Command Routing

Parse command argument:
- `/blueprint init` → Initialize blueprint-flow in project
- `/blueprint develop` → Develop/improve blueprint-flow framework (interactive)
- `/blueprint pull` → Pull latest blueprint-flow from remote
- `/blueprint` (no args) → Spec management

---

## Init Flow (`/blueprint init`)

<workflow name="init">
  <step id="select_stack">
    <prompt>Which stack to use?</prompt>
    <options>
      - Laravel + Livewire (Recommended): Laravel 12, Livewire 4, Tailwind 4, daisyUI 5
    </options>
  </step>

  <conditional id="check_submodule">
    <branch condition="submodule_exists">
      <bash>./.blueprint-flow/scripts/init.sh {stack}</bash>
    </branch>
    <branch condition="not_exists">
      <bash>git submodule add https://github.com/tatun55/blueprint-flow .blueprint-flow</bash>
      <bash>./.blueprint-flow/scripts/init.sh {stack}</bash>
    </branch>
  </conditional>

  <step id="report">
    <action>Show initialized files and next steps</action>
  </step>
</workflow>

---

## Develop Flow (`/blueprint develop`)

<workflow name="develop">
  <step id="read_spec">
    <read>.blueprint-flow/docs/SPECIFICATION.md</read>
    <action>Understand architecture, design principles, extension points</action>
  </step>

  <step id="select_improvement">
    <prompt>What would you like to improve?</prompt>
    <options>
      - Add New Feature: New capability (agent, skill, stack, etc.)
      - Fix Bug: Correct an issue in existing functionality
      - Refactor: Improve code quality without changing behavior
      - Update Documentation: Improve SPECIFICATION.md or other docs
      - Add New Stack: Support for a new framework (Rails, Next.js, etc.)
    </options>
  </step>

  <step id="gather_details">
    <prompt>Describe the improvement in detail</prompt>
  </step>

  <step id="review_files">
    <mapping>
      <route improvement="Add Feature" files="Related SKILL.md, agent files"/>
      <route improvement="Fix Bug" files="Affected component files"/>
      <route improvement="Refactor" files="Target files"/>
      <route improvement="Documentation" files="docs/*.md"/>
      <route improvement="New Stack" files="stacks/tall-daisy/* (as reference)"/>
    </mapping>
  </step>

  <step id="propose_changes">
    <prompt>Proceed with these changes?</prompt>
    <options>
      - Yes, apply changes: Make the changes and commit
      - Modify approach: Discuss alternative approach
      - Cancel: Abort without changes
    </options>
  </step>

  <conditional id="apply">
    <branch condition="Yes">
      <action>Make changes to files in .blueprint-flow/</action>
      <action>Update SPECIFICATION.md if architecture changed</action>
      <bash>cd .blueprint-flow && git add -A && git commit -m "{message}" && git push origin main && cd ..</bash>
      <bash>./.blueprint-flow/scripts/update.sh</bash>
    </branch>
    <branch condition="Modify">
      <action>Discuss alternative approach</action>
      <goto>propose_changes</goto>
    </branch>
    <branch condition="Cancel">
      <action>Abort without changes</action>
    </branch>
  </conditional>
</workflow>

---

## Pull Flow (`/blueprint pull`)

<workflow name="pull">
  <step id="check_version">
    <bash>cat .blueprint-flow-version</bash>
  </step>

  <step id="pull">
    <bash>cd .blueprint-flow && git pull origin main && cd ..</bash>
  </step>

  <step id="apply">
    <bash>./.blueprint-flow/scripts/update.sh</bash>
  </step>

  <step id="report">
    <action>Show old vs new version and notable changes</action>
  </step>
</workflow>

---

## Spec Management Flow (no args)

<workflow name="spec_management">
  <step id="initial_check">
    <bash>./scripts/blueprint-db-cli.sh overview</bash>
    <conditional>
      <branch condition="db_not_initialized">
        <bash>./scripts/blueprint-db-cli.sh init</bash>
      </branch>
    </conditional>
  </step>

  <step id="action_selection">
    <prompt>What would you like to do?</prompt>
    <options>
      - Create New Spec: Add a new spec (draft status)
      - Review Pending: Review specs awaiting approval
      - Update Existing: Modify an existing spec
      - Change Status: Move spec through workflow
      - View Progress: Check overall progress
    </options>
  </step>

  <conditional id="route_action">
    <branch condition="Create New Spec">
      <goto>create_flow</goto>
    </branch>
    <branch condition="Review Pending">
      <goto>review_flow</goto>
    </branch>
    <branch condition="Update Existing">
      <goto>update_flow</goto>
    </branch>
    <branch condition="Change Status">
      <goto>status_flow</goto>
    </branch>
    <branch condition="View Progress">
      <goto>progress_flow</goto>
    </branch>
  </conditional>
</workflow>

---

## Status Workflow

<state_machine name="spec_status">
  <state name="draft" type="initial">
    <transition to="pending_review" trigger="human_submits"/>
  </state>

  <state name="pending_review">
    <transition to="approved" trigger="human_approves"/>
    <transition to="needs_revision" trigger="human_requests_changes"/>
  </state>

  <state name="approved">
    <transition to="in_progress" trigger="agent_locks"/>
  </state>

  <state name="in_progress">
    <transition to="impl_review" trigger="coder_completes"/>
    <transition to="blocked" trigger="coder_blocked"/>
  </state>

  <state name="impl_review">
    <transition to="testing" trigger="human_approves"/>
    <transition to="needs_revision" trigger="human_requests_changes"/>
  </state>

  <state name="testing">
    <transition to="done" trigger="tests_pass"/>
    <transition to="needs_revision" trigger="tests_fail"/>
  </state>

  <state name="needs_revision" type="recovery">
    <transition to="pending_review" trigger="spec_updated"/>
  </state>

  <state name="blocked" type="recovery">
    <transition to="approved" trigger="dependency_resolved"/>
  </state>

  <state name="done" type="terminal"/>
</state_machine>

### Status Commands

```bash
./scripts/blueprint-db-cli.sh status {id} pending_review  # Request review
./scripts/blueprint-db-cli.sh status {id} approved        # Human approves
./scripts/blueprint-db-cli.sh status {id} needs_revision  # Request changes
./scripts/blueprint-db-cli.sh revision {id} 'reason'      # With reason
./scripts/blueprint-db-cli.sh lock {id} {agent}           # Start work
./scripts/blueprint-db-cli.sh unlock {id}                 # Release lock
```

---

## Create Flow

<workflow name="create_flow">
  <step id="select_type">
    <prompt>What type of spec to create?</prompt>
    <options>
      - Project Overview: App name, features, user roles (core/overview)
      - Database Table: Table with columns and relations (data/tables)
      - Page Spec: UI page definition (ui/pages)
      - Partial: Reusable component (ui/partials)
      - Layout: Page layout (ui/layouts)
      - Action: Business logic (action/sync, async, scheduled)
      - Seeder Definition: Dummy data spec (data/seeders)
    </options>
  </step>

  <step id="gather_data">
    <action>Collect spec details based on type</action>
    <action>Validate slug: lowercase, underscores only</action>
    <action>Preview JSON before saving</action>
  </step>

  <step id="save">
    <bash>./scripts/blueprint-db-cli.sh add {category} {type} {slug} '{name}' '{json}'</bash>
    <output>Spec created with status=draft</output>
  </step>

  <step id="next_action">
    <prompt>Spec created. What next?</prompt>
    <options>
      - Submit for Review: Set status to pending_review
      - Continue Editing: Make more changes first
      - Done: Leave as draft
    </options>
  </step>

  <conditional id="handle_next">
    <branch condition="Submit for Review">
      <bash>./scripts/blueprint-db-cli.sh status {id} pending_review</bash>
    </branch>
    <branch condition="Continue Editing">
      <goto>gather_data</goto>
    </branch>
    <branch condition="Done">
      <action>Exit</action>
    </branch>
  </conditional>
</workflow>

---

## Review Pending Flow

<workflow name="review_flow">
  <step id="list_pending">
    <bash>./scripts/blueprint-db-cli.sh pending-review</bash>
  </step>

  <loop for_each="pending_specs">
    <step id="get_details">
      <bash>./scripts/blueprint-db-cli.sh get {category} {type} {slug}</bash>
      <action>Display full spec data to user</action>
    </step>

    <step id="decision">
      <prompt>Review decision for this spec?</prompt>
      <options>
        - Approve: Ready for implementation
        - Request Changes: Needs revision before approval
        - Skip: Review later
      </options>
    </step>

    <conditional id="handle_decision">
      <branch condition="Approve">
        <bash>./scripts/blueprint-db-cli.sh status {id} approved</bash>
        <bash>./scripts/blueprint-db-cli.sh reviewed {id}</bash>
      </branch>
      <branch condition="Request Changes">
        <prompt>What changes are needed?</prompt>
        <bash>./scripts/blueprint-db-cli.sh revision {id} '{reason}'</bash>
      </branch>
      <branch condition="Skip">
        <action>Continue to next spec</action>
      </branch>
    </conditional>
  </loop>
</workflow>

---

## Update Spec Flow

<workflow name="update_flow">
  <step id="list_specs">
    <bash>./scripts/blueprint-db-cli.sh overview</bash>
  </step>

  <step id="select_spec">
    <prompt>Which spec to update? (provide ID)</prompt>
  </step>

  <step id="get_current">
    <bash>./scripts/blueprint-db-cli.sh get {category} {type} {slug}</bash>
  </step>

  <conditional id="update_type">
    <branch condition="type=tables">
      <prompt multiSelect="true">What to update?</prompt>
      <options>
        - Add columns
        - Modify columns
        - Remove columns
        - Add relations
      </options>
    </branch>
    <branch condition="type=pages">
      <prompt multiSelect="true">What to update?</prompt>
      <options>
        - Change route
        - Add/modify sections
        - Add/modify actions
        - Change auth/roles
      </options>
    </branch>
  </conditional>

  <step id="apply_changes">
    <action>Merge changes with current data</action>
    <action>Preview JSON before saving</action>
    <bash>./scripts/blueprint-db-cli.sh update {id} '{...merged json...}'</bash>
    <note>Updating resets human_reviewed to false</note>
  </step>
</workflow>

---

## View Progress Flow

```bash
# Overall progress
./scripts/blueprint-db-cli.sh progress

# By status
./scripts/blueprint-db-cli.sh available        # Ready to work
./scripts/blueprint-db-cli.sh in-progress      # Being worked on
./scripts/blueprint-db-cli.sh pending-review   # Awaiting review
./scripts/blueprint-db-cli.sh needs-attention  # Needs revision
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
