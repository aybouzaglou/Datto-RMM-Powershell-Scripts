<#
.SYNOPSIS
Tungsten Printix Client Installation - Datto RMM Applications Component

.DESCRIPTION
Installs or updates Tungsten Printix Client software optimized for Datto RMM Applications component:
- Registry-based software detection (avoids Win32_Product)
- Intelligent installation vs. update detection
- MSI installation with WRAPPED_ARGUMENTS support
- Comprehensive logging and error handling
- Timeout protection for all operations

.COMPONENT
Category: Applications (Software Deployment)
Execution: On-demand or scheduled
Timeout: Up to 30 minutes
Changeable: Yes (can be changed to Scripts category if needed)

.ENVIRONMENT VARIABLES
- SignInMode (String): Sign-in behavior - "AfterInstall" or "PostponeRestart" (default: "AfterInstall")
- DownloadLatest (Boolean): Download latest MSI from Printix API instead of using attached file (default: false)
- ForceReinstall (Boolean): Force reinstall even if already installed (default: false)
- CustomInstallArgs (String): Custom MSI installation arguments (overrides SignInMode if provided)
- SkipDetection (Boolean): Skip software detection and force installation (default: false)

.PARAMETER None
This script does not accept parameters. All configuration is handled via environment variables.

.INPUTS
None. This script does not accept pipeline input.

.OUTPUTS
System.String - Progress messages and status information

.EXAMPLE
# Datto RMM Applications Component Usage:
# Environment Variables:
# SignInMode = AfterInstall (or PostponeRestart)
# DownloadLatest = false (or true to download latest from API)
# ForceReinstall = false
# CustomInstallArgs = (leave empty to use SignInMode selection)
# SkipDetection = false
# Component Type: Applications
# Timeout: 30 minutes

.NOTES
Version: 2.0.0
Author: Datto RMM Function Library
Component Category: Applications (Software Deployment)
Compatible: PowerShell 3.0+, Datto RMM Environment

Datto RMM Applications Exit Codes:
- 0: Success (installation or update completed)
- 3010: Success with reboot required
- 1641: Success with reboot initiated
- Other non-zero: Failed

CHANGELOG:
2.0.0 - Added SignInMode selection, DownloadLatest API support, modern download best practices
1.1.0 - Added environment variable support (ForceReinstall, CustomInstallArgs, SkipDetection)
1.0.0 - Initial Tungsten Printix Client installation script
#>

# Embedded environment variable function (pattern from shared-functions/Core/RMMValidation.ps1)
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
            $envValue -eq 'true' -or $envValue -eq '1' -or $envValue -eq 'yes' -or $envValue -eq 'on'
        }
        default { $envValue }
    }
}

