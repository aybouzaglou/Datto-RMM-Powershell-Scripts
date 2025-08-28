# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository Overview

This is a **Datto RMM PowerShell Scripts** repository containing self-contained PowerShell scripts for Datto RMM with embedded functions. All scripts are designed for direct deployment to Datto RMM components without external dependencies during execution.

## Key Architecture Principles

### Self-Contained Design
- **All functions are embedded directly in each script**
- No external imports or dot-sourcing
- Scripts are copied from `components/` and pasted directly into Datto RMM to create components

### Direct Deployment Model
- Copy entire script content from `components/` directory
- Paste directly into Datto RMM component interface
- Configure environment variables as needed
- Deploy to target devices

## Common Development Commands

### Script Development Workflow
```bash
# Create new script with proper branching and templates
./scripts/new-script-workflow.ps1 -ScriptName "MyScript" -ScriptType "Script" -Action "new"

# Validate scripts before pushing
./scripts/validate-before-push.ps1 -Quick    # Syntax + critical checks
./scripts/validate-before-push.ps1 -Full     # Comprehensive validation

# Install git hooks for validation
./scripts/install-git-hooks.ps1
```

### Testing Scripts Locally
```powershell
# Test syntax validation for all scripts
Get-ChildItem -Filter "*.ps1" -Recurse | ForEach-Object {
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $_.FullName -Raw), [ref]$null)
        Write-Host "✅ $($_.Name)" -ForegroundColor Green
    } catch {
        Write-Host "❌ $($_.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Run PSScriptAnalyzer on a specific script
Invoke-ScriptAnalyzer -Path "components/Scripts/MyScript.ps1" -Severity Error
```

### Working with Templates
```powershell
# Copy template for new application script
Copy-Item "templates/SelfContainedApplication-Template.ps1" "components/Applications/MyApp.ps1"

# Copy template for new monitor
Copy-Item "templates/DirectDeploymentMonitor-Template.ps1" "components/Monitors/MyMonitor.ps1"
```

## Architecture Overview

### Directory Structure
```
components/
├── Applications/    # Software deployment scripts (up to 30 min timeout)
├── Scripts/         # General automation scripts (flexible timeout)  
└── monitors/        # System monitoring scripts (<200ms target)

shared-functions/    # Function patterns to copy into scripts
├── Core/           # Essential functions (RMMLogging, RMMValidation, etc.)
└── Utilities/      # Helper functions (FileOperations, NetworkUtils, etc.)

templates/          # Script templates for different component types
docs/              # Documentation and best practices
scripts/           # Development workflow helpers
```

### Component Categories
- **Applications**: Software deployment/management, up to 30 minutes execution, changeable category
- **Scripts**: General automation/maintenance, flexible timeout, changeable category  
- **Monitors**: System health monitoring, <200ms execution target, diagnostic-first architecture

### Embedded Function Architecture
Instead of importing functions, copy needed functions from `shared-functions/` into your script:

```powershell
############################################################################################################
#                                    EMBEDDED FUNCTION LIBRARY                                            #
############################################################################################################

function Write-RMMLog {
    param([string]$Message, [string]$Level = 'Info')
    $prefix = switch ($Level) {
        'Success' { 'SUCCESS ' }
        'Failed'  { 'FAILED  ' }
        'Warning' { 'WARNING ' }
        default   { 'INFO    ' }
    }
    Write-Output "$prefix$Message"
}

# ... other embedded functions ...

############################################################################################################
#                                    MAIN SCRIPT LOGIC                                                    #
############################################################################################################

# Your script logic here
```

## Monitor Development Patterns

### Critical Requirements for Monitors
- **Execution time**: Target <200ms, maximum 3 seconds
- **Output method**: Use `Write-Host` for ALL output (never mix with `Write-Output`)
- **Result markers**: Required for proper RMM integration
- **Direct deployment only**: No launchers for performance reasons

### Monitor Output Contract (Required)
- Use Write-Host only
- Single diagnostic block: "<-Start Diagnostic->" ... "<-End Diagnostic->"
- Single result block: "<-Start Result->" then exactly one line beginning with "Status=", then "<-End Result->"
- Exit code 0 for OK, non-zero for alert

