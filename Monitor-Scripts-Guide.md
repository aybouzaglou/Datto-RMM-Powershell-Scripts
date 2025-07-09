# Datto RMM Monitor Scripts Guide

## Overview

This guide provides specific guidance for **Monitor Scripts** in Datto RMM - scripts designed for checking system status, monitoring services, and detecting issues with **CRITICAL** performance requirements.

## Purpose & Characteristics

- **Primary Use**: Checking system status, monitoring services, detecting issues
- **Execution Pattern**: Frequent/continuous (every few minutes)
- **Component Category**: Monitors
- **Performance Requirements**: CRITICAL - Must complete in under 3 seconds

## Critical Performance Rules

- ⚠️ **NEVER** use `Get-WmiObject -Class Win32_Product` (causes MSI repair)
- ⚠️ **NEVER** use long-running processes without timeouts
- ⚠️ **ALWAYS** prefer registry-based detection over WMI
- ⚠️ **ALWAYS** use timeouts for ANY potentially slow operations

## Allowed Operations

- ✅ Registry-based detection (PREFERRED)
- ✅ `Get-CimInstance` with caution and timeout
- ✅ Fast service checks
- ✅ File existence checks
- ✅ Quick performance counter reads

## Monitor Output Format

Monitors must output in specific format:
- `OK: [message]` - Normal status
- `WARNING: [message]` - Warning condition
- `CRITICAL: [message]` - Critical issue

## Best Practices Template

```powershell
# Example: Service Monitor Template
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
        Write-Host "CRITICAL: Service '$ServiceName' not found"
        exit 30  # Monitor Critical
    }
    
    switch ($ServiceCheck.Status) {
        "Running" {
            Write-Host "OK: Service '$ServiceName' is running"
            exit 0
        }
        "Stopped" {
            Write-Host "WARNING: Service '$ServiceName' is stopped"
            exit 31  # Monitor Warning
        }
        default {
            Write-Host "CRITICAL: Service '$ServiceName' status: $($ServiceCheck.Status)"
            exit 30  # Monitor Critical
        }
    }
} catch {
    Write-Host "CRITICAL: Monitor failed - $($_.Exception.Message)"
    exit 30  # Monitor Critical
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

# Usage in monitor
$Software = Get-SoftwareFast -Name "Adobe Reader"
if ($Software) {
    Write-Host "OK: Adobe Reader found - Version: $($Software.DisplayVersion)"
    exit 0
} else {
    Write-Host "CRITICAL: Adobe Reader not installed"
    exit 30
}
```

## Universal Requirements for Monitor Scripts

### LocalSystem Context
- All scripts run as NT AUTHORITY\SYSTEM
- No access to network drives (use UNC paths)
- No GUI elements will be visible
- Limited network access in some environments

### Input Variables
- All input variables are strings (even booleans)
- Access via `$env:VariableName`
- Boolean check: `$env:BoolVar -eq 'true'`

### Exit Codes (Monitor-Specific)
- **0**: Success (OK status)
- **30**: Monitor critical
- **31**: Monitor warning

### Event Logging
```powershell
# Standard event logging
Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40000 -Message "Success message"  # Success
Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40001 -Message "Warning message"  # Warning
Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40002 -Message "Error message"    # Error
```

## Key Restrictions

- **NEVER** use banned operations (Win32_Product, etc.)
- **ALWAYS** complete within 3 seconds
- **MUST** use proper output format (OK:/WARNING:/CRITICAL:)
- **MUST** use standardized exit codes

## Quick Reference for Monitor Scripts

- Speed is critical (< 3 seconds)
- Use registry over WMI
- Proper output format is mandatory
- Fail fast with clear messages

## Related Guides

- [Installation Scripts Guide](Installation-Scripts-Guide.md) - For software deployment and configuration
- [Removal/Modification Scripts Guide](Removal-Modification-Scripts-Guide.md) - For software removal and system cleanup
- [Quick Reference](Quick-Reference.md) - Decision matrix and overview
