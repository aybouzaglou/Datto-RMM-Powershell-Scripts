# 🔍 Bluescreen Monitor - Quick Reference Card

## 📋 Component Setup (Copy/Paste Ready)

### Dedicated Monitor Component (Direct Deployment)
```
Component Name: Bluescreen Monitor
Component Type: Monitors (Custom Monitor)
Script Content: [Paste entire BluescreenMonitor.ps1 script content directly]

Environment Variables:
DaysToCheck = 7
IncludeDetails = true
```

### Universal Launcher Alternative
```
Environment Variables:
GitHubRepo = aybouzaglou/Datto-RMM-Powershell-Scripts
ScriptPath = components/monitors/BluescreenMonitor.ps1
DaysToCheck = 7
IncludeDetails = true
```

## ⚙️ Configuration Options

| Setting | Values | Purpose |
|---------|--------|---------|
| `DaysToCheck` | 1-30 | How far back to check for BSODs |
| `IncludeDetails` | true/false | Show detailed BSOD info in alerts |

### Common Configurations:
- **Standard**: `DaysToCheck = 7, IncludeDetails = true`
- **Extended**: `DaysToCheck = 30, IncludeDetails = true`
- **Summary**: `DaysToCheck = 7, IncludeDetails = false`

## 📊 Monitor Results

### ✅ Healthy (No Action Needed)
```
OK: No blue screens detected in the past 7 days
```

### 🚨 Alert (Investigate Immediately)
```
CRITICAL: 2 blue screens detected in the past 7 days 
(Most recent: 2024-01-15 14:30:22) | Recent events: 
01/15 14:30 - BSOD Error Report; 01/12 09:15 - System Reboot (Critical)
```

## 🎯 Alert Settings (Recommended)

- **Alert Priority**: High
- **Alert Frequency**: Immediate
- **Escalation**: Yes
- **Threshold**: Any non-zero exit code

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Access denied" | Check RMM agent permissions |
| "Event log not found" | Verify Windows Event Log service |
| Timeout errors | Reduce DaysToCheck parameter |
| No alerts on known BSODs | Check event log for Event IDs 1001, 6008, 41 |

## 📞 Quick Actions

### When BSOD Alert Triggers:
1. **Immediate**: Check system stability
2. **Review**: Windows Event Viewer for details
3. **Investigate**: Hardware issues (RAM, drivers, overheating)
4. **Document**: BSOD patterns and frequency
5. **Schedule**: Hardware diagnostics if recurring

### Manual Check (Remote PowerShell):
```powershell
Get-WinEvent -FilterHashtable @{LogName='System'; ID=6008; StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue
```

## 📈 What BSODs Mean

- **1 BSOD**: Investigate but may be isolated incident
- **2+ BSODs**: Serious system stability issue - priority investigation
- **Daily BSODs**: Critical hardware/driver problem - immediate action

## ⚠️ Important Notes

- Monitor category is **immutable** (cannot change to Scripts/Applications)
- Script content can be edited, but stays a Monitor
- Runs automatically every few minutes when deployed
- <3 second execution requirement for monitors

---
**Script Location**: `components/monitors/BluescreenMonitor.ps1`  
**Documentation**: `docs/BluescreenMonitor-Guide.md`
