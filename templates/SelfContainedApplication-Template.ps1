<#
.SYNOPSIS
    Application Template - Direct Deployment

.DESCRIPTION
    Template for creating application deployment scripts.
    Supports embedded functions or standard module patterns.
    
    Features:
    - Flexible function management (embed or import)
    - Comprehensive error handling and logging
    - File attachment support for installers
    - Registry-based software detection
    - PowerShell 5.0+ compatible

.COMPONENT
    Category: Applications (Software Deployment)
    Execution: On-demand or scheduled
    Timeout: Up to 30 minutes
    Changeable: Yes (can be changed to Scripts category if needed)

.ENVIRONMENT VARIABLES
    - SoftwareName (String): Name of software to install/check
    - InstallerFile (String): Name of installer file (if using file attachment)
    - InstallArgs (String): Installation arguments (default: "/S /silent")
    - ForceReinstall (Boolean): Force reinstall if already installed (default: false)

.EXAMPLES
    Environment Variables:
    SoftwareName = "Adobe Reader"
    InstallerFile = "AdobeReader.exe"
    InstallArgs = "/S /silent /norestart"
    ForceReinstall = false

.NOTES
    Version: 1.0.0
    Author:         Datto RMM Script
    Compatible:     PowerShell 5.0+, Datto RMM Environment
    Deployment:     Direct to Datto RMM
#>

param(
    [string]$SoftwareName = $env:SoftwareName,
    [string]$InstallerFile = $env:InstallerFile,
    [string]$InstallArgs = $env:InstallArgs,
    [bool]$ForceReinstall = ($env:ForceReinstall -eq "true")
)

# Datto RMM copies any files attached to this component into the script's working directory.
# Reference attachments by filename; see docs/Datto-RMM-File-Attachment-Guide.md for details.

############################################################################################################
#                                    EMBEDDED FUNCTION LIBRARY                                            #
############################################################################################################

# Embedded logging function
function Write-RMMLog {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Status', 'Success', 'Warning', 'Error', 'Failed', 'Config', 'Detect')]
        [string]$Level = 'Info'
    )
    
    $prefix = switch ($Level) {
        'Success' { 'SUCCESS ' }
        'Failed' { 'FAILED  ' }
        'Error' { 'ERROR   ' }
        'Warning' { 'WARNING ' }
        'Status' { 'STATUS  ' }
        'Config' { 'CONFIG  ' }
        'Detect' { 'DETECT  ' }
        default { 'INFO    ' }
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] $prefix$Message"
    Write-Output $logMessage
}

# Embedded environment variable function
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
            $envValue -eq 'true' -or $envValue -eq '1' -or $envValue -eq 'yes' 
        }
        default { $envValue }
    }
}

# Embedded software detection function
function Test-SoftwareInstalled {
    param([string]$SoftwareName)
    
    Write-RMMLog "Checking for existing installation of: $SoftwareName" -Level Status
    
    # Registry paths to check for installed software
    $RegPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($RegPath in $RegPaths) {
        try {
            $installedSoftware = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue
            foreach ($software in $installedSoftware) {
                if ($software.DisplayName -like "*$SoftwareName*") {
                    Write-RMMLog "Found installed software: $($software.DisplayName)" -Level Detect
                    Write-RMMLog "Publisher: $($software.Publisher)" -Level Detect
                    Write-RMMLog "Version: $($software.DisplayVersion)" -Level Detect
                    return $true
                }
            }
        }
        catch {
            Write-RMMLog "Error checking registry path $RegPath`: $($_.Exception.Message)" -Level Warning
        }
    }
    
    Write-RMMLog "$SoftwareName not found in registry" -Level Detect
    return $false
}

