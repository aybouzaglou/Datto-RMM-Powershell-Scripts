# 🚀 Datto RMM PowerShell Scripts - Enterprise-Grade Automation Platform

> **LLM-Optimized Repository**: This README serves as a comprehensive launch pad for AI assistants and developers working with Datto RMM PowerShell automation.

A production-ready collection of PowerShell scripts and reference patterns designed for **Datto RMM (Remote Monitoring and Management)** featuring:
- **🎯 Performance-optimized hybrid deployment** (98.2% faster monitors)
- **🏗️ Enterprise-grade GitHub-based launcher architecture**
- **📚 Reference function library** (copy/paste patterns, not dependencies)
- **🔄 Automated validation pipeline** with GitHub Actions
- **📚 Comprehensive documentation and templates**
- **🧪 Performance testing and benchmarking suite**

## 🎯 Performance Revolution: 98.2% Faster Monitors

### **Hybrid Deployment Architecture**
- **📊 Monitors**: **Direct deployment** for maximum performance (sub-200ms execution)
- **🔧 Applications & Scripts**: **Launcher-based** for flexibility and auto-updates
- **🧪 Validated**: Enterprise-grade GitHub Actions validation pipeline
- **📈 Benchmarked**: Comprehensive performance testing suite included

### **Performance Metrics** (Validated)
| Deployment Type | Execution Time | Performance Grade | Use Case |
|----------------|----------------|-------------------|----------|
| **Direct Monitors** | 25-50ms | Excellent (98% faster) | High-frequency monitoring |
| **Launcher-based** | 200-500ms | Good (flexible) | Applications & Scripts |

## 🚀 Quick Start Guide

### **For LLM Assistants & Developers**
This repository is structured for easy navigation and understanding:

