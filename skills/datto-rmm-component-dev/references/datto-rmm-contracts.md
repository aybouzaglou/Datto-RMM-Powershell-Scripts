# Datto RMM Contracts (Practical Summary)

This repo targets **direct-deployable components** that are pasted into Datto RMM. Keep contracts simple and explicit.

## OS → language expectation

- **Windows endpoints**: PowerShell (`.ps1`)
- **macOS/Linux endpoints**: Bash (`.sh`)

## Run context / privileges

Assume components run elevated:

- **Windows**: LocalSystem
- **macOS/Linux**: root

Write scripts to be non-interactive and deterministic.

## Environment variables

- Treat Datto “environment variables” as the primary configuration surface for components.
- Read variables safely (defaults + type conversion).
- Fail early on missing required variables with clear diagnostics.

## File attachments

Datto RMM places attached files into the component’s working directory.

- Reference attachments by filename (no absolute paths).
- Validate existence before use.
- Prefer attachment for fixed installers; prefer download for “latest” when the vendor supports stable URLs and you can validate integrity/signature.

## Monitors: marker contract + output variable

Monitors must produce:

1. Diagnostic section:
   - `<-Start Diagnostic->`
   - (diagnostic lines)
   - `<-End Diagnostic->`

2. Result section:
   - `<-Start Result->`
   - exactly one line: `<OutputVariable>=...`
   - `<-End Result->`

Default output variable: `Status`

Constraints:

- No spaces around the equals sign: `Status=OK: ...`
- Do not emit multiple result lines.
- Exit code should reflect OK vs alert (0 for OK, non-zero for alert).
