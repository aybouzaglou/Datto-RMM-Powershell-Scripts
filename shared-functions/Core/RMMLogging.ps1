<#
.SYNOPSIS
RMM Logging Functions - Standardized logging for Datto RMM scripts

.DESCRIPTION
Provides consistent logging functions with structured output formats optimized for Datto RMM:
- Standardized log levels (SUCCESS, FAILED, WARNING, STATUS, CONFIG, DETECT, METRIC)
- Global counters for success/failure tracking
- Transcript management with proper paths
- Monitor result markers for Custom Monitor components
- Event log integration for system-level logging

.NOTES
Version: 3.0.0
Author: Datto RMM Function Library
Compatible: PowerShell 2.0+, Datto RMM Environment
#>

# Global counters for tracking script execution metrics
if (-not (Get-Variable -Name "RMMSuccessCount" -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:RMMSuccessCount = 0
}
if (-not (Get-Variable -Name "RMMFailCount" -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:RMMFailCount = 0
}
if (-not (Get-Variable -Name "RMMWarningCount" -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:RMMWarningCount = 0
}

function Write-RMMLog {
    <#
    .SYNOPSIS
    Writes standardized log messages for Datto RMM scripts
    
    .PARAMETER Message
    The message to log
    
    .PARAMETER Level
    Log level: Success, Failed, Warning, Status, Config, Detect, Metric, Info
    
    .PARAMETER UpdateCounters
    Whether to update global counters (default: true)
    
    .EXAMPLE
    Write-RMMLog "Software installation completed" -Level Success
    Write-RMMLog "Failed to download installer" -Level Failed
    Write-RMMLog "HP manufacturer detected" -Level Detect
    #>
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Success','Failed','Warning','Status','Config','Detect','Metric','Info')]
        [string]$Level,

        [bool]$UpdateCounters = $true
    )

    # Handle empty messages for spacing
    if ([string]::IsNullOrEmpty($Message)) {
        Write-Host ""
        return
    }

    $prefix = switch ($Level) {
        'Success' { 'SUCCESS '; if ($UpdateCounters) { $Global:RMMSuccessCount++ } }
        'Failed'  { 'FAILED  '; if ($UpdateCounters) { $Global:RMMFailCount++ } }
        'Warning' { 'WARNING '; if ($UpdateCounters) { $Global:RMMWarningCount++ } }
        'Status'  { 'STATUS  ' }
        'Config'  { 'CONFIG  ' }
        'Detect'  { 'DETECT  ' }
        'Metric'  { 'METRIC  ' }
        'Info'    { 'INFO    ' }
    }
    
    Write-Output "$prefix$Message"
}

function Start-RMMTranscript {
    <#
    .SYNOPSIS
    Starts transcript logging with standardized paths for Datto RMM
    
    .PARAMETER LogName
    Name for the log file (without extension)
    
    .PARAMETER LogDirectory
    Directory for log files (default: C:\ProgramData\DattoRMM)
    
    .PARAMETER Append
    Whether to append to existing log (default: true)
    
    .EXAMPLE
    Start-RMMTranscript -LogName "SoftwareInstall"
    Start-RMMTranscript -LogName "SystemMaintenance" -LogDirectory "C:\Logs"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$LogName,
        
        [string]$LogDirectory = "C:\ProgramData\DattoRMM",
        
        [bool]$Append = $true
    )
    
    try {
        # Ensure log directory exists
        if (-not (Test-Path $LogDirectory)) {
            New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $logPath = Join-Path $LogDirectory "$LogName-$timestamp.log"
        
        if ($Append) {
            Start-Transcript -Path $logPath -Append -Force
        } else {
            Start-Transcript -Path $logPath -Force
        }
        
        Write-RMMLog "Transcript started: $logPath" -Level Info -UpdateCounters $false
        return $logPath
    }
    catch {
        Write-Warning "Failed to start transcript: $($_.Exception.Message)"
        return $null
    }
}

function Stop-RMMTranscript {
    <#
    .SYNOPSIS
    Stops transcript logging with summary information
    
    .PARAMETER ShowSummary
    Whether to display execution summary (default: true)
    
    .EXAMPLE
    Stop-RMMTranscript
    Stop-RMMTranscript -ShowSummary $false
    #>
    param(
        [bool]$ShowSummary = $true
    )
    
    if ($ShowSummary) {
        Write-RMMLog "Execution Summary - Success: $Global:RMMSuccessCount, Failed: $Global:RMMFailCount, Warnings: $Global:RMMWarningCount" -Level Metric -UpdateCounters $false
    }
    
    try {
        Stop-Transcript
    }
    catch {
        # Transcript may not be running, ignore error
    }
}

function Write-RMMMonitorResult {
    <#
    .SYNOPSIS
    Writes monitor results with proper markers for Datto RMM Custom Monitor components
    
    .PARAMETER Status
    Monitor status: OK, WARNING, CRITICAL
    
    .PARAMETER Message
    Status message to display in RMM
    
    .PARAMETER ExitCode
    Exit code (0 for OK, any non-zero for alert state)
    
    .EXAMPLE
    Write-RMMMonitorResult -Status "OK" -Message "All services running normally" -ExitCode 0
    Write-RMMMonitorResult -Status "CRITICAL" -Message "Service XYZ is stopped" -ExitCode 1
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('OK','WARNING','CRITICAL')]
        [string]$Status,
        
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [int]$ExitCode = 0
    )
    
    Write-Host "<-Start Result->"
    Write-Host "${Status}: $Message"
    Write-Host "<-End Result->"
    
    exit $ExitCode
}

function Write-RMMEventLog {
    <#
    .SYNOPSIS
    Writes to Windows Event Log with Datto RMM source
    
    .PARAMETER Message
    Event message
    
    .PARAMETER EventId
    Event ID (default: 40000 for success, 40001 for warning, 40002 for error)
    
    .PARAMETER EntryType
    Event type: Information, Warning, Error
    
    .EXAMPLE
    Write-RMMEventLog "Software installation completed" -EntryType Information
    Write-RMMEventLog "Installation failed" -EntryType Error
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [int]$EventId,
        
        [ValidateSet('Information','Warning','Error')]
        [string]$EntryType = 'Information'
    )
    
    if (-not $EventId) {
        $EventId = switch ($EntryType) {
            'Information' { 40000 }
            'Warning'     { 40001 }
            'Error'       { 40002 }
        }
    }
    
    try {
        # Create event source if it doesn't exist
        if (-not [System.Diagnostics.EventLog]::SourceExists("Datto-RMM-Script")) {
            New-EventLog -LogName Application -Source "Datto-RMM-Script"
        }
        
        Write-EventLog -LogName Application -Source "Datto-RMM-Script" -EventId $EventId -EntryType $EntryType -Message $Message
    }
    catch {
        Write-RMMLog "Failed to write event log: $($_.Exception.Message)" -Level Warning
    }
}

# Export functions for module loading
Export-ModuleMember -Function @(
    'Write-RMMLog',
    'Start-RMMTranscript', 
    'Stop-RMMTranscript',
    'Write-RMMMonitorResult',
    'Write-RMMEventLog'
)
