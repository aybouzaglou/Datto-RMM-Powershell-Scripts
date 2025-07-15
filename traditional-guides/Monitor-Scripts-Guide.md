# Datto RMM Monitor Scripts Guide

## Quick Start
1. [Monitor Script Checklist](#monitor-script-checklist)
2. [Complete Working Example](#complete-monitor-example)
3. [Common Pitfalls](#common-pitfalls)

## Monitor Script Checklist

Before deploying a monitor, verify:
- [ ] Completes in under 3 seconds
- [ ] Uses correct exit codes (0 = OK, any non-zero = Alert)
- [ ] NO Win32_Product WMI/CIM calls
- [ ] Input via `$env:VariableName`
- [ ] Handles missing parameters gracefully
- [ ] **ALWAYS** includes result markers (all monitors are Custom Monitor components)
- [ ] Clear, concise status messages

## Monitor Output Format Requirements

### Result Markers (REQUIRED for ALL Monitors)
**All monitors we create are Custom Monitor components**, so result markers are **ALWAYS REQUIRED**:

```powershell
Write-Host "<-Start Result->"
Write-Host "ALERT: C: drive low – 15.2 GB free"
Write-Host "<-End Result->"
```

**Why they exist:**
- Datto RMM captures all STDOUT, but monitors need concise status text
- Markers let RMM strip away log chatter and show only the delimited text in the "Result" column
- Allows meaningful context for technicians while evaluating exit codes separately

⚠️ **CRITICAL**: Without these markers, the Result field will be blank in the RMM interface!

### Exit Codes for Custom Monitor Components
**Important**: Custom Monitor components have different exit code behavior than regular scripts:

| Exit Code | Monitor Status | Notes |
|-----------|----------------|-------|
| **0** | **OK/Green** (no alert) | Monitor stays healthy |
| **Any non-zero** | **Alert** (severity = Alert Priority setting) | Monitor enters alert state |

**Key Points:**
- Datto RMM does **NOT** distinguish between 1, 2, 30, 31, etc. for monitors
- Any non-zero exit code triggers an alert
- Alert severity is controlled by the monitor's "Alert Priority" setting, not the exit code
- The job itself still shows "Completed" in Job History; only the monitor health changes

## Complete Monitor Examples

### Basic Monitor Example
All our monitors are Custom Monitor components, so they always require result markers:

```powershell
# Monitor: Disk Space Check
[CmdletBinding()]
param(
    [string]$DriveLetter = $env:DriveLetter ?? "C",
    [int]$WarningGB = $env:WarningGB ?? 20,
    [int]$CriticalGB = $env:CriticalGB ?? 10
)

try {
    $Drive = Get-PSDrive $DriveLetter -ErrorAction Stop
    $FreeGB = [math]::Round($Drive.Free / 1GB, 1)

    if ($FreeGB -lt $CriticalGB) {
        Write-Host "<-Start Result->"
        Write-Host "CRITICAL: $DriveLetter`: drive low – $FreeGB GB free"
        Write-Host "<-End Result->"
        exit 1  # Any non-zero triggers alert
    } elseif ($FreeGB -lt $WarningGB) {
        Write-Host "<-Start Result->"
        Write-Host "WARNING: $DriveLetter`: drive getting low – $FreeGB GB free"
        Write-Host "<-End Result->"
        exit 1  # Any non-zero triggers alert
    } else {
        Write-Host "<-Start Result->"
        Write-Host "OK: $DriveLetter`: drive healthy – $FreeGB GB free"
        Write-Host "<-End Result->"
        exit 0  # Only 0 = OK/Green
    }
} catch {
    Write-Host "<-Start Result->"
    Write-Host "ERROR: Cannot check drive $DriveLetter`: - $($_.Exception.Message)"
    Write-Host "<-End Result->"
    exit 1  # Any non-zero triggers alert
}
```

### Service Monitor Example
```powershell
# Monitor: Service Status Check
[CmdletBinding()]
param(
    [string]$ServiceName = $env:ServiceName
)

try {
    $Service = Get-Service -Name $ServiceName -ErrorAction Stop

    if ($Service.Status -eq 'Running') {
        Write-Host "<-Start Result->"
        Write-Host "OK: Service '$ServiceName' is running"
        Write-Host "<-End Result->"
        exit 0  # Only 0 = OK/Green
    } else {
        Write-Host "<-Start Result->"
        Write-Host "ALERT: Service '$ServiceName' is not running - Status: $($Service.Status)"
        Write-Host "<-End Result->"
        exit 1  # Any non-zero triggers alert
    }
} catch {
    Write-Host "<-Start Result->"
    Write-Host "ERROR: Service '$ServiceName' not found - $($_.Exception.Message)"
    Write-Host "<-End Result->"
    exit 1  # Any non-zero triggers alert
}
```

## Common Pitfalls

### Missing Result Markers
❌ **Wrong (all our monitors are Custom Monitor components):**
```powershell
Write-Host "CRITICAL: Disk space low"
exit 1
```
*Result field will be blank in RMM interface*

✅ **Correct (always include result markers):**
```powershell
Write-Host "<-Start Result->"
Write-Host "CRITICAL: Disk space low"
Write-Host "<-End Result->"
exit 1
```

### Using Legacy Exit Codes
❌ **Wrong (legacy thinking from other RMM systems):**
```powershell
Write-Host "<-Start Result->"
Write-Host "WARNING: Disk space getting low"
Write-Host "<-End Result->"
exit 31  # Datto RMM doesn't distinguish between non-zero codes
```

✅ **Correct (simplified exit codes):**
```powershell
Write-Host "<-Start Result->"
Write-Host "WARNING: Disk space getting low"
Write-Host "<-End Result->"
exit 1  # Any non-zero triggers alert; severity set by Alert Priority
```

### Event Log Source Issues
The "Datto-RMM-Script" event source may not exist. Always wrap in try/catch:
```powershell
try {
    Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40000 -Message "Success"
} catch {
    # Silently continue - event logging is optional
}
```

## Overview

This guide provides specific guidance for **Monitor Scripts** in Datto RMM - scripts designed for checking system status, monitoring services, and detecting issues with **CRITICAL** performance requirements.

## Datto RMM Exit Code Behavior Reference

Understanding how exit codes work across different Datto RMM job types is crucial for proper monitoring.

### 1. Script & Application Components, Quick Jobs, Policy Tasks
| Exit code your script returns | How the Datto RMM job is marked | Notes / typical meaning |
|---|---|---|
| **0** | **Completed (Success)** | Everything ran correctly |
| **3010** or **1641** | **Completed – Reboot Required** | Standard Windows MSI codes meaning "success, but a reboot is needed." RMM surfaces the requirement and, if you enabled "Reboot if required," will schedule it |
| **Any other non-zero value** | **Failed** | The component run is flagged red in the Web UI, policy report, and e-mails |

### 2. Custom Monitor Components (ALL our monitors)
| Exit code you return | How the monitor behaves |
|---|---|
| **0** | Monitor stays **OK/Green** (no alert) |
| **Anything else** | Monitor enters **Alert** state (severity = the Alert Priority you set when creating the monitor). Datto RMM does **not** distinguish between 1, 2, 30, 31, etc. |

**Important**: The job itself still shows **Completed** in the device's Job History; only the monitor's health flips to *Alert*.

### 3. Why the rules differ
- **Operational jobs** (scripts, applications, policies) care about *success vs. failure*, so Datto RMM treats almost all non-zero codes as failures—except the two Microsoft-defined reboot codes, which are considered a success that needs follow-up
- **Monitors** are about *state reporting*. Datto RMM only needs to know "healthy" (0) or "unhealthy" (≠0); it ignores the specific number so that any scripting language can be used without a complicated severity mapping

### 4. Recommended best practice
- Always return **0** for success
- For monitors, keep it simple: **0 = OK**, **anything else = Alert**—then control the color/urgency with the monitor's Alert Priority setting rather than the exit code
- If your installer or script detects a required reboot, translate that to **3010** (or **1641**) so Datto RMM can handle it automatically

## Purpose & Characteristics

- **Primary Use**: Checking system status, monitoring services, detecting issues
- **Execution Pattern**: Frequent/continuous (every few minutes)
- **Component Category**: Monitors
- **Performance Requirements**: CRITICAL - Must complete in under 3 seconds

## Requirements

### Performance (CRITICAL)
- Must complete in < 3 seconds
- Use timeouts for any external operations

### PowerShell Version Compatibility
- **PowerShell 2.0**: Use `Get-EventLog` and basic cmdlets only
- **PowerShell 3.0+**: Can use `Get-WinEvent` with `FilterHashtable` for better performance
- **Check version**: `$PSVersionTable.PSVersion.Major` before using advanced features

### Output Format (REQUIRED)
- Wrap output in `<-Start Result->` and `<-End Result->` markers
- Use status prefixes: OK:, WARNING:, CRITICAL:

### Exit Codes
- 0 = OK/Green (no alert)
- Any non-zero = Alert (severity controlled by Alert Priority setting)

## Critical Performance Rules

- ⚠️ **NEVER** use `Get-WmiObject -Class Win32_Product` (causes MSI repair)
- ⚠️ **NEVER** use `Get-CimInstance -ClassName Win32_Product` (causes MSI repair)
- ⚠️ **NEVER** use long-running processes without timeouts
- ⚠️ **ALWAYS** prefer registry-based detection over WMI/CIM
- ⚠️ **ALWAYS** use timeouts for ANY potentially slow operations

## Allowed Operations

- ✅ Registry-based detection (PREFERRED)
- ✅ `Get-CimInstance` for non-Product classes (with timeout)
- ✅ Fast service checks
- ✅ File existence checks
- ✅ Quick performance counter reads

## CIM/WMI Usage Examples

✅ **ALLOWED (with timeout):**

```powershell
# System information
$system = Get-CimInstance -ClassName Win32_ComputerSystem
$manufacturer = $system.Manufacturer

# Service status
$service = Get-CimInstance -ClassName Win32_Service -Filter "Name='Spooler'"

# Disk space
$disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
```

❌ **BANNED:**

```powershell
# Never use Win32_Product - triggers MSI repair
Get-CimInstance -ClassName Win32_Product
Get-WmiObject -Class Win32_Product
```

## Monitor Script Template

All our monitors are Custom Monitor components, so they always require result markers:

```powershell
# Monitor: [Monitor Name]
# Description: [What this monitors]
# Parameters: List expected $env: variables

[CmdletBinding()]
param(
    # Define parameters with defaults from environment
    [string]$Parameter1 = $env:Parameter1,
    [string]$Parameter2 = $env:Parameter2 ?? "default_value"
)

# Constants
$WARNING_THRESHOLD = 80
$CRITICAL_THRESHOLD = 90

try {
    # Validate required parameters
    if ([string]::IsNullOrWhiteSpace($Parameter1)) {
        Write-Host "<-Start Result->"
        Write-Host "ERROR: Parameter1 is required"
        Write-Host "<-End Result->"
        exit 1  # Any non-zero triggers alert
    }

    # Main monitoring logic here (keep it fast!)
    $Result = # Your check here

    # Evaluate results
    if ($Result -gt $CRITICAL_THRESHOLD) {
        Write-Host "<-Start Result->"
        Write-Host "CRITICAL: [Specific message about what's wrong]"
        Write-Host "<-End Result->"
        exit 1  # Any non-zero triggers alert
    }
    elseif ($Result -gt $WARNING_THRESHOLD) {
        Write-Host "<-Start Result->"
        Write-Host "WARNING: [Specific message about what needs attention]"
        Write-Host "<-End Result->"
        exit 1  # Any non-zero triggers alert
    }
    else {
        Write-Host "<-Start Result->"
        Write-Host "OK: [Specific message about what's good]"
        Write-Host "<-End Result->"
        exit 0  # Only 0 = OK/Green
    }

} catch {
    Write-Host "<-Start Result->"
    Write-Host "ERROR: Monitor failed - $($_.Exception.Message)"
    Write-Host "<-End Result->"
    exit 1  # Any non-zero triggers alert
}
```

## Advanced Service Monitor Template

```powershell
# Monitor: Service Status with Timeout
[CmdletBinding()]
param(
    [string]$ServiceName = $env:ServiceName,
    [int]$TimeoutSeconds = 3
)

# Fast timeout wrapper
function Invoke-WithTimeout {
    param(
        [ScriptBlock]$ScriptBlock,
        [int]$TimeoutSeconds = 3
    )

    $Job = Start-Job -ScriptBlock $ScriptBlock
    if (Wait-Job -Job $Job -Timeout $TimeoutSeconds) {
        $Result = Receive-Job -Job $Job
        Remove-Job -Job $Job
        return $Result
    } else {
        Remove-Job -Job $Job -Force
        throw "Operation timed out after $TimeoutSeconds seconds"
    }
}

try {
    $ServiceCheck = Invoke-WithTimeout -TimeoutSeconds $TimeoutSeconds -ScriptBlock {
        # Use registry check first (fastest)
        $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$using:ServiceName"
        if (Test-Path $RegPath) {
            $ServiceData = Get-ItemProperty $RegPath -ErrorAction SilentlyContinue

            # Quick service status check
            $Service = Get-Service -Name $using:ServiceName -ErrorAction SilentlyContinue

            return @{
                Exists = $true
                Status = $Service.Status
                StartType = $ServiceData.Start
                DisplayName = $Service.DisplayName
            }
        } else {
            return @{
                Exists = $false
            }
        }
    }

    if (-not $ServiceCheck.Exists) {
        Write-Host "<-Start Result->"
        Write-Host "ERROR: Service '$ServiceName' not found"
        Write-Host "<-End Result->"
        exit 1  # Any non-zero triggers alert
    }

    switch ($ServiceCheck.Status) {
        "Running" {
            Write-Host "<-Start Result->"
            Write-Host "OK: Service '$ServiceName' is running"
            Write-Host "<-End Result->"
            exit 0  # Only 0 = OK/Green
        }
        "Stopped" {
            Write-Host "<-Start Result->"
            Write-Host "ALERT: Service '$ServiceName' is stopped"
            Write-Host "<-End Result->"
            exit 1  # Any non-zero triggers alert
        }
        default {
            Write-Host "<-Start Result->"
            Write-Host "ALERT: Service '$ServiceName' status: $($ServiceCheck.Status)"
            Write-Host "<-End Result->"
            exit 1  # Any non-zero triggers alert
        }
    }
} catch {
    Write-Host "<-Start Result->"
    Write-Host "ERROR: Monitor failed - $($_.Exception.Message)"
    Write-Host "<-End Result->"
    exit 1  # Any non-zero triggers alert
}
```

## Software Detection for Monitors

```powershell
# Fast software detection for monitors
function Get-SoftwareFast {
    param([string]$Name)

    $RegPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($Path in $RegPaths) {
        try {
            $Software = Get-ChildItem $Path -ErrorAction SilentlyContinue |
                       ForEach-Object { Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue } |
                       Where-Object { $_.DisplayName -like "*$Name*" }

            if ($Software) {
                return $Software
            }
        } catch {
            continue
        }
    }

    return $null
}

# Usage in monitor (all our monitors are Custom Monitor components)
$Software = Get-SoftwareFast -Name "Adobe Reader"
if ($Software) {
    Write-Host "<-Start Result->"
    Write-Host "OK: Adobe Reader found - Version: $($Software.DisplayVersion)"
    Write-Host "<-End Result->"
    exit 0  # Only 0 = OK/Green
} else {
    Write-Host "<-Start Result->"
    Write-Host "ALERT: Adobe Reader not installed"
    Write-Host "<-End Result->"
    exit 1  # Any non-zero triggers alert
}
```

## Testing Your Monitor

### Local Testing
```powershell
# Set test environment variables
$env:ServiceName = "Spooler"
$env:WarningDays = "30"

# Run your script
.\Your-Monitor.ps1

# Check output includes markers
# Check exit code: $LASTEXITCODE
```

### What to Verify
1. **Always**: Output contains `<-Start Result->` and `<-End Result->` (all our monitors are Custom Monitor components)
2. **Always**: Exit code is 0 for OK, any non-zero for alerts
3. **Always**: Completes quickly (use Measure-Command)
4. **Always**: Clear, actionable status messages

## Quick Reference

| Status | Prefix | Exit Code | Use When |
|--------|--------|-----------|----------|
| OK | `OK:` | 0 | Everything is normal |
| Warning | `WARNING:` | 31 | Attention needed soon |
| Critical | `CRITICAL:` | 30 | Immediate action required |

## Banned Operations

| Operation | Why Banned | Alternative |
|-----------|------------|-------------|
| `Get-WmiObject -Class Win32_Product` | Triggers MSI repair | Use registry |
| `Get-CimInstance -ClassName Win32_Product` | Triggers MSI repair | Use registry |
| Long-running operations without timeout | Can hang monitor | Use timeouts |

## Universal Requirements for Monitor Scripts

### LocalSystem Context

- All scripts run as NT AUTHORITY\SYSTEM
- No access to network drives (use UNC paths)
- No GUI elements will be visible
- Limited network access in some environments

### Input Variables

- All input variables are strings (even booleans)
- Access via `$env:VariableName`
- **Boolean parsing**: Use `($env:BoolVar -eq 'true' -or $env:BoolVar -eq '1' -or $env:BoolVar -eq 'yes')`
- **Never use**: `[bool]::Parse($env:BoolVar)` - will throw exceptions on invalid input
- **Integer parsing**: Wrap in try/catch: `try { [int]$env:IntVar } catch { $defaultValue }`

### Exit Codes (Monitor-Specific)

- **0**: Success (OK status)
- **30**: Monitor critical
- **31**: Monitor warning

### Event Logging

```powershell
# Standard event logging (wrap in try/catch)
try {
    Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40000 -Message "Success message"  # Success
    Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40001 -Message "Warning message"  # Warning
    Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40002 -Message "Error message"    # Error
} catch {
    # Silently continue - event logging is optional
}
```

## Key Restrictions

- **NEVER** use banned operations (Win32_Product with any cmdlet, etc.)
- **ALWAYS** complete within 3 seconds
- **MUST** use simplified exit codes (0 = OK, any non-zero = Alert)
- **ALWAYS** wrap output in `<-Start Result->` and `<-End Result->` markers (all our monitors are Custom Monitor components)
- **ALWAYS** control alert severity via Alert Priority setting, not exit code

## Quick Reference for Monitor Scripts

- Speed is critical (< 3 seconds)
- Use registry over WMI
- Result markers are always required (all monitors are Custom Monitor components)
- Simplified exit codes: 0 = OK, anything else = Alert
- Control severity via Alert Priority setting
- Clear, actionable status messages
- Fail fast with meaningful error messages

## Related Guides

- [Installation Scripts Guide](Installation-Scripts-Guide.md) - For software deployment and configuration
- [Removal/Modification Scripts Guide](Removal-Modification-Scripts-Guide.md) - For software removal and system cleanup
- [Quick Reference](Quick-Reference.md) - Decision matrix and overview
