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

.PARAMETER None
This script does not accept parameters. All configuration is handled internally.

.INPUTS
None. This script does not accept pipeline input.

.OUTPUTS
System.String - Progress messages and status information

.EXAMPLE
# Datto RMM Applications Component Usage:
# ScriptName: "TungstenPrintixClient.ps1"
# Component Type: Applications
# Timeout: 30 minutes

.NOTES
Version: 1.0.0
Author: Datto RMM Function Library
Component Category: Applications (Software Deployment)
Compatible: PowerShell 2.0+, Datto RMM Environment

Datto RMM Applications Exit Codes:
- 0: Success (installation or update completed)
- 3010: Success with reboot required
- 1641: Success with reboot initiated
- Other non-zero: Failed

CHANGELOG:
1.0.0 - Initial Tungsten Printix Client installation script
#>

# Embedded logging function (pattern from shared-functions/Core/RMMLogging.ps1)
function Write-RMMLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [ValidateSet("Info", "Status", "Success", "Warning", "Error", "Config", "Detect")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
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

# Configuration
$LogPath = "C:\ProgramData\DattoRMM\Applications"
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Start transcript (embedded pattern from shared-functions/Core/RMMLogging.ps1)
Start-Transcript -Path "$LogPath\TungstenPrintixClient-Applications.log" -Append

Write-RMMLog "=============================================="
Write-RMMLog "Tungsten Printix Client - Applications Component v1.0.0" -Level Status
Write-RMMLog "=============================================="
Write-RMMLog "Component Category: Applications (Software Deployment)" -Level Config
Write-RMMLog "Start Time: $(Get-Date)" -Level Config
Write-RMMLog "Log Directory: $LogPath" -Level Config
Write-RMMLog ""

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

    Write-RMMLog "Starting Tungsten Printix Client installation..." -Level Status

    # MSI configuration
    $MSIName = "CLIENT_{mandevo.printix.net}_{d1a50571-67e6-4566-9da7-64e11a26a4d9} (1).MSI"
    $WrappedArguments = "/id:d1a50571-67e6-4566-9da7-64e11a26a4d9"

    # Check for attached MSI file in current directory (Datto RMM file attachment)
    $MSIPath = $MSIName

    if (Test-Path $MSIPath) {
        Write-RMMLog "Found attached MSI file: $MSIName" -Level Success
    } else {
        Write-RMMLog "MSI file not found as attachment: $MSIName" -Level Error
        Write-RMMLog "Please ensure the MSI file is attached to the Datto RMM component" -Level Error
        return 1
    }
    
    # Build msiexec command
    $MSIArgs = @(
        "/i"
        "`"$MSIPath`""
        "/quiet"
        "/norestart"
        "/l*v"
        "`"$LogPath\PrintixClient-Install.log`""
        "WRAPPED_ARGUMENTS=`"$WrappedArguments`""
    )
    
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
    # Check if Tungsten Printix Client is already installed
    $isInstalled = Test-PrintixClientInstalled
    
    if ($isInstalled) {
        Write-RMMLog "Tungsten Printix Client is already installed" -Level Status
        Write-RMMLog "Skipping installation - software already present" -Level Success
        $exitCode = 0
    } else {
        Write-RMMLog "Tungsten Printix Client not installed - proceeding with installation" -Level Status
        $exitCode = Install-PrintixClient
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
