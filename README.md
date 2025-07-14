# Datto RMM PowerShell Scripts

A comprehensive collection of PowerShell scripts designed for Datto RMM (Remote Monitoring and Management) featuring a **GitHub-based function library architecture** for enterprise-grade automation.

## 🚀 Quick Start

This repository provides both **ready-to-use scripts** and a **sophisticated function library architecture** that transforms your Datto RMM scripting into a professional, maintainable, and scalable automation platform.

### 🆕 **NEW: GitHub Function Library Architecture**

**Zero-maintenance script updates** - Scripts automatically download the latest versions from GitHub without touching your RMM components!

```powershell
# Simple launcher in your Datto RMM component
$LauncherURL = "https://raw.githubusercontent.com/aybouzaglou/Datto-RMM-Powershell-Scripts/main/launchers/UniversalLauncher.ps1"
$LauncherPath = "$env:TEMP\UniversalLauncher.ps1"
(New-Object System.Net.WebClient).DownloadFile($LauncherURL, $LauncherPath)
& $LauncherPath -ScriptName $env:ScriptName -ScriptType $env:ScriptType
exit $LASTEXITCODE
```

**Benefits:**
- ✅ **Auto-updating scripts** - No more manual RMM component updates
- ✅ **Shared function library** - Consistent, reliable operations across all scripts
- ✅ **Version control** - Full Git history and rollback capabilities
- ✅ **Enterprise features** - Caching, offline mode, timeout protection
- ✅ **Better debugging** - Comprehensive logging and error handling

### 🏗️ Architecture Overview

| Component | Purpose | Location | Documentation |
|-----------|---------|----------|---------------|
| 🔧 **Shared Functions** | Reusable function library | `shared-functions/` | [Function Reference](docs/Function-Reference.md) |
| 🚀 **Launchers** | Universal script launchers | `launchers/` | [Deployment Guide](docs/Deployment-Guide.md) |
| 📦 **Components** | Datto RMM component categories | `components/` | [Component Categories Guide](docs/Datto-RMM-Component-Categories.md) |

### 🎯 Datto RMM Component Categories

| Category | Purpose | Timeout | Category Changeable | Location |
|----------|---------|---------|---------------------|----------|
| 🔧 **Applications** | Software deployment/installation | Up to 30 min | Yes (↔ Scripts) | `components/Applications/` |
| 📊 **Monitors** | System health monitoring | <3 seconds | No (category locked) | `components/Monitors/` |
| 📝 **Scripts** | General automation/maintenance | Flexible | Yes (↔ Applications) | `components/Scripts/` |

### Choose Your Approach

| Approach | Best For | Setup Time | Maintenance |
|----------|----------|------------|-------------|
| 🆕 **GitHub Architecture** | New deployments, enterprise environments | 15 minutes | Zero - auto-updating |
| 📚 **Traditional Guides** | Existing scripts, learning, custom development | Immediate | Manual updates |

**📋 [Quick Reference](Quick-Reference.md)** - Traditional script type decision matrix
**🚀 [Deployment Guide](docs/Deployment-Guide.md)** - Get started with GitHub architecture in 15 minutes
**📊 [Component Categories](docs/Datto-RMM-Component-Categories.md)** - Understand Datto RMM's three component types

## 📁 Repository Structure

### 🔧 Shared Function Library
```
shared-functions/
├── Core/
│   ├── RMMLogging.ps1          # Standardized logging functions
│   ├── RMMValidation.ps1       # Input validation and system checks
│   └── RMMSoftwareDetection.ps1 # Fast software detection (no Win32_Product)
├── Utilities/
│   ├── NetworkUtils.ps1        # Network operations and downloads
│   ├── FileOperations.ps1      # File and directory operations
│   └── RegistryHelpers.ps1     # Registry operations
└── SharedFunctions.ps1         # Master loader with caching
```

### 🚀 Universal Launchers
```
launchers/
├── UniversalLauncher.ps1       # Works with all component categories
├── LaunchInstaller.ps1         # Optimized for Applications components
├── LaunchMonitor.ps1           # Optimized for Monitors components
└── LaunchScripts.ps1           # Optimized for Scripts components
```

### 📦 Component Scripts (Datto RMM Categories)
```
components/
├── Applications/               # Software deployment (changeable)
│   └── ScanSnapHome.ps1       # ScanSnap Home installation
├── Monitors/                   # System health (immutable, <3s)
│   └── DiskSpaceMonitor.ps1   # Disk space monitoring
└── Scripts/                    # General automation (changeable)
    └── FocusedDebloat.ps1     # Windows bloatware removal
```

### 📚 Documentation & Guides

#### GitHub Function Library Architecture
- **[GitHub Function Library Guide](docs/GitHub-Function-Library-Guide.md)** - Complete architecture overview
- **[Function Reference](docs/Function-Reference.md)** - Detailed function documentation
- **[Deployment Guide](docs/Deployment-Guide.md)** - 15-minute setup guide
- **[Component Categories](docs/Datto-RMM-Component-Categories.md)** - Datto RMM category guide

