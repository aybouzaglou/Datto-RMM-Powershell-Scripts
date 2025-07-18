# 📎 Datto RMM File Attachment Guide

## 📋 Overview

This guide covers the **official Datto RMM approach** for including installer files, configuration files, and other resources with your components using the built-in file attachment feature.

## 🎯 Key Principle

> **Datto RMM File Attachment**: Files attached to components are automatically placed in the same directory as script execution, allowing direct reference by filename without full paths.

## 📁 How File Attachment Works

### **Official Datto RMM Documentation Example**
```cmd
@echo off
msiexec /i install.msi /qn
echo Product Installed Successfully
exit
```

**Key Points:**
- The file `install.msi` can be referenced **directly by name**
- **No full paths required** - the command shell launches from the directory containing attached files
- This is the **official Datto RMM approach** for including installer files

### **PowerShell Equivalent**
```powershell
# Correct approach - direct file reference
$MSIPath = "install.msi"
if (Test-Path $MSIPath) {
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $MSIPath, "/quiet" -Wait
}
```

## ❌ **Common Mistakes to Avoid**

### **Wrong Approach: Manual File Placement**
```powershell
# ❌ DON'T DO THIS - Searching multiple directories
$SearchPaths = @(
    "$env:TEMP",
    "$env:USERPROFILE\Downloads", 
    "C:\Temp",
    "C:\Install"
)

foreach ($SearchPath in $SearchPaths) {
    $TestPath = Join-Path $SearchPath $MSIName
    if (Test-Path $TestPath) {
        $MSIPath = $TestPath
        break
    }
}
```

### **Correct Approach: File Attachment**
```powershell
# ✅ DO THIS - Direct reference to attached file
$MSIPath = "install.msi"
if (Test-Path $MSIPath) {
    Write-Output "Found attached MSI file: $MSIPath"
    # Proceed with installation
} else {
    Write-Error "MSI file not found as attachment - ensure file is attached to component"
    exit 1
}
```

## 🚀 Implementation Examples

### **MSI Installation Script**
```powershell
<#
.SYNOPSIS
Software Installation using Datto RMM File Attachment

.DESCRIPTION
Installs software using MSI file attached to the Datto RMM component
#>

# Configuration
$MSIFileName = "YourSoftware.msi"
$InstallArgs = @("/i", $MSIFileName, "/quiet", "/norestart")

# Check for attached MSI file
if (Test-Path $MSIFileName) {
    Write-Output "Found attached MSI: $MSIFileName"
    
    # Execute installation
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $InstallArgs -Wait -PassThru
    
    switch ($process.ExitCode) {
        0 { Write-Output "Installation completed successfully"; exit 0 }
        3010 { Write-Output "Installation completed - reboot required"; exit 3010 }
        default { Write-Error "Installation failed with exit code: $($process.ExitCode)"; exit $process.ExitCode }
    }
} else {
    Write-Error "MSI file not found: $MSIFileName"
    Write-Error "Ensure the MSI file is attached to the Datto RMM component"
    exit 1
}
```

### **Configuration File Deployment**
```powershell
# Deploy configuration file attached to component
$ConfigFileName = "app-config.xml"
$DestinationPath = "C:\Program Files\YourApp\config.xml"

if (Test-Path $ConfigFileName) {
    Write-Output "Found attached config file: $ConfigFileName"
    Copy-Item -Path $ConfigFileName -Destination $DestinationPath -Force
    Write-Output "Configuration deployed successfully"
} else {
    Write-Error "Configuration file not found as attachment: $ConfigFileName"
    exit 1
}
```

## 📋 Best Practices

### **1. File Naming**
- Use **exact filenames** including spaces and special characters
- Verify filename matches exactly what you attach
- Consider using simple names without special characters when possible

### **2. File Validation**
```powershell
# Always validate attached files
$RequiredFile = "installer.msi"

if (-not (Test-Path $RequiredFile)) {
    Write-Error "Required file not found: $RequiredFile"
    Write-Error "Please attach the file to the Datto RMM component"
    exit 1
}

# Optional: Validate file size
$FileInfo = Get-Item $RequiredFile
if ($FileInfo.Length -lt 1MB) {
    Write-Warning "File appears small ($($FileInfo.Length) bytes) - verify correct file attached"
}
```

### **3. Multiple File Support**
```powershell
# Handle multiple attached files
$RequiredFiles = @("installer.msi", "config.xml", "license.key")

foreach ($File in $RequiredFiles) {
    if (-not (Test-Path $File)) {
        Write-Error "Required file missing: $File"
        exit 1
    }
    Write-Output "✓ Found: $File"
}

Write-Output "All required files present - proceeding with deployment"
```

## 🔧 Component Configuration

### **Step-by-Step Process**

1. **Create Component**
   - Choose appropriate component type (Applications, Scripts, etc.)
   - Write your script using direct file references

2. **Attach Files**
   - Use the **file attachment fields** beneath the script edit box
   - Upload all required files (MSI, config files, etc.)
   - Verify filenames match exactly what your script expects

3. **Deploy**
   - Files are automatically available in the script's working directory
   - No additional file management required

### **Component Script Template**
```powershell
# Datto RMM Component with File Attachment
param()

# File configuration - update these for your specific files
$RequiredFiles = @(
    "installer.msi",
    "config.xml"
)

# Validate all required files are attached
foreach ($File in $RequiredFiles) {
    if (-not (Test-Path $File)) {
        Write-Error "Required file not attached: $File"
        Write-Error "Please attach all required files to this component"
        exit 1
    }
}

Write-Output "All required files found - proceeding with deployment"

# Your deployment logic here using direct file references
# Example: Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "installer.msi", "/quiet"
```

## 🛠️ Troubleshooting

### **File Not Found Issues**
```
Error: Required file not found: installer.msi
```

**Solutions:**
1. Verify file is attached to the component using file attachment fields
2. Check filename matches exactly (including case, spaces, extensions)
3. Ensure file uploaded successfully (check file size in component editor)

### **Permission Issues**
```
Error: Access denied when accessing attached file
```

**Solutions:**
1. Verify Datto RMM agent has appropriate permissions
2. Check if file is locked by another process
3. Ensure file isn't corrupted during upload

## 📊 Migration from Manual File Placement

### **Before (Manual Placement)**
```powershell
# Old approach - searching multiple locations
$SearchPaths = @("$env:TEMP", "C:\Temp", "C:\Install")
$MSIPath = $null
foreach ($Path in $SearchPaths) {
    $TestPath = Join-Path $Path "installer.msi"
    if (Test-Path $TestPath) {
        $MSIPath = $TestPath
        break
    }
}
```

### **After (File Attachment)**
```powershell
# New approach - direct reference
$MSIPath = "installer.msi"
if (Test-Path $MSIPath) {
    # File is attached and ready to use
}
```

## 🎯 Summary

- ✅ **Use Datto RMM file attachment** for all installer files and resources
- ✅ **Reference files directly by name** - no full paths needed
- ✅ **Validate file presence** before attempting to use
- ❌ **Don't search multiple directories** for files
- ❌ **Don't rely on manual file placement** on target devices
- ❌ **Don't use complex file discovery logic** when file attachment is available

This approach is **simpler**, **more reliable**, and follows **official Datto RMM best practices**.
