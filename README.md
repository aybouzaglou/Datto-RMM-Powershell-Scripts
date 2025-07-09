# Datto RMM PowerShell Scripts

A comprehensive collection of PowerShell scripts designed for Datto RMM (Remote Monitoring and Management) with specialized guidance for different script types and use cases.

## 🚀 Quick Start

This repository contains both **ready-to-use scripts** and **comprehensive guides** for creating your own Datto RMM PowerShell scripts. Each script type has specific requirements and performance considerations.

### Choose Your Guide

| Script Type | Purpose | Performance | Guide |
|-------------|---------|-------------|-------|
| 📦 **Installation** | Software deployment, system configuration | Up to 30 minutes | [Installation Scripts Guide](Installation-Scripts-Guide.md) |
| 🔍 **Monitor** | System health checks, service monitoring | < 3 seconds | [Monitor Scripts Guide](Monitor-Scripts-Guide.md) |
| 🗑️ **Removal/Modification** | Software removal, system cleanup | Balanced with timeouts | [Removal/Modification Scripts Guide](Removal-Modification-Scripts-Guide.md) |

📋 **[Quick Reference](Quick-Reference.md)** - Decision matrix and overview of all script types

## 📁 Repository Contents

### Ready-to-Use Scripts

- **[DattoRMM-FocusedDebloat-Launcher.ps1](DattoRMM-FocusedDebloat-Launcher.ps1)** - Launcher for focused system debloating
- **[FocusedDebloat.ps1](FocusedDebloat.ps1)** - Main debloating script for system cleanup
- **[Scansnap.ps1](Scansnap.ps1)** - Scanner-related automation script

### Documentation & Guides

- **[Installation Scripts Guide](Installation-Scripts-Guide.md)** - Complete guide for software deployment scripts
- **[Monitor Scripts Guide](Monitor-Scripts-Guide.md)** - Performance-critical monitoring script guidance
- **[Removal/Modification Scripts Guide](Removal-Modification-Scripts-Guide.md)** - Safe removal and modification practices
- **[Quick Reference](Quick-Reference.md)** - Decision matrix and quick navigation

## 🎯 Key Features

### Universal Requirements

- **LocalSystem Context**: All scripts run as NT AUTHORITY\SYSTEM
- **No GUI Elements**: Scripts run invisibly in system context
- **Standardized Exit Codes**: Consistent error reporting across all scripts
- **Event Logging**: Built-in Windows Event Log integration
- **Security**: TLS 1.2 enforcement and signature verification

### Performance Optimization

- **Monitor Scripts**: Optimized for < 3-second execution
- **Registry-First Detection**: Fast software detection methods
- **Timeout Protection**: Prevents hanging processes
- **Resource Efficiency**: Minimal system impact

## 🛠️ Getting Started

1. **Identify your script type** using the table above
2. **Read the appropriate guide** for detailed requirements and templates
3. **Use the provided templates** as starting points for your scripts
4. **Test thoroughly** in non-production environments
5. **Deploy** through Datto RMM with confidence

## 📖 Documentation Structure

```text
├── README.md                              # This file - main entry point
├── Quick-Reference.md                     # Decision matrix and overview
├── Installation-Scripts-Guide.md         # Software deployment guide
├── Monitor-Scripts-Guide.md              # System monitoring guide
├── Removal-Modification-Scripts-Guide.md # Software removal guide
├── DattoRMM-FocusedDebloat-Launcher.ps1 # Example launcher script
├── FocusedDebloat.ps1                    # Example debloat script
└── Scansnap.ps1                          # Example utility script
```

## 🔧 Common Operations

### Quick Decision Matrix

| Operation | Monitor Scripts | Installation Scripts | Removal Scripts |
|-----------|----------------|---------------------|-----------------|
| `Get-WmiObject Win32_Product` | ❌ NEVER | ❌ NEVER | ❌ NEVER |
| `Get-CimInstance Win32_Product` | ⚠️ With timeout | ✅ OK | ✅ OK |
| `Start-Process -Wait` (known) | ❌ Too slow | ✅ OK | ✅ OK |
| Registry detection | ✅ PREFERRED | ✅ Good | ✅ Good |
| Network operations | ⚠️ Add timeout | ✅ OK | ✅ OK |

### Standard Exit Codes

- **0**: Success
- **1**: Success with warnings
- **2**: Partial success
- **10**: Permission error
- **11**: Timeout error
- **12**: Configuration error
- **30**: Monitor critical
- **31**: Monitor warning

## 🤝 Contributing

1. Follow the appropriate script type guide
2. Test thoroughly in non-production environments
3. Use standardized exit codes and event logging
4. Include proper error handling and timeouts
5. Document any special requirements or dependencies

## 📞 Support

- Review the [Quick Reference](Quick-Reference.md) for immediate guidance
- Check the specific guide for your script type
- Ensure you're following universal requirements
- Test with appropriate timeouts and error handling

## 📄 License

This project is provided as-is for educational and operational use with Datto RMM systems.

---

**⚡ Ready to get started?** Choose your script type from the table above and dive into the appropriate guide!
