<#
.SYNOPSIS
Self-Contained Script Template - Direct Deployment

.DESCRIPTION
Template for creating self-contained automation scripts with embedded functions.
Optimized for direct deployment to Datto RMM Scripts components.

Features:
- All functions embedded directly in script
- No external dependencies during execution
- Comprehensive error handling and logging
- Flexible timeout support
- System state validation
- PowerShell 2.0+ compatible

.COMPONENT
Category: Scripts (General Automation/Maintenance)
Execution: On-demand or scheduled
Timeout: Flexible (15 minutes recommended)
Changeable: Yes (can be changed to Applications category if needed)

.ENVIRONMENT VARIABLES
- OperationMode (String): Mode of operation (default: "Standard")
- TargetPath (String): Target path for operations (default: "C:\Temp")
- EnableLogging (Boolean): Enable detailed logging (default: true)
- DryRun (Boolean): Perform dry run without making changes (default: false)

.EXAMPLES
Environment Variables:
OperationMode = "Advanced"
TargetPath = "C:\CustomPath"
EnableLogging = true
DryRun = false

.NOTES
Version: 1.0.0
Author: Datto RMM Self-Contained Architecture
Compatible: PowerShell 2.0+, Datto RMM Environment
Deployment: DIRECT (paste script content directly into Datto RMM)
#>

param(
    [string]$OperationMode = $env:OperationMode,
    [string]$TargetPath = $env:TargetPath,
    [bool]$EnableLogging = ($env:EnableLogging -ne "false"),
    [bool]$DryRun = ($env:DryRun -eq "true")
)

############################################################################################################
#                                    EMBEDDED FUNCTION LIBRARY                                            #
############################################################################################################

# Embedded logging function
function Write-RMMLog {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Status', 'Success', 'Warning', 'Error', 'Failed', 'Config', 'Detect')]
        [string]$Level = 'Info'
    )
    
    $prefix = switch ($Level) {
        'Success' { 'SUCCESS ' }
        'Failed'  { 'FAILED  ' }
        'Error'   { 'ERROR   ' }
        'Warning' { 'WARNING ' }
        'Status'  { 'STATUS  ' }
        'Config'  { 'CONFIG  ' }
        'Detect'  { 'DETECT  ' }
        default   { 'INFO    ' }
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] $prefix$Message"
    Write-Output $logMessage
}

# Embedded environment variable function
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

# Embedded timeout function
function Invoke-RMMTimeout {
    param(
        [scriptblock]$Code,
        [int]$TimeoutSec = 300,
        [string]$OperationName = "Operation"
    )
    
    try {
        $job = Start-Job $Code
        if (Wait-Job $job -Timeout $TimeoutSec) {
            $result = Receive-Job $job
            Remove-Job $job -Force
            return $result
        } else {
            Stop-Job $job -Force
            Remove-Job $job -Force
            throw "Operation '$OperationName' exceeded ${TimeoutSec}s timeout"
        }
    } catch {
        Write-RMMLog "Timeout wrapper error for '$OperationName': $($_.Exception.Message)" -Level Failed
        throw
    }
}

