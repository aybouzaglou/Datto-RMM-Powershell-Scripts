<#
.SYNOPSIS
Comprehensive Messenger uninstaller for Datto RMM using RunAsUser module

.DESCRIPTION
This script completely removes Thread Messenger (Chatgenie Messenger) from both system and user contexts.
Uses the RunAsUser PowerShell module to properly handle user-specific installations when running as SYSTEM.
Handles MSI packages, EXE uninstallers, registry cleanup, and file system cleanup.

.ENVIRONMENT VARIABLES
- ForceKill (Boolean): Force terminate processes before uninstall (default: true)
- DetailedLogging (Boolean): Enable verbose logging output (default: true)
- SkipUserContext (Boolean): Skip user context cleanup (default: false)
- SkipSystemContext (Boolean): Skip system context cleanup (default: false)

.PARAMETER None
This script does not accept parameters. All configuration is handled via environment variables.

.INPUTS
None. This script does not accept pipeline input.

.OUTPUTS
System.String - Progress messages and status information

.EXAMPLE
# Datto RMM Applications Component Usage:
# Environment Variables:
# ForceKill = true
# DetailedLogging = true
# Component Type: Applications
# Timeout: 15 minutes

.NOTES
Version: 2.0.0
Author: Datto RMM Function Library
Component Category: Applications (Software Removal)
Compatible: PowerShell 3.0+, Datto RMM Environment
Requires: RunAsUser PowerShell Module (auto-installed)

.LINK
https://github.com/KelvinTegelaar/RunAsUser
#>

[CmdletBinding()]
param()

# ============================================
# CONFIGURATION AND INITIALIZATION
# ============================================

# Configuration
$LogPath = "C:\ProgramData\DattoRMM\Applications"
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogPath "MessengerUninstall-Applications.log"
Start-Transcript -Path $LogFile -Append

# Environment variable processing
function Get-RMMVariable {
    param([string]$Name, [string]$Type = "String", $Default = $null)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($value)) { return $Default }

    switch ($Type) {
        "Boolean" { return $value -eq "true" }
        "Integer" { return [int]$value }
        default { return $value }
    }
}

$ForceKill = Get-RMMVariable -Name "ForceKill" -Type "Boolean" -Default $true
$DetailedLogging = Get-RMMVariable -Name "DetailedLogging" -Type "Boolean" -Default $true
$SkipUserContext = Get-RMMVariable -Name "SkipUserContext" -Type "Boolean" -Default $false
$SkipSystemContext = Get-RMMVariable -Name "SkipSystemContext" -Type "Boolean" -Default $false

