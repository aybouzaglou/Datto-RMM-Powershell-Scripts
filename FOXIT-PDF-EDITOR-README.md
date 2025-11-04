# Foxit PDF Editor SSO Installer - Datto RMM Script

## Overview
This PowerShell script is designed for Datto RMM to deploy Foxit PDF Editor with SSO (Single Sign-On) activation. It is converted from the original Foxit PDF Reader component script and follows Datto RMM best practices.

## Key Features
- **Silent Installation**: Deploys Foxit PDF Editor without user interaction
- **SSO Activation Support**: Prepares the application for SSO authentication by end users
- **Multi-language Support**: Automatically detects system language and installs appropriate version
- **Architecture Detection**: Supports both 32-bit and 64-bit systems
- **Proxy Support**: Works in environments with proxy servers
- **Digital Signature Verification**: Validates installer authenticity before installation
- **Process Clash Detection**: Prevents installation conflicts with running instances

## Important: SSO Activation

### This script installs Foxit PDF Editor but does NOT automatically activate it.

Users must complete SSO activation on first launch by:
1. Opening Foxit PDF Editor
2. Clicking **Activate** → **Sign In** → **SSO Login**
3. Entering their organizational email address
4. Completing authentication through your identity provider (Azure AD, Okta, etc.)

### Prerequisites for SSO
- SSO must be configured in **Foxit Admin Console** by IT administrators before deployment
- Users must have valid organizational accounts in your identity provider
- Network access to your identity provider authentication endpoints

## Script Variables

### Required Variables
None - the script will install with default settings

### Optional Variables

#### `usrAction` (Selection)
Controls the action to perform:
- **install** (default): Fresh installation or upgrade
- **upgrade**: Explicitly upgrade existing installation
- **uninstall**: Remove Foxit PDF Editor

#### `usrFoxitKillSITE` (Boolean - Site/Global Level)
Controls behavior when Foxit PDF Editor is running:
- **false** (default): Abort installation if app is running
- **true**: Force-close the application to proceed with installation

**Recommendation**: Set to `true` at Site or Global level for unattended deployments

## Installation Details

### Download Source
- **CDN**: cdn01.foxitsoftware.com
- **Version**: 2025.2.0 (latest stable as of November 2025)
- **Installer Type**: Promotional EXE (compatible with most existing installations)

### What Gets Installed
- Foxit PDF Editor (formerly PhantomPDF)
- 64-bit or 32-bit version based on system architecture
- Localized language pack based on Windows system language

