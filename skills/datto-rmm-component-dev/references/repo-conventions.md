# Repo Conventions (Datto-RMM-PowerShell-Scripts)

This skill is **repo-specific** and assumes the repository layout and rules defined by `AGENT.md`.

## Layout

- `components/`: deployable components (paste into Datto RMM)
  - `Applications/`: long-running installs
  - `Scripts/`: automation tasks
  - `Monitors/`: fast checks with strict output contract
- `shared-functions/`: approved helper libraries to copy/paste into components
- `templates/`: reference templates for new components
- `docs/`: repository standards and guides
- `scripts/`: local developer helpers (validation, workflows)

## Naming and placement

- New components should use **kebab-case filenames** (no spaces).
- Windows components:
  - `components/Applications/<name>.ps1`
  - `components/Scripts/<name>.ps1`
  - `components/Monitors/<name>.ps1`
- macOS components:
  - `components/<Category>/macOS/<name>.sh`
- Linux components:
  - `components/<Category>/Linux/<name>.sh`

## Logging and output

- Scripts/Applications (PowerShell): use `Write-RMMLog` (parseable output).
- Monitors (PowerShell): use `Write-Host` only, emit required markers, and produce exactly one `Status=...` line inside the result block.
- Monitors (Bash): echo the same marker contract and exactly one `Status=...` line inside the result block.

## Shared helpers

Prefer embedding helpers by copying from:

- `shared-functions/Core/RMMLogging.ps1`
- `shared-functions/Core/RMMValidation.ps1`
- or monitor subsets like `shared-functions/SystemMonitorFunctions.ps1`

Avoid creating new “almost-the-same” helper variants unless required.

## Validation workflow

PowerShell validation:

- Run `scripts/validate-before-push.ps1 -Quick` for syntax + analyzer checks.
- Fix all `Error` severity issues before pushing.

Mac helper:

- `scripts/mac-dev-helper.sh validate` can perform basic structure + syntax checks and prepare “test wrappers”.

## Do-not list (repo rules)

- Do not use `Read-Host` / interactive prompts in deployable components.
- Do not create “launcher” components that pull scripts from GitHub at runtime.
- Do not use `Write-Host` in non-monitor PowerShell components.
- Avoid `+=` on arrays inside `ForEach-Object`; use generic lists.
