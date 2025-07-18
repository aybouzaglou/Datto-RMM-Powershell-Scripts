# 🏗️ Architecture Philosophy - Datto RMM PowerShell Scripts

> **Critical Reference for LLM Assistants and Developers**

## 🎯 **Core Architecture Principles**

### **📚 Shared Functions = Reference Library (NOT Dependencies)**

**Philosophy**: Shared functions are **tried-and-true code patterns** for developers to copy/paste, NOT runtime dependencies.

**✅ Correct Usage:**
```powershell
# Copy function from shared-functions/EmbeddedMonitorFunctions.ps1
function Get-RMMVariable {
    param([string]$Name, [string]$Type = "String", $Default = $null)
    # ... function code copied directly into script
}

# Use in your monitor script
$alertThreshold = Get-RMMVariable -Name "AlertThreshold" -Type "Integer" -Default 80
```

**❌ Incorrect Usage:**
```powershell
# NEVER do this - creates dangerous dependencies
. .\shared-functions\EmbeddedMonitorFunctions.ps1
Import-Module .\shared-functions\Core\RMMLogging.ps1
```

**Why This Approach:**
- ✅ **Zero deployment complexity** - No "what if it can't download shared functions"
- ✅ **Maximum reliability** - Self-contained scripts always work
- ✅ **Performance optimized** - No function loading overhead
- ✅ **Proven patterns** - Use battle-tested code without dependencies

### **🚀 Direct Deployment = Traditional Script Approach (All Components)**

**Philosophy**: All components use direct deployment for maximum reliability and simplicity.

**✅ Direct Deployment Benefits:**
- **Simplicity** - No complex launcher architecture to maintain
- **Reliability** - No network dependencies during execution
- **Performance** - Optimal execution speed for all component types
- **Visibility** - All code visible in RMM component for troubleshooting
- **Consistency** - Same deployment method for all component types

**✅ All Components Use Direct Deployment:**
- **Applications** - Software deployment scripts with embedded functions
- **Scripts** - General automation scripts with embedded functions
- **Monitors** - Performance-critical monitoring with embedded functions

### **📊 Self-Contained Script Architecture**

**Philosophy**: All scripts must be completely self-contained for maximum performance and reliability.

**✅ Self-Contained Script Requirements:**
- **All functions embedded** - Copy needed functions directly into each script
- **No external dependencies** - No network calls, no shared function imports
- **Optimal performance** - No function loading overhead
- **100% reliability** - Must work in all network conditions

**✅ Self-Contained Development Pattern:**
```powershell
# Copy functions directly from EmbeddedMonitorFunctions.ps1
function Write-MonitorAlert {
    param([string]$Message)
    Write-Host '<-Start Result->'
    Write-Host "X=$Message"
    Write-Host '<-End Result->'
    exit 1
}

# Use embedded function
if ($diskUsage -gt $threshold) {
    Write-MonitorAlert "Disk usage is $diskUsage% (threshold: $threshold%)"
}
```

## 🎯 **Component Category Strategy**

### **🔧 Applications (Launcher-Based)**
- **Purpose**: Software deployment and installation
- **Deployment**: Launcher-based for auto-updates
- **Dependencies**: Can use shared functions via launcher
- **Timeout**: Up to 30 minutes
- **Network**: Can tolerate network dependencies

### **📝 Scripts (Launcher-Based)**
- **Purpose**: General automation and maintenance
- **Deployment**: Launcher-based for auto-updates
- **Dependencies**: Can use shared functions via launcher
- **Timeout**: Flexible
- **Network**: Can tolerate network dependencies

### **📊 Monitors (Direct Deployment)**
- **Purpose**: System health monitoring
- **Deployment**: Direct deployment ONLY
- **Dependencies**: NONE - 100% self-contained
- **Timeout**: <3 seconds maximum
- **Network**: NO network dependencies allowed

## 🛠️ **Development Workflow by Component Type**

### **📊 Monitor Development**
1. **Start with template**: `templates/DirectDeploymentMonitor-Template.ps1`
2. **Copy needed functions**: From `shared-functions/EmbeddedMonitorFunctions.ps1`
3. **Embed everything**: No external dependencies
4. **Test performance**: Must execute in <3 seconds
5. **Deploy directly**: Copy entire script to Datto RMM Monitor component

### **🔧 Application/Script Development**
1. **Start with template**: Create in appropriate `components/` directory
2. **Copy function patterns**: Copy needed functions from `shared-functions/` into your script
3. **Embed all functions**: Make script completely self-contained
4. **Test locally**: Ensure all functionality works without external dependencies
5. **Deploy directly**: Paste entire script content into Datto RMM component

## 🚨 **Critical Rules for LLM Assistants**

### **❌ Never Suggest:**
- Importing shared functions into any scripts
- Using launchers for any components
- Creating runtime dependencies for any scripts
- API-based deployment (manual deployment only)

### **✅ Always Recommend:**
- Copy/paste functions from shared-functions/ into scripts
- Direct deployment for all components
- Self-contained scripts with embedded functions
- Traditional script approach for maximum reliability

### **🎯 Decision Matrix:**
| Component Type | Deployment Method | Function Patterns | Performance Requirement |
|----------------|------------------|-------------------|------------------------|
| **Monitor** | Direct (copy script) | Copy/paste only (self-contained) | <3 seconds |
| **Application** | Launcher-based | Copy/paste from shared-functions | <30 minutes |
| **Script** | Launcher-based | Copy/paste from shared-functions | Flexible |

## 💡 **Why This Architecture Works**

### **🔒 Reliability First**
- Monitors never fail due to network issues
- Self-contained scripts always execute
- No complex dependency chains to break

### **⚡ Performance Optimized**
- Monitors execute in 25-50ms (98.2% faster than launcher-based)
- No function loading overhead
- No network delays for critical monitoring

### **🔄 Maintenance Balance**
- Applications/Scripts get auto-updates via launchers
- Monitors remain stable and reliable
- Shared functions provide proven patterns without dependencies

### **🎯 Simple Deployment**
- Manual deployment maintains control
- No API complexity or authentication issues
- Clear separation of concerns by component type

This architecture provides the perfect balance of **performance, reliability, and maintainability** for Datto RMM PowerShell automation.

## 📚 Related Documentation

### **Development Guides**
- **[Quick Reference & Decision Matrix](Quick-Reference-Decision-Matrix.md)** - Choose the right component type and approach
- **[Monitor Development Guide](Monitor-Performance-Optimization-Guide.md)** - Complete monitor development guide
- **[Script Development Guide](Script-Development-Guide.md)** - Applications and Scripts development patterns
- **[Universal Requirements Reference](Universal-Requirements-Reference.md)** - Requirements that apply to all scripts

### **Implementation Guides**
- **[GitHub Function Library Guide](GitHub-Function-Library-Guide.md)** - Launcher architecture details
- **[Function Reference](Function-Reference.md)** - Copy/paste function patterns
- **[Deployment Guide](Deployment-Guide.md)** - Setup and deployment walkthrough
