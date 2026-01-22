<#
.SYNOPSIS
    Deploy Mark of the Web (MotW) Bypass Policy

.DESCRIPTION
    Enables the "Do not preserve zone information" Group Policy setting to prevent Windows
    from tagging new downloads with Mark of the Web (MotW). This restores File Explorer
    preview functionality for files downloaded from the internet.

    The script configures the HKCU registry setting that corresponds to:
    User Configuration > Administrative Templates > Windows Components > Attachment Manager
    > Do not preserve zone information in file attachments

    Features:
    - Creates registry path if it doesn't exist
    - Sets SaveZoneInformation policy value
    - Verifies policy was applied successfully
    - Supports both user and system context execution

    Requirements:
    - Windows 10 1703+ or Windows 11
    - No restart required (takes effect on new downloads immediately)

.COMPONENT
    Category: Scripts (Security/Windows Configuration)
    Execution: On-demand or scheduled
    Timeout: 5 minutes recommended
    Changeable: Yes

.ENVIRONMENT VARIABLES
    Optional:
    - TargetUser (String): Specific user SID to target when running as SYSTEM (default: current user)
    - EnableLogging (Boolean): Enable detailed RMM transcript logging (default: true)

.EXAMPLES
    Environment Variables in Datto RMM:
    EnableLogging = true

    Run Context:
    - User: Applies to current logged-in user (recommended)
    - System: Applies to SYSTEM context HKCU (use TargetUser for specific user)

.NOTES
    Version: 1.0.0
    Author: Datto RMM Self-Contained Architecture
    Compatible: PowerShell 5.0+, Windows 10 1703+, Windows 11
    Deployment: DIRECT (paste script content directly into Datto RMM)

    Exit Codes:
      0 = Success - Policy applied and verified
      1 = Failed - Policy verification failed
      2 = Error - Registry operation failed

    Security Note:
    This policy prevents MotW tagging on NEW downloads only. Existing files with MotW
    must be unblocked separately using the Unblock-InternetFiles script.
#>

param(
    [string]$TargetUser = $env:TargetUser,
    [bool]$EnableLogging = ($env:EnableLogging -ne "false")
)

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
        'Failed'  { 'FAILED  ' }
        'Error'   { 'ERROR   ' }
        'Warning' { 'WARNING ' }
        'Status'  { 'STATUS  ' }
        'Config'  { 'CONFIG  ' }
        'Detect'  { 'DETECT  ' }
        default   { 'INFO    ' }
    }

    Write-Output "$prefix$Message"
}

