# 🛡️ Error Handling Best Practices for Datto RMM Scripts

## 🚨 Critical Rule: Scripts Must Continue When Possible

**❌ NEVER DO THIS**: Let non-critical errors terminate the entire script
**✅ ALWAYS DO THIS**: Handle errors gracefully and continue execution when safe

## 🎯 Core Principles

### **1. Global Error Handling**
Wrap the **entire script** in try-catch, not just parts:

```powershell
# ❌ WRONG - Only covers part of the script
Write-RMMLog "Starting script..."
Write-RMMLog ""  # This could fail and kill the script

try {
    # Main logic here
} catch {
    # Only catches main logic errors
}
```

```powershell
# ✅ CORRECT - Covers entire script
try {
    Write-RMMLog "Starting script..."
    Write-RMMLog ""  # Now handled gracefully
    
    # Main logic here
    
} catch {
    Write-RMMLog "Script failed: $($_.Exception.Message)" -Level Error
    exit 1
} finally {
    Write-RMMLog "Script completed" -Level Status
}
```

### **2. Robust Logging Functions**
Logging functions must handle edge cases:

```powershell
# ❌ WRONG - Fails on empty strings
function Write-RMMLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,  # This will fail on empty strings
        [string]$Level = "Info"
    )
    # Function body
}
```

```powershell
# ✅ CORRECT - Handles empty strings gracefully
function Write-RMMLog {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]  # Allow empty strings
        [string]$Message,
        [string]$Level = "Info"
    )
    
    # Handle empty messages for spacing
    if ([string]::IsNullOrEmpty($Message)) {
        Write-Host ""  # Empty line for spacing
        return
    }
    
    # Normal logging logic
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
}
```

### **3. Non-Critical vs Critical Errors**

**Non-Critical Errors** (should NOT stop script):
- Logging failures
- Optional cleanup operations
- Non-essential validations
- Cosmetic operations

**Critical Errors** (should stop script):
- Missing required files
- Permission failures for core operations
- System requirement failures
- Network failures for essential downloads

```powershell
# ✅ CORRECT - Non-critical error handling
try {
    Write-RMMLog "Cleaning up temp files..." -Level Status
    Remove-Item -Path $TempPath -Recurse -Force -ErrorAction Stop
} catch {
    Write-RMMLog "Cleanup failed (non-critical): $($_.Exception.Message)" -Level Warning
    # Continue execution - cleanup failure shouldn't stop installation
}

# ✅ CORRECT - Critical error handling
try {
    $installerPath = "installer.msi"
    if (-not (Test-Path $installerPath)) {
        throw "Required installer file not found: $installerPath"
    }
} catch {
    Write-RMMLog "Critical error: $($_.Exception.Message)" -Level Error
    exit 1  # Stop here - can't continue without installer
}
```

## 📋 Script Structure Template