# Logging function
function Write-RMMLog {
    param([string]$Message, [string]$Level = "Info")

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    if ([string]::IsNullOrEmpty($Message)) {
        Write-Host ""
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

# Install/Import RunAsUser module if not present
function Initialize-RunAsUserModule {
    try {
        if (-not (Get-Module -ListAvailable -Name RunAsUser)) {
            Write-RMMLog "RunAsUser module not found - installing..." -Level Status
            Install-Module RunAsUser -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
            Write-RMMLog "RunAsUser module installed successfully" -Level Success
        }

        Import-Module RunAsUser -ErrorAction Stop
        Write-RMMLog "RunAsUser module loaded successfully" -Level Success
        return $true
    } catch {
        Write-RMMLog "Failed to initialize RunAsUser module: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# ============================================
# CORE FUNCTIONS
# ============================================

function Stop-MessengerProcesses {
    <#
    .SYNOPSIS
    Terminates all Messenger-related processes system-wide
    #>
    param([bool]$ForceKill = $true)

    Write-RMMLog "Terminating Messenger processes..." -Level Status

    $ProcessNames = @("Messenger", "ChatgenieMessenger", "Messenger.exe", "ChatgenieMessenger.exe")
    $ProcessesKilled = 0

    foreach ($ProcessName in $ProcessNames) {
        $CleanName = $ProcessName -replace '\.exe$', ''
        $processes = Get-Process -Name $CleanName -ErrorAction SilentlyContinue

        if ($processes) {
            Write-RMMLog "Found $($processes.Count) instance(s) of $ProcessName" -Level Detect

            foreach ($process in $processes) {
                try {
                    if ($ForceKill) {
                        $process | Stop-Process -Force -ErrorAction Stop
                        Write-RMMLog "Force killed process: $ProcessName (PID: $($process.Id))" -Level Success
                    } else {
                        $process | Stop-Process -ErrorAction Stop
                        Write-RMMLog "Gracefully stopped process: $ProcessName (PID: $($process.Id))" -Level Success
                    }
                    $ProcessesKilled++
                } catch {
                    Write-RMMLog "Failed to stop process $ProcessName (PID: $($process.Id)): $($_.Exception.Message)" -Level Warning
                }
            }
        }
    }

    if ($ProcessesKilled -eq 0) {
        Write-RMMLog "No Messenger processes found running" -Level Detect
    } else {
        Write-RMMLog "Terminated $ProcessesKilled Messenger process(es)" -Level Success
        Start-Sleep -Seconds 2
    }
}

# ScriptBlock for user context operations (executed via RunAsUser)
$UserContextScript = {
    # Initialize results array
    $results = @()
    $results += "Starting user context cleanup for: $env:USERNAME"

    # Kill Messenger processes for current user session
    $processNames = @("Messenger", "ChatgenieMessenger")
    $currentSessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId

    foreach ($name in $processNames) {
        $userProcesses = Get-Process -Name $name -ErrorAction SilentlyContinue |
            Where-Object { $_.SessionId -eq $currentSessionId }

        if ($userProcesses) {
            $results += "Found $($userProcesses.Count) user process(es): $name"
            $userProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
            $results += "Terminated user processes: $name"
        }
    }

    # Check for user-specific uninstallers
    $uninstallerPaths = @(
        "$env:LOCALAPPDATA\Programs\Messenger\Uninstall Messenger.exe",
        "$env:LOCALAPPDATA\Programs\ChatgenieMessenger\Uninstall.exe",
        "$env:APPDATA\Messenger\Uninstall.exe",
        "$env:LOCALAPPDATA\Messenger\Uninstall.exe",
        "$env:LOCALAPPDATA\Programs\Messenger\Uninstall.exe"
    )

    foreach ($uninstallerPath in $uninstallerPaths) {
        if (Test-Path $uninstallerPath) {
            $results += "Found uninstaller: $uninstallerPath"
            try {
                # Run uninstaller with multiple silent switches
                $arguments = @("/S", "/quiet", "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART")
                $process = Start-Process -FilePath $uninstallerPath -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop

                if ($process.ExitCode -eq 0) {
                    $results += "SUCCESS: Uninstalled using $uninstallerPath"
                } else {
                    $results += "WARNING: Uninstaller exited with code $($process.ExitCode) for $uninstallerPath"
                }
            } catch {
                $results += "ERROR: Failed to run uninstaller $uninstallerPath - $($_.Exception.Message)"
            }
        }
    }

    # Clean up user registry entries
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    if (Test-Path $regPath) {
        try {
            $uninstallKeys = Get-ChildItem $regPath -ErrorAction SilentlyContinue
            foreach ($key in $uninstallKeys) {
                $app = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
                if ($app -and ($app.DisplayName -like "*Messenger*" -or $app.DisplayName -like "*Chatgenie*")) {
                    try {
                        Remove-Item -Path $key.PSPath -Recurse -Force -ErrorAction Stop
                        $results += "SUCCESS: Removed registry entry: $($app.DisplayName)"
                    } catch {
                        $results += "ERROR: Failed to remove registry entry: $($app.DisplayName) - $($_.Exception.Message)"
                    }
                }
            }
        } catch {
            $results += "ERROR: Failed to access user registry: $($_.Exception.Message)"
        }
    }

    # Clean up user-specific folders
    $foldersToClean = @(
        "$env:LOCALAPPDATA\Messenger",
        "$env:LOCALAPPDATA\Programs\Messenger",
        "$env:LOCALAPPDATA\Programs\ChatgenieMessenger",
        "$env:APPDATA\Messenger",
        "$env:APPDATA\ChatgenieMessenger",
        "$env:TEMP\Messenger"
    )

    foreach ($folder in $foldersToClean) {
        if (Test-Path $folder) {
            try {
                Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
                $results += "SUCCESS: Removed folder: $folder"
            } catch {
                $results += "ERROR: Failed to remove folder $folder - $($_.Exception.Message)"
            }
        }
    }

    $results += "User context cleanup completed for: $env:USERNAME"
    return $results -join "`n"
}

function Uninstall-SystemContext {
    <#
    .SYNOPSIS
    Handles system-level Messenger uninstallation
    #>

    Write-RMMLog "Processing system-level uninstallation..." -Level Status
    $UninstallSuccess = $true

    # Check both 32-bit and 64-bit registry locations
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            Write-RMMLog "Scanning registry path: $path" -Level Config

            try {
                $uninstallKeys = Get-ChildItem $path -ErrorAction SilentlyContinue
                foreach ($key in $uninstallKeys) {
                    $app = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue

                    if ($app -and ($app.DisplayName -like "*Messenger*" -or $app.DisplayName -like "*Chatgenie*")) {
                        Write-RMMLog "Found system installation: $($app.DisplayName)" -Level Detect
                        Write-RMMLog "  Publisher: $($app.Publisher)" -Level Detect
                        Write-RMMLog "  Version: $($app.DisplayVersion)" -Level Detect

                        # Handle MSI installations (GUID format)
                        if ($key.PSChildName -match '^{[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}}$') {
                            Write-RMMLog "  Product Code: $($key.PSChildName)" -Level Detect
                            Write-RMMLog "Executing MSI uninstall..." -Level Status

                            try {
                                $arguments = "/x `"$($key.PSChildName)`" /qn /norestart REBOOT=ReallySuppress"
                                if ($DetailedLogging) {
                                    Write-RMMLog "Executing: msiexec.exe $arguments" -Level Config
                                }

                                $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru -NoNewWindow -ErrorAction Stop
                                $exitCode = $process.ExitCode

                                switch ($exitCode) {
                                    0 {
                                        Write-RMMLog "Successfully uninstalled MSI: $($app.DisplayName)" -Level Success
                                    }
                                    3010 {
                                        Write-RMMLog "Successfully uninstalled MSI: $($app.DisplayName) (reboot required)" -Level Success
                                    }
                                    1605 {
                                        Write-RMMLog "MSI product not found (may have been already uninstalled): $($app.DisplayName)" -Level Warning
                                    }
                                    default {
                                        Write-RMMLog "MSI uninstall returned exit code $exitCode for: $($app.DisplayName)" -Level Warning
                                        $UninstallSuccess = $false
                                    }
                                }
                            } catch {
                                Write-RMMLog "Failed to execute MSI uninstall: $($_.Exception.Message)" -Level Error
                                $UninstallSuccess = $false
                            }
                        }
                        # Handle EXE installations with UninstallString
                        elseif ($app.UninstallString) {
                            Write-RMMLog "  Uninstall String: $($app.UninstallString)" -Level Detect
                            Write-RMMLog "Executing uninstall string..." -Level Status

                            try {
                                $uninstallCmd = $app.UninstallString

                                # Add silent switches based on uninstaller type
                                if ($uninstallCmd -like "*msiexec*") {
                                    if ($uninstallCmd -notlike "*/q*") {
                                        $uninstallCmd += " /qn /norestart REBOOT=ReallySuppress"
                                    }
                                } else {
                                    # Add common silent switches for EXE uninstallers
                                    $silentSwitches = @("/S", "/quiet", "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART")
                                    foreach ($switch in $silentSwitches) {
                                        if ($uninstallCmd -notlike "*$switch*") {
                                            $uninstallCmd += " $switch"
                                        }
                                    }
                                }

                                if ($DetailedLogging) {
                                    Write-RMMLog "Executing: $uninstallCmd" -Level Config
                                }

                                $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $uninstallCmd -Wait -PassThru -NoNewWindow -ErrorAction Stop
                                $exitCode = $process.ExitCode

                                if ($exitCode -eq 0) {
                                    Write-RMMLog "Successfully executed uninstall string for: $($app.DisplayName)" -Level Success
                                } else {
                                    Write-RMMLog "Uninstall string returned exit code $exitCode for: $($app.DisplayName)" -Level Warning
                                }
                            } catch {
                                Write-RMMLog "Failed to execute uninstall string: $($_.Exception.Message)" -Level Error
                                $UninstallSuccess = $false
                            }
                        } else {
                            Write-RMMLog "No valid uninstall method found for: $($app.DisplayName)" -Level Warning
                            $UninstallSuccess = $false
                        }
                    }
                }
            } catch {
                Write-RMMLog "Error scanning registry path $path : $($_.Exception.Message)" -Level Error
                $UninstallSuccess = $false
            }
        }
    }

    # Try WMI/CIM uninstall as additional method
    Write-RMMLog "Checking WMI for additional installations..." -Level Status
    try {
        $products = Get-CimInstance -ClassName Win32_Product -ErrorAction Stop |
            Where-Object { $_.Name -like "*Messenger*" -or $_.Name -like "*Chatgenie*" }

        if ($products) {
            foreach ($product in $products) {
                Write-RMMLog "Found via WMI: $($product.Name)" -Level Detect
                try {
                    $result = $product | Invoke-CimMethod -MethodName Uninstall -ErrorAction Stop
                    if ($result.ReturnValue -eq 0) {
                        Write-RMMLog "Successfully uninstalled via WMI: $($product.Name)" -Level Success
                    } else {
                        Write-RMMLog "WMI uninstall returned code $($result.ReturnValue) for: $($product.Name)" -Level Warning
                    }
                } catch {
                    Write-RMMLog "WMI uninstall failed for $($product.Name): $($_.Exception.Message)" -Level Error
                    $UninstallSuccess = $false
                }
            }
        } else {
            Write-RMMLog "No additional installations found via WMI" -Level Detect
        }
    } catch {
        Write-RMMLog "WMI query failed (this is normal on some systems): $($_.Exception.Message)" -Level Warning
    }

    # Clean up system-wide folders
    Write-RMMLog "Cleaning up system-wide folders..." -Level Status
    $systemFolders = @(
        "$env:ProgramFiles\Messenger",
        "$env:ProgramFiles\Chatgenie Messenger",
        "$env:ProgramFiles\Thread Magic Inc",
        "${env:ProgramFiles(x86)}\Messenger",
        "${env:ProgramFiles(x86)}\Chatgenie Messenger",
        "${env:ProgramFiles(x86)}\Thread Magic Inc",
        "$env:ProgramData\Messenger",
        "$env:ProgramData\ChatgenieMessenger",
        "$env:TEMP\Messenger"
    )

    foreach ($folder in $systemFolders) {
        if (Test-Path $folder) {
            try {
                Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
                Write-RMMLog "Removed system folder: $folder" -Level Success
            } catch {
                Write-RMMLog "Failed to remove folder $folder : $($_.Exception.Message)" -Level Warning
            }
        }
    }

    return $UninstallSuccess
}

# ============================================
# MAIN EXECUTION
# ============================================

try {
    Write-RMMLog "=============================================="
    Write-RMMLog "Messenger Application Uninstall - Applications Component v2.0.0" -Level Status
    Write-RMMLog "=============================================="
    Write-RMMLog "Component Category: Applications (Software Removal)" -Level Config
    Write-RMMLog "Start Time: $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')" -Level Config
    Write-RMMLog "Log Directory: $LogPath" -Level Config
    Write-RMMLog ""

    Write-RMMLog "Environment Variables:" -Level Config
    Write-RMMLog "- ForceKill: $ForceKill" -Level Config
    Write-RMMLog "- DetailedLogging: $DetailedLogging" -Level Config
    Write-RMMLog "- SkipUserContext: $SkipUserContext" -Level Config
    Write-RMMLog "- SkipSystemContext: $SkipSystemContext" -Level Config
    Write-RMMLog ""

    Write-RMMLog "Script running as: $env:USERNAME" -Level Config
    Write-RMMLog "Computer: $env:COMPUTERNAME" -Level Config
    Write-RMMLog ""

    # Initialize RunAsUser module
    $RunAsUserAvailable = Initialize-RunAsUserModule
    if (-not $RunAsUserAvailable -and $env:USERNAME -eq "SYSTEM") {
        Write-RMMLog "RunAsUser module unavailable - user context cleanup may be limited" -Level Warning
    }

    Write-RMMLog "Starting Messenger uninstall process..." -Level Status
    Write-RMMLog ""

    # Step 1: Terminate running processes
    Stop-MessengerProcesses -ForceKill $ForceKill
    Write-RMMLog ""

    # Step 2: Handle user context uninstallation
    $UserSuccess = $true
    if (-not $SkipUserContext) {
        if ($env:USERNAME -eq "SYSTEM") {
            Write-RMMLog "Running as SYSTEM - using RunAsUser for user context operations" -Level Status

            if ($RunAsUserAvailable) {
                try {
                    # Get all logged-in users
                    $loggedInUsers = Get-LoggedInUser -ErrorAction Stop

                    if ($loggedInUsers) {
                        Write-RMMLog "Found $($loggedInUsers.Count) logged-in user(s)" -Level Detect

                        foreach ($user in $loggedInUsers) {
                            Write-RMMLog "Processing user: $($user.Username) (Session: $($user.SessionId))" -Level Status

                            try {
                                $result = Invoke-AsCurrentUser -ScriptBlock $UserContextScript -ErrorAction Stop

                                if ($result) {
                                    $result -split "`n" | ForEach-Object {
                                        if ($_ -like "*SUCCESS*") {
                                            Write-RMMLog $_.Replace("SUCCESS: ", "") -Level Success
                                        } elseif ($_ -like "*ERROR*") {
                                            Write-RMMLog $_.Replace("ERROR: ", "") -Level Error
                                            $UserSuccess = $false
                                        } elseif ($_ -like "*WARNING*") {
                                            Write-RMMLog $_.Replace("WARNING: ", "") -Level Warning
                                        } else {
                                            Write-RMMLog $_ -Level Config
                                        }
                                    }
                                }
                            } catch {
                                Write-RMMLog "RunAsUser failed for $($user.Username): $($_.Exception.Message)" -Level Error
                                $UserSuccess = $false
                            }
                        }
                    } else {
                        Write-RMMLog "No users currently logged in - performing direct profile cleanup" -Level Status

                        # Fallback: Clean up all user profiles even if not logged in
                        try {
                            $userProfiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop |
                                Where-Object { $_.Special -eq $false -and $_.LocalPath -ne $null }

                            foreach ($userProfile in $userProfiles) {
                                $userPath = $userProfile.LocalPath
                                Write-RMMLog "Cleaning profile: $userPath" -Level Status

                                # Clean up known locations in user profile
                                $pathsToClean = @(
                                    "$userPath\AppData\Local\Programs\Messenger",
                                    "$userPath\AppData\Local\Programs\ChatgenieMessenger",
                                    "$userPath\AppData\Local\Messenger",
                                    "$userPath\AppData\Roaming\Messenger",
                                    "$userPath\AppData\Roaming\ChatgenieMessenger"
                                )

                                foreach ($path in $pathsToClean) {
                                    if (Test-Path $path) {
                                        try {
                                            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                                            Write-RMMLog "Removed profile folder: $path" -Level Success
                                        } catch {
                                            Write-RMMLog "Failed to remove profile folder $path : $($_.Exception.Message)" -Level Warning
                                        }
                                    }
                                }
                            }
                        } catch {
                            Write-RMMLog "Failed to enumerate user profiles: $($_.Exception.Message)" -Level Error
                            $UserSuccess = $false
                        }
                    }
                } catch {
                    Write-RMMLog "RunAsUser module error: $($_.Exception.Message)" -Level Error
                    Write-RMMLog "Falling back to direct profile cleanup" -Level Warning
                    $UserSuccess = $false
                }
            } else {
                Write-RMMLog "RunAsUser module not available - skipping user context cleanup" -Level Warning
                $UserSuccess = $false
            }
        } else {
            # We're already running as a user
            Write-RMMLog "Running as user $env:USERNAME - executing user context directly" -Level Status
            try {
                $result = & $UserContextScript
                if ($result) {
                    $result -split "`n" | ForEach-Object {
                        if ($_ -like "*SUCCESS*") {
                            Write-RMMLog $_.Replace("SUCCESS: ", "") -Level Success
                        } elseif ($_ -like "*ERROR*") {
                            Write-RMMLog $_.Replace("ERROR: ", "") -Level Error
                            $UserSuccess = $false
                        } elseif ($_ -like "*WARNING*") {
                            Write-RMMLog $_.Replace("WARNING: ", "") -Level Warning
                        } else {
                            Write-RMMLog $_ -Level Config
                        }
                    }
                }
            } catch {
                Write-RMMLog "User context execution failed: $($_.Exception.Message)" -Level Error
                $UserSuccess = $false
            }
        }
    } else {
        Write-RMMLog "Skipping user context cleanup (SkipUserContext = true)" -Level Config
    }
    Write-RMMLog ""

    # Step 3: System-level uninstallation
    $SystemSuccess = $true
    if (-not $SkipSystemContext) {
        $SystemSuccess = Uninstall-SystemContext
    } else {
        Write-RMMLog "Skipping system context cleanup (SkipSystemContext = true)" -Level Config
    }
    Write-RMMLog ""

    # Step 4: Final process cleanup
    Stop-MessengerProcesses -ForceKill $ForceKill
    Write-RMMLog ""

    # Step 5: Determine final result
    $OverallSuccess = $SystemSuccess -and $UserSuccess

    if ($OverallSuccess) {
        Write-RMMLog "Messenger uninstall completed successfully" -Level Success
        $ExitCode = 0
    } elseif ($SystemSuccess -or $UserSuccess) {
        Write-RMMLog "Messenger uninstall partially successful" -Level Warning
        Write-RMMLog "Some installations were removed but others may have failed" -Level Warning
        $ExitCode = 2
    } else {
        Write-RMMLog "Messenger uninstall failed" -Level Error
        $ExitCode = 1
    }

    Write-RMMLog ""
    Write-RMMLog "=============================================="
    Write-RMMLog "Messenger Uninstall Summary:" -Level Status
    Write-RMMLog "- System context success: $SystemSuccess" -Level Status
    Write-RMMLog "- User context success: $UserSuccess" -Level Status
    Write-RMMLog "- Overall result: $(if ($OverallSuccess) { 'SUCCESS' } elseif ($SystemSuccess -or $UserSuccess) { 'PARTIAL SUCCESS' } else { 'FAILED' })" -Level Status
    Write-RMMLog "- Exit code: $ExitCode" -Level Status
    Write-RMMLog "- End time: $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')" -Level Status
    Write-RMMLog "=============================================="

} catch {
    Write-RMMLog "Critical error during execution: $($_.Exception.Message)" -Level Error
    Write-RMMLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    $ExitCode = 1
} finally {
    Stop-Transcript
    exit $ExitCode
}