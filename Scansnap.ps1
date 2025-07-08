<#
.SYNOPSIS
    Installs or updates ScanSnap Home software using bundled installer files.

.DESCRIPTION
    This Datto RMM installation script automates the deployment and updating of Fujitsu ScanSnap Home software.
    The script detects if ScanSnap Home is already installed and either performs a fresh installation or
    runs the update process accordingly. It handles prerequisite installation (Visual C++ redistributables)
    and uses silent installation methods suitable for automated deployment.

    Script Type: Installation Script (Applications/Deployment)
    Execution Pattern: One-time or occasional deployment
    Performance Requirements: Up to 30 minutes execution time allowed

.PARAMETER None
    This script does not accept parameters. All configuration is handled internally.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    System.String
    Progress messages and status information are written to the console and log files.

.EXAMPLE
    .\Scansnap.ps1

    Executes the script to install or update ScanSnap Home. The script will:
    - Check if ScanSnap Home is currently installed
    - If not installed: Extract and install from bundled installer
    - If installed: Run the update process
    - Log all activities to ProgramData\ScanSnap\InstallUpdate\

.NOTES
    File Name      : Scansnap.ps1
    Author         : Datto RMM Script
    Prerequisite   : PowerShell 5.0+, Administrator privileges
    Script Type    : Installation/Deployment

    Datto RMM Context:
    - Runs as NT AUTHORITY\SYSTEM
    - Bundled installer files must be included in the component
    - No GUI elements will be visible during execution
    - Automatic logging to ProgramData directory

    Exit Codes:
    - 0: Success (installation or update completed)
    - 1: Warning (update process encountered issues)
    - 3: Error (script execution failed)

.LINK
    https://www.fujitsu.com/global/products/computing/peripheral/scanners/scansnap/

.COMPONENT
    ScanSnap Home Software Deployment

.ROLE
    Software Installation and Management

.FUNCTIONALITY
    - Detects existing ScanSnap Home installation
    - Extracts bundled installer files
    - Installs Visual C++ prerequisites
    - Performs silent installation of ScanSnap Home
    - Executes update process for existing installations
    - Comprehensive logging and error handling
#>

#Requires -RunAsAdministrator

# Initialize logging
$LogPath = "$env:ProgramData\ScanSnap\InstallUpdate"
If (-Not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force }
Start-Transcript -Path "$LogPath\ScanSnapHome-InstallUpdate.log" -Append

Write-Host "Starting ScanSnap Home Install/Update process..."

# Function to check if ScanSnap Home is installed
function Test-ScanSnapHomeInstalled {
    $ScanSnapHome = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*ScanSnap Home*" }
    return $null -ne $ScanSnapHome
}

# Function to install ScanSnap Home from bundled installer
function Install-ScanSnapHome {
    Write-Host "Installing ScanSnap Home from bundled installer..."
    
    # The bundled installer is available in the current directory when deployed via Datto RMM
    $Installer = Get-ChildItem -Path "." -Filter "WinSSHOfflineInstaller*.exe" | Select-Object -First 1
    
    if (-not $Installer) {
        Write-Error "ScanSnap Home installer not found in component bundle"
        return $false
    }
    
    try {
        Write-Host "Found installer: $($Installer.Name)"
        
        # Run the installer to extract files
        Write-Host "Extracting installer files..."
        $Process = Start-Process -FilePath $Installer.FullName -Wait -PassThru

        if ($Process.ExitCode -ne 0) {
            Write-Error "Installer extraction failed with exit code: $($Process.ExitCode)"
            return $false
        }
        
        # The installer extracts to %LocalAppData%\Temp\SSHomeDownloadInstaller
        $ExtractedPath = "$env:LOCALAPPDATA\Temp\SSHomeDownloadInstaller"
        
        if (Test-Path $ExtractedPath) {
            Write-Host "Files extracted successfully"
            
            # Install prerequisites first
            $PrereqPath = "$ExtractedPath\Prerequisite"
            if (Test-Path "$PrereqPath\ms_vcredist_x86_2013\vcredist_x86.exe") {
                Write-Host "Installing VC++ 2013 x86..."
                Start-Process -FilePath "$PrereqPath\ms_vcredist_x86_2013\vcredist_x86.exe" -ArgumentList "/install", "/quiet", "/norestart" -Wait
            }
            
            if (Test-Path "$PrereqPath\ms_vcredist_x86_2017\vcredist_x86.exe") {
                Write-Host "Installing VC++ 2017 x86..."
                Start-Process -FilePath "$PrereqPath\ms_vcredist_x86_2017\vcredist_x86.exe" -ArgumentList "/install", "/quiet", "/norestart" -Wait
            }
            
            # Install main application
            $MainInstaller = Get-ChildItem -Path "$ExtractedPath\download" -Filter "WinSSHomeInstaller*.exe" | Select-Object -First 1
            $ResponseFile = Get-ChildItem -Path "$ExtractedPath\download" -Filter "WinSSHomeInstaller*.iss" | Select-Object -First 1
            
            if ($MainInstaller -and $ResponseFile) {
                Write-Host "Installing ScanSnap Home main application..."
                $InstallArgs = @(
                    "-s"
                    "-f1`"$($ResponseFile.FullName)`""
                    "-f2`"$LogPath\ScanSnapHome-Install.log`""
                )
                
                Start-Process -FilePath $MainInstaller.FullName -ArgumentList $InstallArgs -Wait
                Write-Host "ScanSnap Home installation completed"
                return $true
            }
        }
        
        return $false
    }
    catch {
        Write-Error "Installation failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to update ScanSnap Home
function Update-ScanSnapHome {
    Write-Host "Updating ScanSnap Home..."
    
    try {
        # Look for ScanSnap Online Update
        $OnlineUpdatePath = "${env:ProgramFiles(x86)}\PFU\ScanSnap\SSUpdate\SSUpdate.exe"
        if (-not (Test-Path $OnlineUpdatePath)) {
            $OnlineUpdatePath = "$env:ProgramFiles\PFU\ScanSnap\SSUpdate\SSUpdate.exe"
        }
        
        if (Test-Path $OnlineUpdatePath) {
            Write-Host "Running ScanSnap Online Update..."
            Start-Process -FilePath $OnlineUpdatePath -Wait
            Write-Host "Update process completed"
            return $true
        }
        
        return $false
    }
    catch {
        Write-Error "Update failed: $($_.Exception.Message)"
        return $false
    }
}

# Main execution logic
try {
    if (Test-ScanSnapHomeInstalled) {
        Write-Host "ScanSnap Home is already installed. Checking for updates..."
        $UpdateResult = Update-ScanSnapHome
        
        if ($UpdateResult) {
            Write-Host "ScanSnap Home update process completed successfully"
            $ExitCode = 0
        }
        else {
            Write-Warning "Update process encountered issues"
            $ExitCode = 1
        }
    }
    else {
        Write-Host "ScanSnap Home is not installed. Starting installation..."
        $InstallResult = Install-ScanSnapHome
        
        if ($InstallResult) {
            Write-Host "ScanSnap Home installation completed successfully"
            $ExitCode = 0
        }
        else {
            Write-Error "Installation failed"
            $ExitCode = 1
        }
    }
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    $ExitCode = 3
}
finally {
    Stop-Transcript
    Write-Host "Script completed with exit code: $ExitCode"
    Exit $ExitCode
}