### **Applications/Scripts Template**
```powershell
<#
.SYNOPSIS
Robust Script Template with Proper Error Handling
#>

# Global error handling wrapper
try {
    # Robust logging function
    function Write-RMMLog {
        param(
            [Parameter(Mandatory=$true)]
            [AllowEmptyString()]
            [string]$Message,
            [string]$Level = "Info"
        )
        
        if ([string]::IsNullOrEmpty($Message)) {
            Write-Host ""
            return
        }
        
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logMessage = "[$timestamp] [$Level] $Message"
        Write-Host $logMessage
    }
    
    # Initialize logging
    $LogPath = "C:\ProgramData\DattoRMM\Applications"
    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }
    
    Start-Transcript -Path "$LogPath\Script.log" -Append
    
    Write-RMMLog "=============================================="
    Write-RMMLog "Script Starting v1.0.0" -Level Status
    Write-RMMLog "=============================================="
    Write-RMMLog ""  # This is now safe
    
    # Non-critical cleanup
    try {
        Write-RMMLog "Performing cleanup..." -Level Status
        # Cleanup operations
    } catch {
        Write-RMMLog "Cleanup failed (continuing): $($_.Exception.Message)" -Level Warning
    }
    
    # Critical validation
    $requiredFile = "required-file.msi"
    if (-not (Test-Path $requiredFile)) {
        throw "Critical: Required file not found: $requiredFile"
    }
    
    # Main logic with specific error handling
    Write-RMMLog "Starting main operations..." -Level Status
    
    # Your main script logic here
    
    Write-RMMLog "Script completed successfully" -Level Success
    $exitCode = 0
    
} catch {
    Write-RMMLog "Script failed: $($_.Exception.Message)" -Level Error
    Write-RMMLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    $exitCode = 1
} finally {
    Write-RMMLog ""
    Write-RMMLog "=============================================="
    Write-RMMLog "Script execution completed" -Level Status
    Write-RMMLog "Final exit code: $exitCode" -Level Status
    Write-RMMLog "End time: $(Get-Date)" -Level Status
    Write-RMMLog "=============================================="
    
    Stop-Transcript
    exit $exitCode
}
```

### **Monitor Template**
```powershell
<#
.SYNOPSIS
Robust Monitor Template with Proper Error Handling
#>

# Global error handling for monitors
try {
    # Robust alert function
    function Write-MonitorAlert {
        param([string]$Message)
        Write-Host '<-Start Result->'
        Write-Host $Message
        Write-Host '<-End Result->'
        exit 1
    }
    
    # Safe logging for monitors
    function Write-MonitorLog {
        param([string]$Message)
        if (-not [string]::IsNullOrEmpty($Message)) {
            Write-Host $Message
        }
    }
    
    Write-MonitorLog "Starting monitor check..."
    
    # Your monitoring logic here
    
    # Success case
    Write-Host '<-Start Result->'
    Write-Host "OK: Monitor check passed"
    Write-Host '<-End Result->'
    exit 0
    
} catch {
    # Critical monitor failure
    Write-MonitorAlert "CRITICAL: Monitor failed - $($_.Exception.Message)"
}
```

## 🔧 Common Fixes

### **Fix 1: Logging Function Parameters**
```powershell
# Before (problematic)
param([Parameter(Mandatory=$true)][string]$Message)

# After (robust)
param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Message)
```

### **Fix 2: Empty String Handling**
```powershell
# Before (fails on empty)
Write-RMMLog ""

# After (handles gracefully)
if ([string]::IsNullOrEmpty($Message)) {
    Write-Host ""
    return
}
```

### **Fix 3: Global Try-Catch**
```powershell
# Before (partial coverage)
Write-RMMLog "Starting..."
try { # main logic } catch { # errors }

# After (full coverage)
try {
    Write-RMMLog "Starting..."
    # all logic
} catch {
    # all errors
}
```

## 🎯 Testing Error Handling

### **Test Your Scripts**
1. **Test with empty environment variables**
2. **Test with missing files**
3. **Test with permission issues**
4. **Test with network failures**
5. **Test with invalid parameters**

### **Validation Checklist**
- ✅ Script continues after non-critical errors
- ✅ Logging functions handle empty strings
- ✅ Global try-catch covers entire script
- ✅ Critical errors properly terminate script
- ✅ Exit codes are meaningful
- ✅ Logs provide useful troubleshooting information

## 📖 References

- **[Function Reference](Function-Reference.md)** - Proper function usage
- **[Component Categories](Datto-RMM-Component-Categories.md)** - Category-specific requirements
- **[File Attachment Guide](Datto-RMM-File-Attachment-Guide.md)** - File handling best practices

## 🚨 Remember

**The goal is resilient scripts that:**
1. **Continue when possible** (non-critical errors)
2. **Fail gracefully** (critical errors)
3. **Provide useful feedback** (comprehensive logging)
4. **Exit with meaningful codes** (0=success, others=specific failures)
