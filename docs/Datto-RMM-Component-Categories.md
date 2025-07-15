# Datto RMM Component Categories

## Overview

Datto RMM organizes automation into three distinct component categories, each with specific characteristics, execution patterns, and use cases. This repository structure aligns with these official Datto RMM categories.

## Component Categories

### 🔧 **Applications**
**Purpose**: Software deployment, installation, configuration, and management

**Characteristics**:
- **Execution**: On-demand or scheduled
- **Timeout**: Up to 30 minutes (configurable)
- **Category Changeable**: Yes (can convert to Scripts category)
- **Focus**: Software lifecycle management

**Exit Codes**:
- `0`: Success (operation completed successfully)
- `3010`: Success with reboot required
- `1641`: Success with reboot initiated
- Other non-zero: Failed

**Use Cases**:
- Software installation and updates
- Application configuration
- License management
- Software deployment automation

**Repository Location**: `components/Applications/`

**Launcher**: `launchers/LaunchInstaller.ps1` (optimized for Applications)

**Example Scripts**:
- `ScanSnapHome.ps1` - ScanSnap Home installation/update
- Software installers with prerequisites
- Application configuration scripts

---

### 📊 **Monitors**
**Purpose**: System health monitoring with continuous/recurring execution

**Characteristics**:
- **Execution**: Continuous/recurring (automatic scheduling)
- **Timeout**: <3 seconds (critical requirement)
- **Category Changeable**: No (cannot convert to Applications/Scripts)
- **Content Editable**: Yes (can edit script content, just stays a Monitor)
- **Focus**: Real-time system health assessment

**Exit Codes**:
- `0`: OK/Green (system healthy)
- Any non-zero: Alert state (triggers RMM alert)

**Special Requirements**:
- Must use `<-Start Result->` and `<-End Result->` markers
- Must complete execution in under 3 seconds
- Designed for frequent execution (every few minutes)
- Component category cannot be changed after creation (but content can be edited)

