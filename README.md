# Datto RMM PowerShell Scripts

Self-contained PowerShell scripts for Datto RMM with embedded functions.

## Quick Start

| Task | Location | Documentation |
|------|----------|---------------|
| Find scripts | `components/` | [Component Categories](docs/Datto-RMM-Component-Categories.md) |
| Create scripts | `templates/` | [Templates](#templates) |
| Copy functions | `shared-functions/` | [Function Reference](docs/Function-Reference.md) |
| Deploy | Direct paste to RMM | [Deployment Guide](docs/Deployment-Guide.md) |
| Download files | Modern patterns | [Download Best Practices](docs/Datto-RMM-Download-Best-Practices.md) |

## Architecture

All scripts are self-contained with embedded functions. No network dependencies during execution.

```powershell
# Example embedded function
function Write-RMMLog {
    param([string]$Message, [string]$Level = 'Info')
    Write-Output "[$Level] $Message"
}
```

### Monitor Output Contract (Critical)
For Datto RMM Custom Monitors, output must follow this exact contract so RMM parses results reliably:

- Use Write-Host exclusively (no Write-Output/Write-Verbose)
- Emit exactly one diagnostic section:
  - "<-Start Diagnostic->" ... "<-End Diagnostic->"
- Emit exactly one result section immediately after diagnostics:
  - "<-Start Result->"
  - A single line beginning with "Status=..."
  - "<-End Result->"
- Exit code: 0 for OK, non-zero for alert states

Minimal example:
```powershell
# Diagnostics
Write-Host '<-Start Diagnostic->'
Write-Host 'My Monitor: running checks...'
Write-Host '<-End Diagnostic->'

# Results (single line)
Write-Host '<-Start Result->'
Write-Host 'Status=OK: All checks passed'
Write-Host '<-End Result->'
exit 0
```

Recommended helper pattern (centralized):
```powershell
function Write-MonitorAlert { param([string]$Message)
  Write-Host '<-End Diagnostic->'
  Write-Host '<-Start Result->'
  Write-Host "Status=$Message"
  Write-Host '<-End Result->'
  exit 1
}

function Write-MonitorSuccess { param([string]$Message)
  Write-Host '<-End Diagnostic->'
  Write-Host '<-Start Result->'
  Write-Host "Status=$Message"
  Write-Host '<-End Result->'
  exit 0
}
```

## Repository Structure

```
components/
├── Applications/    # Software deployment scripts
├── Monitors/        # System monitoring scripts
└── Scripts/         # General automation scripts

shared-functions/    # Function patterns to copy/paste
templates/          # Script templates
docs/              # Documentation
```

## Available Scripts

### Applications
- `ScanSnapHome.ps1` - ScanSnap Home installation

### Scripts
- `FocusedDebloat.ps1` - Windows bloatware removal
- `Setup-TestDevice.ps1` - Test device configuration

## Templates

- `SelfContainedApplication-Template.ps1` - Application script template
- `SelfContainedScript-Template.ps1` - General script template
- `DirectDeploymentMonitor-Template.ps1` - Monitor script template

## Usage

1. Copy script content from `components/`
2. Paste directly into Datto RMM component
3. Set environment variables as needed
4. Deploy





## Documentation

- [Deployment Guide](docs/Deployment-Guide.md) - How to deploy scripts
- [Function Reference](docs/Function-Reference.md) - Available function patterns
- [Best Practices](docs/Function-Reference.md#best-practices) - **Critical PowerShell development guidelines**
- [Component Categories](docs/Datto-RMM-Component-Categories.md) - RMM component types
- [File Attachment Guide](docs/Datto-RMM-File-Attachment-Guide.md) - Using file attachments