### Monitor Template Pattern
```powershell
# Diagnostic phase
Write-Host '<-Start Diagnostic->'
Write-Host "Monitor Name: Performing system checks..."
Write-Host "- Checking system state..."

# ... diagnostics here ...

# Do NOT end result here. Close diagnostics just before writing results

# Result phase (single line result)
Write-Host '<-End Diagnostic->'
Write-Host '<-Start Result->'
if ($healthy) {
    Write-Host "Status=OK: System is healthy"
    exit 0
} else {
    Write-Host "Status=CRITICAL: Issue detected"
    exit 1
}
Write-Host '<-End Result->'
```

### Centralized Result Helpers (Recommended)
```powershell
function Write-MonitorAlert {
  param([string]$Message)
  Write-Host '<-End Diagnostic->'
  Write-Host '<-Start Result->'
  Write-Host "Status=$Message"
  Write-Host '<-End Result->'
  exit 1
}

function Write-MonitorSuccess {
  param([string]$Message)
  Write-Host '<-End Diagnostic->'
  Write-Host '<-Start Result->'
  Write-Host "Status=$Message"
  Write-Host '<-End Result->'
  exit 0
}
```

### Centralized Alert Functions
```powershell
function Write-MonitorAlert {
    param([string]$Message)
    Write-Host '<-End Diagnostic->'
    Write-Host '<-Start Result->'
    Write-Host "X=$Message"
    Write-Host '<-End Result->'
    exit 1
}
```

## Critical Development Rules

### Array Handling (Critical PowerShell Pitfall)
**Never use `+=` with arrays in loops - use Generic Lists instead:**

```powershell
# ❌ WRONG - Unreliable due to scoping issues
$foundItems = @()
Get-ChildItem | ForEach-Object {
    $foundItems += $_  # May result in empty array
}

# ✅ CORRECT - Always reliable
$foundItems = [System.Collections.Generic.List[object]]::new()
Get-ChildItem | ForEach-Object {
    $foundItems.Add($_)  # Always works correctly
}
```

### Error Handling Best Practices
- Use global try-catch around entire script
- Handle non-critical errors gracefully (continue execution)
- Only terminate on critical errors (missing required files, permissions)
- Use robust logging functions that handle edge cases

### Launcher Cache Standards
- **Use 5 minutes or less** for all cache timeouts
- **Always try download first** - use cache only as fallback
- Avoid long cache times (60+ minutes) that cause stale script issues

## Validation and Quality Standards

### Banned Operations in Datto RMM
- `Get-WmiObject Win32_Product` - Use registry-based detection instead
- `Get-CimInstance Win32_Product` - Performance issues
- Interactive elements: `Read-Host`, `Get-Credential`, Windows Forms
- Mixed output methods in monitors

### PSScriptAnalyzer Rules
Scripts must pass PSScriptAnalyzer validation with no critical errors:
```powershell
Invoke-ScriptAnalyzer -Path "script.ps1" -Severity Error
```

### File Attachments
For Applications requiring installer files:
- Use Datto RMM's file attachment feature
- Reference files by name only (e.g., `"installer.msi"`)
- Files automatically available in working directory

## Documentation References

Key documentation files in the repository:
- `docs/Function-Reference.md` - Complete function library with examples
- `docs/Deployment-Guide.md` - Step-by-step deployment instructions
- `docs/Monitor-Development-Guidelines.md` - Monitor-specific best practices
- `docs/Datto-RMM-Download-Best-Practices.md` - Modern download patterns

## Development Workflow

1. **Create feature branch**: Use `new-script-workflow.ps1` for proper branching
2. **Copy functions**: Embed needed functions from `shared-functions/` 
3. **Validate locally**: Run `validate-before-push.ps1` before committing
4. **Test deployment**: Test on development devices before production
5. **Monitor performance**: Especially for monitors (<200ms target)

## Environment Variables

Scripts use Datto RMM environment variables for configuration:
```powershell
# Example patterns for environment variable handling
$CustomPath = Get-RMMVariable -Name "CustomPath" -Default "C:\Temp"
$EnableDebug = Get-RMMVariable -Name "EnableDebug" -Type "Boolean" -Default $false
$Timeout = Get-RMMVariable -Name "Timeout" -Type "Integer" -Default 300
```

## Deployment Method

**All components use direct deployment:**
1. Copy entire script content from `components/` directory
2. Paste directly into Datto RMM component interface  
3. Set environment variables as needed in RMM interface
4. Save and deploy to target devices
