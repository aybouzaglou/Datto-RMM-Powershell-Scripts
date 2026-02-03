# CyberDrain-inspired patterns (notes)

These are high-level patterns to emulate when building Datto RMM components. Treat as inspiration, not a verbatim spec.

## Diagnostic-first monitors

- Always print diagnostics first, then a single result line.
- Use small helper functions that:
  1) close `<-End Diagnostic->`
  2) open `<-Start Result->`
  3) write exactly one `Status=...` (or configured output variable) line
  4) close `<-End Result->` and exit with the correct code

This keeps monitors debuggable and consistent.

## Defensive scripting

- Validate inputs early; fail with actionable messages.
- Prefer registry/filesystem checks over slow or side-effectful queries.
- Keep the “happy path” clear and keep error-handling explicit.

## Collections in PowerShell

Avoid `+=` on arrays inside pipeline loops; use a generic list and `.Add()` when building collections inside `ForEach-Object`.

## Keep deployable components self-contained

- Embed required helpers so the component behaves identically on endpoints.
- Avoid runtime downloads of scripts (download installers/resources from vendors only, with validation).
