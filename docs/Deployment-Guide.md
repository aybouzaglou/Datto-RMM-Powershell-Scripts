# Datto RMM Traditional Script Deployment Guide

## Quick Start

### 1. Repository Setup
Your repository is configured with the traditional script architecture. The structure includes:

```
├── shared-functions/          # Function reference patterns (copy/paste)
├── components/               # Self-contained scripts by type
└── docs/                   # Documentation
```

### 2. Immediate Usage
You can start using scripts immediately with direct deployment:

**Self-Contained Scripts (All Components)**
- `components/Scripts/FocusedDebloat.ps1` - Windows debloat script with embedded functions
- `components/Applications/ScanSnapHome.ps1` - ScanSnap installer with embedded functions (uses file attachment)
- `components/Applications/TungstenPrintixClient.ps1` - Printix client installer with embedded functions (uses file attachment)
- `components/Monitors/DiskSpaceMonitor.ps1` - Disk space monitor with embedded functions

**Deployment Method: Direct Paste**
- Copy entire script content and paste directly into Datto RMM component
- No launchers needed - all functions are embedded in each script
- All components use the same deployment method for consistency

## 📎 File Attachment for Installers

For Applications components that install software, use **Datto RMM's file attachment feature**:

### **Correct Approach**
1. **Attach Files**: Use file attachment fields beneath the script edit box
2. **Reference Directly**: Scripts reference files by name (e.g., `"installer.msi"`)
3. **No Path Required**: Files are automatically available in the working directory

### **Example Script Pattern**
```powershell
# Check for attached installer file
$InstallerFile = "YourSoftware.msi"
if (Test-Path $InstallerFile) {
    Write-Output "Found attached installer: $InstallerFile"
    # Proceed with installation
} else {
    Write-Error "Installer not found - ensure file is attached to component"
    exit 1
}
```

**📖 See**: [File Attachment Guide](Datto-RMM-File-Attachment-Guide.md) for complete details

## 🔧 Script Development Standards

### **Self-Contained Script Requirements**
All scripts must be completely self-contained with embedded functions:

#### **✅ Recommended Approach: Embedded Functions**
```powershell
# Embed all needed functions directly in the script
function Write-RMMLog {
    param([string]$Message, [string]$Level = 'Info')
    $prefix = switch ($Level) {
        'Success' { 'SUCCESS ' }
        'Failed'  { 'FAILED  ' }
        'Warning' { 'WARNING ' }
        'Status'  { 'STATUS  ' }
        'Config'  { 'CONFIG  ' }
        'Detect'  { 'DETECT  ' }
        default   { 'INFO    ' }
    }
    Write-Output "$prefix$Message"
}

# Use embedded function
Write-RMMLog "Script starting..." -Level Status
}
```

#### **❌ Avoid: Long Cache Timeouts**
```powershell
# DON'T DO THIS - causes stale script issues
if ($fileAge.TotalMinutes -lt 60) {  # Too long!
    $shouldDownload = $false
}
```

### **Why Short Cache Times Matter**
- ✅ **Bug fixes deploy quickly** - Critical fixes reach production faster
- ✅ **Consistent behavior** - Same approach for all environments
- ✅ **Reduced support issues** - Fewer problems from stale scripts
- ✅ **Better testing experience** - Changes are reflected immediately

## Datto RMM Component Configuration

### Direct Deployment Method (All Components)

All components use the same simple deployment method:

#### **Step 1: Copy Script Content**
1. Navigate to the appropriate script in `components/` directory
2. Copy the **entire script content** (all functions are embedded)
3. Paste directly into Datto RMM component script field

#### **Step 2: Configure Environment Variables**
Set environment variables specific to your script needs:

**For FocusedDebloat.ps1:**
```
customwhitelist = App1,App2,App3
skipwindows = false
skiphp = false
skipdell = false
skiplenovo = false
```

**For DiskSpaceMonitor.ps1:**
```
WarningThreshold = 15
CriticalThreshold = 5
DriveLetters = C,D
```

**For ScanSnapHome.ps1:**
```
(No specific environment variables - script handles detection automatically)
```

#### **Step 3: Deploy Component**
1. Save the component configuration
2. Deploy to target devices
3. Monitor execution results

**Benefits of Direct Deployment:**
- ✅ **No network dependencies** during execution
- ✅ **Maximum performance** - no download overhead
- ✅ **100% reliability** - works in all network conditions
- ✅ **Easy troubleshooting** - all code visible in component
- ✅ **Consistent approach** - same method for all component types

## Migration Strategy

### Phase 1: Test with Self-Contained Scripts (Immediate)
1. **Test FocusedDebloat Script**:
   - Copy entire content from `components/Scripts/FocusedDebloat.ps1`
   - Paste directly into Datto RMM Scripts component
   - Set environment variables: `customwhitelist`, `skipwindows`, etc.
   - Verify improved logging and error handling

2. **Test ScanSnap Installation**:
   - Copy entire content from `components/Applications/ScanSnapHome.ps1`
   - Paste directly into Datto RMM Applications component
   - **Attach installer files** using Datto RMM file attachment feature
   - Test installation detection and process

3. **Test Disk Space Monitor**:
   - Copy entire content from `components/Monitors/DiskSpaceMonitor.ps1`
   - Paste directly into Datto RMM Custom Monitor component
   - Configure thresholds: `WarningThreshold = 15`, `CriticalThreshold = 5`

### Phase 2: Gradual Migration (1-2 weeks)
1. **Migrate High-Value Scripts**:
   - Start with scripts that run frequently
   - Focus on scripts with reliability issues
   - Convert to self-contained approach with embedded functions

