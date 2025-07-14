<#
.SYNOPSIS
Monitor Script Launcher - Specialized launcher for Datto RMM monitor scripts

.DESCRIPTION
Specialized launcher optimized for monitor scripts with:
- Fast execution (3-second timeout)
- Monitor result markers for Custom Monitor components
- Status interpretation (OK/WARNING/CRITICAL)
- Minimal logging for performance
- Error handling with proper exit codes

.PARAMETER ScriptName
Name of the monitor script to execute

.PARAMETER GitHubRepo
GitHub repository (default: auto-detected)

.PARAMETER Branch
Git branch or tag to use

.EXAMPLE
# From Datto RMM Custom Monitor component
.\LaunchMonitor.ps1

# With environment variables set:
# ScriptName = "MonitorDiskSpace.ps1"
# Any monitor-specific thresholds or parameters

.NOTES
Version: 3.0.0
Author: Datto RMM Function Library
Optimized for: Monitor Scripts (Custom Monitor component)
Exit Codes: 0 = OK/Green, Any non-zero = Alert state
#>

param(
    [string]$ScriptName = $env:ScriptName,
    [string]$GitHubRepo = "aybouzaglou/Datto-RMM-Powershell-Scripts",
    [string]$Branch = "main"
)

# Set script type for monitors
$env:ScriptType = "monitors"

# Minimal logging for monitors (performance critical)
$LogDir = "C:\ProgramData\DattoRMM\Monitors"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

try {
    # Fast validation
    if ([string]::IsNullOrWhiteSpace($ScriptName)) {
        Write-Host "<-Start Result->"
        Write-Host "CRITICAL: ScriptName parameter is required"
        Write-Host "<-End Result->"
        exit 1
    }
    
    # Set TLS 1.2 for downloads
    [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
    
    # Download and execute with 3-second timeout
    $WorkingDir = "$env:TEMP\RMM-Monitor"
    if (-not (Test-Path $WorkingDir)) {
        New-Item -Path $WorkingDir -ItemType Directory -Force | Out-Null
    }
    
    # Download shared functions (minimal, cached version preferred)
    $functionsURL = "https://raw.githubusercontent.com/$GitHubRepo/$Branch/shared-functions/SharedFunctions.ps1"
    $functionsPath = Join-Path $WorkingDir "SharedFunctions.ps1"
    
    # Try to use cached version first for speed
    if (-not (Test-Path $functionsPath)) {
        try {
            (New-Object System.Net.WebClient).DownloadFile($functionsURL, $functionsPath)
        } catch {
            # Continue without shared functions for monitors (performance critical)
        }
    }
    
    # Load shared functions if available
    if (Test-Path $functionsPath) {
        try {
            . $functionsPath -GitHubRepo $GitHubRepo -Branch $Branch -OfflineMode
        } catch {
            # Continue without shared functions
        }
    }
    
    # Download monitor script
    $scriptURL = "https://raw.githubusercontent.com/$GitHubRepo/$Branch/components/monitors/$ScriptName"
    $scriptPath = Join-Path $WorkingDir $ScriptName
    
    try {
        (New-Object System.Net.WebClient).DownloadFile($scriptURL, $scriptPath)
    } catch {
        if (-not (Test-Path $scriptPath)) {
            Write-Host "<-Start Result->"
            Write-Host "CRITICAL: Failed to download monitor script: $ScriptName"
            Write-Host "<-End Result->"
            exit 1
        }
    }
    
    # Execute monitor with timeout protection
    Push-Location $WorkingDir
    try {
        # Create a job to run the monitor with timeout
        $job = Start-Job -ScriptBlock {
            param($ScriptPath)
            & $ScriptPath
        } -ArgumentList $scriptPath
        
        # Wait for completion with 3-second timeout
        if (Wait-Job $job -Timeout 3) {
            $output = Receive-Job $job
            $exitCode = if ($job.State -eq "Completed") { 0 } else { 1 }
            Remove-Job $job -Force
            
            # Output the monitor results
            Write-Output $output
            exit $exitCode
        } else {
            # Timeout occurred
            Stop-Job $job -Force
            Remove-Job $job -Force
            
            Write-Host "<-Start Result->"
            Write-Host "CRITICAL: Monitor script timed out (>3 seconds)"
            Write-Host "<-End Result->"
            exit 1
        }
    } finally {
        Pop-Location
    }
    
} catch {
    # Critical error in monitor launcher
    Write-Host "<-Start Result->"
    Write-Host "CRITICAL: Monitor launcher failed: $($_.Exception.Message)"
    Write-Host "<-End Result->"
    exit 1
}

# If we reach here, something went wrong
Write-Host "<-Start Result->"
Write-Host "CRITICAL: Monitor execution completed unexpectedly"
Write-Host "<-End Result->"
exit 1
