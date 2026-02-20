# Auth & Authorization
> Custom auth, Policy + Gate, role column

## Authentication

- **Custom implementation** (no Breeze/Jetstream)

## Authorization

- **Policy** (model-bound) + **Gate** (global permissions) combined
- Check via `$this->authorize()` / `Gate::allows()`

## Permission Management

- Managed via `role` column on `users` table
- Role values defined in core config