2. **Create New Scripts**:
   - Use self-contained architecture for all new script development
   - Follow the component structure for organization
   - Copy needed functions from shared-functions/ into each script

### Phase 3: Full Adoption (1 month)
1. **Migrate Remaining Scripts**:
   - Convert all scripts to self-contained approach
   - Retire old standalone scripts
   - Update documentation and procedures

2. **Optimization**:
   - Review and optimize embedded functions
   - Standardize common patterns across scripts
   - Create new reference functions as needed

## Component Examples

### Installation Component
```
Component Name: ScanSnap Home Installation
Component Type: Application
Script Language: PowerShell
Timeout: 30 minutes

Environment Variables:
(No specific environment variables - script handles detection automatically)

Script Content: [Paste entire content from components/Applications/ScanSnapHome.ps1]
File Attachments: ScanSnap Home installer files
```

### Monitor Component
```
Component Name: Disk Space Monitor
Component Type: Custom Monitor
Script Language: PowerShell
Timeout: 3 seconds

Environment Variables:
- WarningThreshold (Integer): 15
- CriticalThreshold (Integer): 5
- DriveLetters (String): "C,D"

Script Content: [Paste entire content from components/Monitors/DiskSpaceMonitor.ps1]
```

### Maintenance Component
```
Component Name: System Debloat
Component Type: Scripts
Script Language: PowerShell
Timeout: 15 minutes

Environment Variables:
- customwhitelist (String): "App1,App2,App3"
- skipwindows (Boolean): false
- skiphp (Boolean): false
- skipdell (Boolean): false
- skiplenovo (Boolean): false

Script Content: [Paste entire content from components/Scripts/FocusedDebloat.ps1]
```

## Script Customization

### Adding Custom Functions
To add custom functions to existing scripts:

1. **Copy base script** from components/ directory
2. **Add your custom functions** at the top of the script
3. **Use your functions** in the main script logic
4. **Test thoroughly** before deployment

### Environment-Specific Configurations
Use environment variables for different environments:

```powershell
# Example: Environment-specific configuration
$Environment = $env:RMM_Environment
$ConfigPath = switch ($Environment) {
    "Production" { "C:\Config\Production\" }
    "Staging"    { "C:\Config\Staging\" }
    "Development" { "C:\Config\Dev\" }
    default      { "C:\Config\Default\" }
}
```

### Script Versioning
For production stability, maintain version comments in scripts:

```powershell
<#
.NOTES
Version: 2.1.0
Author: Your Organization
Last Modified: 2025-01-15
Environment: Production
#>
```

## Monitoring and Troubleshooting

### Log Locations
- **Script Logs**: Varies by script type
  - Applications: `C:\ProgramData\DattoRMM\Applications\`
  - Monitors: `C:\ProgramData\DattoRMM\Monitors\`
  - Scripts: `C:\ProgramData\DattoRMM\Scripts\`

### Script Status Checking
```powershell
# Example embedded logging function
function Write-RMMLog {
    param([string]$Message, [string]$Level = 'Info')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage

    # Optional: Write to log file
    $logFile = "$env:TEMP\RMM-Script-$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}
```

### Common Issues and Solutions

#### Script Execution Errors
**Symptoms**: Scripts fail with PowerShell errors
**Solutions**:
- Check PowerShell execution policy
- Verify all required functions are embedded in script
- Test script locally before deployment
- Review Datto RMM component logs

#### Environment Variable Issues
**Symptoms**: Scripts don't receive expected configuration
**Solutions**:
- Verify environment variables are set correctly in component
- Check variable names match exactly (case-sensitive)
- Use default values in script for optional variables

#### Performance Issues
**Symptoms**: Scripts run slowly or timeout
**Solutions**:
- Optimize embedded functions for performance
- Remove unnecessary operations
- Increase component timeout if needed
- Consider breaking large scripts into smaller components

## Best Practices

### Development
1. **Test Locally**: Test scripts locally before deploying to RMM
2. **Use Branches**: Develop new features in Git branches
3. **Version Control**: Tag stable releases for production use
4. **Documentation**: Document all custom functions and scripts
5. **Embed Functions**: Copy needed functions directly into each script

### Deployment
1. **Gradual Rollout**: Start with test devices and low-risk scripts
2. **Monitor Logs**: Watch for script execution issues
3. **Backup Strategy**: Keep old scripts as fallback during migration
4. **Self-Contained**: Ensure all scripts are completely self-contained
5. **Test Thoroughly**: Verify all embedded functions work correctly

### Maintenance
1. **Regular Updates**: Update embedded functions in scripts as needed
2. **Performance Monitoring**: Monitor script execution times
3. **Log Review**: Regularly review logs for issues
4. **Function Optimization**: Optimize embedded functions for performance
5. **Consistency**: Maintain consistent function patterns across scripts

## Support and Resources

### Documentation
- [Function Reference](Function-Reference.md) - Complete function documentation for copy/paste patterns
- [Architecture Philosophy](Architecture-Philosophy.md) - Self-contained script approach

### Troubleshooting
- Check transcript logs for detailed execution information
- Review script content directly in Datto RMM component
- Test scripts locally to identify issues
- Verify all required functions are embedded in script

### Getting Help
- Review the function reference for copy/paste patterns
- Check the troubleshooting section in this guide
- Test scripts in isolation to identify issues
- Use verbose logging to trace execution flow
- Ensure all dependencies are embedded in the script