# Embedded installation function
function Install-Software {
    param(
        [string]$InstallerFile,
        [string]$InstallArgs = "/S /silent"
    )
    
    Write-RMMLog "Starting software installation..." -Level Status
    Write-RMMLog "Installer: $InstallerFile" -Level Config
    Write-RMMLog "Arguments: $InstallArgs" -Level Config
    
    # Check for installer file (Datto RMM file attachment)
    if (-not (Test-Path $InstallerFile)) {
        Write-RMMLog "Installer file not found: $InstallerFile" -Level Error
        Write-RMMLog "Please ensure the installer file is attached to the Datto RMM component" -Level Error
        return 1
    }
    
    Write-RMMLog "Found installer file: $InstallerFile" -Level Success
    
    try {
        # Execute installation
        $process = Start-Process -FilePath $InstallerFile -ArgumentList $InstallArgs -Wait -PassThru -NoNewWindow
        $exitCode = $process.ExitCode
        
        Write-RMMLog "Installation completed with exit code: $exitCode" -Level Status
        
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
    }
    catch {
        Write-RMMLog "Error during installation: $($_.Exception.Message)" -Level Error
        return 1
    }
}

############################################################################################################
#                                    MAIN SCRIPT LOGIC                                                    #
############################################################################################################

# Initialize logging
$LogPath = "C:\ProgramData\DattoRMM\Applications"
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

Start-Transcript -Path "$LogPath\Application-$(Get-Date -Format 'yyyyMMdd-HHmmss').log" -Append

Write-RMMLog "=============================================="
Write-RMMLog "Application Deployment Template v1.0.0" -Level Status
Write-RMMLog "=============================================="
Write-RMMLog "Component Category: Applications (Software Deployment)" -Level Config
Write-RMMLog "Start Time: $(Get-Date)" -Level Config
Write-RMMLog "Functions: Flexible (Embedded/Imported)" -Level Config
Write-RMMLog ""

# Process environment variables
$SoftwareName = Get-RMMVariable -Name "SoftwareName" -Default "Example Software"
$InstallerFile = Get-RMMVariable -Name "InstallerFile" -Default "installer.exe"
$InstallArgs = Get-RMMVariable -Name "InstallArgs" -Default "/S /silent"
$ForceReinstall = Get-RMMVariable -Name "ForceReinstall" -Type "Boolean" -Default $false

Write-RMMLog "Configuration:" -Level Config
Write-RMMLog "- Software Name: $SoftwareName" -Level Config
Write-RMMLog "- Installer File: $InstallerFile" -Level Config
Write-RMMLog "- Install Arguments: $InstallArgs" -Level Config
Write-RMMLog "- Force Reinstall: $ForceReinstall" -Level Config
Write-RMMLog ""

# Main execution
$exitCode = 0

try {
    # Check if software is already installed
    $isInstalled = Test-SoftwareInstalled -SoftwareName $SoftwareName
    
    if ($isInstalled -and -not $ForceReinstall) {
        Write-RMMLog "$SoftwareName is already installed" -Level Status
        Write-RMMLog "Skipping installation - software already present" -Level Success
        $exitCode = 0
    }
    else {
        if ($isInstalled -and $ForceReinstall) {
            Write-RMMLog "$SoftwareName is installed but ForceReinstall is enabled" -Level Status
        }
        else {
            Write-RMMLog "$SoftwareName not installed - proceeding with installation" -Level Status
        }
        
        $exitCode = Install-Software -InstallerFile $InstallerFile -InstallArgs $InstallArgs
    }
    
}
catch {
    Write-RMMLog "Unexpected error during execution: $($_.Exception.Message)" -Level Error
    Write-RMMLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    $exitCode = 1
}
finally {
    Write-RMMLog ""
    Write-RMMLog "=============================================="
    Write-RMMLog "Application deployment completed" -Level Status
    Write-RMMLog "Final exit code: $exitCode" -Level Status
    Write-RMMLog "End Time: $(Get-Date)" -Level Status
    Write-RMMLog "=============================================="
    
    Stop-Transcript
    exit $exitCode
}
