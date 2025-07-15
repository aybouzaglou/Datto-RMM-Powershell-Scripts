<#
.SYNOPSIS
Bluescreen Monitor - Datto RMM Monitors Component

.DESCRIPTION
Fast bluescreen (BSOD) monitoring script optimized for Datto RMM Monitors component:
- Checks Windows Event Log for blue screen events in the past 7 days
- Uses shared RMM function library for improved reliability
- Fast execution (completes in under 3 seconds)
- Configurable time window for BSOD detection
- Proper <-Start Result-> and <-End Result-> markers for RMM UI
- Provides detailed BSOD information including error codes and timestamps

.COMPONENT
Category: Monitors (System Health Monitoring)
Execution: Continuous/recurring
Timeout: <3 seconds (critical requirement)
Changeable: No (Monitors category is immutable once created)

.PARAMETER DaysToCheck
Number of days to look back for BSOD events (default: 7)

.PARAMETER IncludeDetails
Include detailed BSOD information in the output (default: true)

.EXAMPLE
# Datto RMM Monitors Component Usage:
# ScriptName: "BluescreenMonitor.ps1"
# Component Type: Monitors
# Environment Variables: DaysToCheck, IncludeDetails

.NOTES
Version: 1.0.0
Author: Enhanced for Datto RMM Function Library
Component Category: Monitors (System Health Monitoring)
Compatible: PowerShell 3.0+, Datto RMM Environment

Datto RMM Monitors Exit Codes:
- 0: OK/Green (no blue screens found)
- Any non-zero: Alert state (blue screens detected - triggers alert in RMM)

Monitor Requirements:
- Must complete in <3 seconds
- Must use <-Start Result-> and <-End Result-> markers
- Category is immutable (cannot be changed after creation)
- Designed for continuous/recurring execution

Event IDs Monitored:
- 1001: Windows Error Reporting (BSOD summary)
- 6008: System unexpected shutdown
- 41: Kernel-Power critical error (system reboot without clean shutdown)

CHANGELOG:
1.0.0 - Initial bluescreen monitor for Datto RMM
#>

param(
    [int]$DaysToCheck = 7,
    [bool]$IncludeDetails = $true
)

############################################################################################################
#                                         Initial Setup                                                    #
############################################################################################################

# Load shared functions if available (fallback to standalone mode if not)
if ($Global:RMMFunctionsLoaded) {
    # Use shared logging but don't update counters for monitors
    function Write-MonitorLog {
        param([string]$Message, [string]$Level = 'Info')
        Write-RMMLog $Message -Level $Level -UpdateCounters $false
    }
} else {
    # Fallback logging function for monitors
    function Write-MonitorLog {
        param([string]$Message, [string]$Level = 'Info')
        # Minimal logging for performance
        # Don't write to console to avoid interfering with monitor output
    }
}

# Get environment variables using shared functions if available
if ($Global:RMMFunctionsLoaded -and (Get-Command Get-RMMVariable -ErrorAction SilentlyContinue)) {
    $DaysToCheck = Get-RMMVariable -Name "DaysToCheck" -Type "Integer" -Default $DaysToCheck
    $IncludeDetails = Get-RMMVariable -Name "IncludeDetails" -Type "Boolean" -Default $IncludeDetails
} else {
    # Fallback environment variable handling
    if ($env:DaysToCheck) {
        try {
            $DaysToCheck = [int]$env:DaysToCheck
        } catch {
            Write-MonitorLog "Invalid DaysToCheck value: $env:DaysToCheck, using default: $DaysToCheck" -Level Warning
        }
    }
    if ($env:IncludeDetails) {
        $IncludeDetails = ($env:IncludeDetails -eq 'true' -or $env:IncludeDetails -eq '1' -or $env:IncludeDetails -eq 'yes')
    }
}

############################################################################################################
#                                    Bluescreen Detection                                                  #
############################################################################################################