| **Task** | **Primary Location** | **Documentation** |
|----------|---------------------|-------------------|
| 🔍 **Find existing scripts** | `components/` | [Component Categories](docs/Datto-RMM-Component-Categories.md) |
| 🛠️ **Create new scripts** | `templates/` | [Templates & Examples](#-templates--examples) |
| 📚 **Copy function patterns** | `shared-functions/` | [Function Reference](docs/Function-Reference.md) |
| 🚀 **Deploy scripts** | `launchers/` | [Deployment Guide](docs/Deployment-Guide.md) |
| 🧪 **Test & validate** | `tests/` + GitHub Actions | [Testing & Validation](#-testing--validation) |
| 📖 **Learn architecture** | `docs/` | [Architecture Overview](#-architecture-overview) |

### **GitHub Launcher Architecture**

**Zero-maintenance script updates** - Applications/Scripts automatically download latest versions from GitHub:

```powershell
# Universal launcher for any Datto RMM component category
$LauncherURL = "https://raw.githubusercontent.com/aybouzaglou/Datto-RMM-Powershell-Scripts/main/launchers/UniversalLauncher.ps1"
$LauncherPath = "$env:TEMP\UniversalLauncher.ps1"
[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
(New-Object System.Net.WebClient).DownloadFile($LauncherURL, $LauncherPath)
& $LauncherPath -ScriptName $env:ScriptName -ScriptType $env:ScriptType
exit $LASTEXITCODE
```

**Enterprise Benefits:**
- ✅ **Auto-updating scripts** - Zero maintenance, Applications/Scripts update automatically
- ✅ **Reference function patterns** - 50+ proven code patterns for copy/paste development
- ✅ **Version control** - Full Git history, rollback capabilities, branch support
- ✅ **GitHub Actions validation** - Enterprise-grade automated testing pipeline
- ✅ **Performance benchmarking** - Automated performance testing and reporting
- ✅ **Comprehensive logging** - Detailed execution logs and error handling

## 🏗️ Architecture Overview

### **Core Components**
| Component | Purpose | Location | Key Files | Documentation |
|-----------|---------|----------|-----------|---------------|
| 📚 **Reference Functions** | 50+ copy/paste patterns | `shared-functions/` | `EmbeddedMonitorFunctions.ps1` | [Function Reference](docs/Function-Reference.md) |
| 🚀 **Launchers** | Auto-updating deployment | `launchers/` | `UniversalLauncher.ps1` | [Deployment Guide](docs/Deployment-Guide.md) |
| 📦 **Components** | Production scripts | `components/` | Category-organized scripts | [Component Categories](docs/Datto-RMM-Component-Categories.md) |
| 📋 **Templates** | Script templates | `templates/` | Ready-to-use templates | [Templates Section](#-templates--examples) |
| 🧪 **Tests** | Validation & benchmarks | `tests/` | Performance testing suite | [Testing Section](#-testing--validation) |
| 📚 **Documentation** | Comprehensive guides | `docs/` | 15+ detailed guides | [Documentation Index](#-documentation-index) |

### **Datto RMM Component Categories & Deployment Strategy**
| Category | Purpose | Timeout | Changeable | Deployment Strategy | Function Patterns | Location |
|----------|---------|---------|------------|-------------------|-------------------|----------|
| 🔧 **Applications** | Software deployment | Up to 30 min | Yes ↔ Scripts | **Launcher-based** | Copy/paste from shared-functions | `components/Applications/` |
| 📊 **Monitors** | System health checks | <3 seconds | **No** (immutable) | **Direct deployment ONLY** | **Embedded only** (copy/paste) | `components/monitors/` |
| 📝 **Scripts** | General automation | Flexible | Yes ↔ Applications | **Launcher-based** | Copy/paste from shared-functions | `components/Scripts/` |

**🎯 Critical Architecture Rules:**
- **Monitors**: Always self-contained, embed functions directly, no external dependencies
- **Applications/Scripts**: Can use launchers and reference shared functions for auto-updates
- **Shared Functions**: Reference library only - copy/paste patterns, not runtime dependencies

### **Deployment Strategy Decision Matrix**
| Use Case | Recommended Approach | Performance | Maintenance | Best For |
|----------|---------------------|-------------|-------------|----------|
| 🆕 **New Deployments** | GitHub Architecture | Excellent | Zero | Enterprise environments |
| 📊 **High-frequency Monitors** | Direct Deployment | 98% faster | Manual | Critical monitoring |
| 🔧 **Complex Applications** | Launcher-based | Good | Auto-updating | Software deployment |
| 📚 **Learning/Custom** | Traditional Guides | Variable | Manual | Development & learning |

**🎯 Quick Navigation:**
- **📋 [Tech Quick Reference](docs/Tech-Quick-Reference-Card.md)** - Technician deployment guide
- **🚀 [Deployment Guide](docs/Deployment-Guide.md)** - 15-minute setup walkthrough
- **📊 [Component Categories](docs/Datto-RMM-Component-Categories.md)** - Detailed category guide

## 📁 Complete Repository Structure

### 📚 **Shared Function Library** (`shared-functions/`) - **REFERENCE ONLY**
> **⚠️ IMPORTANT**: These are **reference functions and code patterns**, NOT runtime dependencies. Copy/paste into your scripts - do NOT import or dot-source these functions.

```
shared-functions/
├── Core/                       # Core RMM function patterns
│   ├── RMMLogging.ps1         # Logging, transcripts, event log patterns
│   ├── RMMValidation.ps1      # Input validation, system check patterns
│   └── RMMSoftwareDetection.ps1 # Fast software detection patterns (registry-based)
├── Utilities/                  # Utility function patterns
│   ├── NetworkUtils.ps1       # Network operations, download patterns
│   ├── FileOperations.ps1     # File/directory operation patterns
│   └── RegistryHelpers.ps1    # Registry operation patterns
├── EmbeddedMonitorFunctions.ps1 # **COPY THESE** into monitor scripts for direct deployment
├── PerformanceMonitorFunctions.ps1 # Performance monitoring patterns
├── SecurityMonitorFunctions.ps1    # Security monitoring patterns
└── SystemMonitorFunctions.ps1      # System health monitoring patterns
```

**🎯 Usage Philosophy:**
- **For Monitors**: Copy functions from `EmbeddedMonitorFunctions.ps1` directly into your script
- **For Applications/Scripts**: Copy needed function patterns directly into your scripts
- **For Development**: Use as reference patterns and proven code examples

### 🚀 **Universal Launchers** (`launchers/`) - **APPLICATIONS & SCRIPTS ONLY**
> **⚠️ IMPORTANT**: Launchers are ONLY for Applications and Scripts components. Monitors use direct deployment for maximum performance.

```
launchers/
├── UniversalLauncher.ps1      # For Applications & Scripts (NOT Monitors)
├── LaunchInstaller.ps1        # Optimized for Applications (30min timeout)

└── LaunchScripts.ps1          # Optimized for Scripts (flexible timeout)
```

**🎯 Launcher Usage:**
- **✅ Applications**: Use launchers for auto-updating software deployment
- **✅ Scripts**: Use launchers for auto-updating automation scripts
- **❌ Monitors**: NEVER use launchers - direct deployment only for performance

### 📦 **Production Components** (`components/`)
```
components/
├── Applications/              # Software deployment (changeable category)
│   └── ScanSnapHome.ps1      # ScanSnap Home installation with detection
├── monitors/                  # System health monitoring (immutable category)
│   ├── BluescreenMonitor-Direct.ps1    # Direct deployment (sub-50ms)
│   ├── BluescreenMonitor.ps1           # Launcher-based version
│   ├── DiskSpaceMonitor-Direct.ps1     # Direct deployment (sub-10ms)
│   └── DiskSpaceMonitor.ps1            # Launcher-based version
└── Scripts/                   # General automation (changeable category)
    ├── FocusedDebloat.ps1    # Windows bloatware removal
    ├── Setup-TestDevice.ps1  # Test device configuration
    ├── Test-Workflow.ps1     # Workflow testing script
    └── Validate-TestEnvironment.ps1 # Environment validation
```

### 📋 **Templates & Examples** (`templates/`)
```
templates/
├── DirectDeploymentMonitor-Template.ps1    # High-performance monitor template
└── SoftwareMonitor-DattoExpert-Template.ps1 # Expert software detection pattern
```

### 🧪 **Testing & Validation** (`tests/`)
```
tests/
├── Performance-Benchmark.ps1             # Performance benchmarking suite
├── Performance-Testing-Suite.ps1         # Comprehensive performance testing
└── Performance-Report-20250715-163523.json # Latest performance results
```

### 📚 **Comprehensive Documentation** (`docs/`)
```
docs/
├── BluescreenMonitor-Guide.md            # Bluescreen monitoring guide
├── BluescreenMonitor-QuickRef.md         # Quick reference for bluescreen monitoring
├── Datto-RMM-Component-Categories.md     # Complete component category guide
├── Deployment-Guide.md                   # 15-minute deployment walkthrough
├── Direct-Deployment-Guide.md            # Direct deployment strategy guide
├── Function-Reference.md                 # Complete function documentation
├── GitHub-Function-Library-Guide.md     # Architecture overview
├── Monitor-Performance-Optimization-Guide.md # Monitor optimization guide
├── Production-Deployment-Checklist.md   # Production deployment checklist
├── Tech-Quick-Reference-Card.md          # Technician quick reference
└── Technician-Deployment-Guide.md       # Technician deployment guide
```

### 🔄 **Legacy & Traditional**
```
legacy/                        # Legacy scripts (superseded by new architecture)
├── DattoRMM-FocusedDebloat-Launcher.ps1  # Original launcher
├── FocusedDebloat.ps1                    # Original debloat script
└── Scansnap.ps1                          # Original scanner script

traditional-guides/            # Traditional development guides
├── Quick-Reference.md                     # Decision matrix and navigation
├── Installation-Scripts-Guide.md         # Software deployment guide
├── Monitor-Scripts-Guide.md              # Performance-critical monitoring
└── Removal-Modification-Scripts-Guide.md # Safe removal practices
```

### 🔧 **Development Tools** (`scripts/`)
```
scripts/
├── install-git-hooks.ps1     # Git hooks installation
├── mac-dev-helper.sh         # macOS development helper
├── new-script-workflow.ps1   # New script creation workflow
└── validate-before-push.ps1  # Pre-push validation
```

### 🏗️ **GitHub Actions & CI/CD** (`.github/workflows/`)
```
.github/workflows/
└── validate-scripts.yml      # Enterprise-grade validation pipeline
                              # - PowerShell syntax validation
                              # - PSScriptAnalyzer analysis
                              # - Datto RMM compatibility checks
                              # - Performance validation
                              # - Automated artifact creation
```

## 🎯 Key Features & Capabilities

### �️ **Enterprise Architecture**
- **🔄 Auto-updating scripts** - Zero maintenance, Applications/Scripts update automatically from GitHub
- **📚 50+ reference patterns** - Comprehensive copy/paste function patterns for development
- **🏷️ Version control** - Full Git history, rollback capabilities, branch/tag support
- **🧪 GitHub Actions validation** - Enterprise-grade automated testing pipeline
- **� Performance benchmarking** - Automated performance testing and reporting
- **🔧 Modular design** - Self-contained components, easy customization and extension

### 📊 **Datto RMM Integration**
- **🎯 Component categories** - Perfectly aligned with Applications, Monitors, Scripts
- **⏱️ Timeout optimization** - Category-specific execution patterns and limits
- **🔒 Immutable Monitors** - Proper handling of Monitor category restrictions
- **📈 Exit code standards** - Category-appropriate success/failure codes
- **🔄 Launcher system** - Universal and specialized launchers for each category
- **🎛️ Environment variables** - Standardized parameter passing through RMM

### 🛡️ **Production Requirements**
- **🔐 LocalSystem Context** - All scripts run as NT AUTHORITY\SYSTEM
- **👻 No GUI Elements** - Scripts run invisibly in system context
- **📊 Standardized Exit Codes** - Consistent error reporting across all scripts
- **📝 Event Logging** - Built-in Windows Event Log integration
- **🔒 Security** - TLS 1.2 enforcement and secure downloads
- **🛡️ Error Handling** - Comprehensive try/catch blocks and graceful degradation

### ⚡ **Performance Optimization**
- **📊 Direct Deployment Monitors** - Sub-200ms execution (98.2% faster than launcher-based)
- **🔍 Registry-First Detection** - Fast software detection (avoids slow Win32_Product WMI)
- **⏰ Timeout Protection** - Prevents hanging processes with configurable timeouts
- **💾 Resource Efficiency** - Minimal system impact with intelligent caching
- **🚀 Function Caching** - Local caching reduces download overhead
- **🎯 Hybrid Strategy** - Optimized deployment method for each component type
- **📈 Benchmarked Performance** - Validated execution times with performance grades

## 🛠️ Getting Started

### 🚀 **Quick Start (GitHub Architecture - Recommended)**

1. **Choose your Datto RMM component category**:
   - 🔧 **Applications**: Software deployment/installation (up to 30min timeout)
   - 📊 **Monitors**: System health monitoring (<3 seconds, immutable category)
   - 📝 **Scripts**: General automation/maintenance (flexible timeout)

2. **Create a Datto RMM component** with this universal launcher:
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

4. **Deploy and enjoy** - Scripts auto-update from GitHub with zero maintenance!

### 📊 **Available Production Scripts**

#### **Applications** (`components/Applications/`)
- **`ScanSnapHome.ps1`** - ScanSnap Home installation with automatic detection

#### **Monitors** (`components/monitors/`)
- **`BluescreenMonitor-Direct.ps1`** - Direct deployment bluescreen detection (sub-50ms)
- **`DiskSpaceMonitor-Direct.ps1`** - Direct deployment disk space monitoring (sub-10ms)
- **`BluescreenMonitor.ps1`** - Launcher-based bluescreen detection
- **`DiskSpaceMonitor.ps1`** - Launcher-based disk space monitoring

#### **Scripts** (`components/Scripts/`)
- **`FocusedDebloat.ps1`** - Windows bloatware removal with manufacturer detection
- **`Setup-TestDevice.ps1`** - Test device configuration and validation
- **`Validate-TestEnvironment.ps1`** - Environment validation and testing

### 📋 **Templates & Examples**

#### **Monitor Templates** (`templates/`)
- **`DirectDeploymentMonitor-Template.ps1`** - High-performance monitor template
- **`SoftwareMonitor-DattoExpert-Template.ps1`** - Expert software detection pattern

#### **Usage Examples**
```powershell
# Example: Deploy FocusedDebloat script
# Environment Variables: ScriptName="FocusedDebloat.ps1", ScriptType="Scripts"

# Example: Deploy disk space monitor (direct deployment recommended)
# Copy content of DiskSpaceMonitor-Direct.ps1 directly into Datto RMM Monitor component

# Example: Deploy ScanSnap installer
# Environment Variables: ScriptName="ScanSnapHome.ps1", ScriptType="Applications"
```

## 🧪 Testing & Validation

### **GitHub Actions Pipeline** (Automated)
Every push triggers enterprise-grade validation:
- **✅ PowerShell Syntax Validation** - Ensures all scripts parse correctly
- **✅ PSScriptAnalyzer Analysis** - Advanced static analysis (VSCode-level quality)
- **✅ Datto RMM Compatibility** - Validates RMM-specific requirements
- **✅ Performance Analysis** - Ensures monitors meet <3 second requirement
- **✅ Architecture Validation** - Validates shared functions and component categories
- **✅ Deployment Artifacts** - Creates validated deployment packages

### **Performance Testing Suite** (`tests/`)
```powershell
# Run performance benchmarks
.\tests\Performance-Testing-Suite.ps1 -TestIterations 10 -GenerateReport

# Quick performance check
.\tests\Performance-Benchmark.ps1
```

**Latest Performance Results** (Validated):
- **Direct Deployment Monitors**: 25-50ms average (Excellent grade)
- **Launcher-based Scripts**: 200-500ms average (Good grade)
- **98.2% performance improvement** for direct deployment vs launcher-based

### **Manual Testing**
```powershell
# Test individual scripts locally
.\components\Scripts\FocusedDebloat.ps1 -WhatIf

# Validate function patterns (copy/paste approach)
# Functions are now embedded directly in scripts

# Test launchers
.\launchers\UniversalLauncher.ps1 -ScriptName "Test-Workflow.ps1" -ScriptType "Scripts"
```

## 📚 Documentation Index

### **🎯 For LLM Assistants & Developers**
| Task | Primary Documentation | Secondary Resources |
|------|----------------------|-------------------|
| **🏗️ Understanding Architecture** | **[Architecture Philosophy](docs/Architecture-Philosophy.md)** | [GitHub Launcher Guide](docs/GitHub-Function-Library-Guide.md) |
| **Creating New Scripts** | [Templates](#-templates--examples) | [Function Reference](docs/Function-Reference.md) |
| **Deployment Strategies** | [Deployment Guide](docs/Deployment-Guide.md) | [Component Categories](docs/Datto-RMM-Component-Categories.md) |
| **Performance Optimization** | [Monitor Performance Guide](docs/Monitor-Performance-Optimization-Guide.md) | [Direct Deployment Guide](docs/Direct-Deployment-Guide.md) |
| **Technician Support** | [Tech Quick Reference](docs/Tech-Quick-Reference-Card.md) | [Technician Deployment Guide](docs/Technician-Deployment-Guide.md) |

### **📋 Complete Documentation List**
- **[🏗️ Architecture Philosophy](docs/Architecture-Philosophy.md)** - **ESSENTIAL** - Core design principles and constraints
- **[GitHub Launcher Guide](docs/GitHub-Function-Library-Guide.md)** - Complete launcher architecture overview
- **[Function Reference](docs/Function-Reference.md)** - Detailed function patterns (50+ copy/paste examples)
- **[Deployment Guide](docs/Deployment-Guide.md)** - 15-minute setup walkthrough
- **[Component Categories](docs/Datto-RMM-Component-Categories.md)** - Detailed category guide
- **[Direct Deployment Guide](docs/Direct-Deployment-Guide.md)** - Direct deployment strategy
- **[Monitor Performance Guide](docs/Monitor-Performance-Optimization-Guide.md)** - Monitor optimization
- **[Tech Quick Reference](docs/Tech-Quick-Reference-Card.md)** - Technician quick reference
- **[Technician Deployment Guide](docs/Technician-Deployment-Guide.md)** - Technician deployment guide
- **[Production Deployment Checklist](docs/Production-Deployment-Checklist.md)** - Production checklist
- **[Bluescreen Monitor Guide](docs/BluescreenMonitor-Guide.md)** - Bluescreen monitoring guide
- **[Developer Workflow](docs/DEVELOPER-WORKFLOW.md)** - Development workflow guide

### **📚 Traditional Development Guides**
- **[Quick Reference](traditional-guides/Quick-Reference.md)** - Decision matrix and navigation
- **[Installation Scripts Guide](traditional-guides/Installation-Scripts-Guide.md)** - Software deployment
- **[Monitor Scripts Guide](traditional-guides/Monitor-Scripts-Guide.md)** - Performance-critical monitoring
- **[Removal/Modification Scripts Guide](traditional-guides/Removal-Modification-Scripts-Guide.md)** - Safe removal practices

## � Development & Contribution

### **For LLM Assistants**
When working with this repository:
1. **Always check `components/` first** for existing scripts before creating new ones
2. **Use `templates/` as starting points** for new script development
3. **Reference `shared-functions/`** for available reusable functions
4. **Follow component category guidelines** in [Component Categories](docs/Datto-RMM-Component-Categories.md)
5. **Test with GitHub Actions** before suggesting deployment

### **Development Workflow**
```powershell
# 1. Create new script from template
Copy-Item "templates/DirectDeploymentMonitor-Template.ps1" "components/monitors/NewMonitor.ps1"

# 2. Use shared functions
# Reference shared-functions/ for available functions

# 3. Test locally
.\tests\Performance-Testing-Suite.ps1

# 4. Validate with GitHub Actions
git push origin feature/new-monitor

# 5. Deploy manually (no API deployment)
# Copy validated scripts to Datto RMM console
```

### **Contribution Guidelines**
1. **Add new functions** to appropriate modules in `shared-functions/`
2. **Create new scripts** in correct component category directories
3. **Use shared functions** for consistent behavior and error handling
4. **Test with performance suite** to ensure compliance
5. **Update documentation** for new functions or scripts
6. **Follow naming conventions** and include proper headers

## 🔧 Common Operations

### 📊 Datto RMM Component Category Matrix

| Operation | Applications | Monitors | Scripts |
|-----------|-------------|----------|---------|
| `Get-WmiObject Win32_Product` | ❌ NEVER | ❌ NEVER | ❌ NEVER |
| `Get-CimInstance Win32_Product` | ✅ OK | ❌ Too slow | ✅ OK |
| `Start-Process -Wait` | ✅ OK | ❌ Too slow | ✅ OK |
| Registry detection | ✅ PREFERRED | ✅ REQUIRED | ✅ PREFERRED |
| Network operations | ✅ OK | ⚠️ Cached only | ✅ OK |
| Function patterns | ✅ Copy any patterns | ⚠️ Copy minimal only | ✅ Copy any patterns |
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

### Reference Pattern Development
1. **Add new patterns** to appropriate modules in `shared-functions/`
2. **Create new scripts** in correct component category directories
3. **Copy proven patterns** for consistent behavior and error handling
4. **Test with launchers** for Applications/Scripts (not Monitors)
5. **Update documentation** for new patterns or scripts

### Traditional Script Development
1. Follow the appropriate script type guide
2. Test thoroughly in non-production environments
3. Use standardized exit codes and event logging
4. Include proper error handling and timeouts
5. Document any special requirements or dependencies

## 📞 Support

### GitHub Launcher Architecture
- **[Deployment Guide](docs/Deployment-Guide.md)** - 15-minute setup walkthrough
- **[Function Reference](docs/Function-Reference.md)** - Complete pattern documentation
- **[Component Categories](docs/Datto-RMM-Component-Categories.md)** - Category selection guide
- **[GitHub Launcher Guide](docs/GitHub-Function-Library-Guide.md)** - Architecture overview

### Traditional Script Development
- **[Traditional Guides](traditional-guides/)** - Complete collection of development guides
- **[Quick Reference](traditional-guides/Quick-Reference.md)** - Decision matrix and immediate guidance
- **[Installation Scripts Guide](traditional-guides/Installation-Scripts-Guide.md)** - Software deployment
- **[Monitor Scripts Guide](traditional-guides/Monitor-Scripts-Guide.md)** - Performance-critical monitoring
- **[Removal/Modification Scripts Guide](traditional-guides/Removal-Modification-Scripts-Guide.md)** - Safe removal practices

## 📄 License

This project is provided as-is for educational and operational use with Datto RMM systems.

---

## 🤖 LLM Assistant Quick Reference

### **Common Tasks & Locations**
| **User Request** | **Primary Location** | **Key Files** | **Documentation** |
|------------------|---------------------|---------------|-------------------|
| "Create a monitor script" | `templates/` → `components/monitors/` | `DirectDeploymentMonitor-Template.ps1` | [Monitor Performance Guide](docs/Monitor-Performance-Optimization-Guide.md) |
| "Find software detection" | `shared-functions/Core/` | `RMMSoftwareDetection.ps1` | [Function Reference](docs/Function-Reference.md) |
| "Deploy a script" | `launchers/` | `UniversalLauncher.ps1` | [Deployment Guide](docs/Deployment-Guide.md) |
| "Check performance" | `tests/` | `Performance-Testing-Suite.ps1` | [Testing Section](#-testing--validation) |
| "Understand categories" | `docs/` | `Datto-RMM-Component-Categories.md` | [Component Categories](docs/Datto-RMM-Component-Categories.md) |
| "Find existing scripts" | `components/` | Category-organized scripts | [Available Scripts](#-available-production-scripts) |

### **Key Constraints for LLM Assistants**
- **❌ Never suggest API deployment** - This repo uses manual deployment only
- **❌ Never suggest shared function imports for monitors** - Monitors must be self-contained
- **❌ Never suggest launchers for monitors** - Direct deployment only for performance
- **✅ Always use direct deployment for monitors** - 98.2% performance improvement
- **✅ Copy patterns from shared-functions/ into scripts** - Reference library, not dependencies
- **✅ Use launchers only for Applications/Scripts** - Never for monitors
- **✅ Use templates as starting points** - Don't create scripts from scratch
- **✅ Follow component category rules** - Monitors are immutable, Applications/Scripts are changeable
- **✅ Include performance considerations** - Monitors must execute in <3 seconds

### **Repository Philosophy**
- **Performance-first** - Direct deployment for monitors, launcher-based for flexibility
- **Enterprise-grade** - GitHub Actions validation, comprehensive testing
- **Manual deployment** - Simple, reliable, controlled (no API complexity)
- **Shared functions as reference** - Copy/paste patterns, NOT runtime dependencies
- **Documentation-driven** - Comprehensive guides for every use case

**📖 [Complete Architecture Philosophy](docs/Architecture-Philosophy.md)** - Essential reading for understanding the design decisions

---

## 🚀 Quick Navigation

### **🎯 For New Users**
- **Start here**: [Deployment Guide](docs/Deployment-Guide.md) - 15-minute setup walkthrough
- **Understand categories**: [Component Categories](docs/Datto-RMM-Component-Categories.md) - Choose the right category
- **See examples**: [Available Scripts](#-available-production-scripts) - Production-ready scripts

### **🔧 For Developers**
- **Architecture overview**: [GitHub Launcher Guide](docs/GitHub-Function-Library-Guide.md)
- **Function patterns**: [Function Reference](docs/Function-Reference.md) - 50+ copy/paste patterns
- **Templates**: [Templates Section](#-templates--examples) - Starting points for new scripts

### **👨‍💻 For Technicians**
- **Quick reference**: [Tech Quick Reference](docs/Tech-Quick-Reference-Card.md) - Copy/paste deployment guide
- **Deployment guide**: [Technician Deployment Guide](docs/Technician-Deployment-Guide.md) - Step-by-step instructions

### **🧪 For Testing & Validation**
- **Performance testing**: [Testing Section](#-testing--validation) - Benchmark and validate scripts
- **GitHub Actions**: Automated validation pipeline runs on every push
- **Manual testing**: Local testing procedures and validation scripts

---

**📊 Repository Stats**: 50+ shared functions • 10+ production scripts • 15+ documentation guides • Enterprise-grade validation pipeline • 98.2% performance improvement for monitors
