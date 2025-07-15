<#
.SYNOPSIS
Hard-Coded Launcher for Setup Test Device Script

.DESCRIPTION
Hard-coded launcher that downloads and executes Setup-TestDevice.ps1 from GitHub with:
- Hard-coded script path (no environment variable consumption for script selection)
- All environment variables passed through to the underlying script
- Comprehensive error handling and logging
- Offline fallback capabilities

.PARAMETER GitHubRepo
GitHub repository in format "owner/repo"

.PARAMETER Branch
Git branch or tag to use

.PARAMETER ForceDownload
Force re-download even if cached

.PARAMETER OfflineMode
Use only cached files

.EXAMPLE
# Deploy as Datto RMM Scripts component
# Environment variables like TestResultsPath, CleanupOldResults will be passed to Setup-TestDevice.ps1

.NOTES
Version: 4.0.0
Author: Datto RMM Function Library
Compatible: PowerShell 2.0+, Datto RMM Environment
Script: Setup-TestDevice.ps1 (Test Environment Setup)
#>

param(
    [string]$GitHubRepo = "aybouzaglou/Datto-RMM-Powershell-Scripts",
    [string]$Branch = "main",
    [switch]$ForceDownload,
    [switch]$OfflineMode
)

# ===== HARD-CODED SCRIPT CONFIGURATION =====
$SCRIPT_PATH = "components/Scripts/Setup-TestDevice.ps1"
$SCRIPT_TYPE = "Scripts"
$SCRIPT_DISPLAY_NAME = "Setup Test Device Environment"
# ============================================

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
$transcriptPath = "$LogDir\Setup-TestDevice-Launcher-$timestamp.log"
Start-Transcript -Path $transcriptPath -Force

try {
    Write-Output "=============================================="
    Write-Output "Datto RMM Hard-Coded Launcher v4.0.0"
    Write-Output "=============================================="
    Write-Output "Timestamp: $(Get-Date)"
    Write-Output "Repository: $GitHubRepo"
    Write-Output "Branch: $Branch"
    Write-Output "Working Directory: $WorkingDir"
    Write-Output "Log Directory: $LogDir"
    Write-Output ""
    
    # Extract script name from path for display and file operations
    $ScriptName = Split-Path $SCRIPT_PATH -Leaf
    
    Write-Output "Hard-Coded Script Configuration:"
    Write-Output "- Display Name: $SCRIPT_DISPLAY_NAME"
    Write-Output "- Script Name: $ScriptName"
    Write-Output "- Script Path: $SCRIPT_PATH"
    Write-Output "- Script Type: $SCRIPT_TYPE"
    Write-Output "- Force Download: $ForceDownload"
    Write-Output "- Offline Mode: $OfflineMode"
    Write-Output ""
    
    # Display Datto RMM environment variables (all will be passed to script)
    Write-Output "Environment Variables (passed to script):"
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
    
    # Step 1: Note about embedded functions
    Write-Output "=== Note: Scripts now use embedded functions (no shared function loading) ==="
    Write-Output "✓ Modern scripts are self-contained for maximum reliability"
    
    # Step 2: Download target script
    Write-Output ""
    Write-Output "=== Downloading Target Script ==="
    $scriptURL = "$BaseURL/$SCRIPT_PATH"
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
    Write-Output "Display Name: $SCRIPT_DISPLAY_NAME"
    Write-Output "Script: $ScriptName"
    Write-Output "Type: $SCRIPT_TYPE"
    Write-Output "Source: $scriptURL"
    Write-Output "Working Directory: $WorkingDir"
    Write-Output "Execution Time: $(Get-Date)"
    Write-Output ""
    Write-Output "All environment variables will be passed to the script:"
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
        Write-Output "=============================================="
        
        exit $exitCode
    } finally {
        Pop-Location
    }
    
} catch {
    Write-Error "Launcher failed: $($_.Exception.Message)"
    Write-Error "Line: $($_.InvocationInfo.ScriptLineNumber)"
    exit 2
} finally {
    Stop-Transcript
}
