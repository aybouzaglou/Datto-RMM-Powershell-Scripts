<#
.SYNOPSIS
Performance Monitor Function Subset - Optimized for Performance Monitoring

.DESCRIPTION
Specialized function subset for performance monitoring (CPU, memory, network, etc.)
Designed for embedding in direct deployment performance monitors.

.NOTES
Version: 1.0.0
Purpose: Performance monitoring functions
Performance: <15ms total overhead for all functions
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
        "Double" { try { [double]$envValue } catch { $Default } }
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
#                                    PERFORMANCE MONITORING FUNCTIONS                                    #
############################################################################################################

function Get-RMMCPUUsage {
    param([int]$SampleSeconds = 1)
    try {
        $cpu = Get-WmiObject -Class Win32_Processor -ErrorAction Stop
        $usage = ($cpu | Measure-Object -Property LoadPercentage -Average).Average
        return [math]::Round($usage, 1)
    } catch {
        # Fallback method
        try {
            $perfCounter = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop
            return [math]::Round($perfCounter.CounterSamples[0].CookedValue, 1)
        } catch { return $null }
    }
}

function Get-RMMMemoryUsage {
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
        $totalMB = [math]::Round($os.TotalVisibleMemorySize / 1024, 0)
        $freeMB = [math]::Round($os.FreePhysicalMemory / 1024, 0)
        $usedMB = $totalMB - $freeMB
        $usedPercent = [math]::Round(($usedMB / $totalMB) * 100, 1)
        
        return @{
            TotalMB = $totalMB
            UsedMB = $usedMB
            FreeMB = $freeMB
            UsedPercent = $usedPercent
        }
    } catch { return $null }
}

function Get-RMMDiskPerformance {
    param([string]$DriveLetter = "C")
    try {
        $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='${DriveLetter}:'" -ErrorAction Stop
        if (-not $disk) { return $null }
        
        return @{
            FreeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 1)
            TotalSizeGB = [math]::Round($disk.Size / 1GB, 1)
            UsedPercent = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1)
            FileSystem = $disk.FileSystem
        }
    } catch { return $null }
}

function Test-RMMNetworkConnectivity {
    param([string]$Target = "8.8.8.8", [int]$TimeoutMs = 1000)
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $result = $ping.Send($Target, $TimeoutMs)
        return $result.Status -eq 'Success'
    } catch { return $false }
}

function Get-RMMProcessPerformance {
    param([string]$ProcessName)
    try {
        $processes = Get-Process $ProcessName -ErrorAction Stop
        $totalCPU = ($processes | Measure-Object -Property CPU -Sum).Sum
        $totalMemoryMB = [math]::Round(($processes | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 1)
        
        return @{
            ProcessCount = $processes.Count
            TotalCPUTime = [math]::Round($totalCPU, 2)
            TotalMemoryMB = $totalMemoryMB
        }
    } catch { return $null }
}

<#
USAGE EXAMPLE - CPU Monitor:
============================

param([int]$CPUThreshold = 80)

# Embed functions here...

$CPUThreshold = Get-RMMVariable -Name "CPUThreshold" -Type "Integer" -Default $CPUThreshold
$cpuUsage = Get-RMMCPUUsage

if ($cpuUsage -eq $null) { Write-MonitorAlert "Cannot measure CPU usage" }
if ($cpuUsage -gt $CPUThreshold) { Write-MonitorAlert "CRITICAL: CPU usage at $cpuUsage%" }
Write-MonitorSuccess "CPU usage is $cpuUsage% (threshold: $CPUThreshold%)"

USAGE EXAMPLE - Memory Monitor:
===============================

param([int]$MemoryThreshold = 85)

# Embed functions here...

$memInfo = Get-RMMMemoryUsage
if (-not $memInfo) { Write-MonitorAlert "Cannot measure memory usage" }
if ($memInfo.UsedPercent -gt $MemoryThreshold) { 
    Write-MonitorAlert "CRITICAL: Memory usage at $($memInfo.UsedPercent)% ($($memInfo.UsedMB)MB used)" 
}
Write-MonitorSuccess "Memory usage is $($memInfo.UsedPercent)% ($($memInfo.UsedMB)MB of $($memInfo.TotalMB)MB used)"
#>
