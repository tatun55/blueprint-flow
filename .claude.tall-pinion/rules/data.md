# Data Layer Rules
> Model, validation, Actions, queries, data sharing

## Model

- **Slim Model**: relations, scopes, and $casts only
- No business logic in models

## Validation

- Rules defined **inside the Model**

## Action Pattern

- Small logic → directly in Livewire component
- Reusable/complex logic → extract to `app/Actions/`

## Data Sharing

- Livewire standard patterns:
  - Parent → Child: props
  - Child → Parent: dispatch events
  - Between pages: URL parameters / session

## Queries

- **Eloquent** as primary
- **Query Builder** or raw SQL for complex aggregations/reports

## Job / Queue / Event

- **Minimal usage**: only for truly async needs (e.g., email sending)
- Prefer direct calls over Event/Listener pattern