# Function to set MotW policy
function Set-MotWPolicy {
    param(
        [string]$RegistryPath,
        [string]$RegistryName,
        [int]$RegistryValue
    )

    try {
        # Create registry path if it doesn't exist
        if (-not (Test-Path $RegistryPath)) {
            New-Item -Path $RegistryPath -Force -ErrorAction Stop | Out-Null
            Write-RMMLog "Created registry path: $RegistryPath" -Level Config
        }

        # Set the policy value
        Set-ItemProperty -Path $RegistryPath -Name $RegistryName -Value $RegistryValue -Type DWord -Force -ErrorAction Stop
        Write-RMMLog "Set registry value: $RegistryName = $RegistryValue" -Level Success

        return $true
    }
    catch {
        Write-RMMLog "Failed to set registry value: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Function to verify MotW policy
function Test-MotWPolicy {
    param(
        [string]$RegistryPath,
        [string]$RegistryName,
        [int]$ExpectedValue
    )

    try {
        $currentValue = (Get-ItemProperty -Path $RegistryPath -Name $RegistryName -ErrorAction Stop).$RegistryName

        if ($currentValue -eq $ExpectedValue) {
            Write-RMMLog "Policy verification passed: $RegistryName = $currentValue" -Level Success
            return $true
        }
        else {
            Write-RMMLog "Policy verification failed: Expected $ExpectedValue, got $currentValue" -Level Failed
            return $false
        }
    }
    catch {
        Write-RMMLog "Failed to verify policy: $($_.Exception.Message)" -Level Error
        return $false
    }
}

############################################################################################################
#                                    MAIN SCRIPT LOGIC                                                    #
############################################################################################################

# Initialize logging
$LogPath = "C:\ProgramData\DattoRMM\Scripts"
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

if ($EnableLogging) {
    Start-Transcript -Path "$LogPath\Deploy-MotW-Policy-$(Get-Date -Format 'yyyyMMdd-HHmmss').log" -Append
}

Write-RMMLog "=============================================="
Write-RMMLog "Deploy Mark of the Web (MotW) Bypass Policy v1.0.0" -Level Status
Write-RMMLog "=============================================="
Write-RMMLog "Component Category: Scripts (Security/Windows Configuration)" -Level Config
Write-RMMLog "Start Time: $(Get-Date)" -Level Config
Write-RMMLog ""

# Configuration
$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments"
$RegName = "SaveZoneInformation"
$RegValue = 1  # 1 = Do not preserve zone information (bypass MotW)

Write-RMMLog "Configuration:" -Level Config
Write-RMMLog "- Registry Path: $RegPath" -Level Config
Write-RMMLog "- Registry Name: $RegName" -Level Config
Write-RMMLog "- Registry Value: $RegValue (Do not preserve zone information)" -Level Config
Write-RMMLog "- Current User: $env:USERNAME" -Level Config
Write-RMMLog "- Computer Name: $env:COMPUTERNAME" -Level Config
Write-RMMLog ""

# Detect Windows version
$osVersion = [System.Environment]::OSVersion.Version
$osBuild = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).BuildNumber
Write-RMMLog "Windows Version: $($osVersion.Major).$($osVersion.Minor) (Build $osBuild)" -Level Detect

# Verify Windows 10 1703+ or Windows 11
if ($osVersion.Major -lt 10) {
    Write-RMMLog "This script requires Windows 10 or later" -Level Warning
}
Write-RMMLog ""

# Main execution
$exitCode = 0

try {
    Write-RMMLog "Starting MotW policy deployment..." -Level Status

    # Check current policy state
    Write-RMMLog "Checking current policy state..." -Level Status
    $currentExists = Test-Path $RegPath
    if ($currentExists) {
        $currentValue = (Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction SilentlyContinue).$RegName
        if ($null -ne $currentValue) {
            Write-RMMLog "Current policy value: $currentValue" -Level Detect
            if ($currentValue -eq $RegValue) {
                Write-RMMLog "Policy is already configured correctly" -Level Success
            }
        }
        else {
            Write-RMMLog "Policy not currently set" -Level Detect
        }
    }
    else {
        Write-RMMLog "Policy registry path does not exist (will be created)" -Level Detect
    }

    Write-RMMLog ""

    # Apply policy
    Write-RMMLog "Applying MotW bypass policy..." -Level Status
    $setResult = Set-MotWPolicy -RegistryPath $RegPath -RegistryName $RegName -RegistryValue $RegValue

    if (-not $setResult) {
        Write-RMMLog "Failed to apply MotW policy" -Level Failed
        $exitCode = 2
    }
    else {
        Write-RMMLog ""

        # Verify policy was applied
        Write-RMMLog "Verifying policy application..." -Level Status
        $verifyResult = Test-MotWPolicy -RegistryPath $RegPath -RegistryName $RegName -ExpectedValue $RegValue

        if ($verifyResult) {
            Write-RMMLog ""
            Write-RMMLog "MotW bypass policy deployed successfully" -Level Success
            Write-RMMLog "New downloads will no longer be tagged with Mark of the Web" -Level Info
            Write-RMMLog "File Explorer preview should now work for internet-downloaded files" -Level Info
            $exitCode = 0
        }
        else {
            Write-RMMLog "Policy verification failed after deployment" -Level Failed
            $exitCode = 1
        }
    }

}
catch {
    Write-RMMLog "Unexpected error during execution: $($_.Exception.Message)" -Level Error
    Write-RMMLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    $exitCode = 2
}
finally {
    Write-RMMLog ""
    Write-RMMLog "=============================================="
    Write-RMMLog "MotW Policy Deployment completed" -Level Status
    Write-RMMLog "Final exit code: $exitCode" -Level Status
    Write-RMMLog "End Time: $(Get-Date)" -Level Status
    Write-RMMLog "=============================================="

    if ($EnableLogging) {
        Stop-Transcript
    }
    exit $exitCode
}
