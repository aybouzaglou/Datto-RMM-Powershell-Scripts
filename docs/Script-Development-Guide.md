# 🔧 Datto RMM Script Development Guide

## 📋 Overview

This comprehensive guide covers development patterns for **Application and Script components** in Datto RMM - scripts designed for software installation, system configuration, removal, and modification tasks.

## 🎯 Component Types Covered

### **📦 Installation Scripts (Applications Category)**
- **Primary Use**: Installing software, deploying applications, initial system configuration
- **Execution Pattern**: One-time or occasional deployment
- **Component Category**: Applications
- **Performance Requirements**: More flexible - can run longer processes (up to 30 minutes)

### **🗑️ Removal/Modification Scripts (Applications/Scripts Category)**
- **Primary Use**: Uninstalling software, modifying configurations, system cleanup
- **Execution Pattern**: As-needed or periodic remediation
- **Component Category**: Applications or Scripts
- **Performance Requirements**: Balanced approach - timeouts recommended

## 🏗️ Architecture & Deployment

### **✅ Recommended Deployment Pattern**
Both Installation and Removal/Modification scripts should use **launcher-based deployment** for:
- **Automatic updates** from GitHub repository
- **Flexible configuration** via environment variables
- **Consistent function patterns** across scripts
- **Easy maintenance** and version control

### **🚀 Launcher Integration**
```powershell
# Scripts are deployed via launchers that:
# 1. Download latest script from GitHub
# 2. Cache for offline scenarios
# 3. Pass environment variables to script
# 4. Handle error reporting and logging
```

## ✅ Allowed Operations

### **Installation Scripts**
- ✅ `Start-Process -Wait` with known installers/MSIs
- ✅ Network operations for reliable sources
- ✅ CIM operations (EXCEPT Win32_Product - use registry instead)
- ✅ File downloads with explicit timeouts
- ✅ Registry modifications and system configuration
- ✅ Service installation and configuration

### **Removal/Modification Scripts**
- ✅ `Start-Process -Wait` for known uninstallers
- ✅ Registry cleanup operations
- ✅ File system modifications and cleanup
- ✅ Service management (stop/start/modify)
- ✅ Process monitoring for critical repairs
- ✅ Configuration file modifications
- ✅ CIM operations (EXCEPT Win32_Product - use registry instead)

## 🚨 Critical Restrictions

### **❌ BANNED Operations (All Script Types)**
```powershell
# Never use Win32_Product - triggers MSI repair operations
Get-CimInstance -ClassName Win32_Product
Get-WmiObject -Class Win32_Product
```

### **⚠️ Performance Considerations**
- Still need timeouts for unknown processes
- Must handle LocalSystem context (no network drives)
- No GUI elements (invisible in LocalSystem)
- Must verify digital signatures for downloaded files

## 🔧 CIM/WMI Usage Examples

### **✅ ALLOWED:**
```powershell
# System information for installation/removal decisions
$system = Get-CimInstance -ClassName Win32_ComputerSystem
$manufacturer = $system.Manufacturer
$model = $system.Model

# OS version for compatibility checks
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$osVersion = $os.Version

# Disk space checks
$disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
$freeSpace = $disk.FreeSpace

# Service management during removal
$service = Get-CimInstance -ClassName Win32_Service -Filter "Name='ServiceName'"
if ($service) {
    Stop-Service -Name $service.Name -Force
}

# Process monitoring during cleanup
$processes = Get-CimInstance -ClassName Win32_Process -Filter "Name='app.exe'"
foreach ($proc in $processes) {
    $proc | Invoke-CimMethod -MethodName Terminate
}
```

## 📋 Universal Requirements (All Script Types)

### **LocalSystem Context**
- All scripts run as NT AUTHORITY\SYSTEM
- No access to network drives (use UNC paths)
- No GUI elements will be visible
- Limited network access in some environments

### **Input Variables**
- All input variables are strings (even booleans)
- Access via `$env:VariableName`
- Boolean check: `$env:BoolVar -eq 'true'`

### **Exit Codes**
- **0**: Success
- **1**: Success with warnings
- **2**: Partial success
- **10**: Permission error
- **11**: Timeout error
- **12**: Configuration error

