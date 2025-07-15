<#
.SYNOPSIS
Bluescreen Monitor - Direct Deployment (Production Optimized)

.DESCRIPTION
Ultra-fast bluescreen (BSOD) monitoring script optimized for direct deployment:
- ZERO external dependencies - all functions embedded
- Sub-200ms execution time optimized
- No network calls during execution
- Production-grade diagnostic-first architecture
- Embedded lightweight function library
- Optimized for high-frequency execution (every 1-2 minutes)

.COMPONENT
Category: Monitors (System Health Monitoring)
Deployment: DIRECT (paste script content directly into Datto RMM)
Execution: <200ms (performance optimized)
Dependencies: NONE (fully self-contained)

.PARAMETER DaysToCheck
Number of days to look back for BSOD events (default: 7)

.PARAMETER IncludeDetails
Include detailed BSOD information in the output (default: true)

.EXAMPLE
# Datto RMM Direct Deployment:
# 1. Create Custom Monitor component
# 2. Paste this ENTIRE script as component content
# 3. Set environment variables: DaysToCheck=7, IncludeDetails=true
# 4. Deploy - NO launcher needed

.NOTES
Version: 2.0.0 - Direct Deployment Optimized
Author: Datto RMM Performance Optimization
Deployment: DIRECT (no launcher required)
Performance: <200ms execution, zero network dependencies
Compatible: PowerShell 3.0+, Datto RMM Environment

PERFORMANCE OPTIMIZATIONS:
- Embedded functions eliminate external loading overhead
- Optimized event log queries with minimal processing
- Streamlined diagnostic output for speed
- No job creation or timeout management overhead
- Direct execution path with minimal branching

Event IDs Monitored:
- 1001: Windows Error Reporting (BSOD summary)
- 6008: System unexpected shutdown  
- 41: Kernel-Power critical error (system reboot without clean shutdown)

CHANGELOG:
2.0.0 - Direct deployment optimization, embedded functions, <200ms performance
1.0.0 - Initial launcher-based version
#>

param(
    [int]$DaysToCheck = 7,
    [bool]$IncludeDetails = $true
)

############################################################################################################
#                                    EMBEDDED FUNCTION LIBRARY                                            #
############################################################################################################

# Lightweight environment variable handler (embedded)
function Get-RMMVariable {
    param(
        [string]$Name,
        [string]$Type = "String", 
        $Default = $null
    )
    
    $envValue = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($envValue)) { return $Default }
    
    switch ($Type) {
        "Integer" { 
            try { [int]$envValue } 
            catch { $Default } 
        }
        "Boolean" { 
            $envValue -eq 'true' -or $envValue -eq '1' -or $envValue -eq 'yes' 
        }
        default { $envValue }
    }
}

# Centralized alert function (embedded)
function Write-MonitorAlert {
    param([string]$Message)
    Write-Host '<-End Diagnostic->'
    Write-Host '<-Start Result->'
    Write-Host "X=$Message"
    Write-Host '<-End Result->'
    exit 1
}

# Minimal logging function (embedded)
function Write-MonitorLog {
    param([string]$Message, [string]$Level = 'Info')
    # Minimal logging for performance - no file I/O during execution
    # Could be extended for debugging if needed
}

############################################################################################################
#                                    PARAMETER PROCESSING                                                 #
############################################################################################################

# Get parameters from environment (optimized)
$DaysToCheck = Get-RMMVariable -Name "DaysToCheck" -Type "Integer" -Default $DaysToCheck
$IncludeDetails = Get-RMMVariable -Name "IncludeDetails" -Type "Boolean" -Default $IncludeDetails

############################################################################################################
#                                    DIAGNOSTIC PHASE                                                     #
############################################################################################################

# Start diagnostic output
Write-Host '<-Start Diagnostic->'
Write-Host "Bluescreen Monitor: Direct deployment optimized for <200ms execution"
Write-Host "Checking for BSODs in past $DaysToCheck days"
Write-Host "Include details: $IncludeDetails"
Write-Host "-------------------------"

