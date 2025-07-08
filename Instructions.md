# Datto RMM Script Type-Specific Best Practices

## Overview

This guide provides targeted advice for the three distinct types of Datto RMM scripts, each with unique requirements and constraints based on their execution patterns and performance requirements.

## 1. Installation Scripts (Applications/Deployment)

### Purpose & Characteristics
- **Primary Use**: Installing software, deploying applications, initial system configuration
- **Execution Pattern**: One-time or occasional deployment
- **Component Category**: Applications
- **Performance Requirements**: More flexible - can run longer processes (up to 30 minutes)

### Allowed Operations
- ✅ `Start-Process -Wait` with known installers/MSIs
- ✅ Network operations for reliable sources
- ✅ CIM operations for software management
- ✅ File downloads with explicit timeouts
- ✅ Registry modifications and system configuration
- ✅ Service installation and configuration

### Best Practices
```powershell
# Example: Software Installation Template
[CmdletBinding()]
param(
    [string]$InstallerPath = $env:InstallerPath,
    [string]$InstallArgs = $env:InstallArgs,
    [int]$TimeoutSeconds = 1800  # 30 minutes
)

# Set TLS 1.2 for downloads
[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)

try {
    # Download with timeout
    if ($InstallerPath -like "http*") {
        $LocalPath = "$env:TEMP\installer.exe"
        Invoke-WebRequest -Uri $InstallerPath -OutFile $LocalPath -TimeoutSec 300
        $InstallerPath = $LocalPath
    }
    
    # Install with timeout protection
    $Process = Start-Process -FilePath $InstallerPath -ArgumentList $InstallArgs -PassThru -NoNewWindow
    if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
        $Process.Kill()
        throw "Installation timeout after $TimeoutSeconds seconds"
    }
    
    # Verify installation
    if ($Process.ExitCode -eq 0) {
        Write-Host "Installation completed successfully"
        Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40000 -Message "Software installation successful"
        exit 0
    } else {
        throw "Installation failed with exit code: $($Process.ExitCode)"
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40002 -Message "Installation failed: $($_.Exception.Message)"
    exit 1
}
```

### Key Restrictions
- Still need timeouts for unknown processes
- Must handle LocalSystem context (no network drives)
- No GUI elements (invisible in LocalSystem)
- Must verify digital signatures for downloaded files

---

## 2. Removal/Modification Scripts (Applications/Remediation)

### Purpose & Characteristics
- **Primary Use**: Uninstalling software, modifying configurations, system cleanup
- **Execution Pattern**: As-needed or periodic remediation
- **Component Category**: Applications or Scripts
- **Performance Requirements**: Balanced approach - timeouts recommended

### Allowed Operations
- ✅ `Start-Process -Wait` for known uninstallers
- ✅ Registry cleanup operations
- ✅ File system modifications and cleanup
- ✅ Service management (stop/start/modify)
- ✅ Process monitoring for critical repairs
- ✅ Configuration file modifications

### Best Practices
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

### Key Restrictions
- Must add timeouts for unknown operations
- Careful with system-critical modifications
- No GUI elements
- Test modifications in non-production first

---

## 3. Monitor Scripts

### Purpose & Characteristics
- **Primary Use**: Checking system status, monitoring services, detecting issues
- **Execution Pattern**: Frequent/continuous (every few minutes)
- **Component Category**: Monitors
- **Performance Requirements**: CRITICAL - Must complete in under 3 seconds

### Critical Performance Rules
- ⚠️ **NEVER** use `Get-WmiObject -Class Win32_Product` (causes MSI repair)
- ⚠️ **NEVER** use long-running processes without timeouts
- ⚠️ **ALWAYS** prefer registry-based detection over WMI
- ⚠️ **ALWAYS** use timeouts for ANY potentially slow operations

### Allowed Operations
- ✅ Registry-based detection (PREFERRED)
- ✅ `Get-CimInstance` with caution and timeout
- ✅ Fast service checks
- ✅ File existence checks
- ✅ Quick performance counter reads

### Monitor Output Format
Monitors must output in specific format:
- `OK: [message]` - Normal status
- `WARNING: [message]` - Warning condition
- `CRITICAL: [message]` - Critical issue

### Best Practices
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

### Software Detection for Monitors
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

### Key Restrictions
- **NEVER** use banned operations (Win32_Product, etc.)
- **ALWAYS** complete within 3 seconds
- **MUST** use proper output format (OK:/WARNING:/CRITICAL:)
- **MUST** use standardized exit codes

---

## Universal Requirements (All Script Types)

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
- **30**: Monitor critical
- **31**: Monitor warning

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

---

## Decision Matrix

| Operation | Monitor | Installation | Removal |
|-----------|---------|-------------|---------|
| `Get-WmiObject Win32_Product` | ❌ NEVER | ❌ NEVER | ❌ NEVER |
| `Get-CimInstance Win32_Product` | ⚠️ With timeout | ✅ OK | ✅ OK |
| `Start-Process -Wait` (known) | ❌ Too slow | ✅ OK | ✅ OK |
| `Start-Process -Wait` (unknown) | ❌ Too slow | ⚠️ Add timeout | ⚠️ Add timeout |
| Registry detection | ✅ PREFERRED | ✅ Good | ✅ Good |
| Network operations | ⚠️ Add timeout | ✅ OK | ✅ OK |

## Quick Reference

### For Installation Scripts:
- Focus on reliability and error handling
- Use appropriate timeouts (up to 30 minutes)
- Verify successful installation
- Handle rollback scenarios

### For Removal/Modification Scripts:
- Test in non-production first
- Create restore points when possible
- Handle partial failures gracefully
- Verify changes were applied

### For Monitor Scripts:
- Speed is critical (< 3 seconds)
- Use registry over WMI
- Proper output format is mandatory
- Fail fast with clear messages