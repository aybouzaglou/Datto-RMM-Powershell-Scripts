# Datto RMM PowerShell Scripts - Quick Reference

## Overview

This repository contains comprehensive guides for the three distinct types of Datto RMM scripts, each with unique requirements and constraints based on their execution patterns and performance requirements.

## Script Type Guides

### 📦 [Installation Scripts Guide](Installation-Scripts-Guide.md)

**Purpose**: Installing software, deploying applications, initial system configuration

- **Execution Pattern**: One-time or occasional deployment
- **Component Category**: Applications
- **Performance**: More flexible - can run longer processes (up to 30 minutes)
- **Focus**: Reliability and error handling

### 🔍 [Monitor Scripts Guide](Monitor-Scripts-Guide.md)

**Purpose**: Checking system status, monitoring services, detecting issues

- **Execution Pattern**: Frequent/continuous (every few minutes)
- **Component Category**: Monitors
- **Performance**: CRITICAL - Must complete in under 3 seconds
- **Focus**: Speed and proper output format

### 🗑️ [Removal/Modification Scripts Guide](Removal-Modification-Scripts-Guide.md)

**Purpose**: Uninstalling software, modifying configurations, system cleanup

- **Execution Pattern**: As-needed or periodic remediation
- **Component Category**: Applications or Scripts
- **Performance**: Balanced approach - timeouts recommended
- **Focus**: Safe modifications and rollback scenarios

## Decision Matrix

| Operation | Monitor | Installation | Removal |
|-----------|---------|-------------|---------|
| `Get-WmiObject Win32_Product` | ❌ NEVER | ❌ NEVER | ❌ NEVER |
| `Get-CimInstance Win32_Product` | ❌ NEVER | ❌ NEVER | ❌ NEVER |
| `Get-CimInstance` (other classes) | ⚠️ Add timeout | ✅ OK | ✅ OK |
| `Start-Process -Wait` (known) | ❌ Too slow | ✅ OK | ✅ OK |
| `Start-Process -Wait` (unknown) | ❌ Too slow | ⚠️ Add timeout | ⚠️ Add timeout |
| Registry detection | ✅ PREFERRED | ✅ PREFERRED | ✅ PREFERRED |
| Network operations | ⚠️ Add timeout | ✅ OK | ✅ OK |

## CIM/WMI Usage Rules

✅ **ALLOWED:**

```powershell
Get-CimInstance -ClassName Win32_ComputerSystem    # System info
Get-CimInstance -ClassName Win32_OperatingSystem   # OS details
Get-CimInstance -ClassName Win32_Service           # Service info
Get-CimInstance -ClassName Win32_LogicalDisk       # Disk info
Get-CimInstance -ClassName Win32_Process           # Process info
```

❌ **BANNED:**

```powershell
Get-CimInstance -ClassName Win32_Product           # Triggers MSI repair
Get-WmiObject -Class Win32_Product                 # Triggers MSI repair
```

> **⚠️ Why Win32_Product is banned:** Both `Get-WmiObject` and `Get-CimInstance` accessing the `Win32_Product` WMI class can trigger MSI repair operations, causing system instability, performance issues, and script failures. Always use registry-based detection for software detection instead.

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

### Standard Exit Codes

- **0**: Success
- **1**: Success with warnings
- **2**: Partial success
- **10**: Permission error
- **11**: Timeout error
- **12**: Configuration error
- **30**: Monitor critical
- **31**: Monitor warning

### Event Logging Template

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

## Quick Selection Guide

**Choose Installation Scripts when:**

- Deploying new software
- Configuring systems for the first time
- Setting up services or applications
- Need longer execution times (up to 30 minutes)

**Choose Monitor Scripts when:**

- Checking system health
- Monitoring service status
- Detecting configuration drift
- Need fast execution (< 3 seconds)
- Require specific output format (OK:/WARNING:/CRITICAL:)

**Choose Removal/Modification Scripts when:**

- Uninstalling software
- Cleaning up system configurations
- Modifying existing settings
- Need balanced performance with safety checks

## Repository Structure

```text
├── Installation-Scripts-Guide.md      # Software deployment & configuration
├── Monitor-Scripts-Guide.md           # System monitoring & health checks
├── Removal-Modification-Scripts-Guide.md  # Software removal & cleanup
├── Quick-Reference.md                 # This file - overview & decision matrix
├── DattoRMM-FocusedDebloat-Launcher.ps1  # Example script
├── FocusedDebloat.ps1                 # Example script
├── Scansnap.ps1                       # Example script
└── README.md                          # Repository information
```

## Getting Started

1. **Identify your script type** using the descriptions above
2. **Read the appropriate guide** for detailed requirements and examples
3. **Use the templates** provided in each guide as starting points
4. **Test thoroughly** in non-production environments first
5. **Follow the universal requirements** for all script types

## Need Help?

- Check the specific guide for your script type
- Review the decision matrix for operation compatibility
- Ensure you're following universal requirements
- Test with appropriate timeouts and error handling
