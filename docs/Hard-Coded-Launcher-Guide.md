# 🚀 Hard-Coded Launcher System Guide

## 📋 Overview

The hard-coded launcher system solves the environment variable conflict issue by:
- **Hard-coding script paths** in launcher templates (no more `ScriptName` environment variables)
- **Freeing up all environment variables** to be passed to the underlying scripts
- **Providing dedicated launchers** for each script with clear naming

## ❌ Problem with Previous Approach

### Old Universal Launcher Issues:
```powershell
# ❌ Old approach consumed environment variables for launcher configuration
# Environment Variables: ScriptName="FocusedDebloat.ps1", ScriptType="Scripts"
# This left no way to pass RebootEnabled, MaxRetries, etc. to the actual script
```

**Problems:**
- Launcher consumed `ScriptName` and `ScriptType` environment variables
- No environment variables available for the underlying script configuration
- Couldn't pass script-specific settings like `customwhitelist`, `RebootEnabled`, `MaxRetries`

## ✅ New Hard-Coded Launcher Solution

### Hard-Coded Configuration:
```powershell
# ✅ New approach hard-codes script path in launcher
$SCRIPT_PATH = "components/Scripts/FocusedDebloat.ps1"
$SCRIPT_TYPE = "Scripts"
$SCRIPT_DISPLAY_NAME = "Windows Focused Debloat"

# All environment variables now available for the script:
# customwhitelist, skipwindows, RebootEnabled, MaxRetries, etc.
```

**Benefits:**
- Script path is hard-coded (no environment variable consumption)
- All environment variables passed through to the underlying script
- Clear, dedicated launchers for each script
- Better logging and identification

## 📁 Available Hard-Coded Launchers

### Applications Components:
- **`launchers/hardcoded/ScanSnapHome-Launcher.ps1`**
  - Script: `components/Applications/ScanSnapHome.ps1`
  - Purpose: ScanSnap Home installation
  - Environment Variables: All passed to script

### Scripts Components:
- **`launchers/hardcoded/FocusedDebloat-Launcher.ps1`**
  - Script: `components/Scripts/FocusedDebloat.ps1`
  - Purpose: Windows bloatware removal
  - Environment Variables: `customwhitelist`, `skipwindows`, `skiphp`, `skipdell`, `skiplenovo`

- **`launchers/hardcoded/Setup-TestDevice-Launcher.ps1`**
  - Script: `components/Scripts/Setup-TestDevice.ps1`
  - Purpose: Test environment setup
  - Environment Variables: `TestResultsPath`, `CleanupOldResults`

- **`launchers/hardcoded/Validate-TestEnvironment-Launcher.ps1`**
  - Script: `components/Scripts/Validate-TestEnvironment.ps1`
  - Purpose: Test environment validation
  - Environment Variables: `TestResultsPath`

## 🔧 Deployment Instructions

### Step 1: Create Datto RMM Component

1. **Component Name**: Use descriptive name (e.g., "Windows Focused Debloat")
2. **Component Type**: 
   - Applications (for software installation)
   - Scripts (for general automation)
3. **Script Content**: Copy the entire hard-coded launcher content

### Step 2: Configure Environment Variables

Set environment variables specific to your script needs:

#### For FocusedDebloat:
```
customwhitelist = App1,App2,App3
skipwindows = false
skiphp = false
skipdell = false
skiplenovo = false
```

#### For ScanSnapHome:
```
(No specific environment variables - script handles detection automatically)
```

#### For Test Scripts:
```
TestResultsPath = C:\TestResults
CleanupOldResults = 7
```

### Step 3: Deploy Component

Deploy the component through Datto RMM as usual. The launcher will:
1. Download the specified script from GitHub
2. Pass all environment variables to the script
3. Execute the script with full environment variable access

## 🛠️ Creating New Hard-Coded Launchers

### Template Structure:
```powershell
# ===== HARD-CODED SCRIPT CONFIGURATION =====
$SCRIPT_PATH = "components/Scripts/YourScript.ps1"  # ← Customize this
$SCRIPT_TYPE = "Scripts"                            # ← Customize this
$SCRIPT_DISPLAY_NAME = "Your Script Display Name"  # ← Customize this
# ============================================
```

### Steps to Create New Launcher:
1. Copy `launchers/UniversalLauncher.ps1` template
2. Update the three configuration variables above
3. Rename file to `YourScript-Launcher.ps1`
4. Save in `launchers/hardcoded/` directory
5. Test with your Datto RMM component

## 📊 Comparison: Old vs New

| Aspect | Old Universal Launcher | New Hard-Coded Launcher |
|--------|----------------------|-------------------------|
| **Script Selection** | Environment variable (`ScriptName`) | Hard-coded in launcher |
| **Environment Variables** | Consumed by launcher | All passed to script |
| **Configuration Flexibility** | Limited by launcher needs | Full script configuration |
| **Deployment** | Generic launcher + env vars | Dedicated launcher per script |
| **Maintenance** | Single launcher, complex config | Multiple launchers, simple config |
| **Clarity** | Generic, requires documentation | Self-documenting, script-specific |

## 🔍 Troubleshooting

### Common Issues:

#### Environment Variables Not Working:
- **Old Problem**: Launcher consumed `ScriptName`, blocking script variables
- **New Solution**: Hard-coded path frees all environment variables for script

#### Script Not Found:
- Check `SCRIPT_PATH` matches actual file location in repository
- Verify `SCRIPT_TYPE` matches directory (Applications/Scripts)
- Ensure GitHub repository and branch are correct

#### Execution Errors:
- Review launcher logs in `C:\ProgramData\DattoRMM\`
- Check if script requires specific environment variables
- Verify script permissions and PowerShell execution policy

## 🎯 Best Practices

### Naming Convention:
- Launcher files: `ScriptName-Launcher.ps1`
- Location: `launchers/hardcoded/`
- Clear, descriptive display names

### Environment Variable Usage:
- Document required environment variables in launcher comments
- Use meaningful variable names (`RebootEnabled` vs `R`)
- Provide default values in scripts when possible

### Testing:
- Test launchers in development environment first
- Verify environment variable passthrough works correctly
- Check script execution with various environment variable combinations

## 📚 Related Documentation

- **Main README**: Repository overview and quick start
- **Deployment Guide**: General deployment strategies
- **Component Categories**: Understanding Applications vs Scripts vs Monitors
- **GitHub Actions**: Validation and testing pipeline

---

**Note**: Monitors use direct deployment (paste script content directly) and do not use launchers for optimal performance.
