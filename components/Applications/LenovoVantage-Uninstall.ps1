<#
.SYNOPSIS
Comprehensive Lenovo Vantage uninstaller for Datto RMM

.DESCRIPTION
This script completely removes Lenovo Vantage and Commercial Vantage using the official VantageInstaller.exe tool.
Handles both consumer and commercial versions, with support for file attachments and automatic download.

Features:
- Supports Datto RMM file attachments (preferred method)
- Falls back to automatic download from Lenovo CDN if no attachment
- Uninstalls both Lenovo Vantage and Commercial Vantage
- Cleans up AppX packages and residual files
- Process termination for clean uninstall
- Comprehensive logging and error handling

.COMPONENT
Category: Applications (Software Removal)
Execution: On-demand
Timeout: 15-20 minutes recommended
Changeable: Yes

.ENVIRONMENT VARIABLES
- InstallerFile (String): Name of attached VantageInstaller.exe file (default: "VantageInstaller.exe")
- InstallerURL (String): Fallback URL for VantageInstaller.exe download (optional)
- ForceKill (Boolean): Force terminate Vantage processes before uninstall (default: true)
- CleanupAppx (Boolean): Remove AppX packages for Vantage (default: true)
- DetailedLogging (Boolean): Enable verbose logging output (default: true)

.EXAMPLES
Example 1 - Using File Attachment (Recommended):
1. Download VantageInstaller.exe from: https://download.lenovo.com/pccbbs/thinkvantage_en/commercial_vantage/VantageInstaller.exe
2. Attach VantageInstaller.exe to the Datto RMM component
3. Set environment variables:
   InstallerFile = VantageInstaller.exe
   ForceKill = true
   CleanupAppx = true

Example 2 - Using Automatic Download:
Environment Variables:
ForceKill = true
CleanupAppx = true
(No InstallerFile specified - will auto-download)

.NOTES
Version: 1.0.0
Author: Datto RMM Self-Contained Architecture
Component Category: Applications (Software Removal)
Compatible: PowerShell 5.0+, Windows 10/11
Deployment: DIRECT (paste script content directly into Datto RMM)

.LINK
https://blog.lenovocdrt.com/deploying-commercial-vantage-with-intune/
#>

[CmdletBinding()]
param()

############################################################################################################
#                                    CONFIGURATION AND INITIALIZATION                                      #
############################################################################################################

# Configuration
$LogPath = "C:\ProgramData\DattoRMM\Applications"
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogPath "LenovoVantageUninstall-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $LogFile -Append

# Environment variable processing
function Get-RMMVariable {
    param(
        [string]$Name,
        [string]$Type = "String",
        $Default = $null
    )

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    switch ($Type) {
        "Boolean" {
            return $value -eq "true" -or $value -eq "1" -or $value -eq "yes"
        }
        "Integer" {
            try { return [int]$value }
            catch { return $Default }
        }
        default {
            return $value
        }
    }
}

# Process environment variables
$InstallerFile = Get-RMMVariable -Name "InstallerFile" -Default "VantageInstaller.exe"
$InstallerURL = Get-RMMVariable -Name "InstallerURL" -Default "https://download.lenovo.com/pccbbs/thinkvantage_en/commercial_vantage/VantageInstaller.exe"
$ForceKill = Get-RMMVariable -Name "ForceKill" -Type "Boolean" -Default $true
$CleanupAppx = Get-RMMVariable -Name "CleanupAppx" -Type "Boolean" -Default $true
$DetailedLogging = Get-RMMVariable -Name "DetailedLogging" -Type "Boolean" -Default $true

# Global variables for installer paths
$AttachedInstallerPath = Join-Path (Get-Location) $InstallerFile
$TempInstallerPath = Join-Path $env:TEMP "VantageInstaller.exe"
$InstallerPath = $null  # Will be determined based on availability

############################################################################################################
#                                    EMBEDDED FUNCTION LIBRARY                                             #
############################################################################################################

