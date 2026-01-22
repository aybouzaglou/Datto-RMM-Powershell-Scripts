# Manage Mark of the Web (MotW) - Consolidated Component

## Overview

This consolidated Datto RMM component addresses File Explorer preview issues caused by Mark of the Web (MotW) tagging on internet downloads. It combines two operations into a single script with configurable input variables:

1. **Enable Policy**: Sets registry policy to prevent MotW tagging on NEW downloads
2. **Unblock Files**: Removes MotW tags from existing downloaded files

This addresses the issue described in [Issue #7](https://github.com/aybouzaglou/Datto-RMM-Powershell-Scripts/issues/7) by consolidating Script 1 (policy enable) and Script 2 (bulk unblock) into one component.

## Problem Statement

After Microsoft's security updates, Windows tags files downloaded from the internet with Mark of the Web (MotW), which can:
- Prevent File Explorer preview functionality
- Block file execution without explicit unblocking
- Impact productivity for users working with PDFs, Office documents, and other downloads

## Solution

This script provides a comprehensive solution with flexible deployment options:

- **Preventive**: Enable registry policy to stop MotW tagging on future downloads
- **Remedial**: Remove MotW from existing files in targeted locations
- **Flexible**: Configure which operations to run and where to target them

## Datto RMM Setup

### Component Configuration

1. **Create New Component**
   - Type: **Script**
   - Category: Scripts (General Automation/Maintenance)
   - Language: **PowerShell**

2. **Script Content**
   - Copy contents of `Manage-MarkOfTheWeb.ps1`
   - Paste into Datto RMM script editor

3. **Execution Settings**
   - Run Context: **User** (required for HKCU registry and user file access)
   - Timeout: **15 minutes** (longer for full profile scans)
   - Execution: On-demand or scheduled

### Input Variables

Configure the following environment variables in Datto RMM:

| Variable Name | Type | Default | Description |
|--------------|------|---------|-------------|
| `EnablePolicy` | String | `true` | Enable registry policy to prevent MotW on new downloads |
| `UnblockFiles` | String | `true` | Remove MotW from existing files |
| `UnblockScope` | String | `Downloads` | Scope for unblocking: `Downloads` or `UserProfile` |
| `FilePatterns` | String | `*.pdf,*.docx,*.xlsx,*.pptx,*.doc,*.xls` | Comma-separated file patterns to unblock |
| `CustomPath` | String | _(empty)_ | Optional custom path for unblocking (overrides UnblockScope) |

## Usage Scenarios

### Scenario 1: Enable Policy Only (Prevent Future Issues)

**Use Case**: Deploy to all devices to prevent MotW tagging on new downloads

**Configuration**:
```
EnablePolicy = true
UnblockFiles = false
```

**Benefits**:
- Fast execution (<1 minute)
- No user impact
- Prevents future downloads from being tagged
- No restart required

### Scenario 2: Unblock Downloads Folder Only

**Use Case**: Fix existing files in Downloads folder for immediate user relief

**Configuration**:
```
EnablePolicy = false
UnblockFiles = true
UnblockScope = Downloads
FilePatterns = *.pdf,*.docx,*.xlsx,*.pptx,*.doc,*.xls
```

**Benefits**:
- Targeted remediation
- Faster than full profile scan
- Focuses on most common file types
- Execution time: 2-3 minutes for ~500 files

### Scenario 3: Full Remediation (Recommended)

**Use Case**: Complete solution - prevent future issues and fix existing files

**Configuration**:
```
EnablePolicy = true
UnblockFiles = true
UnblockScope = Downloads
FilePatterns = *.pdf,*.docx,*.xlsx
```

**Benefits**:
- Comprehensive fix
- Prevents future issues
- Resolves current user impact
- Recommended for initial deployment

### Scenario 4: Full User Profile Scan

**Use Case**: Thorough cleanup for heavily impacted users

**Configuration**:
```
EnablePolicy = true
UnblockFiles = true
UnblockScope = UserProfile
```

**Warning**: 
- Can take 10+ minutes for large profiles
- Scans all user directories recursively
- Deploy during off-hours if possible
- Ignores FilePatterns (unblocks ALL files)

### Scenario 5: Custom Path Target

**Use Case**: Unblock files in specific shared or custom locations

**Configuration**:
```
EnablePolicy = false
UnblockFiles = true
CustomPath = C:\SharedDocs
FilePatterns = *.pdf,*.doc
```

**Use Cases**:
- Shared network folders
- Company document repositories
- Specific project directories

## Deployment Strategy

### Recommended Rollout Sequence

**Phase 1 - Policy Deployment (Day 1)**

Deploy to all affected devices with:
```
EnablePolicy = true
UnblockFiles = false
```

This prevents future downloads from being tagged. No user restart required.

**Phase 2 - Targeted Remediation (Day 1-2)**

For users reporting issues, deploy with:
```
EnablePolicy = true
UnblockFiles = true
UnblockScope = Downloads
```

This fixes existing files while ensuring policy is enabled.

**Phase 3 - Full Cleanup (Optional)**

For heavily impacted users, deploy during off-hours with:
```
EnablePolicy = true
UnblockFiles = true
UnblockScope = UserProfile
```

### Performance Considerations

| Operation | Typical Duration | Notes |
|-----------|-----------------|-------|
| Policy Enable | <1 minute | Registry change only |
| Unblock Downloads | 2-3 minutes | ~500 files |
| Unblock UserProfile | 10+ minutes | Varies by file count |

## Verification

### Policy Verification (Manual)

Run on target machine to verify policy is enabled:

```powershell
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v SaveZoneInformation
```

**Expected Output**:
```
SaveZoneInformation    REG_DWORD    0x1
```

### User Verification (End User)

1. Download a test PDF from the internet
2. Right-click the file → Properties
3. Verify **"Unblock" button is NOT visible** (policy working)
4. File preview should now work in File Explorer

### Script Output Verification

The script provides comprehensive logging:

- **SUCCESS**: All enabled operations completed successfully (Exit Code: 0)
- **FAILED**: One or more operations failed (Exit Code: 1)
- **CONFIG ERROR**: Invalid input variables (Exit Code: 2)

Check Datto RMM execution logs for detailed operation status.

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Policy fails with access denied | Running in System context | Change to User context |
| Policy doesn't apply immediately | Registry not refreshed | User may need to sign out/in |
| Unblock takes too long | Full profile scan | Use `UnblockScope = Downloads` instead |
| Some files still blocked | Network/UNC paths | Add to Trusted Sites or use CustomPath |
| Script exit code 2 | Invalid configuration | Check environment variables |

### Debug Mode

Check Datto RMM script execution logs for detailed output:
- Operation start/completion timestamps
- File counts processed
- Verification results
- Error messages with stack traces

## Exit Codes

| Code | Meaning | Action Required |
|------|---------|-----------------|
| 0 | Success | None - all operations completed |
| 1 | Failure | Review logs - one or more operations failed |
| 2 | Configuration Error | Fix environment variables |

## Advanced Usage

### Custom File Patterns

Target specific file types:

```
FilePatterns = *.exe,*.msi,*.zip
```

### Multiple Custom Patterns

```
FilePatterns = *.pdf,*.doc,*.docx,*.xls,*.xlsx,*.ppt,*.pptx,*.zip,*.rar
```

### Environment Variable Expansion

CustomPath supports environment variables:

```
CustomPath = $env:USERPROFILE\Documents\Projects
CustomPath = $env:PUBLIC\SharedFiles
```

## Integration with Datto RMM

### Component Assignment

- Assign to device groups experiencing File Explorer preview issues
- Can be deployed to all Windows 10 1703+ and Windows 11 devices

### Scheduling

- **On-Demand**: For immediate remediation
- **Scheduled**: For maintenance windows (recommended for UserProfile scope)

### Monitoring

Monitor in Datto RMM:
- **Script Executions** tab for real-time status
- Check exit codes for success/failure
- Review logs for detailed operation results

## Customer Communication Template

Use this template when deploying to customers:

```
Subject: File Explorer Preview Restoration

We're deploying a policy fix to restore File Explorer preview functionality 
for internet-downloaded files. This addresses recent Microsoft security updates.

What to expect:
- No user action required
- Files will preview normally in File Explorer
- One-time performance impact during file processing
- No system restart needed

Timeline:
- Deployment: [Date/Time]
- Expected duration: 2-5 minutes per device
- Full functionality restored immediately after

If you experience any issues after deployment, please contact IT support.
```

## Technical Details

### Registry Changes

**Path**: `HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments`  
**Value**: `SaveZoneInformation = 1 (DWORD)`  
**Effect**: Disables Zone Information preservation on new downloads

### File Operations

The script uses PowerShell's `Unblock-File` cmdlet, which:
- Removes the `Zone.Identifier` alternate data stream
- Operates safely on files without the stream (no errors)
- Requires no special permissions beyond file access

### Compatibility

- **Windows 10**: Version 1703 or later
- **Windows 11**: All versions
- **PowerShell**: 5.0 or later (included in modern Windows)

## Version History

### Version 1.0.0
- Initial release
- Consolidates Script 1 (policy enable) and Script 2 (bulk unblock)
- Supports configurable operations via input variables
- Implements flexible scoping (Downloads/UserProfile/Custom)
- Adds comprehensive logging and verification
- Supports User context execution

## Related Documentation

- [Issue #7](https://github.com/aybouzaglou/Datto-RMM-Powershell-Scripts/issues/7) - Original feature request
- [Datto RMM Component Categories](../../docs/Datto-RMM-Component-Categories.md)
- [Deployment Guide](../../docs/Deployment-Guide.md)

## Support

For issues or questions:
1. Review the Troubleshooting section above
2. Check Datto RMM execution logs for detailed error messages
3. Refer to the repository documentation
4. Open an issue on GitHub
