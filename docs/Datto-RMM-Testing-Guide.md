# 🧪 Datto RMM Hard-Coded Launcher Testing Guide

## 📋 Overview

This guide walks you through testing the hard-coded launcher system in your Datto RMM environment step-by-step.

**Test Branch**: `feature/hard-coded-launchers`
**GitHub URL**: `https://github.com/aybouzaglou/Datto-RMM-Powershell-Scripts`

## 🚀 Step 1: Local Testing (Optional but Recommended)

Before deploying to Datto RMM, test locally:

```powershell
# Run the environment variable inheritance test
.\tests\Test-DattoRMM-EnvVars.ps1
```

**Expected Result**: ✅ SUCCESS message confirming environment variables work

## 🔧 Step 2: Create Test Component in Datto RMM

### **Component Configuration:**

1. **Navigate to**: Datto RMM → Components → Create Component
2. **Component Name**: `TEST - Hard-Coded Launcher - FocusedDebloat`
3. **Component Type**: `Scripts`
4. **Description**: `Testing hard-coded launcher system with environment variables`

### **Script Content:**

Copy and paste this **ENTIRE** script content:

```powershell
<#
.SYNOPSIS
Hard-Coded Launcher for FocusedDebloat Script

.DESCRIPTION
Hard-coded launcher that downloads and executes FocusedDebloat.ps1 from GitHub with:
- Hard-coded script path (no environment variable consumption for script selection)
- All environment variables passed through to the underlying script
- Comprehensive error handling and logging
- Offline fallback capabilities

.PARAMETER GitHubRepo
GitHub repository in format "owner/repo"

.PARAMETER Branch
Git branch or tag to use

.PARAMETER ForceDownload
Force re-download even if cached

.PARAMETER OfflineMode
Use only cached files

.EXAMPLE
# Deploy as Datto RMM Scripts component
# All environment variables (customwhitelist, skipwindows, etc.) will be passed to FocusedDebloat.ps1

.NOTES
Version: 4.0.0
Author: Datto RMM Function Library
Compatible: PowerShell 2.0+, Datto RMM Environment
Script: FocusedDebloat.ps1 (Windows Debloat)
#>

param(
    [string]$GitHubRepo = "aybouzaglou/Datto-RMM-Powershell-Scripts",
    [string]$Branch = "feature/hard-coded-launchers",
    [switch]$ForceDownload,
    [switch]$OfflineMode
)

# ===== HARD-CODED SCRIPT CONFIGURATION =====
$SCRIPT_PATH = "components/Scripts/FocusedDebloat.ps1"
$SCRIPT_TYPE = "Scripts"
$SCRIPT_DISPLAY_NAME = "Windows Focused Debloat"
# ============================================

# Configuration
$BaseURL = "https://raw.githubusercontent.com/$GitHubRepo/$Branch"
$WorkingDir = "$env:TEMP\RMM-Execution"
$LogDir = "C:\ProgramData\DattoRMM"

# Ensure directories exist
@($WorkingDir, $LogDir) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -Path $_ -ItemType Directory -Force | Out-Null
    }
}

# Start transcript with unique name
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$transcriptPath = "$LogDir\FocusedDebloat-Launcher-$timestamp.log"
Start-Transcript -Path $transcriptPath -Force

try {
    Write-Output "=============================================="
    Write-Output "Datto RMM Hard-Coded Launcher v4.0.0"
    Write-Output "=============================================="
    Write-Output "Timestamp: $(Get-Date)"
    Write-Output "Repository: $GitHubRepo"
    Write-Output "Branch: $Branch"
    Write-Output "Working Directory: $WorkingDir"
    Write-Output "Log Directory: $LogDir"
    Write-Output ""
    
    # Extract script name from path for display and file operations
    $ScriptName = Split-Path $SCRIPT_PATH -Leaf
    
    Write-Output "Hard-Coded Script Configuration:"
    Write-Output "- Display Name: $SCRIPT_DISPLAY_NAME"
    Write-Output "- Script Name: $ScriptName"
    Write-Output "- Script Path: $SCRIPT_PATH"
    Write-Output "- Script Type: $SCRIPT_TYPE"
    Write-Output "- Force Download: $ForceDownload"
    Write-Output "- Offline Mode: $OfflineMode"
    Write-Output ""
    
    # Display Datto RMM environment variables (all will be passed to script)
    Write-Output "Environment Variables (passed to script):"
    $rmmVars = Get-ChildItem env: | Where-Object { 
        $_.Name -notlike "TEMP*" -and 
        $_.Name -notlike "TMP*" -and 
        $_.Name -notlike "PATH*" -and
        $_.Name -notlike "PROCESSOR*" -and
        $_.Name -notlike "PROGRAM*" -and
        $_.Name -notlike "SYSTEM*" -and
        $_.Name -notlike "USER*" -and
        $_.Name -notlike "WINDOWS*" -and
        $_.Name -notlike "COMPUTER*" -and
        $_.Name -notlike "LOGON*" -and
        $_.Name -notlike "SESSION*" -and
        $_.Name -notlike "APPDATA*" -and
        $_.Name -notlike "COMMON*" -and
        $_.Name -notlike "DRIVER*" -and
        $_.Name -notlike "FP_*" -and
        $_.Name -notlike "HOME*" -and
        $_.Name -notlike "LOCAL*" -and
        $_.Name -notlike "NUMBER_OF_*" -and
        $_.Name -notlike "OS*" -and
        $_.Name -notlike "PS*" -and
        $_.Name -notlike "PUBLIC*" -and
        $_.Name -notlike "WINDIR*"
    } | Sort-Object Name
    
    if ($rmmVars) {
        foreach ($var in $rmmVars) {
            Write-Output "  $($var.Name) = $($var.Value)"
        }
    } else {
        Write-Output "  (No custom environment variables detected)"
    }
    Write-Output ""
    
    # Set TLS 1.2 for secure downloads
    if (-not $OfflineMode) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
            Write-Output "TLS 1.2 security protocol enabled"
        } catch {
            Write-Warning "Failed to set TLS 1.2: $($_.Exception.Message)"
        }
    }
    
    # Step 1: Note about embedded functions
    Write-Output "=== Note: Scripts now use embedded functions (no shared function loading) ==="
    Write-Output "✓ Modern scripts are self-contained for maximum reliability"
    
    # Step 2: Download target script
    Write-Output ""
    Write-Output "=== Downloading Target Script ==="
    $scriptURL = "$BaseURL/$SCRIPT_PATH"
    $scriptPath = Join-Path $WorkingDir $ScriptName
    
    if (-not $OfflineMode) {
        try {
            Write-Output "Downloading script from: $scriptURL"
            (New-Object System.Net.WebClient).DownloadFile($scriptURL, $scriptPath)
            Write-Output "✓ Downloaded script: $ScriptName"
            
            # Verify download
            $fileSize = (Get-Item $scriptPath).Length
            Write-Output "File size: $fileSize bytes"
            
            # Basic PowerShell script validation
            if ($ScriptName -like "*.ps1") {
                $firstLine = Get-Content $scriptPath -TotalCount 1 -ErrorAction SilentlyContinue
                if ($firstLine -and ($firstLine -like "*#*" -or $firstLine -like "*<#*")) {
                    Write-Output "✓ PowerShell script validation passed"
                } else {
                    Write-Warning "Downloaded file may not be a valid PowerShell script"
                }
            }
        } catch {
            Write-Error "Failed to download script from $scriptURL"
            Write-Error "Error: $($_.Exception.Message)"
            
            # Check for cached version
            if (Test-Path $scriptPath) {
                Write-Output "Using cached version of script"
            } else {
                exit 11
            }
        }
    } else {
        if (-not (Test-Path $scriptPath)) {
            Write-Error "Script not available in offline mode: $ScriptName"
            exit 11
        }
        Write-Output "Using cached script: $ScriptName"
    }
    
    # Step 3: Execute the script
    Write-Output ""
    Write-Output "=== Executing Script ==="
    Write-Output "Display Name: $SCRIPT_DISPLAY_NAME"
    Write-Output "Script: $ScriptName"
    Write-Output "Type: $SCRIPT_TYPE"
    Write-Output "Source: $scriptURL"
    Write-Output "Working Directory: $WorkingDir"
    Write-Output "Execution Time: $(Get-Date)"
    Write-Output ""
    Write-Output "All environment variables will be passed to the script:"
    Write-Output "=============================================="
    
    # Change to working directory and execute
    Push-Location $WorkingDir
    try {
        # Execute the script and capture exit code
        & $scriptPath
        $exitCode = $LASTEXITCODE
        
        Write-Output ""
        Write-Output "=============================================="
        Write-Output "Script execution completed"
        Write-Output "Exit code: $exitCode"
        Write-Output "Completion time: $(Get-Date)"
        Write-Output "=============================================="
        
        exit $exitCode
    } finally {
        Pop-Location
    }
    
} catch {
    Write-Error "Launcher failed: $($_.Exception.Message)"
    Write-Error "Line: $($_.InvocationInfo.ScriptLineNumber)"
    exit 2
} finally {
    Stop-Transcript
}
```

