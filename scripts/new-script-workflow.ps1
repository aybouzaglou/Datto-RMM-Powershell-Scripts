#!/usr/bin/env pwsh
<#
.SYNOPSIS
    🚀 Bulletproof Script Development Workflow Helper

.DESCRIPTION
    This script helps you follow the safe development workflow for Datto RMM PowerShell scripts.
    It creates feature branches, validates scripts, and guides you through the process.

.PARAMETER ScriptName
    Name of the new script you're creating

.PARAMETER ScriptType
    Type of script: Application, Monitor, Script, SharedFunction, or Launcher

.PARAMETER Action
    Action to perform: new, fix, enhance, or hotfix

.EXAMPLE
    .\new-script-workflow.ps1 -ScriptName "Office-Debloater" -ScriptType "Application" -Action "new"
    
.EXAMPLE
    .\new-script-workflow.ps1 -ScriptName "Disk-Monitor" -ScriptType "Monitor" -Action "fix"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptName,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("Application", "Monitor", "Script", "SharedFunction", "Launcher")]
    [string]$ScriptType,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("new", "fix", "enhance", "hotfix")]
    [string]$Action
)

# Color functions for better output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

Write-Host "🚀 === BULLETPROOF SCRIPT DEVELOPMENT WORKFLOW ===" -ForegroundColor Magenta
Write-Host ""

# Determine branch name and directory
$branchPrefix = switch ($Action) {
    "new" { "feature" }
    "fix" { "script" }
    "enhance" { "enhancement" }
    "hotfix" { "hotfix" }
}

$branchName = "$branchPrefix/$($ScriptName.ToLower().Replace(' ', '-').Replace('_', '-'))"
$scriptDir = switch ($ScriptType) {
    "Application" { "components/Applications" }
    "Monitor" { "components/Monitors" }
    "Script" { "components/Scripts" }
    "SharedFunction" { "shared-functions" }
    "Launcher" { "launchers" }
}

Write-Info "Script: $ScriptName"
Write-Info "Type: $ScriptType"
Write-Info "Action: $Action"
Write-Info "Branch: $branchName"
Write-Info "Directory: $scriptDir"
Write-Host ""

# Check if we're in a git repository
if (-not (Test-Path ".git")) {
    Write-Error "Not in a git repository! Please run this from the repository root."
    exit 1
}

# Check current branch
$currentBranch = git branch --show-current
Write-Info "Current branch: $currentBranch"

# Create and switch to feature branch
Write-Info "Creating and switching to branch: $branchName"
try {
    git checkout -b $branchName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Created new branch: $branchName"
    } else {
        # Branch might already exist, try to switch to it
        git checkout $branchName
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Switched to existing branch: $branchName"
        } else {
            Write-Error "Failed to create or switch to branch: $branchName"
            exit 1
        }
    }
} catch {
    Write-Error "Git operation failed: $($_.Exception.Message)"
    exit 1
}

# Create directory if it doesn't exist
if (-not (Test-Path $scriptDir)) {
    New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
    Write-Success "Created directory: $scriptDir"
}

# Create script file
$scriptFileName = "$ScriptName.ps1"
$scriptPath = Join-Path $scriptDir $scriptFileName

if (Test-Path $scriptPath) {
    Write-Warning "Script file already exists: $scriptPath"
    $overwrite = Read-Host "Overwrite existing file? (y/N)"
    if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
        Write-Info "Keeping existing file. You can edit it manually."
    } else {
        Remove-Item $scriptPath -Force
        Write-Info "Removed existing file."
    }
}