function Write-RMMLog {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Status', 'Success', 'Warning', 'Error', 'Failed', 'Config', 'Detect')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    if ([string]::IsNullOrEmpty($Message)) {
        Write-Host ""
        return
    }

    $prefix = switch ($Level) {
        'Success' { 'SUCCESS ' }
        'Failed'  { 'FAILED  ' }
        'Error'   { 'ERROR   ' }
        'Warning' { 'WARNING ' }
        'Status'  { 'STATUS  ' }
        'Config'  { 'CONFIG  ' }
        'Detect'  { 'DETECT  ' }
        default   { 'INFO    ' }
    }

    $logMessage = "[$timestamp] $prefix$Message"

    switch ($Level) {
        'Success' { Write-Host $logMessage -ForegroundColor Green }
        'Failed'  { Write-Host $logMessage -ForegroundColor Red }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Status'  { Write-Host $logMessage -ForegroundColor Cyan }
        'Config'  { Write-Host $logMessage -ForegroundColor Magenta }
        'Detect'  { Write-Host $logMessage -ForegroundColor Blue }
        default   { Write-Host $logMessage }
    }
}

function Test-VantageInstalled {
    <#
    .SYNOPSIS
    Checks if Lenovo Vantage or Commercial Vantage is installed
    #>

    Write-RMMLog "Checking for Lenovo Vantage installation..." -Level Status
    $installed = $false

    # Check registry for installed software
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($regPath in $regPaths) {
        try {
            $apps = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
            foreach ($app in $apps) {
                if ($app.DisplayName -like "*Lenovo Vantage*" -or $app.DisplayName -like "*Commercial Vantage*") {
                    Write-RMMLog "Found: $($app.DisplayName)" -Level Detect
                    Write-RMMLog "  Version: $($app.DisplayVersion)" -Level Detect
                    Write-RMMLog "  Publisher: $($app.Publisher)" -Level Detect
                    $installed = $true
                }
            }
        }
        catch {
            Write-RMMLog "Error checking registry path $regPath : $($_.Exception.Message)" -Level Warning
        }
    }

    # Check for AppX packages
    try {
        $appxPackages = Get-AppxPackage -AllUsers -Name "*LenovoVantage*" -ErrorAction SilentlyContinue
        if ($appxPackages) {
            foreach ($package in $appxPackages) {
                Write-RMMLog "Found AppX Package: $($package.Name)" -Level Detect
                Write-RMMLog "  Version: $($package.Version)" -Level Detect
                $installed = $true
            }
        }
    }
    catch {
        Write-RMMLog "Error checking AppX packages: $($_.Exception.Message)" -Level Warning
    }

    # Check for Store apps
    try {
        $storeApps = Get-AppxPackage -AllUsers | Where-Object {
            $_.Name -like "*E046963F.LenovoCompanion*" -or
            $_.Name -like "*E046963F.LenovoSettingsforEnterprise*" -or
            $_.PackageFullName -like "*LenovoVantageService*"
        }
        if ($storeApps) {
            foreach ($app in $storeApps) {
                Write-RMMLog "Found Store App: $($app.Name)" -Level Detect
                $installed = $true
            }
        }
    }
    catch {
        Write-RMMLog "Error checking Store apps: $($_.Exception.Message)" -Level Warning
    }

    if (-not $installed) {
        Write-RMMLog "No Lenovo Vantage installation detected" -Level Detect
    }

    return $installed
}

function Stop-VantageProcesses {
    <#
    .SYNOPSIS
    Terminates all Lenovo Vantage related processes
    #>
    param([bool]$ForceKill = $true)

    Write-RMMLog "Checking for Lenovo Vantage processes..." -Level Status

    $processNames = @(
        "LenovoVantage",
        "LenovoVantageService",
        "VantageService",
        "ImController",
        "ImControllerService",
        "SystemInterface",
        "LenovoCompanion"
    )

    $processesKilled = 0

    foreach ($processName in $processNames) {
        $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue

        if ($processes) {
            Write-RMMLog "Found $($processes.Count) instance(s) of $processName" -Level Detect

            foreach ($process in $processes) {
                try {
                    if ($ForceKill) {
                        $process | Stop-Process -Force -ErrorAction Stop
                        Write-RMMLog "Force killed: $processName (PID: $($process.Id))" -Level Success
                    }
                    else {
                        $process | Stop-Process -ErrorAction Stop
                        Write-RMMLog "Stopped: $processName (PID: $($process.Id))" -Level Success
                    }
                    $processesKilled++
                }
                catch {
                    Write-RMMLog "Failed to stop $processName (PID: $($process.Id)): $($_.Exception.Message)" -Level Warning
                }
            }
        }
    }

    if ($processesKilled -eq 0) {
        Write-RMMLog "No Lenovo Vantage processes found running" -Level Detect
    }
    else {
        Write-RMMLog "Terminated $processesKilled process(es)" -Level Success
        Start-Sleep -Seconds 3
    }
}

