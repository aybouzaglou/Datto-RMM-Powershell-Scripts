# GitHub Copilot Instructions for Datto RMM PowerShell Scripts

This repository contains PowerShell scripts designed for deployment to Datto RMM. When working in this repository, follow these guidelines to maintain consistency and quality.

## Repository Overview

This is a PowerShell scripting repository for Datto RMM automation. Scripts are designed to be deployed directly to Datto RMM components with embedded functions for reliability.

**Key Files:**
- `AGENT.md` - Comprehensive AI agent guidelines (always review first)
- `PSScriptAnalyzerSettings.psd1` - Linting configuration
- `templates/` - Script templates for new components
- `shared-functions/` - Function library for embedding
- `components/` - Actual deployment scripts

## Core Principles

1. **Always Lint**: Run `Invoke-ScriptAnalyzer` with `PSScriptAnalyzerSettings.psd1` before committing
2. **PowerShell 5.0+ Compatibility**: Avoid PowerShell 7+ syntax (ternary operators, `||`, etc.)
3. **Self-Contained Scripts**: Prefer embedding functions from `shared-functions/` over external dependencies
4. **Standard Logging**: Use `Write-RMMLog` for scripts; `Write-Host` ONLY for monitors
5. **Safe Variable Handling**: Always use `Get-RMMVariable` for environment variables

## Script Structure Requirements

### Metadata Headers (Required)
Every script must start with a standard comment block:

```powershell
<#
.SYNOPSIS
    Short description of the script's purpose.

.DESCRIPTION
    Detailed explanation of what the script does.

.COMPONENT
    Category=Scripts ; Level=Medium(3) ; Timeout=300s ; Build=1.0.0

.INPUTS
    Variable1(Type) ; Variable2(Type)

.REQUIRES
    LocalSystem ; PSVersion >=5.0
#>
```

### Embedded Functions
Copy functions from `shared-functions/` into the script region:

```powershell
############################################################################################################
#                                    EMBEDDED FUNCTION LIBRARY                                            #
############################################################################################################

# [Paste content of shared-functions/Core/RMMLogging.ps1 here]
# [Paste content of shared-functions/Core/RMMValidation.ps1 here]
```

## Category-Specific Rules

### Scripts (`components/Scripts/`)
- General automation tasks
- Use `Write-RMMLog` for all output
- Variable handling with `Get-RMMVariable`
- Expected timeout: 300s (5 minutes)

### Applications (`components/Applications/`)
- Software deployment scripts
- Can run up to 30 minutes
- Use `Write-RMMLog` for progress tracking
- Handle installer downloads and validation

### Monitors (`components/Monitors/`)
- Fast diagnostic checks (target: <200ms)
- **CRITICAL**: Use `Write-Host` ONLY (no `Write-RMMLog`)
- **CRITICAL**: Follow exact output contract:
  ```powershell
  Write-Host "<-Start Diagnostic->"
  Write-Host "Checking status..."
  Write-Host "<-End Diagnostic->"
  
  Write-Host "<-Start Result->"
  Write-Host "Status=OK: Description"
  Write-Host "<-End Result->"
  exit 0
  ```

## Code Quality Standards

### Linting Rules
- **No cmdlet aliases**: Use full names (`Get-WmiObject`, not `gwmi`)
- **No empty catch blocks**: Always comment why errors are ignored
- **Scope variables properly**: Use `$script:` instead of `$Global:` (except standard counters)
- **No array concatenation with +=**: Use `[System.Collections.Generic.List[Object]]::new()`

### Variable Handling
```powershell
# ✅ Correct
$TargetFile = Get-RMMVariable -Name "TargetFile" -Required

# ❌ Incorrect
$TargetFile = $env:TargetFile
```

### Logging Standards
```powershell
# ✅ Correct (Scripts/Applications)
Write-RMMLog "Starting process..." -Level Status
Write-RMMLog "Error occurred" -Level Failed
Write-RMMLog "Disk space: 50GB" -Level Metric

# ❌ Incorrect for Scripts/Applications
Write-Host "Starting process..."

# ✅ Correct (Monitors ONLY)
Write-Host "<-Start Diagnostic->"
Write-Host "Checking service..."
Write-Host "<-End Diagnostic->"
```

## Development Workflow

1. **Plan**: Review `AGENT.md` and check `templates/` for appropriate starting point
2. **Select Template**: Choose from templates based on component type
3. **Embed Functions**: Copy needed functions from `shared-functions/`
4. **Develop**: Write script following standards
5. **Lint**: Run `Invoke-ScriptAnalyzer -Path "path/to/script.ps1" -Settings "PSScriptAnalyzerSettings.psd1"`
6. **Fix**: Address all errors and warnings
7. **Verify**: Ensure no hardcoded absolute paths or machine-specific values

## Common Patterns

### Standard Function Imports
Most scripts need these from `shared-functions/`:
- `RMMLogging.ps1` - `Write-RMMLog` function
- `RMMValidation.ps1` - `Get-RMMVariable` and validation helpers

### Error Handling
```powershell
try {
    # Operation
} catch {
    Write-RMMLog "Error: $_" -Level Failed
    exit 1
}
```

### File Operations
```powershell
# Use Test-Path before operations
if (Test-Path -Path $TargetFile) {
    Remove-Item -Path $TargetFile -Force
}
```

## What NOT to Do

- ❌ Use `Write-Host` in Scripts/Applications (use `Write-RMMLog`)
- ❌ Use `Read-Host` (scripts run headless)
- ❌ Create launcher scripts that download code from GitHub
- ❌ Use PowerShell 7+ syntax without version checks
- ❌ Hardcode absolute paths to specific machines
- ❌ Use `+=` for array concatenation (performance issue)
- ❌ Leave empty catch blocks without comments

## Testing and Validation

Before submitting code:
1. Run PSScriptAnalyzer and fix all issues
2. Test with PowerShell 5.1 (minimum supported version)
3. Verify all required functions are embedded
4. Check that environment variables are handled with `Get-RMMVariable`
5. Ensure monitor scripts follow the exact output contract

## Additional Resources

- **AGENT.md** - Comprehensive guidelines for AI agents
- **docs/Function-Reference.md** - Available embedded functions
- **docs/Monitor-Development-Guidelines.md** - Monitor-specific requirements
- **docs/Deployment-Guide.md** - Deployment procedures
- **docs/Datto-RMM-Component-Categories.md** - Component category guide

## Questions?

When uncertain about implementation:
1. Check existing scripts in `components/` for patterns
2. Review relevant template in `templates/`
3. Consult `AGENT.md` for detailed guidance
4. Look for similar examples in the appropriate `components/` subdirectory
