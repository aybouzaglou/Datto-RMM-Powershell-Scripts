---
type: "agent_requested"
description: "Datto RMM Specific Rules and Patterns"
---
# 🎯 Datto RMM Specific Rules and Patterns

## 🔍 Datto RMM Environment Understanding

### Platform Details
- **Datto RMM platform**: Concord (https://concord.centrastage.net)
- **API URL**: https://concord-api.centrastage.net/api/v2
- **Authentication**: OAuth 2.0 Authorization Code grant type (not password grant)
- **Execution Context**: Scripts run as NT AUTHORITY\SYSTEM with admin privileges

### Script Execution Environment
- **Admin privileges**: Automatically provided, no privilege checks needed
- **Interactive restrictions**: Must avoid GUI calls, interactive input, heavy MSI scans
- **Timeout requirements**: Use timeouts for external processes
- **Logging standards**: Structured logging with standardized exit codes

### Exit Code Standards
```powershell
# Scripts/Applications components:
exit 0     # Success
exit 3010  # Reboot required (success)
exit 1641  # Reboot required (success)
# Other non-zero = Failed

# Custom Monitor components:
exit 0     # OK/Green status
exit 30    # Warning/Yellow status  
exit 31    # Critical/Red status
# Any non-zero = Alert state
```

## 🚫 Banned Operations in Datto RMM

### Absolutely Prohibited
```powershell
# ❌ BANNED - Triggers MSI repair, causes system instability
Get-WmiObject -Class Win32_Product
Get-CimInstance -ClassName Win32_Product

# ❌ BANNED - Interactive elements incompatible with RMM
Read-Host "Enter value"
Get-Credential
[System.Windows.Forms.MessageBox]::Show()
[System.Windows.MessageBox]::Show()
```

### Performance Considerations
```powershell
# ⚠️ AVOID - Heavy operations that can timeout
Get-ChildItem -Path C:\ -Recurse  # Full C: drive recursion
Get-Process | Where-Object { ... }  # Use -Name parameter instead
Get-Service | Where-Object { ... }  # Use -Name parameter instead
```

**Rule**: Prefer registry lookups over WMI queries for performance.

## 📊 Monitor Component Requirements

### Result Markers (Required for Custom Monitors)
```powershell
# ✅ REQUIRED - Result markers for UI extraction
Write-Host "<-Start Result->"
Write-Host "OK: System is healthy"
Write-Host "<-End Result->"
```

### Status Prefixes
```powershell
# ✅ CORRECT - Standardized status prefixes
Write-Host "OK: Everything is working"      # Green status
Write-Host "WARNING: Minor issue detected"  # Yellow status  
Write-Host "CRITICAL: System failure"       # Red status
```

### Performance Requirements
- **Execution time**: Must complete in under 3 seconds
- **Error handling**: Include try/catch blocks with proper exit codes
- **Parameter validation**: Validate inputs before processing

### Monitor Template
```powershell
try {
    Write-Host "<-Start Result->"
    
    # Your monitoring logic here
    $status = Test-SystemHealth
    
    if ($status.IsHealthy) {
        Write-Host "OK: System is healthy"
        Write-Host "<-End Result->"
        exit 0
    } elseif ($status.HasWarnings) {
        Write-Host "WARNING: $($status.Message)"
        Write-Host "<-End Result->"
        exit 30
    } else {
        Write-Host "CRITICAL: $($status.Message)"
        Write-Host "<-End Result->"
        exit 31
    }
} catch {
    Write-Host "CRITICAL: Monitor execution failed: $($_.Exception.Message)"
    Write-Host "<-End Result->"
    exit 31
}
```

## 🏗️ Component Categories

### Applications
- **Purpose**: Software installation/deployment
- **Category**: Changeable after creation
- **Timeout**: Up to 30 minutes
- **Use cases**: Installing software, system configuration

### Monitors  
- **Purpose**: System health monitoring
- **Category**: IMMUTABLE (cannot change after creation)
- **Timeout**: Under 3 seconds
- **Requirements**: Result markers, proper exit codes
- **Use cases**: Health checks, compliance monitoring

### Scripts
- **Purpose**: General automation tasks
- **Category**: Changeable after creation  
- **Timeout**: Flexible
- **Use cases**: Maintenance, troubleshooting, automation

## 🚀 Deployment Strategies

### Manual Deployment (Preferred)
- **Approach**: GitHub Actions validation + manual RMM console deployment
- **Benefits**: Full control, security, simplicity
- **Process**: Validate → Download artifacts → Manual deploy in RMM console

### API Deployment (Not Recommended)
- **Issues**: Complex authentication, security concerns, limited control
- **User preference**: Avoid API-based deployment for simplicity

## 🔧 Environment Variables Pattern

### Standard Environment Variables
```
GitHubRepo = aybouzaglou/Datto-RMM-Powershell-Scripts
ScriptPath = components/Scripts/YourScript.ps1
CacheTimeout = 3600
```

### Two-Tier Deployment Strategy
1. **Dedicated Components**: For frequently used scripts (weekly+)
   - Pre-configured environment variables
   - One-click deployment for technicians
   
2. **Universal Launcher**: For occasional scripts (monthly-)
   - Change ScriptPath variable for different scripts
   - Perfect for testing and one-offs

## 📋 Technician-Friendly Documentation

### Required Documentation Elements
- **Decision matrices**: When to use which approach
- **Copy/paste examples**: Script paths and configurations  
- **Quick reference cards**: Printable guides for daily use
- **Troubleshooting guides**: Common issues and solutions

### Documentation Structure
```
docs/
├── technician-guides/
│   ├── quick-reference-cards/
│   ├── decision-matrices/
│   └── troubleshooting/
├── deployment-strategies/
└── component-categories/
```

## ⚠️ Common Pitfalls to Avoid

1. **Creating Monitors without result markers** - Will fail validation
2. **Forgetting Monitor category is immutable** - Choose carefully
3. **Using banned WMI operations** - Even with timeout wrappers
4. **Interactive elements in RMM scripts** - Incompatible with automation
5. **Improper exit codes** - Breaks RMM status reporting
6. **Heavy operations in monitors** - Will timeout and fail
7. **Missing error handling** - Causes unpredictable failures