### **Environment Variables:**

Add these Input Variables in Datto RMM:

| Variable Name | Type | Default Value | Description |
|---------------|------|---------------|-------------|
| `customwhitelist` | Variable Value/String | `TestApp1,TestApp2` | Apps to preserve during debloat |
| `skipwindows` | Boolean | `false` | Skip Windows built-in app removal |
| `TestMode` | Boolean | `true` | Enable test mode (safe testing) |

## 📊 Step 3: Deploy and Monitor

### **Deploy the Component:**

1. **Save** the component
2. **Deploy** to a test device (preferably a VM or test machine)
3. **Run** the component as a Quick Job

### **What to Monitor:**

#### **In Datto RMM Job Output:**
Look for these key indicators:

✅ **Success Indicators:**
```
✓ Downloaded script: FocusedDebloat.ps1
Environment Variables (passed to script):
  customwhitelist = TestApp1,TestApp2
  skipwindows = false
  TestMode = true
Script execution completed
Exit code: 0
```

❌ **Failure Indicators:**
```
Failed to download script from [URL]
Environment variables NOT inherited
Exit code: [non-zero]
```

#### **On the Target Device:**
Check these log locations:

1. **Launcher Logs**: `C:\ProgramData\DattoRMM\FocusedDebloat-Launcher-[timestamp].log`
2. **Script Logs**: `C:\ProgramData\Debloat\Debloat.log` (if script executes)