try {
    Write-MonitorLog "Starting bluescreen check for past $DaysToCheck days" -Level Info

    # Add timeout protection (leave 0.5 seconds buffer for the 3-second requirement)
    $timeout = 2.5
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Calculate the start time for our search
    $startTime = (Get-Date).AddDays(-$DaysToCheck)
    
    # Initialize results
    $bluescreenEvents = @()
    $totalBSODs = 0
    
    # Event IDs to check for BSOD-related events
    $eventIds = @(
        @{ Id = 1001; Log = "Application"; Source = "Windows Error Reporting"; Description = "BSOD Error Report" },
        @{ Id = 6008; Log = "System"; Source = "EventLog"; Description = "Unexpected Shutdown" },
        @{ Id = 41; Log = "System"; Source = "Microsoft-Windows-Kernel-Power"; Description = "System Reboot (Critical)" }
    )
    
    # Check each event type
    foreach ($eventType in $eventIds) {
        # Check timeout
        if ($stopwatch.ElapsedMilliseconds -gt ($timeout * 1000)) {
            Write-MonitorLog "Timeout reached, stopping event checks" -Level Warning
            break
        }

        try {
            Write-MonitorLog "Checking $($eventType.Log) log for Event ID $($eventType.Id)" -Level Info

            # Use Get-WinEvent for better performance and filtering
            $filterHashtable = @{
                LogName = $eventType.Log
                ID = $eventType.Id
                StartTime = $startTime
            }

            # Add source filter if specified and not EventLog
            if ($eventType.Source -and $eventType.Source -ne "EventLog") {
                $filterHashtable.ProviderName = $eventType.Source
            }

            $events = Get-WinEvent -FilterHashtable $filterHashtable -ErrorAction Stop

            if ($events) {
                foreach ($logEvent in $events) {
                    $eventInfo = [PSCustomObject]@{
                        TimeCreated = $logEvent.TimeCreated
                        EventId = $logEvent.Id
                        LogName = $logEvent.LogName
                        Source = $logEvent.ProviderName
                        Description = $eventType.Description
                        Message = $logEvent.Message.Substring(0, [Math]::Min(200, $logEvent.Message.Length))
                    }

                    $bluescreenEvents += $eventInfo
                    $totalBSODs++

                    Write-MonitorLog "Found BSOD event: $($eventType.Description) at $($logEvent.TimeCreated)" -Level Warning
                }
            }
        } catch [System.Exception] {
            if ($_.Exception.Message -like "*No events were found*") {
                # This is expected - no events found
                Write-MonitorLog "No events found for $($eventType.Description)" -Level Info
            } else {
                Write-MonitorLog "Event log access error for $($eventType.Log): $($_.Exception.Message)" -Level Warning
            }
        }
    }
    
    # Sort events by time (most recent first)
    $bluescreenEvents = $bluescreenEvents | Sort-Object TimeCreated -Descending
    
    ############################################################################################################
    #                                    Generate Monitor Result                                               #
    ############################################################################################################
    
    if ($totalBSODs -eq 0) {
        $status = "OK"
        $message = "No blue screens detected in the past $DaysToCheck days"
        $exitCode = 0
        Write-MonitorLog "No blue screens found" -Level Success
    } else {
        $status = "CRITICAL"
        $exitCode = 1
        
        # Build detailed message
        if ($totalBSODs -eq 1) {
            $message = "1 blue screen detected in the past $DaysToCheck days"
        } else {
            $message = "$totalBSODs blue screens detected in the past $DaysToCheck days"
        }
        
        # Add most recent BSOD timestamp
        if ($bluescreenEvents.Count -gt 0) {
            $mostRecent = $bluescreenEvents[0].TimeCreated
            $message += " (Most recent: $($mostRecent.ToString('yyyy-MM-dd HH:mm:ss')))"
        }
        
        # Add details if requested and within reasonable length
        if ($IncludeDetails -and $bluescreenEvents.Count -gt 0) {
            $details = @()
            foreach ($bsodEvent in $bluescreenEvents | Select-Object -First 3) {
                $details += "$($bsodEvent.TimeCreated.ToString('MM/dd HH:mm')) - $($bsodEvent.Description)"
            }

            if ($details.Count -gt 0) {
                $message += " | Recent events: " + ($details -join "; ")
            }

            if ($bluescreenEvents.Count -gt 3) {
                $message += " (and $($bluescreenEvents.Count - 3) more)"
            }
        }
        
        Write-MonitorLog "Blue screens detected: $totalBSODs" -Level Failed
    }
    
    # Output monitor result using shared function if available
    if ($Global:RMMFunctionsLoaded -and (Get-Command Write-RMMMonitorResult -ErrorAction SilentlyContinue)) {
        Write-RMMMonitorResult -Status $status -Message $message -ExitCode $exitCode
    } else {
        # Fallback monitor output with validation
        try {
            Write-Host "<-Start Result->"
            Write-Host "${status}: $message"
            Write-Host "<-End Result->"

            # Validate output was written
            if (-not $?) {
                Write-Host "CRITICAL: Failed to write monitor output"
                exit 1
            }
        } catch {
            Write-Host "CRITICAL: Monitor output error: $($_.Exception.Message)"
            exit 1
        }
        exit $exitCode
    }
    
} catch {
    # Critical error in monitor
    $errorMessage = "Bluescreen monitor failed: $($_.Exception.Message)"

    if ($Global:RMMFunctionsLoaded -and (Get-Command Write-RMMMonitorResult -ErrorAction SilentlyContinue)) {
        Write-RMMMonitorResult -Status "CRITICAL" -Message $errorMessage -ExitCode 1
    } else {
        try {
            Write-Host "<-Start Result->"
            Write-Host "CRITICAL: $errorMessage"
            Write-Host "<-End Result->"

            # Validate output was written
            if (-not $?) {
                Write-Host "CRITICAL: Failed to write error output"
            }
        } catch {
            # Last resort - try to output something
            Write-Host "CRITICAL: Monitor completely failed"
        }
        exit 1
    }
}
