# Sample PowerShell Component for Datto RMM
# This is a demonstration component showing proper structure

<#
.SYNOPSIS
    Gets comprehensive system information for monitoring and troubleshooting
.DESCRIPTION
    This component collects detailed system information including hardware specs, 
    operating system details, installed software, and system performance metrics.
    It's designed to be used with Datto RMM for remote system monitoring.
.PARAMETER OutputFormat
    Specifies the output format for the results (JSON, XML, or Text)
.PARAMETER IncludeProcesses
    Include running processes in the output
.EXAMPLE
    .\Get-SystemInfo.ps1 -OutputFormat JSON
    .\Get-SystemInfo.ps1 -OutputFormat Text -IncludeProcesses
.NOTES
    Author: Datto RMM Team
    Version: 1.0
    Created: 2025-07-14
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("JSON", "XML", "Text")]
    [string]$OutputFormat = "JSON",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeProcesses
)

try {
    # Initialize result object
    $systemInfo = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ComputerName = $env:COMPUTERNAME
        Domain = $env:USERDOMAIN
        Username = $env:USERNAME
        OSInfo = $null
        HardwareInfo = $null
        NetworkInfo = $null
        DiskInfo = $null
        ProcessInfo = $null
        Services = $null
        EventLogErrors = $null
    }
    
    # Get Operating System Information
    Write-Host "Collecting OS information..." -ForegroundColor Yellow
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $systemInfo.OSInfo = [PSCustomObject]@{
        Caption = $osInfo.Caption
        Version = $osInfo.Version
        BuildNumber = $osInfo.BuildNumber
        Architecture = $osInfo.OSArchitecture
        InstallDate = $osInfo.InstallDate
        LastBootUpTime = $osInfo.LastBootUpTime
        TotalVisibleMemorySize = [math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 2)
        FreePhysicalMemory = [math]::Round($osInfo.FreePhysicalMemory / 1MB, 2)
        MemoryUsagePercent = [math]::Round((($osInfo.TotalVisibleMemorySize - $osInfo.FreePhysicalMemory) / $osInfo.TotalVisibleMemorySize) * 100, 2)
    }
    
    # Get Hardware Information
    Write-Host "Collecting hardware information..." -ForegroundColor Yellow
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    $processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $systemInfo.HardwareInfo = [PSCustomObject]@{
        Manufacturer = $computerSystem.Manufacturer
        Model = $computerSystem.Model
        TotalPhysicalMemory = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
        ProcessorName = $processor.Name
        ProcessorCores = $processor.NumberOfCores
        ProcessorLogicalProcessors = $processor.NumberOfLogicalProcessors
        ProcessorMaxClockSpeed = $processor.MaxClockSpeed
    }
    
    # Get Network Information
    Write-Host "Collecting network information..." -ForegroundColor Yellow
    $networkAdapters = Get-CimInstance -ClassName Win32_NetworkAdapter | Where-Object { $_.NetEnabled -eq $true }
    $systemInfo.NetworkInfo = $networkAdapters | ForEach-Object {
        $config = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.Index -eq $_.Index }
        [PSCustomObject]@{
            Name = $_.Name
            MACAddress = $_.MACAddress
            IPAddress = $config.IPAddress -join ", "
            DHCPEnabled = $config.DHCPEnabled
            DNSServers = $config.DNSServerSearchOrder -join ", "
        }
    }
    
    # Get Disk Information
    Write-Host "Collecting disk information..." -ForegroundColor Yellow
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    $systemInfo.DiskInfo = $disks | ForEach-Object {
        [PSCustomObject]@{
            Drive = $_.DeviceID
            Label = $_.VolumeName
            FileSystem = $_.FileSystem
            SizeGB = [math]::Round($_.Size / 1GB, 2)
            FreeSpaceGB = [math]::Round($_.FreeSpace / 1GB, 2)
            UsedSpacePercent = [math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 2)
        }
    }
    
    # Get Process Information (if requested)
    if ($IncludeProcesses) {
        Write-Host "Collecting process information..." -ForegroundColor Yellow
        $processes = Get-Process | Sort-Object CPU -Descending | Select-Object -First 20
        $systemInfo.ProcessInfo = $processes | ForEach-Object {
            [PSCustomObject]@{
                ProcessName = $_.ProcessName
                Id = $_.Id
                CPU = if ($_.CPU) { [math]::Round($_.CPU, 2) } else { 0 }
                WorkingSetMB = [math]::Round($_.WorkingSet / 1MB, 2)
                StartTime = if ($_.StartTime) { $_.StartTime } else { "N/A" }
            }
        }
    }
    
    # Get Critical Services Status
    Write-Host "Collecting service information..." -ForegroundColor Yellow
    $criticalServices = @('Spooler', 'BITS', 'Themes', 'AudioSrv', 'Dhcp', 'Dnscache', 'EventLog', 'PlugPlay', 'RpcSs', 'Schedule', 'W32Time', 'Winmgmt')
    $systemInfo.Services = $criticalServices | ForEach-Object {
        $service = Get-Service -Name $_ -ErrorAction SilentlyContinue
        if ($service) {
            [PSCustomObject]@{
                Name = $service.Name
                DisplayName = $service.DisplayName
                Status = $service.Status
                StartType = $service.StartType
            }
        }
    } | Where-Object { $_ -ne $null }
    
    # Get Recent Event Log Errors
    Write-Host "Collecting recent event log errors..." -ForegroundColor Yellow
    $eventLogErrors = Get-EventLog -LogName System -EntryType Error -Newest 10 -ErrorAction SilentlyContinue
    $systemInfo.EventLogErrors = $eventLogErrors | ForEach-Object {
        [PSCustomObject]@{
            TimeGenerated = $_.TimeGenerated
            Source = $_.Source
            EventID = $_.EventID
            Message = $_.Message.Substring(0, [Math]::Min(200, $_.Message.Length))
        }
    }
    
    # Output results based on format
    Write-Host "Formatting output..." -ForegroundColor Yellow
    switch ($OutputFormat) {
        "JSON" {
            $output = $systemInfo | ConvertTo-Json -Depth 10
            Write-Host "System information collected successfully (JSON format)" -ForegroundColor Green
        }
        "XML" {
            $output = $systemInfo | ConvertTo-Xml -Depth 10 -NoTypeInformation
            Write-Host "System information collected successfully (XML format)" -ForegroundColor Green
        }
        "Text" {
            $output = @"
=== SYSTEM INFORMATION REPORT ===
Generated: $($systemInfo.Timestamp)
Computer: $($systemInfo.ComputerName)
Domain: $($systemInfo.Domain)
User: $($systemInfo.Username)

=== OPERATING SYSTEM ===
OS: $($systemInfo.OSInfo.Caption)
Version: $($systemInfo.OSInfo.Version)
Build: $($systemInfo.OSInfo.BuildNumber)
Architecture: $($systemInfo.OSInfo.Architecture)
Memory Usage: $($systemInfo.OSInfo.MemoryUsagePercent)%

=== HARDWARE ===
Manufacturer: $($systemInfo.HardwareInfo.Manufacturer)
Model: $($systemInfo.HardwareInfo.Model)
Processor: $($systemInfo.HardwareInfo.ProcessorName)
Cores: $($systemInfo.HardwareInfo.ProcessorCores)
RAM: $($systemInfo.HardwareInfo.TotalPhysicalMemory) GB

=== DISK USAGE ===
$($systemInfo.DiskInfo | ForEach-Object { "$($_.Drive) $($_.UsedSpacePercent)% used ($($_.FreeSpaceGB) GB free)" } | Out-String)

=== CRITICAL SERVICES ===
$($systemInfo.Services | ForEach-Object { "$($_.Name): $($_.Status)" } | Out-String)
"@
            Write-Host "System information collected successfully (Text format)" -ForegroundColor Green
        }
    }
    
    # Return the output
    return $output
}
catch {
    $errorMessage = "Failed to collect system information: $($_.Exception.Message)"
    Write-Error $errorMessage
    
    # Return error information
    $errorInfo = [PSCustomObject]@{
        Success = $false
        Error = $errorMessage
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ComputerName = $env:COMPUTERNAME
    }
    
    if ($OutputFormat -eq "JSON") {
        return $errorInfo | ConvertTo-Json
    }
    else {
        return $errorMessage
    }
}