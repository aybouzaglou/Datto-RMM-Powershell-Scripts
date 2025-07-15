<#
.SYNOPSIS
Embedded Monitor Functions - Lightweight Function Library for Direct Deployment

.DESCRIPTION
Ultra-lightweight function library designed for embedding directly into monitor scripts.
Optimized for <200ms execution times with zero external dependencies.

.NOTES
Version: 1.0.0
Author: Datto RMM Performance Optimization Team
Purpose: Provide essential functions for direct deployment monitors
Performance: Optimized for minimal overhead and fast execution

USAGE:
Copy and paste these functions directly into your monitor scripts.
Do NOT dot-source this file - embed functions for zero dependency deployment.

PERFORMANCE CHARACTERISTICS:
- Get-RMMVariable: <1ms execution time
- Write-MonitorAlert: <1ms execution time  
- Write-MonitorLog: <1ms execution time (no-op for performance)
- Write-MonitorSuccess: <1ms execution time
- Test-RMMEnvironment: <5ms execution time
#>

############################################################################################################
#                                    CORE EMBEDDED FUNCTIONS                                              #
############################################################################################################

<#
.SYNOPSIS
Lightweight environment variable handler optimized for monitors

.DESCRIPTION
Fast environment variable retrieval with type conversion and default value support.
Designed for embedding in direct deployment monitors.

.PARAMETER Name
Environment variable name

.PARAMETER Type
Expected data type: String, Integer, Boolean

.PARAMETER Default
Default value if environment variable is not set or invalid

.EXAMPLE
$threshold = Get-RMMVariable -Name "Threshold" -Type "Integer" -Default 15
$enabled = Get-RMMVariable -Name "Enabled" -Type "Boolean" -Default $true
#>
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
            $envValue -eq 'true' -or $envValue -eq '1' -or $envValue -eq 'yes' -or $envValue -eq 'on'
        }
        "Double" {
            try { [double]$envValue }
            catch { $Default }
        }
        default { $envValue }
    }
}

<#
.SYNOPSIS
Centralized alert function for monitor failures

.DESCRIPTION
Outputs properly formatted alert message with diagnostic end and result markers.
Automatically exits with code 1 to trigger Datto RMM alert.

.PARAMETER Message
Alert message to display

.EXAMPLE
Write-MonitorAlert "CRITICAL: Disk space below 5GB"
#>
function Write-MonitorAlert {
    param([string]$Message)
    Write-Host '<-End Diagnostic->'
    Write-Host '<-Start Result->'
    Write-Host "X=$Message"
    Write-Host '<-End Result->'
    exit 1
}

<#
.SYNOPSIS
Success result function for healthy monitors

.DESCRIPTION
Outputs properly formatted success message with diagnostic end and result markers.
Automatically exits with code 0 for healthy status.

.PARAMETER Message
Success message to display

.EXAMPLE
Write-MonitorSuccess "System is healthy - all checks passed"
#>
function Write-MonitorSuccess {
    param([string]$Message)
    Write-Host '<-End Diagnostic->'
    Write-Host '<-Start Result->'
    Write-Host "OK: $Message"
    Write-Host '<-End Result->'
    exit 0
}

<#
.SYNOPSIS
Minimal logging function optimized for monitor performance

.DESCRIPTION
Lightweight logging function that prioritizes performance over functionality.
In direct deployment monitors, this is typically a no-op to maximize speed.

.PARAMETER Message
Log message

.PARAMETER Level
Log level (Info, Warning, Error)

.EXAMPLE
Write-MonitorLog "Processing completed" -Level "Info"
#>
function Write-MonitorLog {
    param(
        [string]$Message, 
        [string]$Level = 'Info'
    )
    # No-op for performance in direct deployment monitors
    # Could be extended for debugging if needed:
    # Write-Verbose "$Level`: $Message" -Verbose:$VerbosePreference
}

<#
.SYNOPSIS
Fast environment validation for monitors

.DESCRIPTION
Quick validation of monitor execution environment.
Optimized for speed with minimal system calls.

.EXAMPLE
$envOk = Test-RMMEnvironment
if (-not $envOk) { Write-MonitorAlert "Environment validation failed" }
#>
function Test-RMMEnvironment {
    try {
        # Basic PowerShell version check
        if ($PSVersionTable.PSVersion.Major -lt 3) {
            return $false
        }
        
        # Basic execution policy check (non-blocking)
        $policy = Get-ExecutionPolicy -ErrorAction SilentlyContinue
        if ($policy -eq 'Restricted') {
            return $false
        }
        
        return $true
    } catch {
        return $false
    }
}

