# 🔍 Bluescreen Monitor - Deployment Guide

## Overview

The **Bluescreen Monitor** is a Datto RMM Monitor component that checks for Windows blue screen (BSOD) events in the past 7 days. It provides early warning of system stability issues by monitoring Windows Event Logs for BSOD-related events.

## 🎯 Component Details

- **Component Type**: Monitor (Custom Monitor)
- **Category**: System Health Monitoring
- **Execution**: Continuous/recurring (automatic scheduling)
- **Timeout**: <3 seconds (optimized for monitor requirements)
- **Exit Codes**: 0 = No BSODs, Any non-zero = BSODs detected (triggers alert)

## 📊 What It Monitors

The script checks for these BSOD-related Event IDs:

| Event ID | Log | Source | Description |
|----------|-----|--------|-------------|
| 1001 | Application | Windows Error Reporting | BSOD Error Report |
| 6008 | System | EventLog | Unexpected Shutdown |
| 41 | System | Microsoft-Windows-Kernel-Power | System Reboot (Critical) |

## 🚀 Deployment Options

### Option 1: Dedicated Monitor Component (Recommended)

**Best for**: Regular BSOD monitoring across all managed devices

#### Create Datto RMM Component:
1. **Component Name**: `Bluescreen Monitor`
2. **Component Type**: `Monitors` (Custom Monitor)
3. **Script Content**: Paste entire `BluescreenMonitor.ps1` script content directly
4. **Environment Variables**:
   ```
   DaysToCheck = 7
   IncludeDetails = true
   ```

#### Component Script Content:
```powershell
# Use the specialized monitor launcher
# Environment variables will be automatically passed to the script
$ScriptName = "BluescreenMonitor.ps1"
# Launcher will handle GitHub download and execution
```

### Option 2: Universal Launcher

**Best for**: Testing or one-time checks

#### Environment Variables:
```
GitHubRepo = aybouzaglou/Datto-RMM-Powershell-Scripts
ScriptPath = components/Monitors/BluescreenMonitor.ps1
DaysToCheck = 7
IncludeDetails = true
```

## ⚙️ Configuration Parameters

### Environment Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `DaysToCheck` | Integer | 7 | Number of days to look back for BSOD events |
| `IncludeDetails` | Boolean | true | Include detailed BSOD information in alert message |

### Configuration Examples

#### Standard 7-Day Monitoring:
```
DaysToCheck = 7
IncludeDetails = true
```

#### Extended 30-Day Monitoring:
```
DaysToCheck = 30
IncludeDetails = true
```

#### Minimal Output (Summary Only):
```
DaysToCheck = 7
IncludeDetails = false
```

## 📋 Monitor Results

### ✅ Healthy System (Exit Code 0)
```
OK: No blue screens detected in the past 7 days
```

### ⚠️ BSODs Detected (Exit Code 1)
```
CRITICAL: 2 blue screens detected in the past 7 days (Most recent: 2024-01-15 14:30:22) | Recent events: 01/15 14:30 - BSOD Error Report; 01/12 09:15 - System Reboot (Critical)
```

### 🔧 Error State (Exit Code 1)
```
CRITICAL: Bluescreen monitor failed: Access denied to event log
```

## 🎯 Alert Configuration

### Recommended Alert Settings:
- **Alert Priority**: High (BSODs indicate serious system issues)
- **Alert Frequency**: Immediate (don't delay BSOD notifications)
- **Escalation**: Yes (system stability issues need attention)

### Alert Thresholds:
- **OK**: 0 BSODs detected
- **CRITICAL**: Any BSODs detected (1 or more)

## 🔧 Troubleshooting

### Common Issues

#### "Access Denied" Errors
**Cause**: Insufficient permissions to read Event Logs
**Solution**: Ensure Datto RMM agent runs with appropriate privileges

#### "Event Log Not Found" Errors
**Cause**: Event log service issues or corrupted logs
**Solution**: Check Windows Event Log service status

#### "No Data" Issues
**Cause**: Monitor output not being written properly or boolean parsing errors
**Solution**: Check environment variable format - use "true"/"false" or "1"/"0" for boolean values

#### Timeout Issues
**Cause**: Large event logs or slow system performance
**Solution**: Reduce `DaysToCheck` parameter or check system performance

#### PowerShell Version Issues
**Cause**: Script requires PowerShell 3.0+ for Get-WinEvent FilterHashtable
**Solution**: Ensure target systems have PowerShell 3.0 or later

### Testing the Monitor

#### Manual Test (PowerShell):
```powershell
# Download and test the script locally
$scriptPath = "C:\temp\BluescreenMonitor.ps1"
# Download from GitHub...
& $scriptPath -DaysToCheck 7 -IncludeDetails $true
```

#### Expected Output Format:
```
<-Start Result->
OK: No blue screens detected in the past 7 days
<-End Result->
```

## 📈 Performance Characteristics

- **Execution Time**: <2 seconds typical
- **Memory Usage**: <10MB
- **Network Usage**: None (reads local event logs only)
- **System Impact**: Minimal (read-only event log queries)

## 🔄 Maintenance

### Regular Tasks:
- **Monitor alerts**: Review BSOD alerts promptly
- **Validate results**: Occasionally verify against Event Viewer
- **Adjust timeframe**: Modify `DaysToCheck` based on needs

### Updates:
- Script auto-updates via GitHub when using launchers
- No manual maintenance required for function library

## 📚 Related Documentation

- [Datto RMM Component Categories](Datto-RMM-Component-Categories.md)
- [Monitor Development Guide](Monitor-Performance-Optimization-Guide.md)
- [GitHub Function Library Guide](GitHub-Function-Library-Guide.md)

## 🎯 Quick Reference

### Copy/Paste Environment Variables:
```
ScriptName = BluescreenMonitor.ps1
DaysToCheck = 7
IncludeDetails = true
```

### Component Creation Checklist:
- [ ] Component Type: Monitors (Custom Monitor)
- [ ] Script content pasted directly (no launcher needed)
- [ ] Environment variables configured
- [ ] Alert priority set to High
- [ ] Test execution on sample device
- [ ] Deploy to device groups

---

**⚠️ Important**: Monitor category is **immutable** - you cannot change it to Applications or Scripts later. However, you can edit the script content and environment variables.
