<#
.SYNOPSIS
Direct Deployment Monitor Template - Production Optimized

.DESCRIPTION
Template for creating high-performance direct deployment monitors:
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

.PARAMETER YourParameter
Description of your parameter (customize as needed)

.EXAMPLE
# Datto RMM Direct Deployment:
# 1. Create Custom Monitor component
# 2. Paste this ENTIRE script as component content
# 3. Set environment variables as needed
# 4. Deploy - NO launcher needed

.NOTES
Version: 1.0.0 - Direct Deployment Template
Author: Datto RMM Performance Optimization
Deployment: DIRECT (no launcher required)
Performance: <200ms execution, zero network dependencies
Compatible: PowerShell 3.0+, Datto RMM Environment

PERFORMANCE OPTIMIZATIONS:
- Embedded functions eliminate external loading overhead
- Optimized processing with minimal branching
- Streamlined diagnostic output for speed
- No job creation or timeout management overhead
- Direct execution path with performance monitoring

CUSTOMIZATION POINTS:
- Update parameters section for your specific needs
- Modify embedded functions if additional functionality needed
- Customize diagnostic output for your monitoring requirements
- Adjust performance thresholds and validation logic

CHANGELOG:
1.0.0 - Initial direct deployment template
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
