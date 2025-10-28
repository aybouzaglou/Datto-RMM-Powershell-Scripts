<#
.SYNOPSIS
Lenovo Vantage uninstaller for Datto RMM using attached VantageInstaller.exe

.DESCRIPTION
This script completely removes Lenovo Vantage and Commercial Vantage using the official VantageInstaller.exe tool.
Handles both consumer and commercial versions using the attached installer file.

Features:
- Uses attached VantageInstaller.exe from Datto RMM file attachment
- Uninstalls both Lenovo Vantage and Commercial Vantage
- Cleans up AppX packages and residual files
- Force terminates Vantage processes for clean uninstall
- Comprehensive logging and error handling

.COMPONENT
Category: Applications (Software Removal)
Execution: On-demand
Timeout: 15-20 minutes recommended
Changeable: Yes

.ENVIRONMENT VARIABLES
None - All settings are configured as defaults

.EXAMPLES
Usage:
1. Extract VantageInstaller.exe from the Commercial Vantage package
2. Attach VantageInstaller.exe to the Datto RMM component
3. Deploy to target devices

.NOTES
Version: 1.0.0
Author: Datto RMM Self-Contained Architecture
Component Category: Applications (Software Removal)
Compatible: PowerShell 5.0+, Windows 10/11
Deployment: DIRECT (paste script content directly into Datto RMM)
Requirements: VantageInstaller.exe must be attached to the component

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

# Hard-coded configuration (no environment variables needed)
$InstallerFileName = "VantageInstaller.exe"
$InstallerPath = Join-Path (Get-Location) $InstallerFileName

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
                    $process | Stop-Process -Force -ErrorAction Stop
                    Write-RMMLog "Force killed: $processName (PID: $($process.Id))" -Level Success
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
    Write-RMMLog "- Installer File Name: $InstallerFileName" -Level Config
    Write-RMMLog "- Expected Path: $InstallerPath" -Level Config
    Write-RMMLog "- Force Kill Processes: Enabled" -Level Config
    Write-RMMLog "- Cleanup AppX Packages: Enabled" -Level Config
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
        Stop-VantageProcesses
        Write-RMMLog ""

        # Step 3: Verify VantageInstaller.exe exists
        if (-not (Test-Path $InstallerPath)) {
            Write-RMMLog "VantageInstaller.exe not found at: $InstallerPath" -Level Error
            Write-RMMLog "Please ensure VantageInstaller.exe is attached to this Datto RMM component" -Level Error
            $exitCode = 1
        }
        else {
            Write-RMMLog "Found VantageInstaller.exe" -Level Detect
            Write-RMMLog "Location: $InstallerPath" -Level Config
            Write-RMMLog ""

            # Step 4: Run uninstaller
            $uninstallSuccess = Uninstall-VantageWithInstaller -InstallerPath $InstallerPath
            Write-RMMLog ""

            # Step 5: Clean up AppX packages
            Remove-VantageAppxPackages
            Write-RMMLog ""

            # Step 6: Clean up residual folders
            Remove-VantageFolders
            Write-RMMLog ""

            # Step 7: Final process check
            Stop-VantageProcesses
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
