# Messenger Application Uninstall - Datto RMM Component

## Overview

This script intelligently detects and uninstalls Messenger applications from both system and user contexts. It combines the two methods you provided into a single, comprehensive solution that automatically determines the correct uninstall approach.

## Features

- **Dual Context Detection**: Automatically detects installations in both system (MSI) and user contexts
- **Smart Process Management**: Terminates running Messenger processes before uninstall
- **Registry-Based Detection**: Uses fast registry scanning instead of Win32_Product (avoids MSI repair triggers)
- **Multiple Messenger Variants**: Handles Messenger, Chatgenie Messenger, and similar applications
- **Comprehensive Logging**: Detailed logging with color-coded output for easy troubleshooting
- **Verification**: Optional post-uninstall verification to ensure complete removal
- **Flexible Configuration**: Environment variables for customizing behavior

## Installation Context Detection

### System Context (MSI Installations)
The script detects MSI-based installations by scanning:
- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`
- `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall`

Uses `msiexec /x {ProductCode} /qn /norestart` for removal.

### User Context (User-Level Installations)
The script detects user-level installations by:
- Scanning all user registry hives under `HKEY_USERS`
- Checking common installation paths like `%LOCALAPPDATA%\Programs\Messenger`
- Looking for `Uninstall Messenger.exe` executables

Uses the application's native uninstaller with silent flags.

## Environment Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ForceKill` | Boolean | `true` | Force kill processes even if they don't respond gracefully |
| `SkipUserContext` | Boolean | `false` | Skip user context detection and uninstall |
| `SkipSystemContext` | Boolean | `false` | Skip system context detection and uninstall |
| `VerifyUninstall` | Boolean | `true` | Verify complete removal after uninstall |

## Datto RMM Configuration

### Component Settings
- **Category**: Applications (Software Removal)
- **Timeout**: 15 minutes
- **Execution**: On-demand or scheduled

### Environment Variable Examples
```
ForceKill = true
SkipUserContext = false
SkipSystemContext = false
VerifyUninstall = true
```

## Exit Codes

| Code | Meaning | Description |
|------|---------|-------------|
| `0` | Success | Uninstall completed successfully or no installations found |
| `1` | Failed | Uninstall failed or critical error occurred |
| `2` | Partial Success | Some installations removed but others failed |

## Usage Scenarios

### Standard Uninstall (Both Contexts)
```
ForceKill = true
SkipUserContext = false
SkipSystemContext = false
VerifyUninstall = true
```

### System Context Only
```
ForceKill = true
SkipUserContext = true
SkipSystemContext = false
VerifyUninstall = true
```

### User Context Only
```
ForceKill = true
SkipUserContext = false
SkipSystemContext = true
VerifyUninstall = true
```

## How It Works

1. **Process Termination**: Kills all running Messenger processes
2. **Detection Phase**: Scans both system and user contexts for installations
3. **System Uninstall**: Uses MSI product codes with msiexec for system installations
4. **User Uninstall**: Uses native uninstallers for user-level installations
5. **Verification**: Confirms complete removal (optional)
6. **Reporting**: Provides detailed success/failure reporting

## Logging

The script creates detailed logs at:
- **Path**: `C:\ProgramData\DattoRMM\Applications\MessengerUninstall-Applications.log`
- **Format**: Timestamped entries with color-coded severity levels
- **Levels**: Info, Status, Success, Warning, Error, Config, Detect

## Troubleshooting

### Common Issues

**"No installations found" but Messenger is present**
- Check if running as administrator
- Verify registry access permissions
- Check for non-standard installation locations

**Partial uninstall success**
- Review logs for specific failure reasons
- Some user installations may require user context execution
- MSI installations may be corrupted (use Windows Installer Cleanup)

**Process termination failures**
- Increase timeout if processes are slow to respond
- Check for services or background components
- Verify sufficient privileges

### Debug Mode
For additional troubleshooting, the script provides detailed detection information showing:
- Found installations with full details
- Registry paths checked
- User contexts discovered
- Uninstall commands executed

## Integration with Your Documentation

This script implements both methods from your documentation:

### Method 1: System Context (Your PowerShell Script)
```powershell
# Your original approach - now automated
$productCode = Get-ProductCode $appName
Start-Process msiexec.exe -ArgumentList "/x $productCode /qn" -Wait
```

### Method 2: User Context (Your Batch + PowerShell)
```powershell
# Your original approach - now automated
$updatePath = "$env:LOCALAPPDATA\Programs\Messenger\Uninstall Messenger.exe"
Start-Process -FilePath $updatePath -ArgumentList "/S" -Wait
```

The script automatically determines which method(s) to use based on what it finds during detection.

## Best Practices

1. **Test First**: Run with verification enabled to confirm detection accuracy
2. **Backup Important Data**: Ensure users have backed up any important Messenger data
3. **Schedule Appropriately**: Run during maintenance windows when users aren't actively using Messenger
4. **Monitor Results**: Review logs and exit codes to ensure successful deployment
5. **User Communication**: Notify users before running to prevent data loss

## Version History

- **v1.0.0**: Initial release with dual context support, comprehensive detection, and verification