function Get-VantageInstaller {
    <#
    .SYNOPSIS
    Downloads VantageInstaller.exe from Lenovo CDN
    #>
    param([string]$URL, [string]$OutputPath)

    Write-RMMLog "Downloading VantageInstaller.exe..." -Level Status
    Write-RMMLog "Source: $URL" -Level Config
    Write-RMMLog "Destination: $OutputPath" -Level Config

    # Remove existing installer if present
    if (Test-Path $OutputPath) {
        try {
            Remove-Item -Path $OutputPath -Force -ErrorAction Stop
            Write-RMMLog "Removed existing installer" -Level Info
        }
        catch {
            Write-RMMLog "Failed to remove existing installer: $($_.Exception.Message)" -Level Warning
        }
    }

    try {
        # Use TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Download with progress
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")

        Write-RMMLog "Starting download..." -Level Status
        $webClient.DownloadFile($URL, $OutputPath)
        $webClient.Dispose()

        # Verify download
        if (Test-Path $OutputPath) {
            $fileSize = (Get-Item $OutputPath).Length
            $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
            Write-RMMLog "Download completed successfully" -Level Success
            Write-RMMLog "File size: $fileSizeMB MB" -Level Info

            # Verify it's an executable
            if ($OutputPath -notlike "*.exe") {
                Write-RMMLog "Downloaded file is not an executable" -Level Error
                return $false
            }

            return $true
        }
        else {
            Write-RMMLog "Download failed - file not found after download" -Level Error
            return $false
        }
    }
    catch {
        Write-RMMLog "Download failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Uninstall-VantageWithInstaller {
    <#
    .SYNOPSIS
    Uninstalls Lenovo Vantage using VantageInstaller.exe
    #>
    param([string]$InstallerPath)

    Write-RMMLog "Starting Lenovo Vantage uninstallation..." -Level Status
    Write-RMMLog "Installer: $InstallerPath" -Level Config

    if (-not (Test-Path $InstallerPath)) {
        Write-RMMLog "VantageInstaller.exe not found at: $InstallerPath" -Level Error
        return $false
    }

    try {
        # Build arguments for uninstall
        # Standard uninstall command: VantageInstaller.exe -Uninstall -Vantage
        $arguments = @(
            "-Uninstall",
            "-Vantage"
        )

        Write-RMMLog "Executing: $InstallerPath $($arguments -join ' ')" -Level Config

        # Start the uninstaller
        $process = Start-Process -FilePath $InstallerPath `
                                  -ArgumentList $arguments `
                                  -Wait `
                                  -PassThru `
                                  -NoNewWindow `
                                  -ErrorAction Stop

        $exitCode = $process.ExitCode
        Write-RMMLog "Uninstaller exit code: $exitCode" -Level Status

        # Interpret exit codes
        switch ($exitCode) {
            0 {
                Write-RMMLog "Uninstallation completed successfully" -Level Success
                return $true
            }
            3010 {
                Write-RMMLog "Uninstallation completed - reboot required" -Level Success
                return $true
            }
            1641 {
                Write-RMMLog "Uninstallation completed - reboot initiated" -Level Success
                return $true
            }
            default {
                Write-RMMLog "Uninstallation returned exit code: $exitCode" -Level Warning
                return $false
            }
        }
    }
    catch {
        Write-RMMLog "Uninstallation failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Remove-VantageAppxPackages {
    <#
    .SYNOPSIS
    Removes Lenovo Vantage AppX packages for all users
    #>

    Write-RMMLog "Removing Lenovo Vantage AppX packages..." -Level Status
    $packagesRemoved = 0

    # Vantage-related AppX package patterns
    $packagePatterns = @(
        "*LenovoVantage*",
        "*E046963F.LenovoCompanion*",
        "*E046963F.LenovoSettingsforEnterprise*",
        "*LenovoVantageService*"
    )

    foreach ($pattern in $packagePatterns) {
        try {
            $packages = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue

            foreach ($package in $packages) {
                try {
                    Write-RMMLog "Removing: $($package.Name) v$($package.Version)" -Level Status
                    Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
                    Write-RMMLog "Removed: $($package.Name)" -Level Success
                    $packagesRemoved++
                }
                catch {
                    Write-RMMLog "Failed to remove $($package.Name): $($_.Exception.Message)" -Level Warning
                }
            }
        }
        catch {
            Write-RMMLog "Error searching for packages matching $pattern : $($_.Exception.Message)" -Level Warning
        }
    }

    # Remove provisioned packages (prevents reinstall for new users)
    try {
        $provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*LenovoVantage*" -or $_.DisplayName -like "*LenovoCompanion*" }

        foreach ($package in $provisionedPackages) {
            try {
                Write-RMMLog "Removing provisioned package: $($package.DisplayName)" -Level Status
                Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop
                Write-RMMLog "Removed provisioned: $($package.DisplayName)" -Level Success
                $packagesRemoved++
            }
            catch {
                Write-RMMLog "Failed to remove provisioned $($package.DisplayName): $($_.Exception.Message)" -Level Warning
            }
        }
    }
    catch {
        Write-RMMLog "Error removing provisioned packages: $($_.Exception.Message)" -Level Warning
    }

    if ($packagesRemoved -eq 0) {
        Write-RMMLog "No AppX packages found to remove" -Level Detect
    }
    else {
        Write-RMMLog "Removed $packagesRemoved AppX package(s)" -Level Success
    }

    return $packagesRemoved -gt 0
}

function Remove-VantageFolders {
    <#
    .SYNOPSIS
    Cleans up residual Lenovo Vantage folders
    #>

    Write-RMMLog "Cleaning up Lenovo Vantage folders..." -Level Status

    $foldersToRemove = @(
        "$env:ProgramFiles\Lenovo\Vantage",
        "$env:ProgramFiles\Lenovo\VantageService",
        "$env:ProgramFiles\Lenovo\ImController",
        "${env:ProgramFiles(x86)}\Lenovo\Vantage",
        "$env:ProgramData\Lenovo\Vantage",
        "$env:ProgramData\Lenovo\ImController",
        "$env:LOCALAPPDATA\Packages\E046963F.LenovoCompanion_*",
        "$env:LOCALAPPDATA\Packages\E046963F.LenovoSettingsforEnterprise_*"
    )

    $foldersRemoved = 0

    foreach ($folder in $foldersToRemove) {
        # Handle wildcards
        if ($folder -like "*`**") {
            $matchingFolders = Get-ChildItem -Path (Split-Path $folder -Parent) -Filter (Split-Path $folder -Leaf) -Directory -ErrorAction SilentlyContinue
            foreach ($matchingFolder in $matchingFolders) {
                if (Test-Path $matchingFolder.FullName) {
                    try {
                        Remove-Item -Path $matchingFolder.FullName -Recurse -Force -ErrorAction Stop
                        Write-RMMLog "Removed folder: $($matchingFolder.FullName)" -Level Success
                        $foldersRemoved++
                    }
                    catch {
                        Write-RMMLog "Failed to remove $($matchingFolder.FullName): $($_.Exception.Message)" -Level Warning
                    }
                }
            }
        }
        else {
            if (Test-Path $folder) {
                try {
                    Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
                    Write-RMMLog "Removed folder: $folder" -Level Success
                    $foldersRemoved++
                }
                catch {
                    Write-RMMLog "Failed to remove $folder : $($_.Exception.Message)" -Level Warning
                }
            }
        }
    }

    if ($foldersRemoved -eq 0) {
        Write-RMMLog "No residual folders found" -Level Detect
    }
    else {
        Write-RMMLog "Removed $foldersRemoved folder(s)" -Level Success
    }
}

