<#
.SYNOPSIS
Universal Datto RMM Script Launcher - Downloads and executes scripts from GitHub

.DESCRIPTION
Universal launcher that downloads and executes Datto RMM scripts from GitHub with:
- Automatic shared function library loading
- Script type detection and validation
- Environment variable passthrough
- Comprehensive error handling and logging
- Offline fallback capabilities
- Version pinning support

.PARAMETER ScriptName
Name of the script file to download and execute (required)

.PARAMETER ScriptType
Datto RMM component category: Applications, Monitors, Scripts (required)

.PARAMETER GitHubRepo
GitHub repository in format "owner/repo"

.PARAMETER Branch
Git branch or tag to use

.PARAMETER ForceDownload
Force re-download even if cached

.PARAMETER OfflineMode
Use only cached files

.EXAMPLE
# Basic usage with Datto RMM environment variables
.\UniversalLauncher.ps1 -ScriptName "ScanSnapHome.ps1" -ScriptType "Applications"

# With specific repository and version
.\UniversalLauncher.ps1 -ScriptName "DiskSpaceMonitor.ps1" -ScriptType "Monitors" -GitHubRepo "myorg/scripts" -Branch "v2.0"

.NOTES
Version: 3.0.0
Author: Datto RMM Function Library
Compatible: PowerShell 2.0+, Datto RMM Environment
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ScriptName = $env:ScriptName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Applications','Monitors','Scripts')]
    [string]$ScriptType = $env:ScriptType,
    
    [string]$GitHubRepo = "aybouzaglou/Datto-RMM-Powershell-Scripts",
    [string]$Branch = "main",
    [switch]$ForceDownload,
    [switch]$OfflineMode
)

# Configuration
$BaseURL = "https://raw.githubusercontent.com/$GitHubRepo/$Branch"
$WorkingDir = "$env:TEMP\RMM-Execution"
$LogDir = "C:\ProgramData\DattoRMM"

# Ensure directories exist
@($WorkingDir, $LogDir) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -Path $_ -ItemType Directory -Force | Out-Null
    }
}

# Start transcript with unique name
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$transcriptPath = "$LogDir\UniversalLauncher-$timestamp.log"
Start-Transcript -Path $transcriptPath -Force

