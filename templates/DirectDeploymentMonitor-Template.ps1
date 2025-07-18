<#
.SYNOPSIS
Monitor Template

.DESCRIPTION
Template for creating Datto RMM monitor scripts with embedded functions.

.PARAMETER YourParameter
Description of your parameter

.NOTES
Self-contained monitor script template
#>

param(
    # Customize parameters for your monitor
    [string]$YourParameter = $env:YourParameter ?? "DefaultValue",
    [bool]$DebugMode = ($env:DebugMode -eq 'true')
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
$YourParameter = Get-RMMVariable -Name "YourParameter" -Type "String" -Default $YourParameter
$DebugMode = Get-RMMVariable -Name "DebugMode" -Type "Boolean" -Default $DebugMode

############################################################################################################
#                                    DIAGNOSTIC PHASE                                                     #
############################################################################################################

# Start diagnostic output
Write-Host '<-Start Diagnostic->'
Write-Host "Monitor Name: Direct deployment optimized for <200ms execution"
Write-Host "Parameter: $YourParameter"
Write-Host "Debug mode: $DebugMode"
Write-Host "-------------------------"

try {
    # Performance timer for optimization
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    # CUSTOMIZE: Add your validation logic here
    Write-Host "- Performing system validation..."
    
    # Example validation (customize for your needs)
    if ([string]::IsNullOrWhiteSpace($YourParameter)) {
        Write-MonitorAlert "ERROR: Required parameter is missing or empty"
    }
    
    # CUSTOMIZE: Add your main monitoring logic here
    Write-Host "- Executing main monitoring checks..."
    
    # Example monitoring logic (replace with your implementation)
    $monitoringResult = $true  # Replace with your actual check
    $detailMessage = "System check completed successfully"  # Replace with your details
    
    # CUSTOMIZE: Add additional checks as needed
    Write-Host "- Additional validation checks..."
    
    # Performance measurement
    $stopwatch.Stop()
    Write-Host "- Analysis completed in $($stopwatch.ElapsedMilliseconds)ms"
    
    ############################################################################################################
    #                                    RESULT GENERATION                                                    #
    ############################################################################################################
    
    if ($monitoringResult) {
        Write-Host "- Monitor check passed - system is healthy"
        Write-MonitorSuccess $detailMessage
    } else {
        Write-Host "! ALERT: Monitor check failed - issue detected"
        Write-MonitorAlert "CRITICAL: $detailMessage"
    }
    
} catch {
    # Critical error handling
    Write-Host "! CRITICAL ERROR: Monitor execution failed"
    Write-Host "  Exception: $($_.Exception.Message)"
    Write-MonitorAlert "CRITICAL: Monitor failed - $($_.Exception.Message)"
}

<#
CUSTOMIZATION GUIDE:
===================

1. UPDATE PARAMETERS:
   - Modify the param() block for your specific needs
   - Add environment variable handling in the parameter processing section

2. CUSTOMIZE VALIDATION:
   - Replace example validation with your specific requirements
   - Add system-specific checks (OS version, services, etc.)

3. IMPLEMENT MONITORING LOGIC:
   - Replace the example monitoring logic with your actual checks
   - Use optimized queries and minimal processing for performance

4. ADJUST DIAGNOSTIC OUTPUT:
   - Customize diagnostic messages for your specific monitoring scenario
   - Add relevant system information and processing steps

5. OPTIMIZE PERFORMANCE:
   - Keep execution time under 200ms
   - Minimize file I/O and network operations
   - Use efficient data structures and algorithms

6. TEST THOROUGHLY:
   - Test in various environments and conditions
   - Validate performance under load
   - Ensure reliable operation in production

DEPLOYMENT CHECKLIST:
====================
□ Customize parameters and validation logic
□ Test performance (<200ms execution time)
□ Validate diagnostic output format
□ Test error handling scenarios
□ Update documentation for your specific monitor
□ Deploy to test environment first
□ Monitor performance in production
#>
