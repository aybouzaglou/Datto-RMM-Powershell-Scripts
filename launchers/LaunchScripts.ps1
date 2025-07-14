<#
.SYNOPSIS
Scripts Component Launcher - Specialized launcher for Datto RMM Scripts components

.DESCRIPTION
Specialized launcher optimized for Datto RMM Scripts component category with:
- Extended timeout support for long-running operations
- General automation and maintenance focus
- System state validation before/after operations
- Detailed logging for audit trails
- Safe operation validation

.PARAMETER ScriptName
Name of the Scripts component script to execute

.PARAMETER GitHubRepo
GitHub repository (default: auto-detected)

.PARAMETER Branch
Git branch or tag to use

.PARAMETER TimeoutMinutes
Maximum execution time in minutes (default: 45)

.PARAMETER CreateSystemRestore
Create system restore point before execution

.EXAMPLE
# From Datto RMM Scripts component
.\LaunchScripts.ps1

# With environment variables set:
# ScriptName = "FocusedDebloat.ps1"
# Any script-specific parameters

.NOTES
Version: 3.0.0
Author: Datto RMM Function Library
Optimized for: Scripts Component (General Automation)
#>

param(
    [string]$ScriptName = $env:ScriptName,
    [string]$GitHubRepo = "aybouzaglou/Datto-RMM-Powershell-Scripts",
    [string]$Branch = "main",
    [int]$TimeoutMinutes = 45,
    [switch]$CreateSystemRestore
)

# Set script type for Scripts component
$env:ScriptType = "Scripts"

# Enhanced logging for Scripts components
$LogDir = "C:\ProgramData\DattoRMM\Scripts"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$transcriptPath = "$LogDir\Scripts-$ScriptName-$timestamp.log"
Start-Transcript -Path $transcriptPath -Force

