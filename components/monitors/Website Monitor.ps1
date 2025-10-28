<#
.SYNOPSIS
    Website Monitor - Datto RMM Monitor Script (Direct Deployment)

.DESCRIPTION
    Monitors website availability and content verification with diagnostic-first architecture.
    Optimized for direct deployment to Datto RMM with <200ms execution target.

.COMPONENT
    Category: Monitors (System Health Monitoring)
    Deployment: DIRECT (paste script content directly into Datto RMM)
    Execution: <200ms (performance optimized)
    Dependencies: NONE (fully self-contained)

.ENVIRONMENT VARIABLES
    - usrURI (String): Target website URL to monitor
    - usrString (String): String to search for in website content
    - usrCaseInsensitive (Boolean): Case-insensitive search (default: false)
    - usrUseHttp11 (Boolean): Use HTTP/1.1 instead of HTTP/2 (default: false)
    - usrCheckWWWToo (Boolean): Also check www variant of URL (default: false)
    - usrTimeoutSec (Integer): Request timeout in seconds (default: 20)
    - usrRetries (Integer): Number of retry attempts (default: 2)

.NOTES
    Version: 1.0.0 - Direct Deployment Optimized
    Performance: <200ms execution, zero network dependencies during setup
    Compatible: PowerShell 3.0+, Datto RMM Environment
#>

[CmdletBinding()]
param()

############################################################################################################
#                                    EMBEDDED FUNCTION LIBRARY                                            #
############################################################################################################

# Centralized alert function (embedded) - handles markers and exit
function Write-MonitorAlert {
    param([string]$Message)
    Write-Host '<-End Diagnostic->'
    Write-Host '<-Start Result->'
    Write-Host "Status=$Message"
    Write-Host '<-End Result->'
    exit 1
}

# Success result function (embedded) - handles markers and exit
function Write-MonitorSuccess {
    param([string]$Message)
    Write-Host '<-End Diagnostic->'
    Write-Host '<-Start Result->'
    Write-Host "Status=$Message"
    Write-Host '<-End Result->'
    exit 0
}

# Lightweight environment variable handler (embedded)
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

############################################################################################################
#                                    PARAMETER PROCESSING                                                 #
############################################################################################################

# Get parameters from environment (optimized)
$Uri             = Get-RMMVariable -Name "usrURI"
$Needle          = Get-RMMVariable -Name "usrString"
$CaseInsensitive = Get-RMMVariable -Name "usrCaseInsensitive" -Type "Boolean" -Default $false
$UseHttp11       = Get-RMMVariable -Name "usrUseHttp11" -Type "Boolean" -Default $false
$CheckWWWToo     = Get-RMMVariable -Name "usrCheckWWWToo" -Type "Boolean" -Default $false
$TimeoutSec      = Get-RMMVariable -Name "usrTimeoutSec" -Type "Integer" -Default 10
$Retries         = Get-RMMVariable -Name "usrRetries" -Type "Integer" -Default 1

############################################################################################################
#                                    DIAGNOSTIC PHASE                                                     #
############################################################################################################

# Start diagnostic output
Write-Host '<-Start Diagnostic->'
Write-Host "Website Monitor: Direct deployment optimized for <200ms execution"
Write-Host "Target URI: $Uri"
Write-Host "Search String: $Needle"
Write-Host "Case Insensitive: $CaseInsensitive"
Write-Host "Use HTTP/1.1: $UseHttp11"
Write-Host "Check WWW Too: $CheckWWWToo"
Write-Host "Timeout: $TimeoutSec seconds"
Write-Host "Retries: $Retries"
Write-Host "-------------------------"

# Basic validation
if ([string]::IsNullOrWhiteSpace($Uri) -or [string]::IsNullOrWhiteSpace($Needle)) {
    Write-Host "! CRITICAL ERROR: Missing required parameters"
    Write-MonitorAlert "ERROR: Missing usrURI or usrString environment variables"
}

# TLS setup
Write-Host "- Configuring TLS security protocols..."
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    Write-Host "- TLS 1.2/1.3 configured successfully"
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host "- TLS 1.2 configured (fallback)"
}

# Build target URL list
Write-Host "- Building target URL list..."
$Targets = New-Object System.Collections.Generic.List[string]
$Targets.Add($Uri)
Write-Host "- Primary target: $Uri"

