<#
.SYNOPSIS
Network Utility Functions - Network operations for Datto RMM scripts

.DESCRIPTION
Provides network-related utility functions optimized for Datto RMM environment:
- Secure file downloads with TLS 1.2
- Timeout-protected web requests
- Connectivity testing
- URL validation and parsing
- Download verification and integrity checks

.NOTES
Version: 3.0.0
Author: Datto RMM Function Library
Compatible: PowerShell 5.0+, Datto RMM Environment
#>

function Set-RMMSecurityProtocol {
    <#
    .SYNOPSIS
    Sets TLS 1.2 security protocol for secure downloads
    
    .EXAMPLE
    Set-RMMSecurityProtocol
    #>
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
        Write-RMMLog "TLS 1.2 security protocol enabled" -Level Config
    }
    catch {
        Write-RMMLog "Failed to set TLS 1.2: $($_.Exception.Message)" -Level Warning
    }
}

function Invoke-RMMDownload {
    <#
    .SYNOPSIS
    Downloads files with timeout protection and verification
    
    .PARAMETER Url
    URL to download from
    
    .PARAMETER OutputPath
    Local path to save the file
    
    .PARAMETER TimeoutSec
    Download timeout in seconds (default: 300)
    
    .PARAMETER UserAgent
    User agent string for the request
    
    .PARAMETER VerifySize
    Verify downloaded file size is greater than this value in bytes
    
    .PARAMETER OverwriteExisting
    Whether to overwrite existing files (default: true)
    
    .EXAMPLE
    Invoke-RMMDownload -Url "https://example.com/installer.exe" -OutputPath "$env:TEMP\installer.exe"
    Invoke-RMMDownload -Url "https://example.com/file.zip" -OutputPath "C:\Temp\file.zip" -TimeoutSec 600 -VerifySize 1000000
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [int]$TimeoutSec = 300,
        
        [string]$UserAgent = "Datto-RMM-Script/3.0",
        
        [long]$VerifySize = 0,
        
        [bool]$OverwriteExisting = $true
    )
    
    try {
        # Ensure TLS 1.2 is enabled
        Set-RMMSecurityProtocol
        
        # Check if file exists and handle overwrite
        if ((Test-Path $OutputPath) -and -not $OverwriteExisting) {
            Write-RMMLog "File already exists and overwrite disabled: $OutputPath" -Level Warning
            return $false
        }
        
        # Ensure output directory exists
        $outputDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
            Write-RMMLog "Created output directory: $outputDir" -Level Info
        }
        
        Write-RMMLog "Starting download from: $Url" -Level Status
        Write-RMMLog "Output path: $OutputPath" -Level Status
        Write-RMMLog "Timeout: ${TimeoutSec}s" -Level Config
        
        # Perform download with timeout protection
        $result = Invoke-RMMTimeout -Code {
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", $UserAgent)
            $webClient.DownloadFile($Url, $OutputPath)
        } -TimeoutSec $TimeoutSec -OperationName "Download from $Url"
        
        # Verify download was successful
        if (-not (Test-Path $OutputPath)) {
            throw "Downloaded file not found at $OutputPath"
        }
        
        $fileSize = (Get-Item $OutputPath).Length
        Write-RMMLog "Download completed. File size: $fileSize bytes" -Level Success
        
        # Verify minimum file size if specified
        if ($VerifySize -gt 0 -and $fileSize -lt $VerifySize) {
            throw "Downloaded file size ($fileSize bytes) is smaller than expected minimum ($VerifySize bytes)"
        }
        
        # Basic content verification for PowerShell scripts
        if ($OutputPath -like "*.ps1") {
            $firstLine = Get-Content $OutputPath -TotalCount 1 -ErrorAction SilentlyContinue
            if ($firstLine -and $firstLine -notlike "*#*" -and $firstLine -notlike "*<#*") {
                Write-RMMLog "Warning: Downloaded PowerShell file may not be valid. First line: $firstLine" -Level Warning
            }
        }
        
        return $true
    }
    catch {
        Write-RMMLog "Download failed: $($_.Exception.Message)" -Level Failed
        
        # Clean up partial download
        if (Test-Path $OutputPath) {
            try {
                Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-RMMLog "Could not clean up partial download: $OutputPath" -Level Warning
            }
        }
        
        return $false
    }
}

