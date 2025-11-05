# Foxit PDF Editor+ SSO Installer (MSI) - Datto RMM Script

## Overview
This PowerShell script deploys Foxit PDF Editor+ (subscription version with SSO support) using an MSI file attached to the Datto RMM component. This is the simplified deployment method that doesn't require internet access on target machines.

## Prerequisites

### 1. Download the Correct MSI
**CRITICAL**: You must use **Foxit PDF Editor+ (2025.x subscription version)**, NOT the perpetual v14 edition.

- **Correct Version**: PDF Editor+ with 2025.x numbering (e.g., 2025.2.0)
- **Wrong Version**: PDF Editor 14.x (perpetual desktop-only version)
- **Why**: Only the subscription version supports SSO activation

**Download Source**:
- Foxit Admin Console (for existing customers)
- Official Foxit website downloads page
- Contact Foxit sales for subscription version access

**Expected Filename**: `FoxitPDFEditor20252_L10N_Setup.msi` (or similar for newer versions)

### 2. SSO Configuration
SSO must be pre-configured in **Foxit Admin Console** by IT administrators before deployment. This script installs the application but does NOT configure SSO.

## Deployment Steps

### Step 1: Prepare the MSI File
1. Download Foxit PDF Editor+ MSI (subscription version)
2. Verify it's the 2025.x version (not v14.x)
3. Note the exact filename

### Step 2: Configure in Datto RMM
1. Create or edit a Component in Datto RMM
2. Upload this PowerShell script
3. **Attach the MSI file** to the component
4. Configure variables (see below)

### Step 3: Deploy
1. Assign component to target devices/sites
2. Run or schedule execution
3. Inform users about SSO activation requirement

## Script Variables

### Optional Variables

#### `usrAction` (Selection)
Controls the action to perform:
- **install** (default): Install or upgrade Foxit PDF Editor
- **uninstall**: Remove Foxit PDF Editor

#### `usrFoxitKillSITE` (Boolean - Site/Global Level)
Controls behavior when Foxit PDF Editor is running:
- **false** (default): Abort installation if app is running
- **true**: Force-close the application to proceed

**Recommendation**: Set to `true` for unattended deployments

#### `usrMsiFileName` (String - Site/Global Level)
Specifies the exact MSI filename if different from default:
- **Default**: `FoxitPDFEditor20252_L10N_Setup.msi`
- **Custom**: Set to your MSI filename if different (e.g., `FoxitPDFEditor20253_L10N_Setup.msi`)

**When to Set**: If you're using a newer version or differently-named MSI file

## SSO Activation

### Users Must Complete SSO Activation on First Launch

This script **installs** Foxit PDF Editor+ but does **NOT activate** it automatically.

**User Steps (First Launch)**:
1. Open Foxit PDF Editor
2. Click **Activate**
3. Click **Sign In**
4. Click **SSO Login**
5. Enter organizational email address
6. Complete authentication through your identity provider (Azure AD, Okta, etc.)

**IT Admin Prerequisites**:
- SSO must be configured in Foxit Admin Console
- Users must have valid organizational accounts
- Network access to identity provider endpoints

## Installation Details

### What the Script Does
1. ✅ Checks for running Foxit processes (force-closes if enabled)
2. ✅ Locates the attached MSI file
3. ✅ Runs silent MSI installation: `msiexec /i <file> /qn /norestart`
4. ✅ Creates verbose installation log
5. ✅ Returns detailed exit codes for monitoring

### Installation Command
```powershell
msiexec /i "FoxitPDFEditor20252_L10N_Setup.msi" /qn /norestart /L*v "foxit-install.log"
```

**Parameters**:
- `/i` - Install
- `/qn` - Quiet mode, no UI
- `/norestart` - Don't restart after install
- `/L*v` - Verbose logging