try {
    Write-Output "=============================================="
    Write-Output "Datto RMM Scripts Launcher v3.0.0"
    Write-Output "=============================================="
    Write-Output "Script: $ScriptName"
    Write-Output "Timeout: $TimeoutMinutes minutes"
    Write-Output "System Restore: $CreateSystemRestore"
    Write-Output "Start Time: $(Get-Date)"
    Write-Output ""
    
    # Pre-execution system assessment
    Write-Output "=== Pre-Execution System Assessment ==="
    
    # Check system uptime
    try {
        $uptime = (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
        Write-Output "System uptime: $($uptime.Days) days, $($uptime.Hours) hours"
        
        if ($uptime.Days -gt 30) {
            Write-Warning "System has been running for over 30 days. Consider scheduling a reboot."
        }
    } catch {
        Write-Warning "Could not determine system uptime: $($_.Exception.Message)"
    }
    
    # Check available disk space
    try {
        $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        $totalSpaceGB = [math]::Round($disk.Size / 1GB, 2)
        $freePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
        
        Write-Output "Disk space: ${freeSpaceGB}GB free of ${totalSpaceGB}GB total (${freePercent}%)"
        
        if ($freePercent -lt 10) {
            Write-Warning "Low disk space detected. Script operations may help free up space."
        }
    } catch {
        Write-Warning "Could not check disk space: $($_.Exception.Message)"
    }
    
    # Create system restore point if requested
    if ($CreateSystemRestore) {
        Write-Output ""
        Write-Output "=== Creating System Restore Point ==="
        try {
            # Enable system restore if not enabled
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            
            # Create restore point
            $restorePoint = "Datto RMM Scripts - $ScriptName - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            Checkpoint-Computer -Description $restorePoint -RestorePointType "MODIFY_SETTINGS"
            Write-Output "✓ System restore point created: $restorePoint"
        } catch {
            Write-Warning "Failed to create system restore point: $($_.Exception.Message)"
            Write-Output "Continuing with script execution without restore point..."
        }
    }
    
    Write-Output ""
    Write-Output "System assessment complete. Ready for script execution."
    Write-Output ""
    
    # Call the universal launcher with Scripts-specific settings
    $launcherPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) "UniversalLauncher.ps1"
    
    if (-not (Test-Path $launcherPath)) {
        # Download universal launcher if not available
        $launcherURL = "https://raw.githubusercontent.com/$GitHubRepo/$Branch/launchers/UniversalLauncher.ps1"
        $tempLauncher = "$env:TEMP\UniversalLauncher.ps1"
        
        [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
        (New-Object System.Net.WebClient).DownloadFile($launcherURL, $tempLauncher)
        $launcherPath = $tempLauncher
    }
    
    # Execute with timeout protection
    Write-Output "=== Starting Script Execution ==="
    $job = Start-Job -ScriptBlock {
        param($LauncherPath, $ScriptName, $GitHubRepo, $Branch)
        & $LauncherPath -ScriptName $ScriptName -ScriptType "Scripts" -GitHubRepo $GitHubRepo -Branch $Branch
    } -ArgumentList $launcherPath, $ScriptName, $GitHubRepo, $Branch
    
    $timeoutSeconds = $TimeoutMinutes * 60
    if (Wait-Job $job -Timeout $timeoutSeconds) {
        $result = Receive-Job $job
        $exitCode = $job.State -eq "Completed" ? 0 : 1
        Remove-Job $job -Force
        
        Write-Output $result
    } else {
        Write-Warning "Script execution timed out after $TimeoutMinutes minutes"
        Stop-Job $job -Force
        Remove-Job $job -Force
        $exitCode = 11  # Timeout error
    }
    
    # Post-execution assessment
    Write-Output ""
    Write-Output "=== Post-Execution Assessment ==="
    
    # Check disk space improvement
    try {
        $diskAfter = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        $freeSpaceAfterGB = [math]::Round($diskAfter.FreeSpace / 1GB, 2)
        $freePercentAfter = [math]::Round(($diskAfter.FreeSpace / $diskAfter.Size) * 100, 1)
        
        Write-Output "Disk space after execution: ${freeSpaceAfterGB}GB free (${freePercentAfter}%)"
        
        if ($freeSpaceAfterGB -gt $freeSpaceGB) {
            $spaceFreed = $freeSpaceAfterGB - $freeSpaceGB
            Write-Output "✓ Freed up ${spaceFreed}GB of disk space"
        }
    } catch {
        Write-Warning "Could not check post-execution disk space"
    }
    
    Write-Output ""
    Write-Output "=== Scripts Component Summary ==="
    Write-Output "Completion Time: $(Get-Date)"
    Write-Output "Exit Code: $exitCode"
    Write-Output "Component Category: Scripts"
    
    # Interpret exit codes for Scripts category
    switch ($exitCode) {
        0 { 
            Write-Output "Status: SUCCESS - Script completed successfully"
        }
        1 {
            Write-Output "Status: SUCCESS WITH WARNINGS - Script completed with warnings"
        }
        2 {
            Write-Output "Status: ERROR - Script encountered errors"
        }
        10 {
            Write-Output "Status: PERMISSION ERROR - Insufficient permissions"
        }
        11 {
            Write-Output "Status: TIMEOUT - Script exceeded time limit"
        }
        default { 
            Write-Output "Status: UNKNOWN - Script failed with exit code $exitCode"
        }
    }
    
    exit $exitCode
    
} catch {
    Write-Error "Scripts launcher failed: $($_.Exception.Message)"
    Write-Error "Line: $($_.InvocationInfo.ScriptLineNumber)"
    
    Write-Output ""
    Write-Output "Scripts Component Troubleshooting:"
    Write-Output "- Verify the script name is correct: $ScriptName"
    Write-Output "- Check if operations require specific permissions"
    Write-Output "- Ensure sufficient disk space for operations"
    Write-Output "- Review the full log: $transcriptPath"
    
    exit 2
} finally {
    Stop-Transcript
}
