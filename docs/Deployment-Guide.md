# Datto RMM Script Deployment Guide

## Quick Start

### Repository Structure
```
├── shared-functions/    # Function patterns to copy/paste
├── components/         # Self-contained scripts by type
└── docs/              # Documentation
```

### Deployment Method
**All components use direct deployment:**
1. Copy entire script content from `components/`
2. Paste directly into Datto RMM component
3. Set environment variables as needed
4. Deploy

### File Attachments
For Applications that need installer files:
- Use Datto RMM's file attachment feature
- Reference files by name only (e.g., `"installer.msi"`)
- Files are automatically available in working directory

**📖 Details**: [File Attachment Guide](Datto-RMM-File-Attachment-Guide.md)

## Script Development

### Self-Contained Requirements
- All functions must be embedded in each script
- Copy needed functions from `shared-functions/` into your script
- No external dependencies or imports

### Example Embedded Function
```powershell
function Write-RMMLog {
    param([string]$Message, [string]$Level = 'Info')
    $prefix = switch ($Level) {
        'Success' { 'SUCCESS ' }
        'Failed'  { 'FAILED  ' }
        'Warning' { 'WARNING ' }
        default   { 'INFO    ' }
    }
    Write-Output "$prefix$Message"
}
```

## Component Configuration

### Deployment Steps
1. **Copy Script**: Get entire script content from `components/`
2. **Paste to RMM**: Paste directly into Datto RMM component
3. **Set Variables**: Configure environment variables as needed
4. **Deploy**: Save and deploy to target devices

### Environment Variables Examples
**FocusedDebloat.ps1:**
```
customwhitelist = App1,App2,App3
skipwindows = false
```

**ScanSnapHome.ps1:**
```
(No variables needed - auto-detection)
```

## Available Scripts

### Applications
- **ScanSnapHome.ps1** - ScanSnap Home installation with file attachments

### Scripts
- **FocusedDebloat.ps1** - Windows bloatware removal with customization options

## Customization

### Adding Functions
1. Copy base script from `components/`
2. Add custom functions at the top
3. Test thoroughly before deployment

### Environment Variables
Use Datto RMM environment variables for script configuration:
```powershell
# Example: Using environment variables in your scripts
$CustomPath = $env:CustomPath
$EnableDebug = ($env:EnableDebug -eq "true")
$Threshold = if ($env:Threshold) { [int]$env:Threshold } else { 10 }
```

## Troubleshooting

### Common Issues
- **Script Errors**: Verify all functions are embedded, test locally first
- **Variable Issues**: Check variable names are exact (case-sensitive)
- **Performance**: Optimize functions, increase timeout if needed

### Log Locations
- Applications: `C:\ProgramData\DattoRMM\Applications\`
- Monitors: `C:\ProgramData\DattoRMM\Monitors\`
- Scripts: `C:\ProgramData\DattoRMM\Scripts\`

## Best Practices

- **Test locally** before deploying to RMM
- **Use Git branches** for development
- **Embed all functions** - ensure scripts are self-contained
- **Start with test devices** for gradual rollout
- **Monitor logs** for execution issues
- **Monitors**: Use direct deployment only (no launchers for optimal performance)
- **Follow diagnostic-first design** - show work before results

## Related Documentation

- [Function Reference](Function-Reference.md) - Copy/paste function patterns
- [Component Categories](Datto-RMM-Component-Categories.md) - RMM component types
- [File Attachment Guide](Datto-RMM-File-Attachment-Guide.md) - Using file attachments
- [Monitor Development Guidelines](Monitor-Development-Guidelines.md) - Expert monitor patterns