### Installation Path
Default: `C:\Program Files\Foxit Software\Foxit PDF Editor\`

### Logging
Log file created at: `<working directory>\foxit-install.log`

## Exit Codes

| Code | Meaning | Action Required |
|------|---------|-----------------|
| 0 | Success | Inform users about SSO activation |
| 1602 | User cancelled | Should not occur in silent mode |
| 1603 | Fatal error | Uninstall, reboot, reinstall |
| 1618 | Another installation running | Wait and retry |
| 1619 | Invalid/corrupt MSI | Re-download and re-attach MSI |
| 1641 | Success - rebooting | System restarting automatically |
| 3010 | Success - reboot needed | Schedule system restart |

## Troubleshooting

### Error: MSI file not found
**Symptoms**: Script exits with "MSI file not found" error

**Solutions**:
1. Verify MSI file is attached to component in Datto RMM
2. Check filename matches exactly (case-sensitive)
3. If using custom filename, set `usrMsiFileName` variable

### Error: Installation failed with code 1603
**Symptoms**: Fatal installation error

**Solutions**:
1. Run component with `usrAction` = `Uninstall`
2. Reboot the system
3. Run installation again
4. Check MSI file isn't corrupted

### Wrong Version Installed (v14 instead of 2025.x)
**Symptoms**: Users see "PDF Editor 14" instead of "PDF Editor+ 2025"

**Solutions**:
1. You attached the wrong MSI (perpetual v14 instead of subscription 2025.x)
2. Download the correct subscription version MSI
3. Re-attach to component
4. Run installation again

### SSO Login Button Not Appearing
**Symptoms**: Users don't see SSO login option

**Solutions**:
1. Verify you're using PDF Editor+ (2025.x), not v14
2. Ensure SSO is configured in Foxit Admin Console
3. Check internet connectivity to Foxit servers
4. Contact Foxit support for SSO configuration

### Application Won't Close
**Symptoms**: Installation fails because app is running

**Solutions**:
- Set `usrFoxitKillSITE` = `true` at Site/Global level
- OR manually close Foxit on target machine before deployment

## Advanced Configuration

### Custom MSI Properties
To add custom MSI properties (e.g., installation location), edit line ~174-181:

```powershell
$msiArgs = @(
    "/i"
    "`"$msiPath`""
    "/qn"
    "/norestart"
    "INSTALLLOCATION=`"C:\Custom\Path`""  # Add custom properties here
    "/L*v"
    "`"$PWD\foxit-install.log`""
)
```

**Common Properties**:
- `INSTALLLOCATION="C:\Custom\Path"` - Custom install location
- `ADDLOCAL="FX_PDFVIEWER"` - Install specific features
- See [Foxit MSI documentation](https://kb.foxit.com/s/articles/360061805411-Foxit-PDF-EditorMSI-Installer-Public-Properties)

### Disable Features
To disable specific features during installation:
```powershell
"ADDLOCAL=ALL"
"ADVERTISE=FX_CREATOR"  # Disable PDF Creator feature
```

## File Locations

### Script Location
```
components/Applications/Foxit-PDF-Editor-SSO-Installer.ps1
```

### Log Location (After Install)
```
<Datto RMM Working Directory>\foxit-install.log
```

### Registry Locations (Verification)
- `HKLM:\SOFTWARE\Foxit Software\Foxit PDF Editor`
- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{GUID}`

## Comparison: MSI vs EXE Deployment

| Aspect | MSI (This Script) | EXE (Web Download) |
|--------|-------------------|-------------------|
| Internet Required | ❌ No | ✅ Yes |
| File Size | ~800-1000 MB attached | ~800-1000 MB download |
| Version Control | Manual MSI update | Auto-latest version |
| Customization | Full MSI properties | Limited parameters |
| Logging | Verbose MSI logs | Basic logs |
| Enterprise Standard | ✅ Yes | Less common |
| Best For | Air-gapped networks, strict control | Auto-updating deployments |

## Security Considerations

### MSI File Integrity
- Download MSI only from official Foxit sources
- Verify file size matches expected (800-1000 MB range)
- Check digital signature of MSI before deployment
- Store MSI securely - it contains the full application

### SSO Security Benefits
- Centralized access control through identity provider
- Multi-factor authentication support (if configured)
- Automatic license deactivation when user account disabled
- Audit trail of user activations
- No license key distribution required

## Version Updates

### When Foxit Releases New Version

1. Download new MSI from Foxit
2. Update `usrMsiFileName` variable if filename changes
3. Update README version references
4. Replace attached MSI in Datto RMM component
5. Test on pilot devices
6. Deploy to production

**Version Naming**: `FoxitPDFEditor[YYYYM]_L10N_Setup.msi`
- Example: `FoxitPDFEditor20252_L10N_Setup.msi` = 2025.2
- Example: `FoxitPDFEditor20253_L10N_Setup.msi` = 2025.3

## Support

### Foxit Documentation
- [MSI Installer Properties](https://kb.foxit.com/s/articles/360061805411-Foxit-PDF-EditorMSI-Installer-Public-Properties)
- [Command-line Deployments](https://kb.foxit.com/s/articles/360040660271-Command-line-Deployments-of-Foxit-PDF-Editor)
- [SSO Configuration](https://kb.foxit.com/s/articles/8621399503636-Set-up-SSO)
- [Admin Console Setup](https://kb.foxit.com/s/articles/4685946393108-Foxit-Admin-Console-Setup-Quick-Start)

### Datto RMM Best Practices
- Component script structure
- File attachment procedures
- Variable configuration
- Exit code monitoring

## License and Copyright

This script, like all Datto RMM Component scripts unless otherwise explicitly stated, is the copyrighted property of Datto, Inc. It may not be shared, sold, or distributed beyond the Datto RMM product, whole or in part, even with modifications applied, for any reason.

**The moment you edit this script it becomes your own risk and support will not provide assistance with it.**

## Version History

### Build 3/2025 (November 2025)
- **Major Change**: Switched to MSI-based deployment
- Removed all download/web fetch functionality
- MSI file must be attached to Datto RMM component
- Simplified script - no proxy support needed
- Added detailed MSI logging
- Enhanced error messages and troubleshooting
- Added `usrMsiFileName` variable for flexibility

### Build 2/2025 (November 2025)
- Fixed download URL for PDF Editor+ subscription version
- Used Foxit cloud API endpoint

### Build 1/2025 (November 2025)
- Initial conversion from Foxit Reader to Foxit PDF Editor
- Added SSO activation support and instructions
- Updated for 2025.x release

---

**Created**: November 2025
**Converted from**: Foxit Reader Component
**For**: Datto RMM Platform
**Deployment Method**: MSI Attachment (Manual)
