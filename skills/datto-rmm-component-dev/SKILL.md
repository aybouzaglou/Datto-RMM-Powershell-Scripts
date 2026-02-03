---
name: datto-rmm-component-dev
description: "Standardize creation, debugging, and validation of Datto RMM components in this repo (components/, shared-functions/, templates/, docs/). Use for: creating new PowerShell (Windows) or Bash (macOS/Linux) components, enforcing Datto monitor output markers and Output Variable formatting, wiring env vars + file attachments, and running local scaffolding/validation via scripts/rmm.py."
---

# Datto RMM Component Dev

## Overview

Use the repo’s conventions to create, debug, and validate Datto RMM components:

- **Windows endpoints**: PowerShell components (`.ps1`)
- **macOS/Linux endpoints**: Bash components (`.sh`)

Prefer **direct deployment** patterns (single-file components with embedded helpers) and keep output consistent and parseable.

## Workflow Decision Tree

### Create a new component

1. Choose target `--os` (`windows|macos|linux`)
2. Choose component `--category` (`applications|scripts|monitors`)
3. Scaffold a new file (kebab-case filename; no spaces):

```bash
python3 skills/datto-rmm-component-dev/scripts/rmm.py scaffold --os windows --category scripts --name "my-task"
python3 skills/datto-rmm-component-dev/scripts/rmm.py scaffold --os macos --category monitors --name "my-monitor" --output-var Status
```

4. Implement logic, then validate monitor output (monitors only) and run locally:

```bash
python3 skills/datto-rmm-component-dev/scripts/rmm.py run --script components/Monitors/macOS/my-monitor.sh --validate-monitor
python3 skills/datto-rmm-component-dev/scripts/rmm.py run --script components/Monitors/my-monitor.ps1 --validate-monitor
```

### Debug an existing component

1. Run locally and capture logs:

```bash
python3 skills/datto-rmm-component-dev/scripts/rmm.py run --script components/Scripts/some-script.ps1 --vars ./vars.env
python3 skills/datto-rmm-component-dev/scripts/rmm.py run --script components/Scripts/Linux/some-script.sh --vars ./vars.env
```

2. If it’s a monitor, validate the output contract:

```bash
python3 skills/datto-rmm-component-dev/scripts/rmm.py validate-monitor-output --input /path/to/stdout.txt --output-var Status
```

3. For repo-wide validation (PowerShell): run `scripts/validate-before-push.ps1` and fix analyzer findings.

### Refactor / standardize a component

- Start from `templates/` as the baseline for structure.
- Prefer embedding shared helpers by copying from `shared-functions/` instead of inventing new variants.
- Follow `AGENT.md` rules (logging, non-interactive scripts, analyzer constraints, monitor output contract).

## Identify Target

Decide these up front:

- **OS**: `windows|macos|linux`
- **Category**: `Applications|Scripts|Monitors`

File placement rules (repo-standard):

- Windows: `components/<Category>/<name>.ps1`
- macOS: `components/<Category>/macOS/<name>.sh`
- Linux: `components/<Category>/Linux/<name>.sh`

## Follow Datto Contracts

### Run context / privileges

Assume components run **elevated**:

- Windows: **LocalSystem**
- macOS/Linux: **root**

Avoid interactive prompts and UI elements; components run headless.

### Monitors: required markers + single result line

Monitors must emit:

- Diagnostic section:
  - `<-Start Diagnostic->`
  - `<-End Diagnostic->`
- Result section:
  - `<-Start Result->`
  - Exactly one line: `Status=...` (or your configured output variable)
  - `<-End Result->`

Match the variable name (default: `Status`) to the Datto RMM monitor’s **Output Variable** setting.

## Use Repo Patterns

### PowerShell components

- Use `Write-RMMLog` for scripts/applications (parseable logs).
- Use `Get-RMMVariable` to read environment variables safely (type conversion + defaults).
- For installers/configs, prefer Datto file attachments and reference by filename in the working directory.
- Avoid launcher scripts that download and execute remote code.

Key references:
- `AGENT.md`
- `docs/Monitor-Development-Guidelines.md`
- `docs/Datto-RMM-Download-Best-Practices.md`
- `docs/Datto-RMM-File-Attachment-Guide.md`

### Bash components (macOS/Linux)

- Use strict mode: `set -euo pipefail`
- Validate inputs early and print actionable diagnostics.
- Prefer vendor downloads + integrity checks; do not curl|bash unknown scripts.
- Keep output stable and machine-parseable; for monitors, follow the exact marker contract.

## Debugging Checklist

- Confirm **category** and **OS** placement (path determines expectations).
- Confirm env vars:
  - Names match the component configuration exactly
  - Types/format match script parsing
- Confirm file attachments:
  - Refer to attached files by **filename**
  - Validate existence and size/hash when relevant
- If monitor:
  - Validate marker ordering
  - Ensure exactly one `Status=...` line in the result block (no spaces around `=`)
  - Ensure exit code aligns with OK vs alert

## Resources

Open these only when needed:

- `references/datto-rmm-contracts.md`: Datto RMM execution + monitor contract reminders
- `references/repo-conventions.md`: repo architecture + validation workflow
- `references/cyberdrain-notes.md`: patterns to emulate (diagnostic-first monitors, defensive scripting)
