<#
.SYNOPSIS
Disk Space Monitor - Direct Deployment (Production Optimized)

.DESCRIPTION
Ultra-fast disk space monitoring script optimized for direct deployment:
- ZERO external dependencies - all functions embedded
- Sub-200ms execution time optimized
- No network calls during execution
- Production-grade diagnostic-first architecture
- Configurable warning and critical thresholds
- Optimized for high-frequency execution (every 1-2 minutes)

.COMPONENT
Category: Monitors (System Health Monitoring)
Deployment: DIRECT (paste script content directly into Datto RMM)
Execution: <200ms (performance optimized)
Dependencies: NONE (fully self-contained)

.PARAMETER DriveLetter
Drive letter to monitor (default: C)

.PARAMETER WarningGB
Warning threshold in GB (default: 20)

.PARAMETER CriticalGB
Critical threshold in GB (default: 10)

.EXAMPLE
# Datto RMM Direct Deployment:
# 1. Create Custom Monitor component
# 2. Paste this ENTIRE script as component content
# 3. Set environment variables: DriveLetter=C, WarningGB=20, CriticalGB=10
# 4. Deploy - NO launcher needed

.NOTES
Version: 2.0.0 - Direct Deployment Optimized
Author: Datto RMM Performance Optimization
Deployment: DIRECT (no launcher required)
Performance: <200ms execution, zero network dependencies
Compatible: PowerShell 3.0+, Datto RMM Environment

PERFORMANCE OPTIMIZATIONS:
- Embedded functions eliminate external loading overhead
- Optimized disk space queries with minimal processing
- Streamlined diagnostic output for speed
- No job creation or timeout management overhead
- Direct execution path with minimal branching

CHANGELOG:
2.0.0 - Direct deployment optimization, embedded functions, <200ms performance
1.0.0 - Initial launcher-based version
#>

param(
    [string]$DriveLetter = "C",
    [int]$WarningGB = 20,
    [int]$CriticalGB = 10
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

# Success result function (embedded)
function Write-MonitorSuccess {
    param([string]$Message)
    Write-Host '<-End Diagnostic->'
    Write-Host '<-Start Result->'
    Write-Host "OK: $Message"
    Write-Host '<-End Result->'
    exit 0
}

############################################################################################################
#                                    PARAMETER PROCESSING                                                 #
############################################################################################################

# Get parameters from environment (optimized)
$DriveLetter = Get-RMMVariable -Name "DriveLetter" -Type "String" -Default $DriveLetter
$WarningGB = Get-RMMVariable -Name "WarningGB" -Type "Integer" -Default $WarningGB
$CriticalGB = Get-RMMVariable -Name "CriticalGB" -Type "Integer" -Default $CriticalGB

############################################################################################################
#                                    DIAGNOSTIC PHASE                                                     #
############################################################################################################

# Start diagnostic output
Write-Host '<-Start Diagnostic->'
Write-Host "Disk Space Monitor: Direct deployment optimized for <200ms execution"
Write-Host "Monitoring drive: $DriveLetter"
Write-Host "Thresholds: Warning=${WarningGB}GB, Critical=${CriticalGB}GB"
Write-Host "-------------------------"

try {
    # Performance timer for optimization
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Validation layer
    Write-Host "- Validating drive letter format..."
    if ($DriveLetter -notmatch '^[A-Za-z]$') {
        Write-MonitorAlert "ERROR: Invalid drive letter format: $DriveLetter (must be single letter)"
    }
    
    # Normalize drive letter
    $DriveLetter = $DriveLetter.ToUpper()
    Write-Host "- Normalized drive letter: $DriveLetter"
    
    # Validate thresholds
    Write-Host "- Validating thresholds..."
    if ($CriticalGB -ge $WarningGB) {
        Write-MonitorAlert "ERROR: Critical threshold ($CriticalGB GB) must be less than warning threshold ($WarningGB GB)"
    }
    
    if ($CriticalGB -le 0 -or $WarningGB -le 0) {
        Write-MonitorAlert "ERROR: Thresholds must be positive values"
    }
    
    # Main disk space check
    Write-Host "- Checking drive $DriveLetter availability..."
    
    try {
        $Drive = Get-PSDrive $DriveLetter -ErrorAction Stop
    } catch {
        Write-MonitorAlert "ERROR: Cannot access drive ${DriveLetter}: - $($_.Exception.Message)"
    }
    
    # Calculate disk space (optimized)
    $FreeGB = [math]::Round($Drive.Free / 1GB, 1)
    $UsedGB = [math]::Round($Drive.Used / 1GB, 1)
    $TotalGB = [math]::Round(($Drive.Used + $Drive.Free) / 1GB, 1)
    $FreePercent = [math]::Round(($Drive.Free / ($Drive.Used + $Drive.Free)) * 100, 1)
    
    Write-Host "- Drive statistics:"
    Write-Host "  Total: ${TotalGB}GB"
    Write-Host "  Used: ${UsedGB}GB"
    Write-Host "  Free: ${FreeGB}GB (${FreePercent}%)"
    
    # Performance measurement
    $stopwatch.Stop()
    Write-Host "- Analysis completed in $($stopwatch.ElapsedMilliseconds)ms"
    
    ############################################################################################################
    #                                    RESULT GENERATION                                                    #
    ############################################################################################################
    
    # Evaluate thresholds
    if ($FreeGB -le $CriticalGB) {
        Write-Host "! CRITICAL threshold exceeded"
        Write-MonitorAlert "CRITICAL: Drive $DriveLetter has only $FreeGB GB free (${FreePercent}%) - threshold: ${CriticalGB}GB"
    } elseif ($FreeGB -le $WarningGB) {
        Write-Host "! WARNING threshold exceeded"
        Write-MonitorAlert "WARNING: Drive $DriveLetter has only $FreeGB GB free (${FreePercent}%) - threshold: ${WarningGB}GB"
    } else {
        Write-Host "- Drive space within acceptable limits"
        Write-MonitorSuccess "Drive $DriveLetter has $FreeGB GB free (${FreePercent}%) of ${TotalGB}GB total"
    }
    
} catch {
    # Critical error handling
    Write-Host "! CRITICAL ERROR: Monitor execution failed"
    Write-Host "  Exception: $($_.Exception.Message)"
    Write-MonitorAlert "CRITICAL: Disk space monitor failed - $($_.Exception.Message)"
}
