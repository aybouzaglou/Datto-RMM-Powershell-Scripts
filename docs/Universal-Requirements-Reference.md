# 🌐 Universal Requirements Reference - Datto RMM Scripts

## 📋 Overview

This guide consolidates the **universal requirements** that apply to ALL Datto RMM PowerShell scripts, regardless of component type (Monitor, Application, or Script). These requirements are fundamental to successful script execution in the Datto RMM environment.

## 🔧 LocalSystem Context

### **Execution Environment**
- **User Context**: All scripts run as `NT AUTHORITY\SYSTEM`
- **Privileges**: Full administrative privileges on the local system
- **Session Type**: Non-interactive session (Session 0)
- **Desktop**: No desktop interaction available

### **Network Access Limitations**
- **Network Drives**: No access to mapped network drives (use UNC paths)
- **User Credentials**: No access to user-stored credentials
- **Network Authentication**: Limited in some environments
- **Internet Access**: May be restricted by firewall/proxy settings

### **GUI Restrictions**
- **No Visual Elements**: GUI elements will not be visible to users
- **No User Interaction**: Cannot prompt for user input
- **No Desktop Access**: Cannot interact with user desktop
- **Service Context**: Runs in background service context

### **File System Access**
```powershell
# ✅ Good - Use UNC paths for network resources
$networkPath = "\\server\share\file.txt"

# ❌ Bad - Mapped drives not available in LocalSystem
$mappedPath = "Z:\file.txt"

# ✅ Good - Local system paths work normally
$localPath = "C:\temp\file.txt"
```

## 📥 Input Variables

### **Variable Types**
- **All variables are strings**: Even boolean and numeric values come as strings
- **Access Method**: Use `$env:VariableName` to access environment variables
- **Case Sensitivity**: Environment variable names are case-insensitive
- **Null Handling**: Variables may be null, empty, or whitespace

### **Boolean Variable Parsing**
```powershell
# ✅ Correct - Robust boolean parsing
$debugMode = $env:DebugMode -eq 'true' -or $env:DebugMode -eq '1' -or $env:DebugMode -eq 'yes'

# ✅ Alternative - Simple true check
$enableFeature = $env:EnableFeature -eq 'true'

# ❌ Wrong - Will throw exceptions on invalid input
$badParsing = [bool]::Parse($env:BoolVar)
```

### **Integer Variable Parsing**
```powershell
# ✅ Correct - Safe integer parsing with fallback
$timeout = try { [int]$env:TimeoutSeconds } catch { 300 }

# ✅ Alternative - Using default parameter pattern
[int]$retryCount = $env:RetryCount ?? 3

# ✅ Comprehensive parsing function
function Get-IntegerVariable {
    param([string]$Name, [int]$Default = 0)
    try {
        $value = [Environment]::GetEnvironmentVariable($Name)
        if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
        return [int]$value
    } catch {
        return $Default
    }
}
```

### **String Variable Handling**
```powershell
# ✅ Good - Handle null/empty strings
$serverName = $env:ServerName
if ([string]::IsNullOrWhiteSpace($serverName)) {
    $serverName = "localhost"
}

# ✅ Alternative - Using null coalescing
$logPath = $env:LogPath ?? "C:\temp\script.log"
```

## 🚪 Exit Codes

### **Standard Exit Codes (Applications & Scripts)**
| Exit Code | Meaning | Usage |
|-----------|---------|-------|
| **0** | Success | Everything completed successfully |
| **1** | Success with warnings | Completed but with minor issues |
| **2** | Partial success | Some operations failed, some succeeded |
| **10** | Permission error | Insufficient permissions to complete |
| **11** | Timeout error | Operation timed out |
| **12** | Configuration error | Invalid configuration or parameters |
| **3010** | Reboot required | Success, but system reboot needed |
| **1641** | Reboot required | Success, but system reboot needed (alternative) |

### **Monitor Exit Codes (Simplified)**
| Exit Code | Monitor Status | Notes |
|-----------|----------------|-------|
| **0** | OK/Green (no alert) | Monitor stays healthy |
| **Any non-zero** | Alert (severity = Alert Priority setting) | Monitor enters alert state |

### **Exit Code Implementation**
```powershell
# ✅ Good - Clear exit code usage
try {
    # Main script logic
    Write-Host "Operation completed successfully"
    exit 0
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Message -like "*permission*") {
        exit 10  # Permission error
    } elseif ($_.Exception.Message -like "*timeout*") {
        exit 11  # Timeout error
    } else {
        exit 1   # General error
    }
}
```

## 📝 Event Logging

