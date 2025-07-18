<#
.SYNOPSIS
Disk Space Monitor - Datto RMM Monitors Component

.DESCRIPTION
Fast disk space monitoring script optimized for Datto RMM Monitors component:
- Uses shared RMM function library for improved reliability
- Fast execution (completes in under 3 seconds)
- Configurable warning and critical thresholds
- Proper <-Start Result-> and <-End Result-> markers for RMM UI
- Multiple drive monitoring support

.COMPONENT
Category: Monitors (System Health Monitoring)
Execution: Continuous/recurring
Timeout: <3 seconds (critical requirement)
Changeable: No (Monitors category is immutable once created)

.PARAMETER WarningThreshold
Free space percentage that triggers warning (default: 15)

.PARAMETER CriticalThreshold
Free space percentage that triggers critical alert (default: 5)

.PARAMETER DriveLetters
Comma-separated list of drive letters to monitor (default: C)

.EXAMPLE
# Datto RMM Monitors Component Usage:
# ScriptName: "DiskSpaceMonitor.ps1"
# Component Type: Monitors
# Environment Variables: WarningThreshold, CriticalThreshold, DriveLetters

.NOTES
Version: 2.0.0
Author: Enhanced for Datto RMM Function Library
Component Category: Monitors (System Health Monitoring)
Compatible: PowerShell 2.0+, Datto RMM Environment

Datto RMM Monitors Exit Codes:
- 0: OK/Green (all drives have sufficient space)
- Any non-zero: Alert state (triggers alert in RMM)

Monitor Requirements:
- Must complete in <3 seconds
- Must use <-Start Result-> and <-End Result-> markers
- Category is immutable (cannot be changed after creation)
- Designed for continuous/recurring execution

CHANGELOG:
2.0.0 - Reorganized for Datto RMM Monitors category
1.0.0 - Initial disk space monitor
#>

param(
    [int]$WarningThreshold = 15,
    [int]$CriticalThreshold = 5,
    [string]$DriveLetters = "C"
)

############################################################################################################
#                                         Initial Setup                                                    #
############################################################################################################

# Embedded logging function for monitors (copied from shared-functions/EmbeddedMonitorFunctions.ps1)
function Write-MonitorLog {
    param([string]$Message, [string]$Level = 'Info')
    # Minimal logging for performance - don't write to console to avoid interfering with monitor output
    # This is embedded for maximum reliability and performance
}

# Embedded environment variable function
function Get-RMMVariable {
    param([string]$Name, [string]$Type = "String", $Default = $null)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($value)) { return $Default }

    switch ($Type) {
        "Integer" { try { return [int]$value } catch { return $Default } }
        "Boolean" { return ($value -eq "true" -or $value -eq "1" -or $value -eq "yes") }
        default { return $value }
    }
}

# Get environment variables using embedded function
$WarningThreshold = Get-RMMVariable -Name "WarningThreshold" -Type "Integer" -Default $WarningThreshold
$CriticalThreshold = Get-RMMVariable -Name "CriticalThreshold" -Type "Integer" -Default $CriticalThreshold
$DriveLetters = Get-RMMVariable -Name "DriveLetters" -Type "String" -Default $DriveLetters

############################################################################################################
#                                    Monitor Logic                                                        #
############################################################################################################

try {
    # Validate thresholds
    if ($CriticalThreshold -ge $WarningThreshold) {
        Write-Host "<-Start Result->"
        Write-Host "CRITICAL: Invalid thresholds - Critical ($CriticalThreshold%) must be less than Warning ($WarningThreshold%)"
        Write-Host "<-End Result->"
        exit 1
    }
    
    # Parse drive letters
    $drives = $DriveLetters -split ',' | ForEach-Object { $_.Trim().ToUpper() }
    
    $criticalDrives = @()
    $warningDrives = @()
    $okDrives = @()
    $results = @()
    
    foreach ($driveLetter in $drives) {
        try {
            # Ensure drive letter format
            if ($driveLetter -notmatch '^[A-Z]$') {
                $driveLetter = $driveLetter.Replace(':', '').ToUpper()
            }
            
            # Get disk information
            $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='${driveLetter}:'" -ErrorAction Stop
            
            if ($disk) {
                $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
                $totalSpaceGB = [math]::Round($disk.Size / 1GB, 2)
                $freePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
                
                $driveInfo = "${driveLetter}: ${freeSpaceGB}GB free of ${totalSpaceGB}GB (${freePercent}%)"
                
                if ($freePercent -le $CriticalThreshold) {
                    $criticalDrives += $driveInfo
                    Write-MonitorLog "Critical disk space on ${driveLetter}: ${freePercent}%" -Level Failed
                } elseif ($freePercent -le $WarningThreshold) {
                    $warningDrives += $driveInfo
                    Write-MonitorLog "Warning disk space on ${driveLetter}: ${freePercent}%" -Level Warning
                } else {
                    $okDrives += $driveInfo
                    Write-MonitorLog "OK disk space on ${driveLetter}: ${freePercent}%" -Level Success
                }
                
                $results += $driveInfo
            } else {
                Write-MonitorLog "Drive ${driveLetter}: not found" -Level Warning
                $warningDrives += "${driveLetter}: Drive not found"
            }
        } catch {
            Write-MonitorLog "Error checking drive ${driveLetter}: $($_.Exception.Message)" -Level Failed
            $criticalDrives += "${driveLetter}: Error - $($_.Exception.Message)"
        }
    }
    
    # Determine overall status and create result message
    if ($criticalDrives.Count -gt 0) {
        $status = "CRITICAL"
        $message = "Low disk space detected on $($criticalDrives.Count) drive(s): $($criticalDrives -join '; ')"
        $exitCode = 1
    } elseif ($warningDrives.Count -gt 0) {
        $status = "WARNING"
        $message = "Disk space warning on $($warningDrives.Count) drive(s): $($warningDrives -join '; ')"
        $exitCode = 1
    } else {
        $status = "OK"
        $message = "All drives have sufficient space: $($okDrives -join '; ')"
        $exitCode = 0
    }
    
    # Add threshold information to message
    $message += " [Thresholds: Warning<${WarningThreshold}%, Critical<${CriticalThreshold}%]"
    
    # Embedded monitor result function
    Write-Host "<-Start Result->"
    Write-Host "${status}: $message"
    Write-Host "<-End Result->"
    exit $exitCode
    
} catch {
    # Critical error in monitor - embedded error handling
    $errorMessage = "Monitor script failed: $($_.Exception.Message)"
    Write-Host "<-Start Result->"
    Write-Host "CRITICAL: $errorMessage"
    Write-Host "<-End Result->"
    exit 1
}
