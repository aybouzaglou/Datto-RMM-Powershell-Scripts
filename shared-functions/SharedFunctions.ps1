<#
.SYNOPSIS
Datto RMM Shared Functions Loader - Master loader for GitHub-based function library

.DESCRIPTION
Downloads and loads all shared function modules from GitHub with intelligent caching:
- Downloads function modules from GitHub repository
- Implements local caching with expiry for performance
- Supports version pinning and branch selection
- Provides fallback mechanisms for offline scenarios
- Validates function loading and provides diagnostics

.PARAMETER GitHubRepo
GitHub repository in format "owner/repo" (default: auto-detected from current repo)

.PARAMETER Branch
Git branch or tag to use (default: "main")

.PARAMETER ForceDownload
Force re-download even if cached files exist

.PARAMETER CacheExpiryHours
Cache expiry time in hours (default: 1)

.PARAMETER OfflineMode
Use only cached files, don't attempt downloads

.EXAMPLE
# Basic usage (auto-detects repository)
. .\SharedFunctions.ps1

# Specify repository and branch
. .\SharedFunctions.ps1 -GitHubRepo "myorg/rmm-scripts" -Branch "v2.1.0"

# Force refresh
. .\SharedFunctions.ps1 -ForceDownload

.NOTES
Version: 3.0.0
Author: Datto RMM Function Library
Compatible: PowerShell 2.0+, Datto RMM Environment
#>

param(
    [string]$GitHubRepo = "aybouzaglou/Datto-RMM-Powershell-Scripts",
    [string]$Branch = "main",
    [switch]$ForceDownload,
    [int]$CacheExpiryHours = 1,
    [switch]$OfflineMode
)

# Configuration
$BaseURL = "https://raw.githubusercontent.com/$GitHubRepo/$Branch/shared-functions"
$LocalCacheDir = "$env:TEMP\RMM-Functions"
$CacheExpiry = $CacheExpiryHours * 3600 # Convert to seconds

# Ensure cache directory exists
if (-not (Test-Path $LocalCacheDir)) {
    New-Item -Path $LocalCacheDir -ItemType Directory -Force | Out-Null
}

# Initialize basic logging if not already available
if (-not (Get-Command Write-RMMLog -ErrorAction SilentlyContinue)) {
    function Write-RMMLog {
        param([string]$Message, [string]$Level = 'Info')
        $prefix = switch ($Level) {
            'Success' { 'SUCCESS ' }
            'Failed'  { 'FAILED  ' }
            'Warning' { 'WARNING ' }
            'Status'  { 'STATUS  ' }
            'Config'  { 'CONFIG  ' }
            'Info'    { 'INFO    ' }
            default   { 'INFO    ' }
        }
        Write-Output "$prefix$Message"
    }
}

