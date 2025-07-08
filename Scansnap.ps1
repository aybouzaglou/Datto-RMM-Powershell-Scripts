#Requires -RunAsAdministrator

# Script: Install or Update ScanSnap Home (Bundled Installer)
# Description: Installs ScanSnap Home from bundled installer file

# Initialize logging
$LogPath = "$env:ProgramData\ScanSnap\InstallUpdate"
If (-Not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force }
Start-Transcript -Path "$LogPath\ScanSnapHome-InstallUpdate.log" -Append

Write-Host "Starting ScanSnap Home Install/Update process..."

# Function to check if ScanSnap Home is installed
function Test-ScanSnapHomeInstalled {
    $ScanSnapHome = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*ScanSnap Home*" }
    return $ScanSnapHome -ne $null
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