#### Traditional Script Development
- **[Installation Scripts Guide](Installation-Scripts-Guide.md)** - Software deployment scripts
- **[Monitor Scripts Guide](Monitor-Scripts-Guide.md)** - Performance-critical monitoring
- **[Removal/Modification Scripts Guide](Removal-Modification-Scripts-Guide.md)** - Safe removal practices
- **[Quick Reference](Quick-Reference.md)** - Decision matrix and navigation

### 🔄 Legacy Scripts (Traditional Approach)
```
legacy/
├── DattoRMM-FocusedDebloat-Launcher.ps1  # Original launcher (superseded)
├── FocusedDebloat.ps1                    # Original debloat script
└── Scansnap.ps1                          # Original scanner script
```
**Migration Path**: Legacy scripts have enhanced versions in the new architecture with shared functions and better error handling.

## 🎯 Key Features

### 🆕 GitHub Function Library Architecture
- **🔄 Auto-updating scripts** - Zero maintenance, scripts update automatically
- **📚 Shared function library** - Consistent, reliable operations across all scripts
- **🏷️ Version control** - Full Git history, rollback capabilities, branch support
- **⚡ Enterprise features** - Caching, offline mode, timeout protection
- **🐛 Enhanced debugging** - Comprehensive logging and error handling
- **🔧 Modular design** - Reusable functions, easy customization

### 📊 Datto RMM Integration
- **🎯 Component categories** - Aligned with Applications, Monitors, Scripts
- **⏱️ Timeout optimization** - Category-specific execution patterns
- **🔒 Immutable Monitors** - Proper handling of Monitor category restrictions
- **📈 Exit code standards** - Category-appropriate success/failure codes
- **🔄 Launcher system** - Universal and specialized launchers

### 🛡️ Universal Requirements
- **🔐 LocalSystem Context**: All scripts run as NT AUTHORITY\SYSTEM
- **👻 No GUI Elements**: Scripts run invisibly in system context
- **📊 Standardized Exit Codes**: Consistent error reporting across all scripts
- **📝 Event Logging**: Built-in Windows Event Log integration
- **🔒 Security**: TLS 1.2 enforcement and secure downloads

### ⚡ Performance Optimization
- **📊 Monitor Scripts**: Optimized for <3-second execution (Datto RMM requirement)
- **🔍 Registry-First Detection**: Fast software detection (avoids Win32_Product)
- **⏰ Timeout Protection**: Prevents hanging processes with configurable timeouts
- **💾 Resource Efficiency**: Minimal system impact with intelligent caching
- **🚀 Function Caching**: Local caching reduces download overhead

## 🛠️ Getting Started

### 🚀 Quick Start (GitHub Architecture - Recommended)

1. **Choose your Datto RMM component category**:
   - 🔧 **Applications**: Software deployment/installation
   - 📊 **Monitors**: System health monitoring (<3 seconds)
   - 📝 **Scripts**: General automation/maintenance

2. **Create a Datto RMM component** with this simple launcher:
   ```powershell
   # Universal launcher for any component category
   $LauncherURL = "https://raw.githubusercontent.com/aybouzaglou/Datto-RMM-Powershell-Scripts/main/launchers/UniversalLauncher.ps1"
   $LauncherPath = "$env:TEMP\UniversalLauncher.ps1"
   [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
   (New-Object System.Net.WebClient).DownloadFile($LauncherURL, $LauncherPath)
   & $LauncherPath -ScriptName $env:ScriptName -ScriptType $env:ScriptType
   exit $LASTEXITCODE
   ```

3. **Set environment variables** in your Datto RMM component:
   - `ScriptName`: Name of script file (e.g., "FocusedDebloat.ps1")
   - `ScriptType`: Component category ("Applications", "Monitors", "Scripts")

4. **Deploy and enjoy** - Scripts auto-update from GitHub!

### 📚 Traditional Approach

1. **Identify your script type** using the [Quick Reference](Quick-Reference.md)
2. **Read the appropriate guide** for detailed requirements and templates
3. **Use the provided templates** as starting points for your scripts
4. **Test thoroughly** in non-production environments
5. **Deploy** through Datto RMM with manual updates

## 📖 Documentation Structure

### 🆕 GitHub Function Library Architecture
```text
├── docs/
│   ├── GitHub-Function-Library-Guide.md     # Complete architecture overview
│   ├── Function-Reference.md                # Detailed function documentation
│   ├── Deployment-Guide.md                  # 15-minute setup guide
│   └── Datto-RMM-Component-Categories.md    # Component category guide
├── shared-functions/                        # Reusable function library
├── launchers/                               # Universal script launchers
└── components/                              # Scripts organized by Datto RMM categories
```

### 📚 Traditional Script Development
```text
├── README.md                              # This file - main entry point
├── Quick-Reference.md                     # Decision matrix and overview
├── Installation-Scripts-Guide.md         # Software deployment guide
├── Monitor-Scripts-Guide.md              # System monitoring guide
├── Removal-Modification-Scripts-Guide.md # Software removal guide
├── DattoRMM-FocusedDebloat-Launcher.ps1 # Legacy launcher script
├── FocusedDebloat.ps1                    # Legacy debloat script
└── Scansnap.ps1                          # Legacy utility script
```