### **Event Logging**
```powershell
# Standard event logging
Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40000 -Message "Success message"  # Success
Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40001 -Message "Warning message"  # Warning
Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId 40002 -Message "Error message"    # Error
```

### **Security Requirements**
- Set TLS 1.2: `[Net.ServicePointManager]::SecurityProtocol = 3072`
- Verify SHA-256 hashes for downloads
- Use digital signature verification when possible

## 📝 Development Templates

### **🔧 Installation Script Template**

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

### **🗑️ Software Removal Template**

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

## 🎯 Best Practices by Script Type

### **Installation Scripts**
- Focus on reliability and error handling
- Use appropriate timeouts (up to 30 minutes)
- Verify successful installation
- Handle rollback scenarios
- Test with various installer types (MSI, EXE, etc.)

### **Removal/Modification Scripts**
- Test in non-production first
- Create restore points when possible
- Handle partial failures gracefully
- Verify changes were applied
- Implement safe modification patterns

## 🔍 Software Detection Patterns

### **Registry-Based Detection (PREFERRED)**
```powershell
# Fast software detection for all script types
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

# Usage example
$Software = Get-SoftwareFast -Name "Adobe Reader"
if ($Software) {
    Write-Host "Adobe Reader found - Version: $($Software.DisplayVersion)"
} else {
    Write-Host "Adobe Reader not installed"
}
```

## 🧪 Testing Guidelines

### **Local Testing**
```powershell
# Set test environment variables
$env:InstallerPath = "C:\temp\installer.msi"
$env:InstallArgs = "/quiet /norestart"
$env:SoftwareName = "Adobe Reader"
$env:ForceRemoval = "true"

# Run your script
.\Your-Script.ps1

# Check exit code: $LASTEXITCODE
# Verify expected changes were made
```

### **Testing Checklist**
- [ ] **Environment Variables**: Test with various input combinations
- [ ] **Error Handling**: Test with invalid inputs and missing files
- [ ] **Timeouts**: Test with slow/hanging processes
- [ ] **Permissions**: Test in LocalSystem context
- [ ] **Rollback**: Test failure scenarios and cleanup
- [ ] **Logging**: Verify event log entries are created

## 📋 Deployment Checklist

### **Pre-Deployment**
- [ ] **Testing**: Thoroughly tested in non-production environment
- [ ] **Error Handling**: Comprehensive error handling implemented
- [ ] **Timeouts**: Appropriate timeouts configured
- [ ] **Logging**: Event logging implemented
- [ ] **Documentation**: Clear parameter documentation

### **Launcher Configuration**
- [ ] **Component Type**: Application or Script (as appropriate)
- [ ] **Launcher**: Use appropriate launcher (UniversalLauncher.ps1)
- [ ] **Environment Variables**: Configure required parameters
- [ ] **Cache Timeout**: Set appropriate cache timeout (5 minutes recommended)
- [ ] **Testing**: Test launcher functionality in Datto RMM

### **Production Deployment**
- [ ] **Gradual Rollout**: Start with test devices
- [ ] **Monitoring**: Monitor execution and results
- [ ] **Documentation**: Update technician guides
- [ ] **Backup Plan**: Have rollback procedure ready

## 🔄 Maintenance & Updates

### **Version Control**
- Use GitHub for version control and automatic updates
- Tag releases for stable versions
- Document changes in commit messages
- Test updates before deployment

### **Function Library Integration**
- Copy useful patterns from shared-functions/ directory
- Embed functions directly in scripts (no runtime dependencies)
- Keep functions minimal and focused
- Update based on proven patterns

## 📚 Quick Reference Summary

### **Installation Scripts**
- Use Applications category
- Focus on reliability over speed
- Implement comprehensive error handling
- Support various installer types
- Verify successful installation

### **Removal/Modification Scripts**
- Use Applications or Scripts category
- Test thoroughly before production
- Handle partial failures gracefully
- Implement safe modification patterns
- Verify changes were applied

### **Universal Guidelines**
- Always use launcher-based deployment
- Embed functions from shared-functions/ (copy/paste)
- Handle LocalSystem context limitations
- Implement proper error handling and logging
- Test with various input scenarios

---

**Remember**: These scripts often make significant system changes. Thorough testing and proper error handling are essential for reliable automation in production environments.