### **Standard Event IDs**
| Event ID | Type | Usage |
|----------|------|-------|
| **40000** | Success | Successful operations |
| **40001** | Warning | Warning conditions |
| **40002** | Error | Error conditions |

### **Event Logging Implementation**
```powershell
# ✅ Correct - Always wrap in try/catch
function Write-ScriptEvent {
    param(
        [string]$Message,
        [ValidateSet("Success", "Warning", "Error")]$Type = "Success"
    )
    
    $EventIds = @{
        "Success" = 40000
        "Warning" = 40001
        "Error" = 40002
    }
    
    try {
        Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId $EventIds[$Type] -Message $Message
    } catch {
        # Silently continue - event logging is optional
        # The "Datto-RMM-Script" source may not exist on all systems
    }
}

# Usage examples
Write-ScriptEvent -Message "Software installation completed successfully" -Type "Success"
Write-ScriptEvent -Message "Warning: Some optional components were skipped" -Type "Warning"
Write-ScriptEvent -Message "Error: Installation failed - insufficient disk space" -Type "Error"
```

### **Event Source Considerations**
- The `"Datto-RMM-Script"` event source may not exist on all systems
- Always wrap event logging in try/catch blocks
- Event logging is optional - scripts should continue if logging fails
- Consider creating the event source if it doesn't exist (requires admin rights)

## 🔒 Security Requirements

### **TLS Configuration**
```powershell
# ✅ Required - Set TLS 1.2 for all network operations
[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)

# ✅ Alternative - More explicit TLS 1.2 setting
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

### **File Download Security**
```powershell
# ✅ Good - Verify file hashes when possible
function Get-SecureFile {
    param(
        [string]$Url,
        [string]$OutputPath,
        [string]$ExpectedHash = $null
    )
    
    # Set TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = 3072
    
    # Download with timeout
    Invoke-WebRequest -Uri $Url -OutFile $OutputPath -TimeoutSec 300
    
    # Verify hash if provided
    if ($ExpectedHash) {
        $actualHash = Get-FileHash -Path $OutputPath -Algorithm SHA256
        if ($actualHash.Hash -ne $ExpectedHash) {
            Remove-Item $OutputPath -Force
            throw "File hash verification failed"
        }
    }
}
```

### **Digital Signature Verification**
```powershell
# ✅ Good - Verify digital signatures when possible
function Test-FileSignature {
    param([string]$FilePath)
    
    try {
        $signature = Get-AuthenticodeSignature -FilePath $FilePath
        return $signature.Status -eq 'Valid'
    } catch {
        return $false
    }
}
```

## 🚨 Common Pitfalls & Solutions

### **Environment Variable Issues**
```powershell
# ❌ Common mistake - Not handling null/empty values
$timeout = [int]$env:TimeoutSeconds  # Throws exception if null/empty

# ✅ Correct - Safe parsing with defaults
$timeout = try { [int]$env:TimeoutSeconds } catch { 300 }
```

### **Boolean Parsing Issues**
```powershell
# ❌ Common mistake - Using Parse methods
$enabled = [bool]::Parse($env:EnableFeature)  # Throws exception on invalid input

# ✅ Correct - String comparison
$enabled = $env:EnableFeature -eq 'true'
```

### **Network Access Issues**
```powershell
# ❌ Common mistake - Assuming network drives work
Copy-Item "Z:\source\file.txt" "C:\destination\"

# ✅ Correct - Use UNC paths
Copy-Item "\\server\share\source\file.txt" "C:\destination\"
```

## 📋 Universal Checklist

### **Before Deployment**
- [ ] **LocalSystem Testing**: Tested in LocalSystem context
- [ ] **Variable Handling**: Robust environment variable parsing
- [ ] **Error Handling**: Comprehensive error handling implemented
- [ ] **Exit Codes**: Appropriate exit codes used
- [ ] **Event Logging**: Event logging implemented with try/catch
- [ ] **Security**: TLS 1.2 configured for network operations
- [ ] **Network Paths**: UNC paths used instead of mapped drives
- [ ] **No GUI Elements**: No user interaction or GUI components

### **During Development**
- [ ] **Test with null variables**: Handle missing environment variables
- [ ] **Test with invalid data**: Handle malformed input gracefully
- [ ] **Test network scenarios**: Handle network failures appropriately
- [ ] **Test permissions**: Verify LocalSystem permissions are sufficient
- [ ] **Test logging**: Verify event logging works or fails gracefully

---

**Remember**: These universal requirements apply to ALL Datto RMM scripts. Following these patterns ensures reliable script execution across diverse environments and reduces support issues.