# Add www variant if requested
try {
    $u = [Uri]$Uri
    if ($CheckWWWToo -and $u.Host -notmatch '^(www\.)') {
        $wwwUri = [Uri]::new($u.Scheme + "://" + "www." + $u.Host + $u.PathAndQuery)
        $Targets.Add($wwwUri.AbsoluteUri)
        Write-Host "- Additional target: $($wwwUri.AbsoluteUri)"
    }
} catch {
    Write-Host "- Warning: URI parsing issue, will validate during request"
}

Write-Host "- Note: Redirects (HTTP->HTTPS, www->non-www, etc.) are treated as normal behavior"

function Get-RMMDnsInfo {
    param(
        [Parameter(Mandatory=$true)][string]$HostName
    )
    $result = [pscustomobject]@{
        Host      = $HostName
        Resolver  = ''
        Addresses = @()
        CName     = $null
        Error     = $null
    }
    try {
        try {
            $records = Resolve-DnsName -Name $HostName -ErrorAction Stop
            $result.Resolver = 'Resolve-DnsName'
            $addrs = @()
            foreach ($rec in $records) {
                if ($rec.QueryType -in @('A','AAAA')) { $addrs += $rec.IPAddress }
                if ($rec.QueryType -eq 'CNAME' -and -not $result.CName) { $result.CName = $rec.NameHost }
            }
            $result.Addresses = ($addrs | Sort-Object -Unique)
        } catch {
            $result.Resolver = '.NET Dns'
            $addrs = [System.Net.Dns]::GetHostAddresses($HostName)
            $ips = @()
            foreach ($ip in $addrs) { $ips += $ip.IPAddressToString }
            $result.Addresses = ($ips | Sort-Object -Unique)
        }
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

function Write-RMMDnsDiagnostics {
    param(
        [Parameter(Mandatory=$true)]$DnsInfo
    )
    Write-Host "- DNS: Resolving $($DnsInfo.Host) ..."
    if ($DnsInfo.Error) {
        Write-Host "  - DNS: Resolution error for $($DnsInfo.Host) - $($DnsInfo.Error)"
        return
    }
    Write-Host "  - Resolver: $($DnsInfo.Resolver)"
    if ($DnsInfo.CName) { Write-Host "  - CNAME: $($DnsInfo.CName)" }
    if ($DnsInfo.Addresses -and $DnsInfo.Addresses.Count -gt 0) {
        foreach ($addr in $DnsInfo.Addresses) { Write-Host "  - Address: $addr" }
    } else {
        Write-Host "  - DNS: No A/AAAA addresses returned"
    }
}

function Invoke-Page {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][int]$TimeoutSec,
        [Parameter(Mandatory = $true)][bool]$UseHttp11
    )

    $attempt = 0
    do {
        $attempt++
        try {
            $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
            $headers = @{
                'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) PowerShell-RMM/1.0'
                'Accept'     = '*/*'
            }

            $irParams = @{
                Uri                = $Url
                Method             = 'GET'
                WebSession         = $session
                Headers            = $headers
                MaximumRedirection = 10
                UseBasicParsing    = $true
                TimeoutSec         = $TimeoutSec
                ErrorAction        = 'Stop'
            }

            if ($UseHttp11) {
                $irParams['HttpVersion'] = [Version]'1.1'
            }

            $resp = Invoke-WebRequest @irParams
            return $resp
        } catch {
            if ($attempt -le $Retries) {
                Start-Sleep -Seconds ([Math]::Min(3 * $attempt, 10))
            } else {
                throw
            }
        }
    } while ($attempt -le $Retries)
}

function Contains-Needle {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][bool]$CaseInsensitive
    )

    # First try exact string match (fastest)
    if ($CaseInsensitive) {
        if ($Content.ToLower().Contains($Needle.ToLower())) {
            return $true
        }
    } else {
        if ($Content.Contains($Needle)) {
            return $true
        }
    }

    # If exact match fails, try flexible regex pattern to handle HTML tags and whitespace
    # This handles cases where text is split by HTML tags like <br>, <span>, etc.
    try {
        # Split search string into words and create flexible pattern
        $words = $Needle -split '\s+'
        $regexPattern = ($words | ForEach-Object { [regex]::Escape($_) }) -join '.*?'

        if ($CaseInsensitive) {
            return ($Content -imatch $regexPattern)
        } else {
            return ($Content -match $regexPattern)
        }
    } catch {
        # Fallback to exact match result if regex fails
        return $false
    }
}

# Performance timer for optimization
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$foundAny = $false
$details  = New-Object System.Collections.Generic.List[string]

