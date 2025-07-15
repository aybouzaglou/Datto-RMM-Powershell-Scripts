<#
.SYNOPSIS
Software Monitor - Datto RMM Monitor Component (Expert Pattern)

.DESCRIPTION
High-performance software detection monitor based on expert Datto RMM patterns.
Optimized for direct deployment with embedded functions for maximum speed.

Features:
- Registry-based detection (avoids slow Win32_Product)
- System and user-level software detection
- Configurable alert logic (alert if found/not found)
- Multiple software search support
- PowerShell 2.0 compatible
- Sub-200ms execution time target

.COMPONENT
Category: Monitor (System Health Check)
Execution: Every 1-2 minutes (high frequency)
Timeout: 3 seconds maximum
Changeable: No (Monitor category is immutable)

.ENVIRONMENT VARIABLES
- SoftwareSearch (String): Software names to search for (space-separated)
- SearchMethod (String): "EQ" = alert if found, "NE" = alert if not found (default: NE)
- IncludeUserLevel (Boolean): Include user-level installations (default: false)
- CustomSearch (String): Custom search terms (alternative to SoftwareSearch)

.EXAMPLES
Environment Variables:
SoftwareSearch = "Chrome Firefox"
SearchMethod = "NE"
IncludeUserLevel = false

.NOTES
Version: 1.0.0
Author: Based on Datto RMM Expert Patterns
Compatible: PowerShell 2.0+, Datto RMM Monitor
Performance: Optimized for <200ms execution
#>

param(
    [string]$SoftwareSearch = $env:SoftwareSearch,
    [string]$SearchMethod = $env:SearchMethod,
    [string]$CustomSearch = $env:CustomSearch,
    [string]$IncludeUserLevel = $env:IncludeUserLevel
)

# Diagnostic output start
Write-Host '<-Start Diagnostic->'
Write-Host "Software Monitor - Datto Expert Pattern"
Write-Host "Execution Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

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

# Fast software detection (Datto expert pattern - embedded)
function Test-MonitorSoftware {
    param(
        [string]$SoftwareName,
        [string]$Method = "NE",
        [bool]$CheckUserLevel = $false
    )
    
    $found = $false
    $foundDetails = @()
    
    try {
        # System-level search (fast registry scan)
        $systemPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        
        foreach ($path in $systemPaths) {
            if (Test-Path $path) {
                Get-ChildItem $path -ErrorAction SilentlyContinue | ForEach-Object {
                    $app = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                    if ($app.DisplayName -and $app.DisplayName -match [regex]::Escape($SoftwareName)) {
                        $found = $true
                        $foundDetails += "System-Level: $($app.DisplayName)"
                    }
                }
            }
        }
        
        # User-level search if requested (Datto expert pattern)
        if ($CheckUserLevel -and -not $found) {
            Get-ChildItem "Registry::HKEY_USERS\" -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer } | ForEach-Object {
                foreach ($node in @("Software", "Software\WOW6432Node")) {
                    $userPath = "Registry::$_\$node\Microsoft\Windows\CurrentVersion\Uninstall"
                    if (Test-Path $userPath -ErrorAction SilentlyContinue) {
                        try {
                            $domainName = (Get-ItemProperty "Registry::$_\Volatile Environment" -Name USERDOMAIN -ErrorAction SilentlyContinue).USERDOMAIN
                            $username = (Get-ItemProperty "Registry::$_\Volatile Environment" -Name USERNAME -ErrorAction SilentlyContinue).USERNAME
                            
                            Get-ChildItem $userPath -ErrorAction SilentlyContinue | ForEach-Object {
                                $app = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                                if ($app.DisplayName -and $app.DisplayName -match [regex]::Escape($SoftwareName)) {
                                    $found = $true
                                    $userContext = if ($domainName -and $username) { "$domainName\$username" } else { "Unknown User" }
                                    $foundDetails += "User-Level ($userContext): $($app.DisplayName)"
                                }
                            }
                        } catch {
                            continue
                        }
                    }
                }
            }
        }
        
        return @{
            Found = $found
            Details = $foundDetails
        }
        
    } catch {
        return @{
            Found = $false
            Details = @("Error: $($_.Exception.Message)")
        }
    }
}

############################################################################################################
#                                    PARAMETER PROCESSING                                                 #
############################################################################################################

# Process parameters (Datto expert pattern)
$searchTerms = if ($CustomSearch -match 'Custom') { $CustomSearch } else { $SoftwareSearch }
$alertMethod = Get-RMMVariable -Name "SearchMethod" -Type "String" -Default "NE"
$checkUserLevel = Get-RMMVariable -Name "IncludeUserLevel" -Type "Boolean" -Default $false

# Validate required parameters
if ([string]::IsNullOrWhiteSpace($searchTerms)) {
    Write-MonitorAlert "CONFIGURATION ERROR: No software specified for monitoring. Set SoftwareSearch environment variable."
}

# Handle legacy configurations (Datto expert pattern)
if (-not $alertMethod) {
    Write-Host "ALERT: Please update monitor settings to include SearchMethod setting. Using default value of 'alert if not found'."
    $alertMethod = "NE"
}

Write-Host "Search Terms: $searchTerms"
Write-Host "Alert Method: $alertMethod"
Write-Host "Include User Level: $checkUserLevel"

############################################################################################################
#                                    SOFTWARE DETECTION                                                   #
############################################################################################################

$softwareArray = $searchTerms.Split() | ForEach-Object { $_.Replace("=", " ").Trim() } | Where-Object { $_ }
$results = @()
$alertMessages = @()
$shouldAlert = $false

Write-Host "Checking $($softwareArray.Count) software items..."

foreach ($software in $softwareArray) {
    Write-Host "Searching for: $software"
    
    $result = Test-MonitorSoftware -SoftwareName $software -Method $alertMethod -CheckUserLevel $checkUserLevel
    
    # Apply alert logic (Datto expert pattern)
    if ($alertMethod -eq "EQ" -and $result.Found) {
        $shouldAlert = $true
        $message = "Software '$software' is installed: $($result.Details -join '; ')"
        $alertMessages += $message
        Write-Host "ALERT: $message"
    } elseif ($alertMethod -eq "NE" -and -not $result.Found) {
        $shouldAlert = $true
        $message = "Software '$software' is not installed"
        $alertMessages += $message
        Write-Host "ALERT: $message"
    } else {
        $status = if ($result.Found) { "FOUND: $($result.Details -join '; ')" } else { "NOT FOUND" }
        Write-Host "OK: Software '$software' - $status"
    }
    
    $results += @{
        Software = $software
        Found = $result.Found
        Details = $result.Details
    }
}

############################################################################################################
#                                    RESULTS AND EXIT                                                     #
############################################################################################################

$summary = "$($results.Count) software items checked"
$foundCount = ($results | Where-Object { $_.Found }).Count
if ($foundCount -gt 0) {
    $summary += ", $foundCount found"
}

Write-Host "Summary: $summary"
Write-Host '<-End Diagnostic->'

# Output results (Datto expert pattern)
Write-Host '<-Start Result->'
if ($shouldAlert) {
    Write-Host "X=$($alertMessages -join '; ')"
    Write-Host '<-End Result->'
    exit 1
} else {
    Write-Host "OK=$summary"
    Write-Host '<-End Result->'
    exit 0
}
