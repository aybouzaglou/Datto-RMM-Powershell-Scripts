<#
.SYNOPSIS
Hard-Coded Launcher for Tungsten Printix Client Installation

.DESCRIPTION
Hard-coded launcher that downloads and executes TungstenPrintixClient.ps1 from GitHub with:
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
# Deploy as Datto RMM Applications component
# Ensure MSI file is available in one of the search locations

.NOTES
Version: 1.0.0
Author: Datto RMM Function Library
Compatible: PowerShell 2.0+, Datto RMM Environment
Script: TungstenPrintixClient.ps1 (Tungsten Printix Client Installation)
#>

param(
    [string]$GitHubRepo = "aybouzaglou/Datto-RMM-Powershell-Scripts",
    [string]$Branch = "main",
    [switch]$ForceDownload,
    [switch]$OfflineMode
)

# ===== HARD-CODED SCRIPT CONFIGURATION =====
$SCRIPT_PATH = "components/Applications/TungstenPrintixClient.ps1"
$SCRIPT_TYPE = "Applications"
$SCRIPT_DISPLAY_NAME = "Tungsten Printix Client Installation"
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
$transcriptPath = "$LogDir\TungstenPrintixClient-Launcher-$timestamp.log"
Start-Transcript -Path $transcriptPath -Force

try {
    Write-Output "=============================================="
    Write-Output "Tungsten Printix Client Launcher v1.0.0"
    Write-Output "=============================================="
    Write-Output "Repository: $GitHubRepo"
    Write-Output "Branch: $Branch"
    Write-Output "Script: $SCRIPT_PATH"
    Write-Output "Script Type: $SCRIPT_TYPE"
    Write-Output "Working Directory: $WorkingDir"
    Write-Output "Start Time: $(Get-Date)"
    Write-Output ""
    
    # Environment variable passthrough information
    Write-Output "Environment Variables (passed to script):"
    Get-ChildItem env: | Where-Object { $_.Name -notlike "PS*" -and $_.Name -notlike "PROCESSOR*" -and $_.Name -notlike "PROGRAM*" } | 
        Sort-Object Name | ForEach-Object {
            if ($_.Value.Length -gt 100) {
                Write-Output "  $($_.Name) = $($_.Value.Substring(0,97))..."
            } else {
                Write-Output "  $($_.Name) = $($_.Value)"
            }
        }
    Write-Output ""
    
    # Construct script URL and local path
    $scriptURL = "$BaseURL/$SCRIPT_PATH"
    $scriptFileName = Split-Path $SCRIPT_PATH -Leaf
    $scriptPath = Join-Path $WorkingDir $scriptFileName
    
    Write-Output "Script URL: $scriptURL"
    Write-Output "Local Path: $scriptPath"
    Write-Output ""
    
    # Download logic with caching and offline support
    $shouldDownload = $true
    
    if ($OfflineMode) {
        Write-Output "Offline mode enabled - using cached script only"
        $shouldDownload = $false
        
        if (-not (Test-Path $scriptPath)) {
            throw "Offline mode enabled but cached script not found: $scriptPath"
        }
    } elseif ((Test-Path $scriptPath) -and -not $ForceDownload) {
        $fileAge = (Get-Date) - (Get-Item $scriptPath).LastWriteTime
        if ($fileAge.TotalMinutes -lt 60) {
            Write-Output "Using cached script (less than 1 hour old)"
            $shouldDownload = $false
        } else {
            Write-Output "Cached script is older than 1 hour - will re-download"
        }
    }
    
    if ($shouldDownload) {
        Write-Output "Downloading script from GitHub..."
        
        try {
            # Set TLS 1.2 for compatibility
            [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
            
            # Download with timeout
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "Datto-RMM-PowerShell-Launcher/1.0")
            $webClient.DownloadFile($scriptURL, $scriptPath)
            $webClient.Dispose()
            
            Write-Output "✅ Script downloaded successfully"
            
            # Verify download
            if (-not (Test-Path $scriptPath)) {
                throw "Downloaded script file not found after download"
            }
            
            $scriptSize = (Get-Item $scriptPath).Length
            if ($scriptSize -lt 100) {
                throw "Downloaded script appears to be too small ($scriptSize bytes) - possible download error"
            }
            
            Write-Output "Script size: $scriptSize bytes"
            
        } catch {
            Write-Error "Failed to download script: $($_.Exception.Message)"
            
            # Try to use cached version as fallback
            if (Test-Path $scriptPath) {
                Write-Output "⚠️  Using cached version as fallback"
            } else {
                throw "No cached version available and download failed"
            }
        }
    }
    
    # Verify script exists and is readable
    if (-not (Test-Path $scriptPath)) {
        throw "Script file not found: $scriptPath"
    }
    
    # Basic script validation
    try {
        $scriptContent = Get-Content $scriptPath -Raw -ErrorAction Stop
        if ($scriptContent.Length -lt 100) {
            throw "Script content appears to be too small - possible corruption"
        }
        Write-Output "✅ Script validation passed"
    } catch {
        throw "Script validation failed: $($_.Exception.Message)"
    }
    
    Write-Output ""
    Write-Output "=============================================="
    Write-Output "Executing Tungsten Printix Client Installation"
    Write-Output "=============================================="
    Write-Output ""
    
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