# Embedded system validation function
function Test-SystemState {
    param([string]$Description = "System State")
    
    Write-RMMLog "Validating $Description..." -Level Status
    
    try {
        # Example system checks - customize as needed
        $diskSpace = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object -ExpandProperty FreeSpace
        $freeSpaceGB = [math]::Round($diskSpace / 1GB, 2)
        
        if ($freeSpaceGB -lt 1) {
            Write-RMMLog "WARNING: Low disk space - $freeSpaceGB GB free" -Level Warning
            return $false
        }
        
        Write-RMMLog "$Description validation passed - $freeSpaceGB GB free space" -Level Success
        return $true
    } catch {
        Write-RMMLog "Error validating $Description`: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Embedded operation function (customize this for your specific needs)
function Invoke-CustomOperation {
    param(
        [string]$Mode,
        [string]$Path,
        [bool]$DryRun
    )
    
    Write-RMMLog "Starting custom operation..." -Level Status
    Write-RMMLog "Mode: $Mode" -Level Config
    Write-RMMLog "Path: $Path" -Level Config
    Write-RMMLog "Dry Run: $DryRun" -Level Config
    
    try {
        # Example operation - replace with your actual logic
        if ($DryRun) {
            Write-RMMLog "DRY RUN: Would perform operation on $Path" -Level Status
            return 0
        }
        
        # Ensure target path exists
        if (-not (Test-Path $Path)) {
            Write-RMMLog "Creating target path: $Path" -Level Status
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        }
        
        # Perform your custom operation here
        Write-RMMLog "Performing operation in $Mode mode..." -Level Status
        
        # Example: Create a test file
        $testFile = Join-Path $Path "operation-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        "Operation completed successfully at $(Get-Date)" | Out-File -FilePath $testFile
        
        Write-RMMLog "Operation completed successfully" -Level Success
        Write-RMMLog "Created file: $testFile" -Level Success
        
        return 0
    } catch {
        Write-RMMLog "Error during custom operation: $($_.Exception.Message)" -Level Error
        return 1
    }
}

############################################################################################################
#                                    MAIN SCRIPT LOGIC                                                    #
############################################################################################################

# Initialize logging
$LogPath = "C:\ProgramData\DattoRMM\Scripts"
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

if ($EnableLogging) {
    Start-Transcript -Path "$LogPath\SelfContainedScript-$(Get-Date -Format 'yyyyMMdd-HHmmss').log" -Append
}

Write-RMMLog "=============================================="
Write-RMMLog "Self-Contained Script Template v1.0.0" -Level Status
Write-RMMLog "=============================================="
Write-RMMLog "Component Category: Scripts (General Automation)" -Level Config
Write-RMMLog "Start Time: $(Get-Date)" -Level Config
Write-RMMLog "Functions: Embedded (self-contained)" -Level Config
Write-RMMLog ""

# Process environment variables
$OperationMode = Get-RMMVariable -Name "OperationMode" -Default "Standard"
$TargetPath = Get-RMMVariable -Name "TargetPath" -Default "C:\Temp"
$EnableLogging = Get-RMMVariable -Name "EnableLogging" -Type "Boolean" -Default $true
$DryRun = Get-RMMVariable -Name "DryRun" -Type "Boolean" -Default $false

Write-RMMLog "Configuration:" -Level Config
Write-RMMLog "- Operation Mode: $OperationMode" -Level Config
Write-RMMLog "- Target Path: $TargetPath" -Level Config
Write-RMMLog "- Enable Logging: $EnableLogging" -Level Config
Write-RMMLog "- Dry Run: $DryRun" -Level Config
Write-RMMLog ""

# Main execution
$exitCode = 0

try {
    # Pre-operation system validation
    Write-RMMLog "Performing pre-operation validation..." -Level Status
    if (-not (Test-SystemState -Description "Pre-Operation")) {
        Write-RMMLog "Pre-operation validation failed - aborting" -Level Error
        $exitCode = 1
    } else {
        # Execute main operation with timeout protection
        $exitCode = Invoke-RMMTimeout -Code {
            Invoke-CustomOperation -Mode $OperationMode -Path $TargetPath -DryRun $DryRun
        } -TimeoutSec 600 -OperationName "Custom Operation"
        
        # Post-operation system validation
        if ($exitCode -eq 0) {
            Write-RMMLog "Performing post-operation validation..." -Level Status
            if (-not (Test-SystemState -Description "Post-Operation")) {
                Write-RMMLog "Post-operation validation failed" -Level Warning
                # Don't fail the script for post-validation issues
            }
        }
    }
    
} catch {
    Write-RMMLog "Unexpected error during execution: $($_.Exception.Message)" -Level Error
    Write-RMMLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    $exitCode = 1
} finally {
    Write-RMMLog ""
    Write-RMMLog "=============================================="
    Write-RMMLog "Self-Contained Script execution completed" -Level Status
    Write-RMMLog "Final exit code: $exitCode" -Level Status
    Write-RMMLog "End Time: $(Get-Date)" -Level Status
    Write-RMMLog "=============================================="
    
    if ($EnableLogging) {
        Stop-Transcript
    }
    exit $exitCode
}
