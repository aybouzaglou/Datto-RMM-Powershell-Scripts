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

### **🚀 Launchers = Auto-Updating Deployment (Applications & Scripts Only)**

**Philosophy**: Launchers provide zero-maintenance auto-updating for non-critical components.

**✅ Use Launchers For:**
- **Applications** - Software deployment scripts (can tolerate network dependencies)
- **Scripts** - General automation scripts (flexibility over performance)

**❌ Never Use Launchers For:**
- **Monitors** - Performance-critical, must be self-contained

**Why This Distinction:**
- **Applications/Scripts**: Run occasionally, can handle network delays, benefit from auto-updates
- **Monitors**: Run every 1-2 minutes, need sub-3-second execution, require 100% reliability

### **📊 Monitors = Direct Deployment Only**

**Philosophy**: Monitors must be 100% self-contained for maximum performance and reliability.

**✅ Monitor Requirements:**
- **Self-contained** - All functions embedded directly in script
- **No external dependencies** - No network calls, no shared function imports
- **Sub-3-second execution** - Performance is critical
- **100% reliability** - Must work in all network conditions

**✅ Monitor Development Pattern:**
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
2. **Use launcher**: `launchers/UniversalLauncher.ps1`
3. **Reference shared functions**: Can use via launcher mechanism
4. **Test with launcher**: Ensure auto-update functionality works
5. **Deploy with launcher**: Use launcher in Datto RMM component

## 🚨 **Critical Rules for LLM Assistants**

### **❌ Never Suggest:**
- Importing shared functions into monitors
- Using launchers for monitors
- Creating runtime dependencies for monitors
- API-based deployment (manual deployment only)

### **✅ Always Recommend:**
- Copy/paste functions from shared-functions/ into scripts
- Direct deployment for monitors
- Launcher-based deployment for Applications/Scripts
- Self-contained monitor scripts with embedded functions

### **🎯 Decision Matrix:**
| Component Type | Deployment Method | Dependencies | Performance Requirement |
|----------------|------------------|--------------|------------------------|
| **Monitor** | Direct (copy script) | None (self-contained) | <3 seconds |
| **Application** | Launcher-based | Can use shared functions | <30 minutes |
| **Script** | Launcher-based | Can use shared functions | Flexible |

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