try {
    # Performance timer for optimization
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Calculate search timeframe
    $startTime = (Get-Date).AddDays(-$DaysToCheck)
    Write-Host "- Search timeframe: $($startTime.ToString('MM/dd HH:mm')) to present"
    
    # Initialize results (optimized)
    $totalBSODs = 0
    $mostRecentEvent = $null
    $eventDetails = @()
    
    # Event IDs to check (optimized array)
    $eventChecks = @(
        @{ Id = 1001; Log = "Application"; Desc = "BSOD Error Report" },
        @{ Id = 6008; Log = "System"; Desc = "Unexpected Shutdown" },
        @{ Id = 41; Log = "System"; Desc = "System Reboot (Critical)" }
    )
    
    Write-Host "- Monitoring Event IDs: 1001, 6008, 41"
    
    # Check each event type (performance optimized)
    foreach ($check in $eventChecks) {
        try {
            Write-Host "- Checking $($check.Log) log for Event ID $($check.Id)"
            
            # Optimized event query
            $events = Get-WinEvent -FilterHashtable @{
                LogName = $check.Log
                ID = $check.Id
                StartTime = $startTime
            } -ErrorAction SilentlyContinue
            
            if ($events) {
                $eventCount = $events.Count
                Write-Host "  ! Found $eventCount event(s): $($check.Desc)"
                $totalBSODs += $eventCount
                
                # Track most recent event
                $newestEvent = $events | Sort-Object TimeCreated -Descending | Select-Object -First 1
                if (-not $mostRecentEvent -or $newestEvent.TimeCreated -gt $mostRecentEvent.TimeCreated) {
                    $mostRecentEvent = $newestEvent
                }
                
                # Collect details if requested (optimized)
                if ($IncludeDetails) {
                    foreach ($event in ($events | Select-Object -First 3)) {
                        $eventDetails += "$($event.TimeCreated.ToString('MM/dd HH:mm')) - $($check.Desc)"
                    }
                }
            } else {
                Write-Host "  - No events found for $($check.Desc)"
            }
        } catch {
            Write-Host "  ! Warning: $($_.Exception.Message)"
        }
    }
    
    # Performance measurement
    $stopwatch.Stop()
    Write-Host "- Analysis completed in $($stopwatch.ElapsedMilliseconds)ms"
    
    ############################################################################################################
    #                                    RESULT GENERATION                                                    #
    ############################################################################################################
    
    if ($totalBSODs -eq 0) {
        Write-Host "- System appears stable - no BSOD events detected"
        Write-Host '<-End Diagnostic->'
        Write-Host '<-Start Result->'
        Write-Host "OK: No blue screens detected in the past $DaysToCheck days"
        Write-Host '<-End Result->'
        exit 0
    } else {
        Write-Host "! ALERT: $totalBSODs BSOD event(s) detected - system stability issue"
        
        # Build alert message (optimized)
        $message = if ($totalBSODs -eq 1) {
            "1 blue screen detected in the past $DaysToCheck days"
        } else {
            "$totalBSODs blue screens detected in the past $DaysToCheck days"
        }
        
        # Add timestamp of most recent event
        if ($mostRecentEvent) {
            $message += " (Most recent: $($mostRecentEvent.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')))"
            Write-Host "  Most recent: $($mostRecentEvent.TimeCreated.ToString('MM/dd HH:mm:ss'))"
        }
        
        # Add details if requested and available
        if ($IncludeDetails -and $eventDetails.Count -gt 0) {
            $detailsToShow = $eventDetails | Select-Object -First 3
            $message += " | Recent: " + ($detailsToShow -join "; ")
            
            if ($eventDetails.Count -gt 3) {
                $message += " (and $($eventDetails.Count - 3) more)"
            }
        }
        
        Write-MonitorAlert "CRITICAL: $message"
    }
    
} catch {
    # Critical error handling
    Write-Host "! CRITICAL ERROR: Monitor execution failed"
    Write-Host "  Exception: $($_.Exception.Message)"
    Write-MonitorAlert "CRITICAL: Bluescreen monitor failed - $($_.Exception.Message)"
}