### Installation Path
Default installation paths:
- 64-bit: `C:\Program Files\Foxit Software\Foxit PDF Editor\`
- 32-bit: `C:\Program Files (x86)\Foxit Software\Foxit PDF Editor\`

## Usage in Datto RMM

### As a Component
1. Create a new PowerShell Component in Datto RMM
2. Upload this script
3. Configure script variables (if needed):
   - Set `usrFoxitKillSITE` to `true` at Site/Global level (recommended)
4. Assign to devices or sites
5. Run or schedule execution

### As Software Management
Can be integrated with Datto RMM Software Management for:
- Automated deployment tracking
- Version management
- Compliance reporting

## Exit Codes

| Code | Meaning | Action Required |
|------|---------|-----------------|
| 0 | Success | None - inform users about SSO activation |
| 1603 | Catastrophic failure | Uninstall existing version, reboot, reinstall |
| 1618 | Another installation in progress | Wait and retry |
| 1641 | Success - reboot initiated | System is restarting automatically |
| 3010 | Success - reboot required | Schedule system restart |

## Changes from Original Foxit Reader Script

### Major Changes
1. **Product**: Changed from Foxit PDF Reader to Foxit PDF Editor
2. **Download URL**: Updated to use PhantomPDF CDN path structure
3. **Version**: Using latest 2025.2.0 stable release
4. **Process Names**: Updated to detect FoxitPDFEditor/FoxitPhantomPDF
5. **Registry Paths**: Updated to check both "Foxit PDF Editor" and "Foxit PhantomPDF" keys
6. **Uninstall Logic**: Handles both PDF Editor and legacy PhantomPDF installations
7. **Activation Method**: Removed license key parameter, added SSO activation instructions

### License Key Removal
The original script supported the `usrFoxitKeySITE` variable for traditional license key activation. This has been **removed** because:
- SSO activation requires user interaction (cannot be automated via command line)
- SSO and traditional license keys are mutually exclusive activation methods
- Organizations using SSO should not use license keys

## Troubleshooting

### Installation Fails with Error 1603
**Cause**: Incompatible previous installation exists
**Solution**:
1. Run script with `usrAction` = `uninstall`
2. Reboot the system
3. Run script again with `usrAction` = `install`

### Application Still Shows Trial Version
**Cause**: User hasn't completed SSO activation
**Solution**: Guide user through SSO activation process (see above)

### Proxy Environment Issues
**Cause**: Proxy settings not configured in Datto RMM agent
**Solution**: Verify proxy configuration in CagService.exe.config

### Download Fails / Certificate Verification Fails
**Cause**: Firewall blocking cdn01.foxitsoftware.com
**Solution**: Whitelist the following in your firewall:
- `cdn01.foxitsoftware.com`
- `*.foxitsoftware.com`

### Different Version Needed
**Cause**: Script uses hardcoded version 2025.2.0
**Solution**: Edit line ~348 in script to change version:
```powershell
$varVersion = "2025.2.0"  # Change to desired version (format: YYYY.M.P)
# Note: Installer names use YYYYM format (e.g., 2025.2.0 → "20252")
```

## Security Considerations

### Digital Signature Verification
The script verifies the installer's digital signature against:
- **Certificate**: DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1
- **Thumbprint**: 7B0F360B775F76C94A12CA48445AA2D2A875701C

If verification fails, installation is aborted to prevent malware installation.

### SSO Security Benefits
- Centralized access control through identity provider
- Multi-factor authentication support (if configured)
- Automatic license deactivation when user account is disabled
- No need to distribute or manage license keys
- Audit trail of user activations

## Support and Maintenance

### Updating to Newer Versions
When Foxit releases a new version:
1. Update the `$varVersion` variable (around line 395)
2. Update the `$varVersionShort` calculation if version format changes
3. Test on a single device before mass deployment
4. Verify certificate thumbprint hasn't changed

### Logging
Installation logs are created at: `$PWD\foxit-editor.log`
The last 100 lines are automatically output to StdErr for Datto RMM visibility

## References

### Foxit Documentation
- [Foxit PDF Editor Deployment Guide](https://cdn01.foxitsoftware.com/pub/foxit/manual/phantom/en_us/PDF-Editor-Deployment-and-Configuration-2024.2.pdf)
- [Foxit Admin Console Setup](https://kb.foxit.com/s/articles/4685946393108-Foxit-Admin-Console-Setup-Quick-Start)
- [SSO Configuration Guide](https://kb.foxit.com/s/articles/8621399503636-Set-up-SSO)
- [Command-line Deployment](https://kb.foxit.com/s/articles/360040660271-Command-line-Deployments-of-Foxit-PDF-Editor)

### Datto RMM Best Practices
- Component script structure and conventions
- Proxy support implementation
- Error handling and exit codes
- User feedback and logging

## License and Copyright

This script, like all Datto RMM Component scripts unless otherwise explicitly stated, is the copyrighted property of Datto, Inc. It may not be shared, sold, or distributed beyond the Datto RMM product, whole or in part, even with modifications applied, for any reason.

**The moment you edit this script it becomes your own risk and support will not provide assistance with it.**

## Version History

### Build 1/2025 (November 2025)
- Initial conversion from Foxit Reader to Foxit PDF Editor
- Added SSO activation support and instructions
- Updated for 2025.2.0 release
- Enhanced documentation and error handling
- Added support for legacy PhantomPDF installations

---

**Created**: November 2025
**Converted from**: Foxit Reader Component (build 29/seagull, September 2025)
**For**: Datto RMM Platform
