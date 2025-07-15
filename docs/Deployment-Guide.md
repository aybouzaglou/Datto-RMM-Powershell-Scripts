# Datto RMM GitHub Function Library Deployment Guide

## Quick Start

### 1. Repository Setup
Your repository is already configured with the function library architecture. The structure includes:

```
├── shared-functions/          # Function library modules
├── components/               # Organized scripts by type
├── launchers/               # Universal launchers
└── docs/                   # Documentation
```

### 2. Immediate Usage
You can start using the new architecture immediately:

**Option A: Use Enhanced Scripts**
- `components/Scripts/FocusedDebloat.ps1` - Enhanced debloat script
- `components/Applications/ScanSnapHome.ps1` - Enhanced ScanSnap installer
- `components/Monitors/DiskSpaceMonitor.ps1` - Example monitor script

**Option B: Use Launchers (Applications & Scripts Only)**
- `launchers/UniversalLauncher.ps1` - Works with Applications & Scripts
- `launchers/LaunchInstaller.ps1` - Optimized for Applications components
- `launchers/LaunchScripts.ps1` - Optimized for Scripts components
- **Note**: Monitors use direct deployment (paste script content directly)

## Datto RMM Component Configuration

### Method 1: Enhanced Existing Scripts

Replace your existing script content with a simple launcher:

```powershell
# Enhanced FocusedDebloat Launcher
$LauncherURL = "https://raw.githubusercontent.com/aybouzaglou/Datto-RMM-Powershell-Scripts/main/launchers/LaunchScripts.ps1"
$LauncherPath = "$env:TEMP\LaunchScripts.ps1"

[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
(New-Object System.Net.WebClient).DownloadFile($LauncherURL, $LauncherPath)

& $LauncherPath -ScriptName "FocusedDebloat.ps1"
exit $LASTEXITCODE
```

**Environment Variables:**
- Keep your existing variables (customwhitelist, skipwindows, etc.)
- The enhanced script will automatically use them

### Method 2: Universal Launcher Approach

Create new components using the universal launcher:

```powershell
# Universal Launcher Component
$LauncherURL = "https://raw.githubusercontent.com/aybouzaglou/Datto-RMM-Powershell-Scripts/main/launchers/UniversalLauncher.ps1"
$LauncherPath = "$env:TEMP\UniversalLauncher.ps1"

[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
(New-Object System.Net.WebClient).DownloadFile($LauncherURL, $LauncherPath)

& $LauncherPath -ScriptName $env:ScriptName -ScriptType $env:ScriptType
exit $LASTEXITCODE
```

**Required Environment Variables:**
- `ScriptName` (String): "FocusedDebloat.ps1"
- `ScriptType` (Selection): "Scripts" | "Applications" | "Monitors"

### Method 3: Specialized Launchers

For specific script types, use specialized launchers:

#### Installation Scripts
```powershell
# Installation Launcher
$LauncherURL = "https://raw.githubusercontent.com/aybouzaglou/Datto-RMM-Powershell-Scripts/main/launchers/LaunchInstaller.ps1"
$LauncherPath = "$env:TEMP\LaunchInstaller.ps1"

[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
(New-Object System.Net.WebClient).DownloadFile($LauncherURL, $LauncherPath)

& $LauncherPath -ScriptName $env:ScriptName
exit $LASTEXITCODE
```

#### Monitor Scripts (Direct Deployment)
```powershell
# ⚠️ DEPRECATED: Monitor launchers are no longer recommended
# Modern approach: Paste the entire monitor script content directly into the component
# This provides maximum performance and reliability for monitors

# For existing monitor scripts, copy the entire script content from:
# components/monitors/YourMonitor.ps1
# and paste it directly into the Datto RMM component script field
```

## Migration Strategy

### Phase 1: Test with Existing Scripts (Immediate)
1. **Test Enhanced FocusedDebloat**:
   - Create a test component using Method 1 above
   - Set `ScriptName = "FocusedDebloat.ps1"`
   - Test with your existing environment variables
   - Verify improved logging and error handling

2. **Test ScanSnap Installation**:
   - Create a test component using the installation launcher
   - Set `ScriptName = "ScanSnapHome.ps1"`
   - Test installation detection and process

3. **Test Disk Space Monitor**:
   - Create a Custom Monitor component using the monitor launcher
   - Set `ScriptName = "DiskSpaceMonitor.ps1"`
   - Configure thresholds: `WarningThreshold = 15`, `CriticalThreshold = 5`

### Phase 2: Gradual Migration (1-2 weeks)
1. **Migrate High-Value Scripts**:
   - Start with scripts that run frequently
   - Focus on scripts with reliability issues
   - Migrate scripts that would benefit from shared functions

2. **Create New Scripts**:
   - Use the function library for all new script development
   - Follow the component structure for organization
   - Leverage shared functions for common operations

### Phase 3: Full Adoption (1 month)
1. **Migrate Remaining Scripts**:
   - Convert all scripts to use the new architecture
   - Retire old standalone scripts
   - Update documentation and procedures

2. **Advanced Features**:
   - Implement version pinning for production
   - Set up environment-specific repositories
   - Create custom shared functions for your specific needs

## Component Examples