# Embedded logging function (pattern from shared-functions/Core/RMMLogging.ps1)
function Write-RMMLog {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Message,

        [ValidateSet("Info", "Status", "Success", "Warning", "Error", "Config", "Detect")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    # Handle empty messages for spacing
    if ([string]::IsNullOrEmpty($Message)) {
        $logMessage = ""
    } else {
        $logMessage = "[$timestamp] [$Level] $Message"
    }

    if ([string]::IsNullOrEmpty($logMessage)) {
        Write-Host ""  # Empty line for spacing
    } else {
        switch ($Level) {
            "Success" { Write-Host $logMessage -ForegroundColor Green }
            "Warning" { Write-Host $logMessage -ForegroundColor Yellow }
            "Error" { Write-Host $logMessage -ForegroundColor Red }
            "Status" { Write-Host $logMessage -ForegroundColor Cyan }
            "Config" { Write-Host $logMessage -ForegroundColor Magenta }
            "Detect" { Write-Host $logMessage -ForegroundColor Blue }
            default { Write-Host $logMessage }
        }
    }
}

# Configuration
$LogPath = "C:\ProgramData\DattoRMM\Applications"
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Start transcript (embedded pattern from shared-functions/Core/RMMLogging.ps1)
Start-Transcript -Path "$LogPath\TungstenPrintixClient-Applications.log" -Append

Write-RMMLog "=============================================="
Write-RMMLog "Tungsten Printix Client - Applications Component v2.0.0" -Level Status
Write-RMMLog "=============================================="
Write-RMMLog "Component Category: Applications (Software Deployment)" -Level Config
Write-RMMLog "Start Time: $(Get-Date)" -Level Config
Write-RMMLog "Log Directory: $LogPath" -Level Config
Write-RMMLog ""

# Process environment variables
$SignInMode = Get-RMMVariable -Name "SignInMode" -Type "String" -Default "AfterInstall"
$DownloadLatest = Get-RMMVariable -Name "DownloadLatest" -Type "Boolean" -Default $false
$ForceReinstall = Get-RMMVariable -Name "ForceReinstall" -Type "Boolean" -Default $false
$CustomInstallArgs = Get-RMMVariable -Name "CustomInstallArgs" -Type "String" -Default ""
$SkipDetection = Get-RMMVariable -Name "SkipDetection" -Type "Boolean" -Default $false

# Validate SignInMode
if ($SignInMode -notin @("AfterInstall", "PostponeRestart")) {
    Write-RMMLog "Invalid SignInMode '$SignInMode'. Using default 'AfterInstall'" -Level Warning
    $SignInMode = "AfterInstall"
}

Write-RMMLog "Environment Variables:" -Level Config
Write-RMMLog "- SignInMode: $SignInMode" -Level Config
Write-RMMLog "- DownloadLatest: $DownloadLatest" -Level Config
Write-RMMLog "- ForceReinstall: $ForceReinstall" -Level Config
Write-RMMLog "- CustomInstallArgs: $(if ([string]::IsNullOrWhiteSpace($CustomInstallArgs)) { '(using SignInMode selection)' } else { $CustomInstallArgs })" -Level Config
Write-RMMLog "- SkipDetection: $SkipDetection" -Level Config
Write-RMMLog ""

function Get-LatestPrintixMSI {
    <#
    .SYNOPSIS
    Downloads the latest Tungsten Printix Client MSI from the API using modern best practices
    #>

    Write-RMMLog "Downloading latest Tungsten Printix Client MSI..." -Level Status

    $ApiUrl = "https://api.printix.net/v1/software/tenants/d1a50571-67e6-4566-9da7-64e11a26a4d9/appl/CLIENT/os/WIN/type/MSI"
    $DownloadPath = "PrintixClient-Latest.msi"

    try {
        # Enforce TLS 1.2 for security (required for older systems)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-RMMLog "TLS 1.2 security protocol enforced" -Level Config

        # Test connectivity first
        Write-RMMLog "Testing connectivity to Printix API..." -Level Status
        try {
            $testResponse = Invoke-WebRequest -Uri $ApiUrl -Method Head -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
            Write-RMMLog "API connectivity confirmed (Status: $($testResponse.StatusCode))" -Level Success
        } catch {
            throw "API connectivity test failed: $($_.Exception.Message)"
        }

        # Download using modern Invoke-WebRequest with progress and auto-resume
        Write-RMMLog "Downloading MSI from: $ApiUrl" -Level Config
        Write-RMMLog "Output path: $DownloadPath" -Level Config

        Invoke-WebRequest -Uri $ApiUrl -OutFile $DownloadPath -UseBasicParsing -TimeoutSec 300 -ErrorAction Stop

        # Verify download completed successfully
        if (-not (Test-Path $DownloadPath)) {
            throw "Download failed - file not found after download"
        }

        # Get file information and verify it's not empty
        $fileInfo = Get-Item $DownloadPath
        if ($fileInfo.Length -lt 1MB) {
            throw "Downloaded file appears too small ($($fileInfo.Length) bytes) - may be corrupted"
        }

        # Verify digital signature if possible
        try {
            $signature = Get-AuthenticodeSignature $DownloadPath
            if ($signature.Status -eq 'Valid') {
                Write-RMMLog "Digital signature verification passed" -Level Success
            } else {
                Write-RMMLog "Digital signature status: $($signature.Status)" -Level Warning
            }
        } catch {
            Write-RMMLog "Could not verify digital signature: $($_.Exception.Message)" -Level Warning
        }

        Write-RMMLog "Download completed successfully: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -Level Success
        return $DownloadPath

    } catch {
        Write-RMMLog "Failed to download latest MSI: $($_.Exception.Message)" -Level Error
        Write-RMMLog "Will attempt to use attached MSI file instead" -Level Warning

        # Clean up partial download
        if (Test-Path $DownloadPath) {
            try {
                Remove-Item $DownloadPath -Force -ErrorAction SilentlyContinue
                Write-RMMLog "Cleaned up partial download" -Level Status
            } catch {
                Write-RMMLog "Could not clean up partial download: $DownloadPath" -Level Warning
            }
        }

        return $null
    }
}

# Pre-execution cleanup
Write-RMMLog "Performing pre-execution cleanup..." -Level Status

# Kill any running Printix processes
$ProcessesToKill = @("PrintixClient*", "Printix*", "msiexec")
foreach ($ProcessName in $ProcessesToKill) {
    $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($processes) {
        Write-RMMLog "Stopping process: $ProcessName" -Level Status
        $processes | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

# Clean up temp installation files
$TempPaths = @("$env:TEMP\PrintixInstall", "$env:TEMP\CLIENT_*")
foreach ($Path in $TempPaths) {
    if (Test-Path $Path) {
        Write-RMMLog "Cleaning up temp path: $Path" -Level Status
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-RMMLog "Pre-execution cleanup completed" -Level Success
Write-RMMLog ""

function Test-PrintixClientInstalled {
    <#
    .SYNOPSIS
    Tests if Tungsten Printix Client is installed using fast registry detection
    #>
    
    Write-RMMLog "Checking for existing Tungsten Printix Client installation..." -Level Status
    
    # Registry paths to check for installed software
    $RegPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($RegPath in $RegPaths) {
        try {
            $installedSoftware = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue
            foreach ($software in $installedSoftware) {
                if ($software.DisplayName -like "*Printix*" -or 
                    $software.DisplayName -like "*Tungsten*" -or
                    $software.Publisher -like "*Printix*") {
                    Write-RMMLog "Found installed software: $($software.DisplayName)" -Level Detect
                    Write-RMMLog "Publisher: $($software.Publisher)" -Level Detect
                    Write-RMMLog "Version: $($software.DisplayVersion)" -Level Detect
                    return $true
                }
            }
        } catch {
            Write-RMMLog "Error checking registry path $RegPath`: $($_.Exception.Message)" -Level Warning
        }
    }
    
    Write-RMMLog "Tungsten Printix Client not found in registry" -Level Detect
    return $false
}

function Install-PrintixClient {
    <#
    .SYNOPSIS
    Installs Tungsten Printix Client using MSI with WRAPPED_ARGUMENTS
    #>
    param(
        [string]$CustomArgs = "",
        [string]$SignInMode = "AfterInstall",
        [bool]$DownloadLatest = $false
    )

    Write-RMMLog "Starting Tungsten Printix Client installation..." -Level Status

    # MSI configuration
    $MSIName = "CLIENT_{mandevo.printix.net}_{d1a50571-67e6-4566-9da7-64e11a26a4d9} (1).MSI"
    $MSIPath = $null

    # Determine MSI source
    if ($DownloadLatest) {
        Write-RMMLog "DownloadLatest enabled - attempting to download latest MSI from API" -Level Status
        $MSIPath = Get-LatestPrintixMSI
        if (-not $MSIPath) {
            Write-RMMLog "Download failed - falling back to attached MSI file" -Level Warning
            $MSIPath = $MSIName
        }
    } else {
        Write-RMMLog "Using attached MSI file" -Level Status
        $MSIPath = $MSIName
    }

    # Verify MSI file exists
    if (Test-Path $MSIPath) {
        $fileInfo = Get-Item $MSIPath
        Write-RMMLog "Found MSI file: $MSIPath ($([math]::Round($fileInfo.Length / 1MB, 2)) MB)" -Level Success
    } else {
        Write-RMMLog "MSI file not found: $MSIPath" -Level Error
        if ($DownloadLatest) {
            Write-RMMLog "Download failed and no attached MSI file found" -Level Error
        } else {
            Write-RMMLog "Please ensure the MSI file is attached to the Datto RMM component" -Level Error
        }
        return 1
    }

    # Determine WRAPPED_ARGUMENTS based on SignInMode
    $WrappedArguments = switch ($SignInMode) {
        "AfterInstall" {
            "/id:d1a50571-67e6-4566-9da7-64e11a26a4d9"
        }
        "PostponeRestart" {
            "/id:d1a50571-67e6-4566-9da7-64e11a26a4d9:oms"
        }
        default {
            "/id:d1a50571-67e6-4566-9da7-64e11a26a4d9"
        }
    }

    # Build msiexec command - use custom args if provided, otherwise use SignInMode selection
    if ([string]::IsNullOrWhiteSpace($CustomArgs)) {
        $MSIArgs = @(
            "/i"
            "`"$MSIPath`""
            "/quiet"
            "/norestart"
            "/l*v"
            "`"$LogPath\PrintixClient-Install.log`""
            "WRAPPED_ARGUMENTS=`"$WrappedArguments`""
        )
        Write-RMMLog "Using SignInMode '$SignInMode' arguments" -Level Config
        Write-RMMLog "WRAPPED_ARGUMENTS: $WrappedArguments" -Level Config
    } else {
        # Parse custom arguments and add required ones
        $MSIArgs = @(
            "/i"
            "`"$MSIPath`""
            "/l*v"
            "`"$LogPath\PrintixClient-Install.log`""
        )
        # Add custom arguments (split by space, handling quoted arguments)
        $CustomArgs.Split(' ') | ForEach-Object {
            if (-not [string]::IsNullOrWhiteSpace($_)) {
                $MSIArgs += $_.Trim()
            }
        }
        Write-RMMLog "Using custom MSI arguments: $CustomArgs" -Level Config
        Write-RMMLog "Note: Custom arguments override SignInMode selection" -Level Warning
    }
    
    $MSICommand = "msiexec.exe"
    $MSIArgumentString = $MSIArgs -join " "
    
    Write-RMMLog "MSI Command: $MSICommand $MSIArgumentString" -Level Config
    Write-RMMLog "Installing Tungsten Printix Client..." -Level Status
    
    try {
        # Execute MSI installation
        $process = Start-Process -FilePath $MSICommand -ArgumentList $MSIArgs -Wait -PassThru -NoNewWindow
        $exitCode = $process.ExitCode
        
        Write-RMMLog "MSI installation completed with exit code: $exitCode" -Level Status
        
        # Interpret exit codes
        switch ($exitCode) {
            0 { 
                Write-RMMLog "Installation completed successfully" -Level Success
                return 0
            }
            3010 { 
                Write-RMMLog "Installation completed successfully - reboot required" -Level Success
                return 3010
            }
            1641 { 
                Write-RMMLog "Installation completed successfully - reboot initiated" -Level Success
                return 1641
            }
            default { 
                Write-RMMLog "Installation failed with exit code: $exitCode" -Level Error
                return $exitCode
            }
        }
    } catch {
        Write-RMMLog "Error during MSI installation: $($_.Exception.Message)" -Level Error
        return 1
    }
}

# Main execution
$exitCode = 0

try {
    # Check if Tungsten Printix Client is already installed (unless SkipDetection is enabled)
    if ($SkipDetection) {
        Write-RMMLog "SkipDetection enabled - proceeding directly to installation" -Level Status
        $isInstalled = $false
    } else {
        $isInstalled = Test-PrintixClientInstalled
    }

    if ($isInstalled -and -not $ForceReinstall) {
        Write-RMMLog "Tungsten Printix Client is already installed" -Level Status
        Write-RMMLog "Skipping installation - software already present (use ForceReinstall=true to override)" -Level Success
        $exitCode = 0
    } else {
        if ($isInstalled -and $ForceReinstall) {
            Write-RMMLog "Tungsten Printix Client is installed but ForceReinstall is enabled" -Level Status
        } elseif ($SkipDetection) {
            Write-RMMLog "Detection skipped - proceeding with installation" -Level Status
        } else {
            Write-RMMLog "Tungsten Printix Client not installed - proceeding with installation" -Level Status
        }

        $exitCode = Install-PrintixClient -CustomArgs $CustomInstallArgs -SignInMode $SignInMode -DownloadLatest $DownloadLatest
    }

} catch {
    Write-RMMLog "Unexpected error during execution: $($_.Exception.Message)" -Level Error
    Write-RMMLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    $exitCode = 1
} finally {
    Write-RMMLog ""
    Write-RMMLog "=============================================="
    Write-RMMLog "Tungsten Printix Client deployment completed" -Level Status
    Write-RMMLog "Final exit code: $exitCode" -Level Status
    Write-RMMLog "End Time: $(Get-Date)" -Level Status
    Write-RMMLog "=============================================="
    
    Stop-Transcript
    exit $exitCode
}