## 🔍 Step 4: Verify Environment Variable Inheritance

### **Key Test Points:**

1. **Environment Variables Listed**: Launcher should display all your custom variables
2. **Script Download**: Should download from the test branch successfully  
3. **Script Execution**: Downloaded script should access environment variables
4. **No Variable Conflicts**: No errors about missing ScriptName/ScriptType

### **Expected Flow:**
```
1. Datto RMM sets: customwhitelist=TestApp1,TestApp2, TestMode=true
2. Launcher displays: "Environment Variables (passed to script): customwhitelist=TestApp1,TestApp2..."
3. Script downloads from: feature/hard-coded-launchers branch
4. Script executes with full access to environment variables
5. Exit code: 0 (success)
```

## 🎯 Step 5: Results Analysis

### **If Test Passes ✅:**
- Environment variables are properly inherited
- Hard-coded launcher approach works with Datto RMM
- Ready to migrate other components to hard-coded launchers
- Can merge feature branch to main

### **If Test Fails ❌:**
- Check specific error messages in job output
- Review device logs for detailed error information
- Verify network connectivity and GitHub access
- Consider alternative approaches or modifications

## 🚀 Next Steps After Successful Test

1. **Test other hard-coded launchers** (ScanSnapHome, etc.)
2. **Migrate existing components** from universal launcher
3. **Merge feature branch** to main branch
4. **Update production components** with hard-coded launchers

## 📞 Troubleshooting

### **Common Issues:**

**Script Download Fails:**
- Check internet connectivity on target device
- Verify GitHub repository access
- Confirm branch name is correct

**Environment Variables Missing:**
- Verify Input Variables are configured in component
- Check variable names match exactly (case-sensitive)
- Ensure variable types are correct

**Script Execution Fails:**
- Check PowerShell execution policy on device
- Verify script permissions and antivirus exclusions
- Review detailed logs in `C:\ProgramData\DattoRMM\`

---

**Ready to test? Follow Step 2 to create your first test component!**