function Get-FunctionFromGitHub {
    <#
    .SYNOPSIS
    Downloads and loads a function module from GitHub
    #>
    param(
        [string]$FunctionFile,
        [string]$SubFolder = ""
    )
    
    $url = if ($SubFolder) {
        "$BaseURL/$SubFolder/$FunctionFile"
    } else {
        "$BaseURL/$FunctionFile"
    }
    
    $localPath = Join-Path $LocalCacheDir $FunctionFile
    $downloadNeeded = $ForceDownload -or $OfflineMode -eq $false
    
    # Check if we need to download (cache expired or doesn't exist)
    if (Test-Path $localPath) {
        $fileAge = (Get-Date) - (Get-Item $localPath).LastWriteTime
        if ($fileAge.TotalSeconds -gt $CacheExpiry) {
            $downloadNeeded = $true
        } else {
            $downloadNeeded = $false
        }
    } else {
        $downloadNeeded = $true
    }
    
    # Skip download in offline mode
    if ($OfflineMode) {
        $downloadNeeded = $false
    }
    
    if ($downloadNeeded -and -not $OfflineMode) {
        try {
            # Set TLS 1.2 for secure downloads
            [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
            
            Write-RMMLog "Downloading function module: $FunctionFile" -Level Status
            (New-Object System.Net.WebClient).DownloadFile($url, $localPath)
            Write-RMMLog "Downloaded: $FunctionFile" -Level Success
        } catch {
            Write-RMMLog "Failed to download $FunctionFile from GitHub: $($_.Exception.Message)" -Level Warning
            
            # Check if we have a cached version to fall back to
            if (-not (Test-Path $localPath)) {
                return $false
            }
            Write-RMMLog "Using cached version of $FunctionFile" -Level Warning
        }
    }
    
    # Load the function file
    if (Test-Path $localPath) {
        try {
            . $localPath
            Write-RMMLog "Loaded function module: $FunctionFile" -Level Success
            return $true
        } catch {
            Write-RMMLog "Failed to load $FunctionFile`: $($_.Exception.Message)" -Level Failed
            return $false
        }
    } else {
        Write-RMMLog "Function module not available: $FunctionFile" -Level Failed
        return $false
    }
}

function Test-FunctionAvailability {
    <#
    .SYNOPSIS
    Tests if expected functions are available after loading
    #>
    param([string[]]$ExpectedFunctions)
    
    $availableFunctions = @()
    $missingFunctions = @()
    
    foreach ($functionName in $ExpectedFunctions) {
        if (Get-Command $functionName -ErrorAction SilentlyContinue) {
            $availableFunctions += $functionName
        } else {
            $missingFunctions += $functionName
        }
    }
    
    if ($missingFunctions.Count -gt 0) {
        Write-RMMLog "Missing functions: $($missingFunctions -join ', ')" -Level Warning
    }
    
    return [PSCustomObject]@{
        Available = $availableFunctions
        Missing = $missingFunctions
        LoadSuccess = $missingFunctions.Count -eq 0
    }
}

# Start loading process
Write-RMMLog "Loading Datto RMM Function Library from GitHub..." -Level Status
Write-RMMLog "Repository: $GitHubRepo" -Level Config
Write-RMMLog "Branch: $Branch" -Level Config
Write-RMMLog "Cache Directory: $LocalCacheDir" -Level Config
Write-RMMLog "Cache Expiry: $CacheExpiryHours hours" -Level Config
Write-RMMLog "Offline Mode: $OfflineMode" -Level Config

# Define function modules to load
$coreModules = @(
    @{ File = "RMMLogging.ps1"; Folder = "Core"; Functions = @("Write-RMMLog", "Start-RMMTranscript", "Stop-RMMTranscript", "Write-RMMMonitorResult", "Write-RMMEventLog") },
    @{ File = "RMMValidation.ps1"; Folder = "Core"; Functions = @("Get-RMMVariable", "Test-RMMVariable", "Invoke-RMMTimeout", "Test-RMMSystemRequirements", "Test-RMMInternetConnectivity") },
    @{ File = "RMMSoftwareDetection.ps1"; Folder = "Core"; Functions = @("Get-RMMSoftware", "Test-RMMSoftwareInstalled", "Get-RMMManufacturer", "Remove-RMMSoftware") }
)

$utilityModules = @(
    @{ File = "NetworkUtils.ps1"; Folder = "Utilities"; Functions = @("Set-RMMSecurityProtocol", "Invoke-RMMDownload", "Test-RMMUrl", "Get-RMMPublicIP", "Test-RMMPort") },
    @{ File = "FileOperations.ps1"; Folder = "Utilities"; Functions = @("New-RMMDirectory", "Remove-RMMDirectory", "Copy-RMMFile", "Expand-RMMArchive", "Stop-RMMProcess", "Get-RMMTempPath") },
    @{ File = "RegistryHelpers.ps1"; Folder = "Utilities"; Functions = @("Get-RMMRegistryValue", "Set-RMMRegistryValue", "Remove-RMMRegistryValue", "Test-RMMRegistryPath", "Get-RMMUninstallInfo", "Backup-RMMRegistryKey") }
)

$loadedCount = 0
$totalModules = $coreModules.Count + $utilityModules.Count
$allExpectedFunctions = @()

# Load core modules
Write-RMMLog "Loading Core modules..." -Level Status
foreach ($module in $coreModules) {
    if (Get-FunctionFromGitHub -FunctionFile $module.File -SubFolder $module.Folder) {
        $loadedCount++
        $allExpectedFunctions += $module.Functions
    }
}

# Load utility modules
Write-RMMLog "Loading Utility modules..." -Level Status
foreach ($module in $utilityModules) {
    if (Get-FunctionFromGitHub -FunctionFile $module.File -SubFolder $module.Folder) {
        $loadedCount++
        $allExpectedFunctions += $module.Functions
    }
}

# Test function availability
$functionTest = Test-FunctionAvailability -ExpectedFunctions $allExpectedFunctions

# Report loading results
Write-RMMLog "Function Library Loading Complete" -Level Status
Write-RMMLog "Modules loaded: $loadedCount of $totalModules" -Level Config
Write-RMMLog "Functions available: $($functionTest.Available.Count) of $($allExpectedFunctions.Count)" -Level Config

if ($functionTest.Missing.Count -gt 0) {
    Write-RMMLog "Some functions failed to load. Check network connectivity and repository access." -Level Warning
} else {
    Write-RMMLog "All functions loaded successfully!" -Level Success
}

# Set global variables to indicate library status
$Global:RMMFunctionsLoaded = $functionTest.LoadSuccess
$Global:RMMFunctionsVersion = "3.0.0"
$Global:RMMFunctionsSource = "GitHub:$GitHubRepo@$Branch"
$Global:RMMFunctionsLoadedCount = $functionTest.Available.Count
$Global:RMMFunctionsMissingCount = $functionTest.Missing.Count
$Global:RMMFunctionsCacheDir = $LocalCacheDir

# Provide usage information
if ($Global:RMMFunctionsLoaded) {
    Write-RMMLog "Ready to use! Example: Write-RMMLog 'Hello World' -Level Success" -Level Info
} else {
    Write-RMMLog "Partial load. Some functions may not be available." -Level Warning
}

# Export status information for scripts to check
$Global:RMMFunctionsStatus = [PSCustomObject]@{
    Loaded = $Global:RMMFunctionsLoaded
    Version = $Global:RMMFunctionsVersion
    Source = $Global:RMMFunctionsSource
    LoadedCount = $Global:RMMFunctionsLoadedCount
    MissingCount = $Global:RMMFunctionsMissingCount
    CacheDirectory = $Global:RMMFunctionsCacheDir
    AvailableFunctions = $functionTest.Available
    MissingFunctions = $functionTest.Missing
}
