<#
.SYNOPSIS
Security Monitor Function Subset - Optimized for Security Monitoring

.DESCRIPTION
Specialized function subset for security monitoring (event logs, failed logins, etc.)
Designed for embedding in direct deployment security monitors.

.NOTES
Version: 1.0.0
Purpose: Security monitoring functions
Performance: <20ms total overhead for all functions
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
#                                    SECURITY MONITORING FUNCTIONS                                       #
############################################################################################################

function Get-RMMSecurityEvents {
    param(
        [string]$LogName = "Security",
        [int[]]$EventIDs = @(4625, 4648, 4771),  # Failed logon events
        [int]$Hours = 24
    )
    
    try {
        $startTime = (Get-Date).AddHours(-$Hours)
        $events = @()
        
        foreach ($eventID in $EventIDs) {
            try {
                $logEvents = Get-WinEvent -FilterHashtable @{
                    LogName = $LogName
                    ID = $eventID
                    StartTime = $startTime
                } -ErrorAction SilentlyContinue
                
                if ($logEvents) {
                    $events += $logEvents
                }
            } catch {
                # Continue with other event IDs if one fails
            }
        }
        
        return $events | Sort-Object TimeCreated -Descending
    } catch {
        return @()
    }
}

function Test-RMMAntivirusStatus {
    try {
        # Check Windows Defender status
        $defender = Get-WmiObject -Namespace "root\SecurityCenter2" -Class "AntiVirusProduct" -ErrorAction SilentlyContinue
        if ($defender) {
            foreach ($av in $defender) {
                if ($av.displayName -like "*Windows Defender*" -or $av.displayName -like "*Microsoft Defender*") {
                    # Check if enabled (productState bit manipulation)
                    $enabled = ($av.productState -band 0x1000) -ne 0
                    $updated = ($av.productState -band 0x10) -eq 0
                    return @{
                        Name = $av.displayName
                        Enabled = $enabled
                        Updated = $updated
                        Status = if ($enabled -and $updated) { "Protected" } else { "At Risk" }
                    }
                }
            }
        }
        return $null
    } catch {
        return $null
    }
}

function Get-RMMFailedLogons {
    param([int]$Hours = 24, [int]$MaxResults = 10)
    
    try {
        $events = Get-RMMSecurityEvents -EventIDs @(4625) -Hours $Hours
        $failedLogons = @()
        
        foreach ($event in ($events | Select-Object -First $MaxResults)) {
            try {
                $xml = [xml]$event.ToXml()
                $eventData = $xml.Event.EventData.Data
                
                $username = ($eventData | Where-Object { $_.Name -eq "TargetUserName" }).InnerText
                $domain = ($eventData | Where-Object { $_.Name -eq "TargetDomainName" }).InnerText
                $sourceIP = ($eventData | Where-Object { $_.Name -eq "IpAddress" }).InnerText
                
                $failedLogons += @{
                    Time = $event.TimeCreated
                    Username = "$domain\$username"
                    SourceIP = $sourceIP
                    EventID = $event.Id
                }
            } catch {
                # Skip malformed events
            }
        }
        
        return $failedLogons
    } catch {
        return @()
    }
}

function Test-RMMFirewallStatus {
    try {
        $firewall = Get-NetFirewallProfile -ErrorAction SilentlyContinue
        if ($firewall) {
            $profiles = @()
            foreach ($profile in $firewall) {
                $profiles += @{
                    Name = $profile.Name
                    Enabled = $profile.Enabled
                    DefaultInboundAction = $profile.DefaultInboundAction
                    DefaultOutboundAction = $profile.DefaultOutboundAction
                }
            }
            return $profiles
        }
        return $null
    } catch {
        # Fallback for older systems
        try {
            $fwPolicy = New-Object -ComObject HNetCfg.FwPolicy2
            return @{
                DomainEnabled = $fwPolicy.FirewallEnabled(1)
                PrivateEnabled = $fwPolicy.FirewallEnabled(2)
                PublicEnabled = $fwPolicy.FirewallEnabled(3)
            }
        } catch {
            return $null
        }
    }
}

function Get-RMMSystemEvents {
    param(
        [int[]]$EventIDs = @(1001, 6008, 41),  # BSOD-related events
        [int]$Hours = 168  # 7 days
    )
    
    try {
        $startTime = (Get-Date).AddHours(-$Hours)
        $events = @()
        
        $logChecks = @(
            @{ Log = "Application"; IDs = @(1001) },
            @{ Log = "System"; IDs = @(6008, 41) }
        )
        
        foreach ($check in $logChecks) {
            foreach ($eventID in $check.IDs) {
                try {
                    $logEvents = Get-WinEvent -FilterHashtable @{
                        LogName = $check.Log
                        ID = $eventID
                        StartTime = $startTime
                    } -ErrorAction SilentlyContinue
                    
                    if ($logEvents) {
                        $events += $logEvents
                    }
                } catch {
                    # Continue with other event IDs
                }
            }
        }
        
        return $events | Sort-Object TimeCreated -Descending
    } catch {
        return @()
    }
}

<#
USAGE EXAMPLE - Failed Logon Monitor:
=====================================

param([int]$MaxFailedLogons = 5, [int]$Hours = 24)

# Embed functions here...

$MaxFailedLogons = Get-RMMVariable -Name "MaxFailedLogons" -Type "Integer" -Default $MaxFailedLogons
$failedLogons = Get-RMMFailedLogons -Hours $Hours

if ($failedLogons.Count -gt $MaxFailedLogons) {
    $recentLogons = $failedLogons | Select-Object -First 3
    $details = ($recentLogons | ForEach-Object { "$($_.Username) from $($_.SourceIP)" }) -join "; "
    Write-MonitorAlert "CRITICAL: $($failedLogons.Count) failed logons in $Hours hours. Recent: $details"
}

Write-MonitorSuccess "Failed logons: $($failedLogons.Count) in past $Hours hours (threshold: $MaxFailedLogons)"

USAGE EXAMPLE - Antivirus Monitor:
==================================

# Embed functions here...

$avStatus = Test-RMMAntivirusStatus
if (-not $avStatus) { Write-MonitorAlert "Cannot determine antivirus status" }
if ($avStatus.Status -ne "Protected") { 
    Write-MonitorAlert "CRITICAL: Antivirus not properly protected - $($avStatus.Name): $($avStatus.Status)" 
}
Write-MonitorSuccess "Antivirus protected: $($avStatus.Name) - $($avStatus.Status)"
#>