try {
    Write-Output "=============================================="
    Write-Output "Datto RMM Universal Launcher v3.0.0"
    Write-Output "=============================================="
    Write-Output "Timestamp: $(Get-Date)"
    Write-Output "Repository: $GitHubRepo"
    Write-Output "Branch: $Branch"
    Write-Output "Working Directory: $WorkingDir"
    Write-Output "Log Directory: $LogDir"
    Write-Output ""
    
    # Pre-flight validation
    if ([string]::IsNullOrWhiteSpace($ScriptName)) {
        Write-Error "FATAL: ScriptName parameter is required (set via parameter or env:ScriptName)"
        Write-Output "Available environment variables:"
        Get-ChildItem env: | Where-Object { $_.Name -like "*Script*" } | ForEach-Object {
            Write-Output "  $($_.Name) = $($_.Value)"
        }
        exit 12
    }
    
    if ([string]::IsNullOrWhiteSpace($ScriptType)) {
        Write-Error "FATAL: ScriptType parameter is required (set via parameter or env:ScriptType)"
        Write-Output "Valid values: Applications, Monitors, Scripts"
        exit 12
    }
    
    Write-Output "Configuration:"
    Write-Output "- Script Name: $ScriptName"
    Write-Output "- Script Type: $ScriptType"
    Write-Output "- Force Download: $ForceDownload"
    Write-Output "- Offline Mode: $OfflineMode"
    Write-Output ""
    
    # Display Datto RMM environment variables
    Write-Output "Datto RMM Environment Variables:"
    $rmmVars = Get-ChildItem env: | Where-Object { 
        $_.Name -notlike "TEMP*" -and 
        $_.Name -notlike "TMP*" -and 
        $_.Name -notlike "PATH*" -and
        $_.Name -notlike "PROCESSOR*" -and
        $_.Name -notlike "PROGRAM*" -and
        $_.Name -notlike "SYSTEM*" -and
        $_.Name -notlike "USER*" -and
        $_.Name -notlike "WINDOWS*" -and
        $_.Name -notlike "COMPUTER*" -and
        $_.Name -notlike "LOGON*" -and
        $_.Name -notlike "SESSION*" -and
        $_.Name -notlike "APPDATA*" -and
        $_.Name -notlike "COMMON*" -and
        $_.Name -notlike "DRIVER*" -and
        $_.Name -notlike "FP_*" -and
        $_.Name -notlike "HOME*" -and
        $_.Name -notlike "LOCAL*" -and
        $_.Name -notlike "NUMBER_OF_*" -and
        $_.Name -notlike "OS*" -and
        $_.Name -notlike "PS*" -and
        $_.Name -notlike "PUBLIC*" -and
        $_.Name -notlike "WINDIR*"
    } | Sort-Object Name
    
    if ($rmmVars) {
        foreach ($var in $rmmVars) {
            Write-Output "  $($var.Name) = $($var.Value)"
        }
    } else {
        Write-Output "  (No custom environment variables detected)"
    }
    Write-Output ""
    
    # Set TLS 1.2 for secure downloads
    if (-not $OfflineMode) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
            Write-Output "TLS 1.2 security protocol enabled"
        } catch {
            Write-Warning "Failed to set TLS 1.2: $($_.Exception.Message)"
        }
    }
    
    # Step 1: Download and load shared functions
    Write-Output "=== Loading Shared Functions ==="
    $functionsURL = "$BaseURL/shared-functions/SharedFunctions.ps1"
    $functionsPath = Join-Path $WorkingDir "SharedFunctions.ps1"
    
    if (-not $OfflineMode) {
        try {
            Write-Output "Downloading shared functions from: $functionsURL"
            (New-Object System.Net.WebClient).DownloadFile($functionsURL, $functionsPath)
            Write-Output "✓ Shared functions downloaded successfully"
        } catch {
            Write-Warning "Could not download shared functions: $($_.Exception.Message)"
            Write-Output "Checking for cached version..."
        }
    }
    
    # Load shared functions (downloaded or cached)
    if (Test-Path $functionsPath) {
        try {
            . $functionsPath -GitHubRepo $GitHubRepo -Branch $Branch -ForceDownload:$ForceDownload -OfflineMode:$OfflineMode
            Write-Output "✓ Shared functions loaded successfully"
        } catch {
            Write-Warning "Failed to load shared functions: $($_.Exception.Message)"
            Write-Output "Continuing without shared functions..."
        }
    } else {
        Write-Warning "Shared functions not available. Some features may be limited."
    }
    
    # Step 2: Download target script
    Write-Output ""
    Write-Output "=== Downloading Target Script ==="
    $scriptURL = "$BaseURL/components/$ScriptType/$ScriptName"
    $scriptPath = Join-Path $WorkingDir $ScriptName
    
    if (-not $OfflineMode) {
        try {
            Write-Output "Downloading script from: $scriptURL"
            (New-Object System.Net.WebClient).DownloadFile($scriptURL, $scriptPath)
            Write-Output "✓ Downloaded script: $ScriptName"
            
            # Verify download
            $fileSize = (Get-Item $scriptPath).Length
            Write-Output "File size: $fileSize bytes"
            
            # Basic PowerShell script validation
            if ($ScriptName -like "*.ps1") {
                $firstLine = Get-Content $scriptPath -TotalCount 1 -ErrorAction SilentlyContinue
                if ($firstLine -and ($firstLine -like "*#*" -or $firstLine -like "*<#*")) {
                    Write-Output "✓ PowerShell script validation passed"
                } else {
                    Write-Warning "Downloaded file may not be a valid PowerShell script"
                }
            }
        } catch {
            Write-Error "Failed to download script from $scriptURL"
            Write-Error "Error: $($_.Exception.Message)"
            
            # Check for cached version
            if (Test-Path $scriptPath) {
                Write-Output "Using cached version of script"
            } else {
                exit 11
            }
        }
    } else {
        if (-not (Test-Path $scriptPath)) {
            Write-Error "Script not available in offline mode: $ScriptName"
            exit 11
        }
        Write-Output "Using cached script: $ScriptName"
    }
    
    # Step 3: Execute the script
    Write-Output ""
    Write-Output "=== Executing Script ==="
    Write-Output "Script: $ScriptName"
    Write-Output "Type: $ScriptType"
    Write-Output "Source: $scriptURL"
    Write-Output "Working Directory: $WorkingDir"
    Write-Output "Execution Time: $(Get-Date)"
    Write-Output ""
    Write-Output "=============================================="
    
    # Change to working directory and execute
    Push-Location $WorkingDir
    try {
        # Execute the script and capture exit code
        & $scriptPath
        $exitCode = $LASTEXITCODE
        
        Write-Output ""
        Write-Output "=============================================="
        Write-Output "Script execution completed"
        Write-Output "Exit code: $exitCode"
        Write-Output "Completion time: $(Get-Date)"
        
        # Interpret exit codes based on script type
        if ($ScriptType -eq "monitors") {
            # Monitor scripts: 0 = OK, any non-zero = Alert
            if ($exitCode -eq 0 -or $null -eq $exitCode) {
                Write-Output "Monitor status: OK"
            } else {
                Write-Output "Monitor status: ALERT (Exit code: $exitCode)"
            }
        } else {
            # Installation/Maintenance scripts: 0 = Success, 3010/1641 = Reboot required, other = Failed
            switch ($exitCode) {
                0 { Write-Output "Status: SUCCESS" }
                3010 { Write-Output "Status: SUCCESS (Reboot required)" }
                1641 { Write-Output "Status: SUCCESS (Reboot initiated)" }
                $null { Write-Output "Status: SUCCESS (No exit code)" }
                default { Write-Output "Status: FAILED (Exit code: $exitCode)" }
            }
        }
        
        exit $exitCode
    } finally {
        Pop-Location
    }
    
} catch {
    Write-Error "Launcher failed: $($_.Exception.Message)"
    Write-Error "Line: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Error "Position: $($_.InvocationInfo.PositionMessage)"
    
    # Provide troubleshooting information
    Write-Output ""
    Write-Output "Troubleshooting Information:"
    Write-Output "- Check internet connectivity (if not using offline mode)"
    Write-Output "- Verify GitHub repository is accessible: https://github.com/$GitHubRepo"
    Write-Output "- Ensure script exists in repository: components/$ScriptType/$ScriptName"
    Write-Output "- Check PowerShell execution policy"
    Write-Output "- Verify antivirus is not blocking downloads"
    Write-Output "- Review transcript log: $transcriptPath"
    
    exit 1
} finally {
    Write-Output ""
    Write-Output "Launcher execution completed at: $(Get-Date)"
    Write-Output "Transcript log saved to: $transcriptPath"
    Stop-Transcript
}