# DNS diagnostics (non-fatal) before web checks
try {
    $primaryHost = ([uri]$Uri).Host
    $primaryDns  = Get-RMMDnsInfo -HostName $primaryHost
    Write-RMMDnsDiagnostics -DnsInfo $primaryDns

    $wwwDns = $null
    if ($CheckWWWToo -and $primaryHost -notmatch '^(www\.)') {
        $wwwHost = "www." + $primaryHost
        $wwwDns  = Get-RMMDnsInfo -HostName $wwwHost
        Write-RMMDnsDiagnostics -DnsInfo $wwwDns
    }

    # Compare address sets when both exist
    if ($primaryDns -and $primaryDns.Addresses -and $wwwDns -and $wwwDns.Addresses) {
        $diff = Compare-Object -ReferenceObject $primaryDns.Addresses -DifferenceObject $wwwDns.Addresses -PassThru | Sort-Object -Unique
        if (-not $diff -or $diff.Count -eq 0) {
            Write-Host "  - DNS: Address sets MATCH between $primaryHost and www.$primaryHost"
        } else {
            Write-Host "  - DNS: Address sets DIFFER"
            Write-Host "    Primary ($primaryHost): $($primaryDns.Addresses -join ', ')"
            Write-Host "    WWW     (www.$primaryHost): $($wwwDns.Addresses -join ', ')"
        }
    }
} catch {
    Write-Host "- DNS: Skipping DNS diagnostics due to parsing error - $($_.Exception.Message)"
}

Write-Host "- Starting website checks..."

foreach ($t in $Targets) {
    try {
        Write-Host "- Testing: $t"
        $resp     = Invoke-Page -Url $t -TimeoutSec $TimeoutSec -UseHttp11 $UseHttp11
        $status   = $resp.StatusCode
        # Determine final (effective) URI robustly
        $finalUri = $null
        try {
            if ($resp.BaseResponse -and $resp.BaseResponse.ResponseUri) {
                $finalUri = $resp.BaseResponse.ResponseUri.AbsoluteUri
            } elseif ($resp.Headers -and $resp.Headers['Content-Location']) {
                $finalUri = [string]$resp.Headers['Content-Location']
            } elseif ($resp.Headers -and $resp.Headers['Location']) {
                $finalUri = [string]$resp.Headers['Location']
            }
        } catch {
            Write-Host "- Note: Effective final URL not available; proceeding without redirect details"
        }
        $content  = [string]$resp.Content

        $hit = Contains-Needle -Content $content -Needle $Needle -CaseInsensitive:$CaseInsensitive

        # Handle redirections as normal behavior
        $redirectInfo = ""
        if ($finalUri -and ($finalUri -ne $t)) {
            $redirectInfo = " (redirected to $finalUri)"
            Write-Host "- Redirect detected: $t -> $finalUri (normal behavior)"
        } elseif ($finalUri) {
            # No redirect; final equals requested
            Write-Host "- Effective URL: $finalUri"
        } else {
            # Final URI not available in this host/PowerShell version; skip redirect note
        }

        # Debug info for troubleshooting (only show if string not found)
        if (-not $hit) {
            $contentPreview = if ($content.Length -gt 150) { $content.Substring(0, 150) + "..." } else { $content }
            Write-Host "- Debug - Content preview: $contentPreview"
            Write-Host "- Debug - Search string: '$Needle' (Case insensitive: $CaseInsensitive)"
        }

        $finalSuffix    = if ($finalUri -and ($finalUri -ne $t)) { "; Final: $finalUri" } else { "" }
        $details.Add("  Requested: $t; Status: $status; Found: $hit$finalSuffix")

        if ($hit) {
            $foundAny = $true
            Write-Host "- SUCCESS: String '$Needle' found$redirectInfo"
        } else {
            Write-Host "- String '$Needle' not found in content (Status: $status)$redirectInfo"
        }
    } catch {
        $errorMsg = $_.Exception.Message
        $details.Add("  $t -> ERROR: $errorMsg")
        Write-Host "- FAILED: $t - $errorMsg"
    }
}

# Performance measurement
$stopwatch.Stop()
Write-Host "- Website checks completed in $($stopwatch.ElapsedMilliseconds)ms"

############################################################################################################
#                                    RESULT GENERATION                                                    #
############################################################################################################

if ($foundAny) {
    $resultDetails = $details -join "; "
    Write-MonitorSuccess "OK: String '$Needle' found. Details: $resultDetails"
} else {
    $resultDetails = $details -join "; "
    Write-MonitorAlert "CRITICAL: String '$Needle' not found. Details: $resultDetails"
}