## 🔧 Common Operations

### 📊 Datto RMM Component Category Matrix

| Operation | Applications | Monitors | Scripts |
|-----------|-------------|----------|---------|
| `Get-WmiObject Win32_Product` | ❌ NEVER | ❌ NEVER | ❌ NEVER |
| `Get-CimInstance Win32_Product` | ✅ OK | ❌ Too slow | ✅ OK |
| `Start-Process -Wait` | ✅ OK | ❌ Too slow | ✅ OK |
| Registry detection | ✅ PREFERRED | ✅ REQUIRED | ✅ PREFERRED |
| Network operations | ✅ OK | ⚠️ Cached only | ✅ OK |
| Shared functions | ✅ Full library | ⚠️ Minimal only | ✅ Full library |
| Timeout requirements | Up to 30 min | <3 seconds | Flexible |

### 🎯 Component-Specific Exit Codes

#### Applications Components
- **0**: Success (installation/deployment completed)
- **3010**: Success with reboot required
- **1641**: Success with reboot initiated
- Other non-zero: Failed

#### Monitors Components
- **0**: OK/Green (system healthy)
- Any non-zero: Alert state (triggers RMM alert)

#### Scripts Components
- **0**: Success (all operations completed)
- **1**: Success with warnings
- **2**: Error (some operations failed)
- **10**: Permission error
- **11**: Timeout error

## 🚀 Example Usage

### Applications Component (Software Installation)
```powershell
# Datto RMM Applications Component
# Environment Variables: ScriptName="ScanSnapHome.ps1"
$LauncherURL = "https://raw.githubusercontent.com/aybouzaglou/Datto-RMM-Powershell-Scripts/main/launchers/LaunchInstaller.ps1"
$LauncherPath = "$env:TEMP\LaunchInstaller.ps1"
(New-Object System.Net.WebClient).DownloadFile($LauncherURL, $LauncherPath)
& $LauncherPath -ScriptName $env:ScriptName
exit $LASTEXITCODE
```

### Monitors Component (System Health)
```powershell
# Datto RMM Custom Monitor Component
# Environment Variables: ScriptName="DiskSpaceMonitor.ps1", WarningThreshold=15, CriticalThreshold=5
$LauncherURL = "https://raw.githubusercontent.com/aybouzaglou/Datto-RMM-Powershell-Scripts/main/launchers/LaunchMonitor.ps1"
$LauncherPath = "$env:TEMP\LaunchMonitor.ps1"
(New-Object System.Net.WebClient).DownloadFile($LauncherURL, $LauncherPath)
& $LauncherPath -ScriptName $env:ScriptName
exit $LASTEXITCODE
```

### Scripts Component (General Automation)
```powershell
# Datto RMM Scripts Component
# Environment Variables: ScriptName="FocusedDebloat.ps1", customwhitelist="App1,App2"
$LauncherURL = "https://raw.githubusercontent.com/aybouzaglou/Datto-RMM-Powershell-Scripts/main/launchers/LaunchScripts.ps1"
$LauncherPath = "$env:TEMP\LaunchScripts.ps1"
(New-Object System.Net.WebClient).DownloadFile($LauncherURL, $LauncherPath)
& $LauncherPath -ScriptName $env:ScriptName
exit $LASTEXITCODE
```

## 🤝 Contributing

### GitHub Function Library Architecture
1. **Add new functions** to appropriate modules in `shared-functions/`
2. **Create new scripts** in correct component category directories
3. **Use shared functions** for consistent behavior and error handling
4. **Test with launchers** to ensure proper integration
5. **Update documentation** for new functions or scripts

### Traditional Script Development
1. Follow the appropriate script type guide
2. Test thoroughly in non-production environments
3. Use standardized exit codes and event logging
4. Include proper error handling and timeouts
5. Document any special requirements or dependencies

## 📞 Support

### GitHub Function Library Architecture
- **[Deployment Guide](docs/Deployment-Guide.md)** - 15-minute setup walkthrough
- **[Function Reference](docs/Function-Reference.md)** - Complete function documentation
- **[Component Categories](docs/Datto-RMM-Component-Categories.md)** - Category selection guide
- **[GitHub Function Library Guide](docs/GitHub-Function-Library-Guide.md)** - Architecture overview

### Traditional Script Development
- **[Quick Reference](Quick-Reference.md)** - Decision matrix and immediate guidance
- **[Installation Scripts Guide](Installation-Scripts-Guide.md)** - Software deployment
- **[Monitor Scripts Guide](Monitor-Scripts-Guide.md)** - Performance-critical monitoring
- **[Removal/Modification Scripts Guide](Removal-Modification-Scripts-Guide.md)** - Safe removal practices

## 📄 License

This project is provided as-is for educational and operational use with Datto RMM systems.

---

**🚀 Ready to get started?**
- **New to the repository?** Start with the [Deployment Guide](docs/Deployment-Guide.md) for the GitHub architecture
- **Existing user?** Check the [Component Categories Guide](docs/Datto-RMM-Component-Categories.md) for the new structure
- **Traditional approach?** Use the [Quick Reference](Quick-Reference.md) for immediate guidance