### Installation Component
```
Component Name: Install Software via GitHub
Component Type: Application
Script Language: PowerShell
Timeout: 30 minutes

Environment Variables:
- ScriptName (String): "InstallChrome.ps1"
- InstallerURL (String): "https://example.com/installer.exe"
- InstallArgs (String): "/S /silent"

Script Content: [Universal Launcher code from Method 2]
```

### Monitor Component
```
Component Name: Disk Space Monitor
Component Type: Custom Monitor
Script Language: PowerShell
Timeout: 3 seconds

Environment Variables:
- ScriptName (String): "DiskSpaceMonitor.ps1"
- WarningThreshold (Integer): 15
- CriticalThreshold (Integer): 5
- DriveLetters (String): "C,D"

Script Content: [Monitor Launcher code from Method 3]
```

### Maintenance Component
```
Component Name: System Debloat
Component Type: Application
Script Language: PowerShell
Timeout: 15 minutes

Environment Variables:
- ScriptName (String): "FocusedDebloat.ps1"
- customwhitelist (String): "App1,App2,App3"
- skipwindows (Boolean): false
- skiphp (Boolean): false

Script Content: [Maintenance Launcher code from Method 3]
```

## Advanced Configuration

### Version Pinning
For production stability, pin to specific versions:

```powershell
# Pin to specific release tag
& $LauncherPath -ScriptName $env:ScriptName -ScriptType $env:ScriptType -Branch "v2.1.0"
```

### Environment-Specific Repositories
Use different repositories for different environments:

```powershell
# Environment-specific repository selection
$GitHubRepo = switch ($env:RMM_Environment) {
    "Production" { "yourorg/rmm-scripts" }
    "Staging"    { "yourorg/rmm-scripts-staging" }
    "Development" { "yourorg/rmm-scripts-dev" }
    default      { "aybouzaglou/Datto-RMM-Powershell-Scripts" }
}

& $LauncherPath -ScriptName $env:ScriptName -ScriptType $env:ScriptType -GitHubRepo $GitHubRepo
```

### Offline Mode
For air-gapped environments:

```powershell
# Use only cached functions, don't attempt downloads
& $LauncherPath -ScriptName $env:ScriptName -ScriptType $env:ScriptType -OfflineMode
```

## Monitoring and Troubleshooting

### Log Locations
- **Launcher Logs**: `C:\ProgramData\DattoRMM\`
- **Script Logs**: Varies by script type
  - Installations: `C:\ProgramData\DattoRMM\Installations\`
  - Monitors: `C:\ProgramData\DattoRMM\Monitors\`
  - Maintenance: `C:\ProgramData\DattoRMM\Maintenance\`

### Function Status Checking
```powershell
# Check if functions loaded successfully
if ($Global:RMMFunctionsLoaded) {
    Write-Output "Functions loaded: $($Global:RMMFunctionsLoadedCount)"
    Write-Output "Version: $($Global:RMMFunctionsVersion)"
    Write-Output "Source: $($Global:RMMFunctionsSource)"
} else {
    Write-Output "Functions not loaded or partially loaded"
    Write-Output "Missing: $($Global:RMMFunctionsMissingCount)"
}
```

### Common Issues and Solutions

#### ⚠️ DEPRECATED: Functions Not Loading
**Note**: Modern scripts use embedded functions, so this issue no longer applies.
**Legacy Solutions** (for old scripts only):
- Check internet connectivity
- Verify repository URL is accessible
- Check Windows Defender/antivirus blocking

#### ⚠️ DEPRECATED: Cache Issues
**Note**: Modern scripts don't use caching - functions are embedded directly.
**Legacy Solutions** (for old scripts only):
- Use `-ForceDownload` parameter
- Clear cache directory: `C:\Users\*\AppData\Local\Temp\RMM-Functions`

#### Timeout Errors
**Symptoms**: Scripts fail with timeout messages
**Solutions**:
- Increase timeout values in launcher parameters
- Check for network latency issues
- Use offline mode for cached functions

## Best Practices

### Development
1. **Test Locally**: Test scripts locally before deploying to RMM
2. **Use Branches**: Develop new features in Git branches
3. **Version Control**: Tag stable releases for production use
4. **Documentation**: Document all custom functions and scripts

### Deployment
1. **Gradual Rollout**: Start with test devices and low-risk scripts
2. **Monitor Logs**: Watch for function loading failures
3. **Backup Strategy**: Keep old scripts as fallback during migration
4. **Version Pinning**: Use specific versions for production components

### Maintenance
1. **Regular Updates**: Keep function library updated
2. **Performance Monitoring**: Monitor script execution times
3. **Log Review**: Regularly review logs for issues
4. **Function Optimization**: Optimize frequently-used functions

## Support and Resources

### Documentation
- [Function Reference](Function-Reference.md) - Complete function documentation
- [GitHub Function Library Guide](GitHub-Function-Library-Guide.md) - Architecture overview

### Troubleshooting
- Check transcript logs for detailed execution information
- ⚠️ **DEPRECATED**: `$Global:RMMFunctionsStatus` (modern scripts use embedded functions)
- Review Git commit history for recent changes
- ⚠️ **DEPRECATED**: `-OfflineMode` (modern scripts don't need network dependencies)

### Getting Help
- Review the function reference for usage examples
- Check the troubleshooting section in the main guide
- Test scripts in isolation to identify issues
- Use verbose logging to trace execution flow