function Test-RMMUrl {
    <#
    .SYNOPSIS
    Tests if a URL is accessible and returns response information
    
    .PARAMETER Url
    URL to test
    
    .PARAMETER TimeoutSec
    Request timeout in seconds (default: 30)
    
    .PARAMETER Method
    HTTP method to use (default: HEAD for faster testing)
    
    .EXAMPLE
    if (Test-RMMUrl -Url "https://example.com/file.exe") {
        Write-RMMLog "URL is accessible" -Level Info
    }
    
    $urlInfo = Test-RMMUrl -Url "https://example.com/api" -Method GET
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        
        [int]$TimeoutSec = 30,
        
        [ValidateSet('HEAD','GET','POST')]
        [string]$Method = 'HEAD'
    )
    
    try {
        Set-RMMSecurityProtocol
        
        Write-RMMLog "Testing URL accessibility: $Url" -Level Status
        
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Method = $Method
        $request.Timeout = $TimeoutSec * 1000
        $request.UserAgent = "Datto-RMM-Script/3.0"
        
        $response = $request.GetResponse()
        
        $result = [PSCustomObject]@{
            Url = $Url
            StatusCode = $response.StatusCode
            StatusDescription = $response.StatusDescription
            ContentLength = $response.ContentLength
            ContentType = $response.ContentType
            LastModified = $response.LastModified
            IsAccessible = $true
        }
        
        $response.Close()
        
        Write-RMMLog "URL is accessible. Status: $($result.StatusCode)" -Level Success
        return $result
    }
    catch {
        Write-RMMLog "URL test failed for $Url`: $($_.Exception.Message)" -Level Failed
        
        return [PSCustomObject]@{
            Url = $Url
            StatusCode = $null
            StatusDescription = $_.Exception.Message
            ContentLength = -1
            ContentType = $null
            LastModified = $null
            IsAccessible = $false
        }
    }
}

function Get-RMMPublicIP {
    <#
    .SYNOPSIS
    Gets the public IP address of the system
    
    .PARAMETER Service
    IP detection service to use
    
    .PARAMETER TimeoutSec
    Request timeout in seconds
    
    .EXAMPLE
    $publicIP = Get-RMMPublicIP
    Write-RMMLog "Public IP: $publicIP" -Level Info
    #>
    param(
        [ValidateSet('ipify','httpbin','icanhazip')]
        [string]$Service = 'ipify',
        
        [int]$TimeoutSec = 15
    )
    
    $serviceUrls = @{
        'ipify' = 'https://api.ipify.org'
        'httpbin' = 'https://httpbin.org/ip'
        'icanhazip' = 'https://icanhazip.com'
    }
    
    try {
        Set-RMMSecurityProtocol
        
        $url = $serviceUrls[$Service]
        Write-RMMLog "Getting public IP from $Service" -Level Status
        
        $request = [System.Net.WebRequest]::Create($url)
        $request.Timeout = $TimeoutSec * 1000
        $request.UserAgent = "Datto-RMM-Script/3.0"
        
        $response = $request.GetResponse()
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $content = $reader.ReadToEnd()
        $reader.Close()
        $response.Close()
        
        # Parse response based on service
        $ip = switch ($Service) {
            'ipify' { $content.Trim() }
            'httpbin' { ($content | ConvertFrom-Json).origin }
            'icanhazip' { $content.Trim() }
        }
        
        # Validate IP format
        if ($ip -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            Write-RMMLog "Public IP detected: $ip" -Level Success
            return $ip
        } else {
            throw "Invalid IP format received: $ip"
        }
    }
    catch {
        Write-RMMLog "Failed to get public IP from $Service`: $($_.Exception.Message)" -Level Failed
        return $null
    }
}

function Test-RMMPort {
    <#
    .SYNOPSIS
    Tests if a specific port is open on a remote host
    
    .PARAMETER ComputerName
    Target computer name or IP address
    
    .PARAMETER Port
    Port number to test
    
    .PARAMETER TimeoutSec
    Connection timeout in seconds
    
    .EXAMPLE
    if (Test-RMMPort -ComputerName "google.com" -Port 443) {
        Write-RMMLog "HTTPS port is accessible" -Level Info
    }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory=$true)]
        [int]$Port,
        
        [int]$TimeoutSec = 10
    )
    
    try {
        Write-RMMLog "Testing port $Port on $ComputerName" -Level Status
        
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutSec * 1000, $false)
        
        if ($wait) {
            try {
                $tcpClient.EndConnect($asyncResult)
                $tcpClient.Close()
                Write-RMMLog "Port $Port is open on $ComputerName" -Level Success
                return $true
            }
            catch {
                Write-RMMLog "Port $Port is closed on $ComputerName" -Level Info
                return $false
            }
        } else {
            $tcpClient.Close()
            Write-RMMLog "Port $Port test timed out on $ComputerName" -Level Warning
            return $false
        }
    }
    catch {
        Write-RMMLog "Port test failed for ${ComputerName}:${Port}: $($_.Exception.Message)" -Level Failed
        return $false
    }
}

# Export functions for module loading
Export-ModuleMember -Function @(
    'Set-RMMSecurityProtocol',
    'Invoke-RMMDownload',
    'Test-RMMUrl',
    'Get-RMMPublicIP',
    'Test-RMMPort'
)
