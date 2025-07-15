<#
.SYNOPSIS
System Monitor Function Subset - Optimized for System Health Monitoring

.DESCRIPTION
Specialized function subset for system monitoring (disk space, services, processes, etc.)
Designed for embedding in direct deployment system monitors.

.NOTES
Version: 1.0.0
Purpose: System health monitoring functions
Performance: <10ms total overhead for all functions
#>

############################################################################################################
#                                    CORE FUNCTIONS (REQUIRED)                                           #
############################################################################################################

function Get-RMMVariable {
    param([string]$Name, [string]$Type = "String", $Default = $null)
    $envValue = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($envValue)) { return $Default }
    switch ($Type) {
        "Integer" { try { [int]$envValue } catch { $Default } }
        "Boolean" { $envValue -eq 'true' -or $envValue -eq '1' -or $envValue -eq 'yes' }
        default { $envValue }
    }
}

function Write-MonitorAlert {
    param([string]$Message)
    Write-Host '<-End Diagnostic->'
    Write-Host '<-Start Result->'
    Write-Host "X=$Message"
    Write-Host '<-End Result->'
    exit 1
}

function Write-MonitorSuccess {
    param([string]$Message)
    Write-Host '<-End Diagnostic->'
    Write-Host '<-Start Result->'
    Write-Host "OK: $Message"
    Write-Host '<-End Result->'
    exit 0
}

############################################################################################################
#                                    SYSTEM MONITORING FUNCTIONS                                         #
############################################################################################################

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
    } catch { return $null }
}

function Test-RMMService {
    param([string]$ServiceName)
    try {
        $service = Get-Service $ServiceName -ErrorAction Stop
        return $service.Status -eq 'Running'
    } catch { return $false }
}

function Test-RMMProcess {
    param([string]$ProcessName)
    try {
        $process = Get-Process $ProcessName -ErrorAction Stop
        return $process.Count -gt 0
    } catch { return $false }
}

function Get-RMMSystemInfo {
    return @{
        OSVersion = [Environment]::OSVersion.Version.ToString()
        MachineName = [Environment]::MachineName
        UserName = [Environment]::UserName
        Is64Bit = [Environment]::Is64BitOperatingSystem
        ProcessorCount = [Environment]::ProcessorCount
    }
}

<#
USAGE EXAMPLE - Disk Space Monitor:
===================================

param([string]$DriveLetter = "C", [int]$WarningGB = 20, [int]$CriticalGB = 10)

# Embed functions here...

$DriveLetter = Get-RMMVariable -Name "DriveLetter" -Default $DriveLetter
$diskInfo = Get-RMMDiskSpace -DriveLetter $DriveLetter

if (-not $diskInfo) { Write-MonitorAlert "Cannot access drive $DriveLetter" }
if ($diskInfo.FreeGB -le $CriticalGB) { Write-MonitorAlert "CRITICAL: Only $($diskInfo.FreeGB)GB free" }
if ($diskInfo.FreeGB -le $WarningGB) { Write-MonitorAlert "WARNING: Only $($diskInfo.FreeGB)GB free" }
Write-MonitorSuccess "Drive $DriveLetter has $($diskInfo.FreeGB)GB free ($($diskInfo.FreePercent)%)"
#>
