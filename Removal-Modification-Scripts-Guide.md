# Datto RMM Removal/Modification Scripts Guide

## Overview

This guide provides specific guidance for **Removal/Modification Scripts** in Datto RMM - scripts designed for uninstalling software, modifying configurations, and system cleanup.

## Purpose & Characteristics

- **Primary Use**: Uninstalling software, modifying configurations, system cleanup
- **Execution Pattern**: As-needed or periodic remediation
- **Component Category**: Applications or Scripts
- **Performance Requirements**: Balanced approach - timeouts recommended

## Allowed Operations

- ✅ `Start-Process -Wait` for known uninstallers
- ✅ Registry cleanup operations
- ✅ File system modifications and cleanup
- ✅ Service management (stop/start/modify)
- ✅ Process monitoring for critical repairs
- ✅ Configuration file modifications

## Best Practices Template

```powershell
# Example: Software Removal Template
[CmdletBinding()]
param(
    [string]$SoftwareName = $env:SoftwareName,
    [switch]$ForceRemoval = ($env:ForceRemoval -eq 'true'),
    [int]$TimeoutSeconds = 300  # 5 minutes
)

function Remove-Software {
    param([string]$Name, [bool]$Force)
    
    $Results = @()
    
    # Check registry first (fast)
    $RegPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($Path in $RegPaths) {
        $Software = Get-ItemProperty $Path -ErrorAction SilentlyContinue | 
                   Where-Object { $_.DisplayName -like "*$Name*" }
        
        foreach ($App in $Software) {
            if ($App.UninstallString) {
                Write-Host "Found: $($App.DisplayName)"
                
                # Parse uninstall string
                if ($App.UninstallString -match '^"([^"]+)"') {
                    $UninstallPath = $matches[1]
                    $UninstallArgs = $App.UninstallString.Substring($matches[0].Length).Trim()
                } else {
                    $UninstallPath = $App.UninstallString
                    $UninstallArgs = ""
                }
                
                # Add quiet flags
                if ($UninstallArgs -notmatch "/quiet|/silent|/S") {
                    $UninstallArgs += " /quiet /norestart"
                }
                
                # Execute uninstall with timeout
                try {
                    $Process = Start-Process -FilePath $UninstallPath -ArgumentList $UninstallArgs -PassThru -NoNewWindow
                    if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
                        $Process.Kill()
                        throw "Uninstall timeout"
                    }
                    
                    $Results += @{
                        Name = $App.DisplayName
                        Success = ($Process.ExitCode -eq 0)
                        ExitCode = $Process.ExitCode
                    }
                } catch {
                    $Results += @{
                        Name = $App.DisplayName
                        Success = $false
                        Error = $_.Exception.Message
                    }
                }
            }
        }
    }
    
    return $Results
}

try {
    $RemovalResults = Remove-Software -Name $SoftwareName -Force $ForceRemoval
    
    if ($RemovalResults.Count -eq 0) {
        Write-Host "No software found matching: $SoftwareName"
        exit 0
    }
    
    $SuccessCount = ($RemovalResults | Where-Object Success).Count
    $TotalCount = $RemovalResults.Count
    
    Write-Host "Removal completed: $SuccessCount/$TotalCount successful"
    Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40000 -Message "Software removal: $SuccessCount/$TotalCount successful"
    
    if ($SuccessCount -eq $TotalCount) {
        exit 0
    } else {
        exit 1
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40002 -Message "Removal failed: $($_.Exception.Message)"
    exit 2
}
```

## Key Restrictions

- Must add timeouts for unknown operations
- Careful with system-critical modifications
- No GUI elements
- Test modifications in non-production first

## Universal Requirements for Removal/Modification Scripts

### LocalSystem Context

- All scripts run as NT AUTHORITY\SYSTEM
- No access to network drives (use UNC paths)
- No GUI elements will be visible
- Limited network access in some environments

### Input Variables

- All input variables are strings (even booleans)
- Access via `$env:VariableName`
- Boolean check: `$env:BoolVar -eq 'true'`

### Exit Codes

- **0**: Success
- **1**: Success with warnings
- **2**: Partial success
- **10**: Permission error
- **11**: Timeout error
- **12**: Configuration error

### Event Logging

```powershell
# Standard event logging
Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40000 -Message "Success message"  # Success
Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40001 -Message "Warning message"  # Warning
Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40002 -Message "Error message"    # Error
```

### Security Requirements

- Set TLS 1.2: `[Net.ServicePointManager]::SecurityProtocol = 3072`
- Verify SHA-256 hashes for downloads
- Use digital signature verification when possible

## Quick Reference for Removal/Modification Scripts

- Test in non-production first
- Create restore points when possible
- Handle partial failures gracefully
- Verify changes were applied

## Related Guides

- [Installation Scripts Guide](Installation-Scripts-Guide.md) - For software deployment and configuration
- [Monitor Scripts Guide](Monitor-Scripts-Guide.md) - For system monitoring and health checks
- [Quick Reference](Quick-Reference.md) - Decision matrix and overview
