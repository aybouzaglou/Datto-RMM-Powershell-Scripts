# GitHub-Based Function Library for Datto RMM - Traditional Script Approach

## Overview

This repository implements a **traditional script deployment architecture** that optimizes for reliability and simplicity:

- **📊 All Components**: Direct deployment with embedded functions for maximum reliability
- **🔧 Consistent Approach**: Same deployment method for Applications, Scripts, and Monitors
- **📚 Reference Library**: Shared functions serve as copy/paste patterns for consistency

This approach provides **maximum reliability**, **simple deployment**, and **easy troubleshooting** across all component types.

## 🎯 Deployment Strategy

### **✅ Use Direct Deployment (Embedded Functions) For:**
- **📊 Monitors**: All monitor components for maximum performance
- **🔧 Applications**: Software deployment and installation scripts
- **📝 Scripts**: General automation and maintenance scripts
- **All Components**: Consistent approach across all component types

### **📚 Function Reference Library:**
- **Copy/Paste Patterns**: Use shared-functions/ as reference for common patterns
- **Self-Contained Scripts**: Each script contains all needed functions
- **No Runtime Dependencies**: Scripts work independently without external calls

## Architecture Benefits

### **Development Workflow**
- **Version Control**: Full Git history for all scripts and function patterns
- **Collaboration**: Multiple team members can contribute via pull requests
- **Testing**: Use branches for testing new features before production
- **Documentation**: README files and inline documentation in the repo

### **Deployment Advantages**
- **Maximum Reliability**: No network dependencies during script execution
- **Simple Deployment**: Copy and paste script content directly into RMM
- **Consistent Patterns**: Same function patterns across all scripts
- **Easy Troubleshooting**: All code visible in RMM component

### **Operational Benefits**
- **Zero Network Dependencies**: Scripts work in all network conditions
- **Better Performance**: No download overhead during execution
- **Simplified Architecture**: No complex launcher system to maintain
- **Full Visibility**: All script logic visible in Datto RMM component

## Repository Structure

```
your-rmm-scripts/
├── shared-functions/
│   ├── Core/
│   │   ├── RMMLogging.ps1          # Standardized logging functions
│   │   ├── RMMValidation.ps1       # Input validation and system checks
│   │   └── RMMSoftwareDetection.ps1 # Fast software detection (no Win32_Product)
│   ├── Utilities/
│   │   ├── NetworkUtils.ps1        # Network operations and downloads
│   │   ├── FileOperations.ps1      # File and directory operations
│   │   └── RegistryHelpers.ps1     # Registry operations and software detection

├── components/
│   ├── Monitors/                   # System health monitoring (<3 seconds, immutable)
│   ├── Applications/               # Software deployment and installation
│   └── Scripts/                    # General automation and maintenance
├── launchers/
│   ├── UniversalLauncher.ps1       # Universal script launcher (Applications & Scripts)
│   ├── LaunchInstaller.ps1         # Applications component launcher
│   └── LaunchScripts.ps1           # Scripts component launcher
└── docs/
    ├── GitHub-Function-Library-Guide.md
    ├── Function-Reference.md
    └── Deployment-Guide.md
```

## Core Function Modules

### **RMMLogging.ps1**
Standardized logging with structured output formats:
- `Write-RMMLog` - Structured logging with levels (SUCCESS, FAILED, WARNING, STATUS, CONFIG, DETECT, METRIC)
- `Start-RMMTranscript` / `Stop-RMMTranscript` - Transcript management
- `Write-RMMMonitorResult` - Monitor result markers for Custom Monitor components
- `Write-RMMEventLog` - Windows Event Log integration

### **RMMValidation.ps1**
Input validation and environment checks:
- `Get-RMMVariable` - Datto RMM environment variable validation with type conversion
- `Test-RMMVariable` - Variable validation with criteria checking
- `Invoke-RMMTimeout` - Universal timeout wrapper for safe operations
- `Test-RMMSystemRequirements` - System requirement validation
- `Test-RMMInternetConnectivity` - Network connectivity testing

### **RMMSoftwareDetection.ps1**
Fast software detection avoiding Win32_Product:
- `Get-RMMSoftware` - Registry-based software detection
- `Test-RMMSoftwareInstalled` - Quick installation check
- `Get-RMMManufacturer` - System manufacturer detection
- `Remove-RMMSoftware` - Safe software removal with multiple methods

### **NetworkUtils.ps1**
Network operations for downloads and connectivity:
- `Set-RMMSecurityProtocol` - TLS 1.2 configuration
- `Invoke-RMMDownload` - Secure file downloads with verification
- `Test-RMMUrl` - URL accessibility testing
- `Get-RMMPublicIP` - Public IP detection
- `Test-RMMPort` - Port connectivity testing

### **FileOperations.ps1**
File and directory operations:
- `New-RMMDirectory` / `Remove-RMMDirectory` - Safe directory operations
- `Copy-RMMFile` - File copying with verification
- `Expand-RMMArchive` - Archive extraction (ZIP, CAB)
- `Stop-RMMProcess` - Safe process termination
- `Get-RMMTempPath` - Temporary file path generation

### **RegistryHelpers.ps1**
Registry operations and software detection:
- `Get-RMMRegistryValue` / `Set-RMMRegistryValue` - Safe registry operations
- `Remove-RMMRegistryValue` - Registry value removal
- `Test-RMMRegistryPath` - Registry path existence checking
- `Get-RMMUninstallInfo` - Fast software detection via registry
- `Backup-RMMRegistryKey` - Registry backup functionality

## Function Reference Architecture