############################################################################################################
#                                    MAIN SCRIPT LOGIC                                                     #
############################################################################################################

$exitCode = 0

try {
    Write-RMMLog "=============================================="
    Write-RMMLog "Lenovo Vantage Uninstaller v1.0.0" -Level Status
    Write-RMMLog "=============================================="
    Write-RMMLog "Component Category: Applications (Software Removal)" -Level Config
    Write-RMMLog "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Config
    Write-RMMLog "Log File: $LogFile" -Level Config
    Write-RMMLog ""

    Write-RMMLog "Configuration:" -Level Config
    Write-RMMLog "- Installer File: $InstallerFile" -Level Config
    Write-RMMLog "- Attached Path: $AttachedInstallerPath" -Level Config
    Write-RMMLog "- Fallback URL: $InstallerURL" -Level Config
    Write-RMMLog "- Force Kill Processes: $ForceKill" -Level Config
    Write-RMMLog "- Cleanup AppX Packages: $CleanupAppx" -Level Config
    Write-RMMLog "- Detailed Logging: $DetailedLogging" -Level Config
    Write-RMMLog ""

    Write-RMMLog "System Information:" -Level Config
    Write-RMMLog "- Computer: $env:COMPUTERNAME" -Level Config
    Write-RMMLog "- User: $env:USERNAME" -Level Config
    Write-RMMLog "- OS: $((Get-CimInstance Win32_OperatingSystem).Caption)" -Level Config
    Write-RMMLog ""

    # Step 1: Check if Vantage is installed
    $isInstalled = Test-VantageInstalled
    if (-not $isInstalled) {
        Write-RMMLog "Lenovo Vantage is not installed - nothing to uninstall" -Level Status
        Write-RMMLog "Script completed successfully" -Level Success
        $exitCode = 0
    }
    else {
        Write-RMMLog ""

        # Step 2: Stop Vantage processes
        Stop-VantageProcesses -ForceKill $ForceKill
        Write-RMMLog ""

        # Step 3: Locate or download VantageInstaller.exe
        $installerReady = $false

        # Priority 1: Check for attached file (Datto RMM file attachment)
        if (Test-Path $AttachedInstallerPath) {
            Write-RMMLog "Found attached VantageInstaller.exe" -Level Detect
            Write-RMMLog "Location: $AttachedInstallerPath" -Level Config
            $InstallerPath = $AttachedInstallerPath
            $installerReady = $true
        }
        # Priority 2: Check temp location (from previous run or manual placement)
        elseif (Test-Path $TempInstallerPath) {
            Write-RMMLog "Found VantageInstaller.exe in temp location" -Level Detect
            Write-RMMLog "Location: $TempInstallerPath" -Level Config
            $InstallerPath = $TempInstallerPath
            $installerReady = $true
        }
        # Priority 3: Download from Lenovo CDN
        else {
            Write-RMMLog "VantageInstaller.exe not found locally - attempting download" -Level Status
            $InstallerPath = $TempInstallerPath
            $installerReady = Get-VantageInstaller -URL $InstallerURL -OutputPath $InstallerPath
        }

        Write-RMMLog ""

        # Step 4: Run uninstaller
        $uninstallSuccess = $false
        if ($installerReady) {
            $uninstallSuccess = Uninstall-VantageWithInstaller -InstallerPath $InstallerPath
            Write-RMMLog ""
        }
        else {
            Write-RMMLog "Cannot proceed without VantageInstaller.exe" -Level Error
        }

        # Step 5: Clean up AppX packages if requested
        if ($CleanupAppx) {
            Remove-VantageAppxPackages
            Write-RMMLog ""
        }

        # Step 6: Clean up residual folders
        Remove-VantageFolders
        Write-RMMLog ""

        # Step 7: Final process check
        Stop-VantageProcesses -ForceKill $ForceKill
        Write-RMMLog ""

        # Step 8: Verify uninstallation
        Write-RMMLog "Verifying uninstallation..." -Level Status
        $stillInstalled = Test-VantageInstalled

        if (-not $stillInstalled) {
            Write-RMMLog "Lenovo Vantage has been completely removed" -Level Success
            $exitCode = 0
        }
        elseif ($uninstallSuccess) {
            Write-RMMLog "Uninstaller completed but some components may remain" -Level Warning
            Write-RMMLog "Manual cleanup or reboot may be required" -Level Warning
            $exitCode = 2
        }
        else {
            Write-RMMLog "Lenovo Vantage uninstallation failed" -Level Error
            $exitCode = 1
        }

        # Clean up installer (only if it was downloaded to temp)
        if ($InstallerPath -eq $TempInstallerPath -and (Test-Path $InstallerPath)) {
            try {
                Remove-Item -Path $InstallerPath -Force -ErrorAction Stop
                Write-RMMLog "Cleaned up downloaded VantageInstaller.exe" -Level Success
            }
            catch {
                Write-RMMLog "Failed to clean up installer: $($_.Exception.Message)" -Level Warning
            }
        }
        elseif ($InstallerPath -eq $AttachedInstallerPath) {
            Write-RMMLog "Keeping attached VantageInstaller.exe (not cleaning up)" -Level Info
        }
    }
}
catch {
    Write-RMMLog "Critical error during execution: $($_.Exception.Message)" -Level Error
    Write-RMMLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    $exitCode = 1
}
finally {
    Write-RMMLog ""
    Write-RMMLog "=============================================="
    Write-RMMLog "Lenovo Vantage Uninstaller Summary" -Level Status
    Write-RMMLog "- Final exit code: $exitCode" -Level Status
    Write-RMMLog "- End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Status
    Write-RMMLog "=============================================="

    Stop-Transcript
    exit $exitCode
}
