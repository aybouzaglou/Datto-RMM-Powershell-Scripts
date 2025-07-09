# Datto RMM Installation Scripts Guide

## Overview

This guide provides specific guidance for **Installation Scripts** in Datto RMM - scripts designed for installing software, deploying applications, and initial system configuration.

## Purpose & Characteristics

- **Primary Use**: Installing software, deploying applications, initial system configuration
- **Execution Pattern**: One-time or occasional deployment
- **Component Category**: Applications
- **Performance Requirements**: More flexible - can run longer processes (up to 30 minutes)

## Allowed Operations

- ✅ `Start-Process -Wait` with known installers/MSIs
- ✅ Network operations for reliable sources
- ✅ CIM operations for software management
- ✅ File downloads with explicit timeouts
- ✅ Registry modifications and system configuration
- ✅ Service installation and configuration

## Best Practices Template

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

## Key Restrictions

- Still need timeouts for unknown processes
- Must handle LocalSystem context (no network drives)
- No GUI elements (invisible in LocalSystem)
- Must verify digital signatures for downloaded files

## Universal Requirements for Installation Scripts

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

## Quick Reference for Installation Scripts

- Focus on reliability and error handling
- Use appropriate timeouts (up to 30 minutes)
- Verify successful installation
- Handle rollback scenarios

## Related Guides

- [Monitor Scripts Guide](Monitor-Scripts-Guide.md) - For system monitoring and health checks
- [Removal/Modification Scripts Guide](Removal-Modification-Scripts-Guide.md) - For software removal and system cleanup
- [Quick Reference](Quick-Reference.md) - Decision matrix and overview