### **Copy/Paste Pattern**
The function library provides reference patterns for embedding in scripts:

```powershell
# Copy functions directly into your script
function Write-RMMLog {
    param([string]$Message, [string]$Level = 'Info')
    $prefix = switch ($Level) {
        'Success' { 'SUCCESS ' }
        'Failed'  { 'FAILED  ' }
        'Warning' { 'WARNING ' }
        default   { 'INFO    ' }
    }
    Write-Output "$prefix$Message"
}

# Use embedded function in your script
Write-RMMLog "Script starting..." -Level Status
```

### **Self-Contained Scripts**

#### **All Component Types**
- All functions embedded directly in each script
- No external dependencies during execution
- Maximum reliability in all network conditions
- Easy troubleshooting with all code visible

#### **Function Embedding Process**
1. Identify needed functions from shared-functions/
2. Copy function code into your script
3. Test script locally to ensure all functions work
4. Deploy script directly to Datto RMM component

## Function Integration Process

### **Manual Integration**
```powershell
# Copy needed functions from shared-functions/ into your script
# Example: Copy Write-RMMLog function
function Write-RMMLog {
    # Function implementation here
}

# Use the function in your script logic
Write-RMMLog "Starting operation..." -Level Status
```

### **Caching System**
- Functions are cached locally for 1 hour by default
- Offline fallback for cached functions
- Force refresh with `-ForceDownload` parameter
- Version pinning support with Git tags/branches

### **Fallback Mechanisms**
Scripts include fallback functions for standalone operation when shared functions aren't available.

## Usage Examples

### **Basic Script with Shared Functions**
```powershell
# Load shared functions (done automatically by launchers)
if (-not $Global:RMMFunctionsLoaded) {
    . .\shared-functions\SharedFunctions.ps1
}

# Use shared validation
if (-not (Test-RMMVariable -VariableName "SoftwareName" -VariableValue $env:SoftwareName -Required)) {
    exit 12
}

# Use shared logging
Write-RMMLog "Starting installation of $($env:SoftwareName)" -Level Status

# Check if already installed
if (Test-RMMSoftwareInstalled -Name $env:SoftwareName) {
    Write-RMMLog "Software already installed" -Level Success
    exit 0
}

# Your installation logic here...
Write-RMMLog "Installation completed successfully" -Level Success
exit 0
```

### **Monitor Script Example**
```powershell
# Monitor scripts use minimal shared functions for performance
param([int]$Threshold = 15)

# Get threshold from environment
$Threshold = Get-RMMVariable -Name "Threshold" -Type "Integer" -Default $Threshold

# Your monitoring logic here...
$result = # Your check

if ($result -gt $Threshold) {
    Write-RMMMonitorResult -Status "CRITICAL" -Message "Value $result exceeds threshold $Threshold" -ExitCode 1
} else {
    Write-RMMMonitorResult -Status "OK" -Message "Value $result is within threshold" -ExitCode 0
}
```

## Datto RMM Integration

### **Component Configuration**
In your Datto RMM components, use minimal launcher scripts:

```powershell
# Minimal RMM component script
$LauncherURL = "https://raw.githubusercontent.com/yourorg/rmm-scripts/main/launchers/LaunchInstaller.ps1"
$LauncherPath = "$env:TEMP\LaunchInstaller.ps1"

[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
(New-Object System.Net.WebClient).DownloadFile($LauncherURL, $LauncherPath)

& $LauncherPath -ScriptName $env:ScriptName -ScriptType $env:ScriptType
exit $LASTEXITCODE
```

### **Environment Variables**
Configure these in your Datto RMM components:
- `ScriptName` (String): "MyScript.ps1"
- `ScriptType` (Selection): "installations", "monitors", "maintenance"
- Any script-specific parameters

## Version Management

### **Production Deployment**
```powershell
# Pin to specific version/tag for production
$Branch = "v2.1.0"  # Use tags for stable releases
```

### **Environment-Specific Configuration**
```powershell
# Different repos for different environments
$GitHubRepo = switch ($env:RMM_Environment) {
    "Production" { "yourorg/rmm-scripts" }
    "Staging"    { "yourorg/rmm-scripts-staging" }
    "Development" { "yourorg/rmm-scripts-dev" }
    default      { "yourorg/rmm-scripts" }
}
```

## Best Practices

### **Script Development**
1. Always use shared functions when available
2. Include fallback functions for standalone operation
3. Use structured logging with appropriate levels
4. Implement timeout protection for long-running operations
5. Validate all input parameters

### **Function Development**
1. Keep functions focused and single-purpose
2. Include comprehensive error handling
3. Use consistent parameter naming
4. Document all functions with proper help text
5. Test functions in isolation

### **Deployment Strategy**
1. Use Git branches for development and testing
2. Tag stable releases for production use
3. Test changes in staging environment first
4. Monitor function loading success rates
5. Maintain backward compatibility when possible

## Troubleshooting

### **Common Issues**
- **Functions not loading**: Check internet connectivity and repository access
- **Cache issues**: Use `-ForceDownload` to refresh cached functions
- **Timeout errors**: Increase timeout values for slow operations
- **Permission errors**: Ensure scripts run with appropriate privileges

### **Debugging**
- Check transcript logs in `C:\ProgramData\DattoRMM\`
- Verify function loading status with `$Global:RMMFunctionsStatus`
- Use `-OfflineMode` for testing with cached functions
- Review Git commit history for recent changes

This architecture transforms your Datto RMM scripting into a professional, maintainable, and scalable automation platform that rivals enterprise configuration management systems.