**Production-Grade Architecture** (Based on Datto's Official Patterns):
- **Diagnostic-First Design**: Use `<-Start Diagnostic->` and `<-End Diagnostic->` markers
- **Single Output Stream**: Use Write-Host exclusively (never mix with Write-Output)
- **Centralized Alert Functions**: Prevent orphaned diagnostics with consistent alert patterns
- **Multi-Layer Validation**: OS requirements → Service dependencies → Main function
- **Defensive File Operations**: Clean up previous runs, preserve debug files when needed
- **Graceful Degradation**: Continue primary function even if non-critical parts fail

**Use Cases**:
- Disk space monitoring
- Service status checks
- Performance threshold monitoring
- Security compliance checks
- Resource utilization monitoring

**Repository Location**: `components/Monitors/`

**Launcher**: `launchers/LaunchMonitor.ps1` (optimized for speed)

**Example Scripts**:
- `DiskSpaceMonitor.ps1` - Disk space threshold monitoring
- Service availability monitors
- Performance metric collectors

---

### 📝 **Scripts**
**Purpose**: General automation, maintenance, and utility operations

**Characteristics**:
- **Execution**: On-demand or scheduled
- **Timeout**: Flexible (configurable based on needs)
- **Category Changeable**: Yes (can convert to Applications category)
- **Focus**: General automation and maintenance tasks

**Exit Codes**:
- `0`: Success (all operations completed)
- `1`: Success with warnings
- `2`: Error (some operations failed)
- `10`: Permission error
- `11`: Timeout error

**Use Cases**:
- System maintenance and cleanup
- Bulk operations and automation
- Troubleshooting and diagnostics
- Custom business logic
- Multi-step workflows

**Repository Location**: `components/Scripts/`

**Launcher**: `launchers/LaunchScripts.ps1` (optimized for general automation)

**Example Scripts**:
- `FocusedDebloat.ps1` - Windows bloatware removal
- System cleanup and optimization
- Bulk configuration changes
- Diagnostic and reporting scripts

## Category Selection Guidelines

### Choose **Applications** when:
- Installing, updating, or configuring software
- Managing application lifecycles
- Deploying software packages
- Handling software dependencies

### Choose **Monitors** when:
- Checking system health continuously
- Monitoring thresholds and alerting
- Collecting real-time metrics
- Performing quick status checks
- Need immediate alert notifications

### Choose **Scripts** when:
- Performing maintenance tasks
- Running general automation
- Executing multi-step workflows
- Handling complex business logic
- Need flexible execution timing

## Architecture Integration

### Launcher Mapping
```
Applications → LaunchInstaller.ps1
Monitors     → LaunchMonitor.ps1
Scripts      → LaunchScripts.ps1
Universal    → UniversalLauncher.ps1 (works with all categories)
```

### Environment Variables
All launchers accept:
- `ScriptName`: Name of the script file to execute
- `ScriptType`: Component category ("Applications", "Monitors", "Scripts")

### Shared Function Library
All categories benefit from the shared function library:
- **Applications**: Extended logging, software detection, installation helpers
- **Monitors**: Minimal overhead functions, result formatting
- **Scripts**: Full function suite for complex operations

## Migration Considerations

### From Traditional Categories
If migrating from generic categories:
- "Installation scripts" → **Applications**
- "Monitor scripts" → **Monitors**
- "Maintenance scripts" → **Scripts**
- "Utility scripts" → **Scripts**

### Category Changes
- **Applications** ↔ **Scripts**: Can convert between these categories as needed
- **Monitors**: Category cannot be changed (locked as Monitor forever)
  - ❌ Cannot convert Monitor → Applications
  - ❌ Cannot convert Monitor → Scripts
  - ✅ Can edit Monitor content (script, variables, settings)
- Consider the 3-second timeout requirement when creating Monitors

### Best Practices
1. **Start with the right category** - Monitor category cannot be changed later (but content can be edited)
2. **Consider execution frequency** - Monitors run continuously/frequently
3. **Plan for timeout requirements** - Monitors must complete in <3 seconds
4. **Use appropriate launchers** - Each category has optimized launchers
5. **Leverage shared functions** - Consistent behavior across categories
6. **Monitor category decision is permanent** - Choose carefully as you cannot convert to Applications/Scripts later

## Component Creation Examples

### Applications Component
```
Component Name: Install ScanSnap Home
Component Type: Applications
Script Content: [LaunchInstaller.ps1 with ScriptName="ScanSnapHome.ps1"]
Environment Variables: ScriptName, any installer-specific settings
```

### Monitors Component
```
Component Name: Disk Space Monitor
Component Type: Monitors (Custom Monitor)
Script Content: [LaunchMonitor.ps1 with ScriptName="DiskSpaceMonitor.ps1"]
Environment Variables: ScriptName, WarningThreshold, CriticalThreshold
```

### Scripts Component
```
Component Name: System Debloat
Component Type: Scripts
Script Content: [LaunchScripts.ps1 with ScriptName="FocusedDebloat.ps1"]
Environment Variables: ScriptName, customwhitelist, skip flags
```

## Important Clarification: "Immutable" Monitors

### What "Immutable" Means for Monitors
- ❌ **Cannot change category**: Monitor components cannot be converted to Applications or Scripts
- ✅ **Can edit content**: You can freely edit the script content, environment variables, settings, etc.
- ✅ **Can update code**: Script logic, parameters, and functionality can be modified
- ✅ **Can change behavior**: The monitoring logic itself can be completely rewritten

### What You CAN Do with Monitor Components
- Edit the PowerShell script content
- Modify environment variables and thresholds
- Update monitoring logic and criteria
- Change alert conditions and messages
- Modify the `<-Start Result->` and `<-End Result->` content
- Update documentation and descriptions

### What You CANNOT Do with Monitor Components
- Convert to Applications component type
- Convert to Scripts component type
- Change the fundamental execution pattern (it will always run as a monitor)
- Exceed the 3-second timeout requirement

### Practical Impact
The "immutable" nature only affects **component type conversion**, not **component editing**. You have full flexibility to modify Monitor components as long as they remain Monitors and meet the <3-second execution requirement.

This categorization ensures optimal performance, appropriate execution patterns, and proper integration with Datto RMM's component management system.
