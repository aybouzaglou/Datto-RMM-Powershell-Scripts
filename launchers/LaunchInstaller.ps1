<#
.SYNOPSIS
Applications Component Launcher - Specialized launcher for Datto RMM Applications components

.DESCRIPTION
Specialized launcher optimized for Datto RMM Applications component category with:
- Extended timeout support (up to 30 minutes)
- Software deployment and installation focus
- Reboot handling (exit codes 3010/1641)
- Pre-installation system checks
- Post-installation verification

.PARAMETER ScriptName
Name of the Applications component script to execute

.PARAMETER GitHubRepo
GitHub repository (default: auto-detected)

.PARAMETER Branch
Git branch or tag to use

.PARAMETER TimeoutMinutes
Maximum execution time in minutes (default: 30)

.EXAMPLE
# From Datto RMM Applications component
.\LaunchInstaller.ps1

# With environment variables set:
# ScriptName = "ScanSnapHome.ps1"
# Any other application-specific variables

.NOTES
Version: 3.0.0
Author: Datto RMM Function Library
Optimized for: Applications Component (Software Deployment)
#>

param(
    [string]$ScriptName = $env:ScriptName,
    [string]$GitHubRepo = "aybouzaglou/Datto-RMM-Powershell-Scripts",
    [string]$Branch = "main",
    [int]$TimeoutMinutes = 30
)

# Set script type for Applications component
$env:ScriptType = "Applications"

# Enhanced logging for Applications components
$LogDir = "C:\ProgramData\DattoRMM\Applications"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$transcriptPath = "$LogDir\Applications-$ScriptName-$timestamp.log"
Start-Transcript -Path $transcriptPath -Force

try {
    Write-Output "=============================================="
    Write-Output "Datto RMM Applications Launcher v3.0.0"
    Write-Output "=============================================="
    Write-Output "Script: $ScriptName"
    Write-Output "Timeout: $TimeoutMinutes minutes"
    Write-Output "Start Time: $(Get-Date)"
    Write-Output ""
    
    # Pre-installation system checks
    Write-Output "=== Pre-Installation Checks ==="
    
    # Check available disk space
    try {
        $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        Write-Output "Available disk space: ${freeSpaceGB}GB"
        
        if ($freeSpaceGB -lt 1) {
            Write-Warning "Low disk space detected. Installation may fail."
        }
    } catch {
        Write-Warning "Could not check disk space: $($_.Exception.Message)"
    }
    
    # Check if system is pending reboot
    $rebootPending = $false
    try {
        $rebootRequired = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue
        if ($rebootRequired) {
            $rebootPending = $true
            Write-Warning "System has pending reboot from Windows Update"
        }
    } catch {
        # Registry key doesn't exist, no pending reboot
    }
    
    Write-Output "System ready for installation"
    Write-Output ""
    
    # Call the universal launcher with installation-specific settings
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
    Write-Output "=== Starting Installation ==="
    $job = Start-Job -ScriptBlock {
        param($LauncherPath, $ScriptName, $GitHubRepo, $Branch)
        & $LauncherPath -ScriptName $ScriptName -ScriptType "installations" -GitHubRepo $GitHubRepo -Branch $Branch
    } -ArgumentList $launcherPath, $ScriptName, $GitHubRepo, $Branch
    
    $timeoutSeconds = $TimeoutMinutes * 60
    if (Wait-Job $job -Timeout $timeoutSeconds) {
        $result = Receive-Job $job
        $exitCode = $job.State -eq "Completed" ? 0 : 1
        Remove-Job $job -Force
        
        Write-Output $result
    } else {
        Write-Warning "Installation timed out after $TimeoutMinutes minutes"
        Stop-Job $job -Force
        Remove-Job $job -Force
        $exitCode = 11  # Timeout error
    }
    
    Write-Output ""
    Write-Output "=== Post-Installation Summary ==="
    Write-Output "Completion Time: $(Get-Date)"
    Write-Output "Exit Code: $exitCode"
    
    # Interpret exit codes for installations
    switch ($exitCode) {
        0 { 
            Write-Output "Status: SUCCESS - Installation completed successfully"
        }
        3010 { 
            Write-Output "Status: SUCCESS - Installation completed, reboot required"
            Write-Output "The system will need to be rebooted to complete the installation."
        }
        1641 { 
            Write-Output "Status: SUCCESS - Installation completed, reboot initiated"
            Write-Output "The installer has initiated a system reboot."
        }
        11 {
            Write-Output "Status: TIMEOUT - Installation exceeded time limit"
            Write-Output "The installation process was terminated due to timeout."
        }
        default { 
            Write-Output "Status: FAILED - Installation failed with exit code $exitCode"
            Write-Output "Check the installation logs for more details."
        }
    }
    
    # Check if reboot is now required
    if ($exitCode -eq 3010 -or $exitCode -eq 1641) {
        Write-Output ""
        Write-Output "REBOOT REQUIRED: The installation requires a system restart."
        Write-Output "Please schedule a reboot through Datto RMM when convenient."
    }
    
    exit $exitCode
    
} catch {
    Write-Error "Installation launcher failed: $($_.Exception.Message)"
    Write-Error "Line: $($_.InvocationInfo.ScriptLineNumber)"
    
    Write-Output ""
    Write-Output "Installation Troubleshooting:"
    Write-Output "- Verify the script name is correct: $ScriptName"
    Write-Output "- Check if the installer requires specific permissions"
    Write-Output "- Ensure sufficient disk space is available"
    Write-Output "- Check if antivirus is blocking the installation"
    Write-Output "- Review the full log: $transcriptPath"
    
    exit 2
} finally {
    Stop-Transcript
}