if (-not (Test-Path $scriptPath)) {
    # Create script template based on type
    $template = switch ($ScriptType) {
        "Monitor" {
@"
<#
.SYNOPSIS
    $ScriptName - Datto RMM Monitor Script

.DESCRIPTION
    Monitor script for Datto RMM that checks system status.
    Must complete in under 3 seconds and use proper exit codes.

.NOTES
    Component Type: Monitor (Custom Monitor)
    Timeout: 3 seconds maximum
    Exit Codes: 0 = OK, 30 = Warning, 31 = Critical
#>

try {
    # Your monitoring logic here
    `$status = "OK"
    `$message = "System is healthy"
    
    # Example check
    `$freeSpace = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" | 
                  Where-Object { `$_.DeviceID -eq "C:" } | 
                  Select-Object -ExpandProperty FreeSpace
    
    if (`$freeSpace -lt 1GB) {
        `$status = "CRITICAL"
        `$message = "Low disk space: `$([math]::Round(`$freeSpace/1GB, 2)) GB free"
        `$exitCode = 31
    } elseif (`$freeSpace -lt 5GB) {
        `$status = "WARNING" 
        `$message = "Disk space getting low: `$([math]::Round(`$freeSpace/1GB, 2)) GB free"
        `$exitCode = 30
    } else {
        `$status = "OK"
        `$message = "Disk space OK: `$([math]::Round(`$freeSpace/1GB, 2)) GB free"
        `$exitCode = 0
    }
    
    # Required result markers for Custom Monitor
    Write-Host "<-Start Result->"
    Write-Host "`$status`: `$message"
    Write-Host "<-End Result->"
    
    exit `$exitCode
    
} catch {
    Write-Host "<-Start Result->"
    Write-Host "CRITICAL: Monitor script error - `$(`$_.Exception.Message)"
    Write-Host "<-End Result->"
    exit 31
}
"@
        }
        "Application" {
@"
<#
.SYNOPSIS
    $ScriptName - Datto RMM Application Script

.DESCRIPTION
    Application deployment/management script for Datto RMM.
    Can run up to 30 minutes with changeable component category.

.NOTES
    Component Type: Application
    Timeout: Up to 30 minutes
    Exit Codes: 0 = Success, 3010/1641 = Reboot Required, Other = Failed
#>

try {
    Write-Output "Starting $ScriptName..."
    
    # Your application logic here
    
    Write-Output "✅ $ScriptName completed successfully"
    exit 0
    
} catch {
    Write-Output "❌ $ScriptName failed: `$(`$_.Exception.Message)"
    exit 1
}
"@
        }
        "Script" {
@"
<#
.SYNOPSIS
    $ScriptName - Datto RMM General Script

.DESCRIPTION
    General automation script for Datto RMM.
    Flexible timeout with changeable component category.

.NOTES
    Component Type: Script
    Timeout: Configurable
    Exit Codes: 0 = Success, Other = Failed
#>

try {
    Write-Output "Starting $ScriptName..."
    
    # Your script logic here
    
    Write-Output "✅ $ScriptName completed successfully"
    exit 0
    
} catch {
    Write-Output "❌ $ScriptName failed: `$(`$_.Exception.Message)"
    exit 1
}
"@
        }
        "SharedFunction" {
@"
<#
.SYNOPSIS
    $ScriptName - Shared Function Library

.DESCRIPTION
    Reusable functions for Datto RMM scripts.
    Downloaded automatically by scripts using GitHub integration.

.NOTES
    Type: Shared Function Library
    Usage: Dot-source this file in other scripts
#>

function Get-$($ScriptName.Replace('-', ''))Info {
    <#
    .SYNOPSIS
        Example function in $ScriptName library
    
    .DESCRIPTION
        Describe what this function does
    
    .EXAMPLE
        Get-$($ScriptName.Replace('-', ''))Info
    #>
    
    return @{
        Name = "$ScriptName"
        Version = "1.0.0"
        Description = "Shared function library"
    }
}

# Export functions if running as module
if (`$MyInvocation.InvocationName -ne '.') {
    Export-ModuleMember -Function Get-$($ScriptName.Replace('-', ''))Info
}
"@
        }
        "Launcher" {
@"
<#
.SYNOPSIS
    $ScriptName - Universal Launcher

.DESCRIPTION
    Universal launcher for executing scripts from GitHub repository.
    Uses environment variables for configuration.

.NOTES
    Component Type: Script (Universal Launcher)
    Environment Variables:
    - GitHubRepo: Repository path (e.g., "user/repo")
    - ScriptPath: Path to script in repo (e.g., "components/Scripts/MyScript.ps1")
    - CacheTimeout: Cache timeout in seconds (default: 3600)
#>

param(
    [string]`$GitHubRepo = `$env:GitHubRepo,
    [string]`$ScriptPath = `$env:ScriptPath,
    [int]`$CacheTimeout = [int](`$env:CacheTimeout ?? 3600)
)

try {
    if (-not `$GitHubRepo -or -not `$ScriptPath) {
        throw "GitHubRepo and ScriptPath environment variables are required"
    }
    
    Write-Output "🚀 $ScriptName Universal Launcher"
    Write-Output "Repository: `$GitHubRepo"
    Write-Output "Script: `$ScriptPath"
    
    # Download and execute script logic here
    # (Implement your GitHub download and caching logic)
    
    Write-Output "✅ Script execution completed"
    exit 0
    
} catch {
    Write-Output "❌ Launcher failed: `$(`$_.Exception.Message)"
    exit 1
}
"@
        }
    }
    
    $template | Out-File -FilePath $scriptPath -Encoding UTF8
    Write-Success "Created script template: $scriptPath"
}

Write-Host ""
Write-Host "🎯 === NEXT STEPS ===" -ForegroundColor Magenta
Write-Host ""
Write-Success "1. Edit your script: $scriptPath"
Write-Success "2. Test locally (optional but recommended)"
Write-Success "3. Commit and push:"
Write-Host "   git add ." -ForegroundColor Gray
Write-Host "   git commit -m 'Add $ScriptName for Datto RMM'" -ForegroundColor Gray
Write-Host "   git push origin $branchName" -ForegroundColor Gray
Write-Success "4. Auto-PR will be created and validated"
Write-Success "5. Gemini will review your code"
Write-Success "6. Merge when ready and deploy to Datto RMM!"
Write-Host ""
Write-Info "📖 See docs/DEVELOPER-WORKFLOW.md for complete guide"
Write-Host ""
Write-Host "🎉 Happy coding! You're now bulletproof! 🛡️" -ForegroundColor Green