############################################################################################################
#                                    SPECIALIZED MONITOR FUNCTIONS                                        #
############################################################################################################

<#
.SYNOPSIS
Fast disk space check optimized for monitors

.DESCRIPTION
Lightweight disk space validation with minimal overhead.
Returns disk information quickly for monitor processing.

.PARAMETER DriveLetter
Drive letter to check (without colon)

.EXAMPLE
$diskInfo = Get-RMMDiskSpace -DriveLetter "C"
if ($diskInfo.FreeGB -lt 10) { Write-MonitorAlert "Low disk space" }
#>
function Get-RMMDiskSpace {
    param([string]$DriveLetter)
    
    try {
        $drive = Get-PSDrive $DriveLetter -ErrorAction Stop
        return @{
            FreeGB = [math]::Round($drive.Free / 1GB, 1)
            UsedGB = [math]::Round($drive.Used / 1GB, 1)
            TotalGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 1)
            FreePercent = [math]::Round(($drive.Free / ($drive.Used + $drive.Free)) * 100, 1)
        }
    } catch {
        return $null
    }
}

<#
.SYNOPSIS
Fast service status check for monitors

.DESCRIPTION
Lightweight service status validation optimized for speed.

.PARAMETER ServiceName
Name of the service to check

.EXAMPLE
$serviceOk = Test-RMMService -ServiceName "Spooler"
if (-not $serviceOk) { Write-MonitorAlert "Print Spooler service not running" }
#>
function Test-RMMService {
    param([string]$ServiceName)
    
    try {
        $service = Get-Service $ServiceName -ErrorAction Stop
        return $service.Status -eq 'Running'
    } catch {
        return $false
    }
}

<#
.SYNOPSIS
Fast process check for monitors

.DESCRIPTION
Lightweight process existence check optimized for speed.

.PARAMETER ProcessName
Name of the process to check (without .exe)

.EXAMPLE
$processRunning = Test-RMMProcess -ProcessName "notepad"
if (-not $processRunning) { Write-MonitorAlert "Required process not running" }
#>
function Test-RMMProcess {
    param([string]$ProcessName)
    
    try {
        $process = Get-Process $ProcessName -ErrorAction Stop
        return $process.Count -gt 0
    } catch {
        return $false
    }
}

############################################################################################################
#                                    PERFORMANCE UTILITIES                                                #
############################################################################################################

<#
.SYNOPSIS
Performance timer for monitor optimization

.DESCRIPTION
Simple stopwatch wrapper for measuring monitor performance.
Useful during development and optimization.

.EXAMPLE
$timer = Start-RMMTimer
# ... monitor logic ...
$elapsed = Stop-RMMTimer $timer
Write-Host "Monitor completed in $elapsed ms"
#>
function Start-RMMTimer {
    return [System.Diagnostics.Stopwatch]::StartNew()
}

function Stop-RMMTimer {
    param([System.Diagnostics.Stopwatch]$Timer)
    $Timer.Stop()
    return $Timer.ElapsedMilliseconds
}

############################################################################################################
#                                    EMBEDDING INSTRUCTIONS                                               #
############################################################################################################

<#
EMBEDDING GUIDE FOR DIRECT DEPLOYMENT MONITORS:
===============================================

1. COPY REQUIRED FUNCTIONS:
   Copy only the functions you need into your monitor script.
   Don't include unused functions to minimize script size.

2. PLACE AT TOP OF SCRIPT:
   Put embedded functions after param() block but before main logic.
   Use the comment header to separate embedded functions.

3. CUSTOMIZE AS NEEDED:
   Modify functions for your specific requirements.
   Remove unnecessary features to optimize performance.

4. TEST PERFORMANCE:
   Ensure your monitor still executes in <200ms with embedded functions.
   Use Start-RMMTimer/Stop-RMMTimer during development.

EXAMPLE EMBEDDING PATTERN:
=========================

param([int]$Threshold = 15)

############################################################################################################
#                                    EMBEDDED FUNCTION LIBRARY                                            #
############################################################################################################

function Get-RMMVariable { ... }
function Write-MonitorAlert { ... }
function Write-MonitorSuccess { ... }

############################################################################################################
#                                    MAIN MONITOR LOGIC                                                   #
############################################################################################################

# Your monitor code here...

PERFORMANCE TARGETS:
===================
- Total monitor execution: <200ms
- Function overhead: <10ms total
- Main logic: <190ms
#>
