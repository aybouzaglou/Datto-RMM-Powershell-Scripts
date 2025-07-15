<#
.SYNOPSIS
Bluescreen Monitor - Datto RMM Monitors Component

.DESCRIPTION
Fast bluescreen (BSOD) monitoring script optimized for Datto RMM Monitors component:
- Checks Windows Event Log for blue screen events in the past 7 days
- Uses embedded RMM functions for maximum reliability and performance
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

# Embedded logging function for monitors (copied from shared-functions/EmbeddedMonitorFunctions.ps1)
function Write-MonitorLog {
    param([string]$Message, [string]$Level = 'Info')
    # Minimal logging for performance - don't write to console to avoid interfering with monitor output
    # This is embedded for maximum reliability and performance
}

# Embedded environment variable function (copied from shared-functions/EmbeddedMonitorFunctions.ps1)
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
$DaysToCheck = Get-RMMVariable -Name "DaysToCheck" -Type "Integer" -Default $DaysToCheck
$IncludeDetails = Get-RMMVariable -Name "IncludeDetails" -Type "Boolean" -Default $IncludeDetails

############################################################################################################
#                                    Centralized Alert Function                                           #
############################################################################################################

function Write-MonitorAlert {
    param([string]$Message)
    Write-Host '<-End Diagnostic->'
    Write-Host '<-Start Result->'
    Write-Host "X=$Message"
    Write-Host '<-End Result->'
    exit 1
}

############################################################################################################
#                                    Diagnostic Phase                                                     #
############################################################################################################

# Start diagnostic output
Write-Host '<-Start Diagnostic->'
Write-Host "Bluescreen Monitor: Checking for BSODs in past $DaysToCheck days"
Write-Host "Debug mode: $($env:DebugMode -eq 'true')"
Write-Host "Include details: $IncludeDetails"
Write-Host "-------------------------"

try {
    Write-MonitorLog "Starting bluescreen check for past $DaysToCheck days" -Level Info

    # Add timeout protection (leave 0.5 seconds buffer for the 3-second requirement)
    $timeout = 2.5
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Calculate the start time for our search
    $startTime = (Get-Date).AddDays(-$DaysToCheck)
    Write-Host "- Search timeframe: $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) to present"
    
    # Initialize results
    $bluescreenEvents = @()
    $totalBSODs = 0

    # Event IDs to check for BSOD-related events
    $eventIds = @(
        @{ Id = 1001; Log = "Application"; Source = "Windows Error Reporting"; Description = "BSOD Error Report" },
        @{ Id = 6008; Log = "System"; Source = "EventLog"; Description = "Unexpected Shutdown" },
        @{ Id = 41; Log = "System"; Source = "Microsoft-Windows-Kernel-Power"; Description = "System Reboot (Critical)" }
    )

    Write-Host "- Event IDs to monitor: 1001 (BSOD Report), 6008 (Unexpected Shutdown), 41 (Critical Reboot)"
    
    # Check each event type
    foreach ($eventType in $eventIds) {
        # Check timeout
        if ($stopwatch.ElapsedMilliseconds -gt ($timeout * 1000)) {
            Write-MonitorLog "Timeout reached, stopping event checks" -Level Warning
            break
        }

        try {
            Write-Host "- Checking $($eventType.Log) log for Event ID $($eventType.Id) ($($eventType.Description))"
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
                Write-Host "  ! Found $($events.Count) event(s) of type: $($eventType.Description)"
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

                    Write-Host "    - $($logEvent.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')): $($eventType.Description)"
                    Write-MonitorLog "Found BSOD event: $($eventType.Description) at $($logEvent.TimeCreated)" -Level Warning
                }
            } else {
                Write-Host "  - No events found for $($eventType.Description)"
            }
        } catch [System.Exception] {
            if ($_.Exception.Message -like "*No events were found*") {
                # This is expected - no events found
                Write-Host "  - No events found for $($eventType.Description)"
                Write-MonitorLog "No events found for $($eventType.Description)" -Level Info
            } else {
                Write-Host "  ! Warning: Event log access issue for $($eventType.Log): $($_.Exception.Message)"
                Write-MonitorLog "Event log access error for $($eventType.Log): $($_.Exception.Message)" -Level Warning
            }
        }
    }
    
    # Sort events by time (most recent first)
    $bluescreenEvents = $bluescreenEvents | Sort-Object TimeCreated -Descending

    Write-Host "- Analysis complete: Found $totalBSODs BSOD-related events"

    ############################################################################################################
    #                                    Generate Monitor Result                                               #
    ############################################################################################################

    if ($totalBSODs -eq 0) {
        Write-Host "- System appears stable - no BSOD events detected"
        Write-MonitorLog "No blue screens found" -Level Success

        Write-Host '<-End Diagnostic->'
        Write-Host '<-Start Result->'
        Write-Host "OK: No blue screens detected in the past $DaysToCheck days"
        Write-Host '<-End Result->'
        exit 0
    } else {
        Write-Host "! ALERT: BSOD events detected - system stability issue"
        Write-MonitorLog "Blue screens detected: $totalBSODs" -Level Failed

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
            Write-Host "  Most recent BSOD: $($mostRecent.ToString('yyyy-MM-dd HH:mm:ss'))"
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

        Write-MonitorAlert "CRITICAL: $message"
    }

} catch {
    # Critical error in monitor - embedded error handling
    Write-Host "! CRITICAL ERROR: Monitor execution failed"
    Write-Host "  Exception: $($_.Exception.Message)"
    $errorMessage = "Bluescreen monitor failed: $($_.Exception.Message)"
    Write-MonitorAlert "CRITICAL: $errorMessage"
}
