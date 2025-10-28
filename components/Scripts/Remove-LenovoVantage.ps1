<#
.SYNOPSIS
Datto RMM remediation script to remove Lenovo Commercial Vantage.

.DESCRIPTION
Runs Lenovo's supported uninstaller (`VantageInstaller.exe Uninstall -Vantage`) to remove the Commercial Vantage UWP app, Lenovo Vantage Service, and add-ins. Handles prerequisite checks, structured logging for Datto RMM, and verifies removal by inspecting Lenovo services and AppX packages.

.COMPONENT
Category=Applications ; Level=Medium(3) ; Timeout=600s ; Build=1.0.0

.REQUIRES
LocalSystem ; PSVersion >=5.1

.INPUTS
installerPath(String) ; skipWhenMissing(Boolean)

.OUTPUTS
Writes progress and result messages to stdout for Datto RMM collection.

.NOTES
Author: Codex (GPT-5)
Created: 2025-10-28
Purpose: Removes Lenovo Commercial Vantage on Lenovo endpoints where VantageInstaller.exe is supplied alongside the script.

.LINK
https://blog.lenovocdrt.com/deploying-commercial-vantage-with-intune/
https://docs.lenovocdrt.com/guides/cv/commercial_vantage/
#>

#requires -Version 5.1

param(
    [string]$installerPath = $env:installerPath,
    [bool]$skipWhenMissing = ($env:skipWhenMissing -eq 'true')
)

Set-StrictMode -Version Latest

function Write-RMMLog {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,

        [ValidateSet('Info','Status','Success','Warning','Error','Failed','Config')]
        [string]$Level = 'Info'
    )

    $prefix = switch ($Level) {
        'Status'  { 'STATUS  ' }
        'Success' { 'SUCCESS ' }
        'Warning' { 'WARNING ' }
        'Error'   { 'ERROR   ' }
        'Failed'  { 'FAILED  ' }
        'Config'  { 'CONFIG  ' }
        default   { 'INFO    ' }
    }

    Write-Output "$prefix$Message"
}

function Test-IsAdministrator {
    try {
        $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-RMMLog "Unable to evaluate administrator rights: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

if (-not (Test-IsAdministrator)) {
    Write-RMMLog "Administrator privileges are required to operate VantageInstaller.exe" -Level 'Failed'
    exit 10
}

Write-RMMLog "Preparing Lenovo Commercial Vantage removal workflow" -Level 'Status'

$scriptRoot = Split-Path -Parent $PSCommandPath
if (-not $scriptRoot) {
    $scriptRoot = Get-Location
}

if ([string]::IsNullOrWhiteSpace($installerPath)) {
    $installerPath = Join-Path -Path $scriptRoot -ChildPath 'VantageInstaller.exe'
    Write-RMMLog "Installer path not provided; defaulting to $installerPath" -Level 'Config'
}

if (-not (Test-Path -Path $installerPath -PathType Leaf)) {
    $msg = "VantageInstaller.exe not found at '$installerPath'. Upload the executable alongside this script or provide installerPath."
    if ($skipWhenMissing) {
        Write-RMMLog $msg -Level 'Warning'
        Write-RMMLog "Skip requested; exiting without changes." -Level 'Status'
        exit 0
    }
    Write-RMMLog $msg -Level 'Failed'
    exit 2
}

Write-RMMLog "Resolved VantageInstaller.exe location: $installerPath" -Level 'Config'

function Test-VantagePresent {
    # Checks for Lenovo Vantage services or AppX packages that indicate presence.
    try {
        $services = @('LenovoVantageService','ImControllerService')
        $serviceExists = $services | ForEach-Object {
            Get-Service -Name $_ -ErrorAction SilentlyContinue
        } | Where-Object { $_.Status -ne $null }

        if ($serviceExists) {
            return $true
        }

        $appxNames = @('E046963F.LenovoCompanion','Lenovo.Vantage')
        $appxFound = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Where-Object { $appxNames -contains $_.Name }

        return [bool]$appxFound
    }
    catch {
        Write-RMMLog "Detection check failed: $($_.Exception.Message)" -Level 'Warning'
        return $true
    }
}

if (-not (Test-VantagePresent)) {
    Write-RMMLog "Lenovo Commercial Vantage is not detected; nothing to remove." -Level 'Success'
    exit 0
}

Write-RMMLog "Invoking VantageInstaller.exe for removal (Uninstall -Vantage)" -Level 'Status'

try {
    & $installerPath 'Uninstall' '-Vantage'
    $exitCode = $LASTEXITCODE
}
catch {
    Write-RMMLog "Failed to launch VantageInstaller.exe: $($_.Exception.Message)" -Level 'Failed'
    exit 3
}

if ($null -eq $exitCode) {
    $exitCode = 0
}

Write-RMMLog "VantageInstaller.exe completed with exit code $exitCode" -Level 'Info'

if ($exitCode -ne 0) {
    Write-RMMLog "VantageInstaller.exe reported a non-zero exit code." -Level 'Failed'
    exit $exitCode
}

Start-Sleep -Seconds 5

if (Test-VantagePresent) {
    Write-RMMLog "Post-uninstall validation indicates Lenovo Commercial Vantage artifacts still present." -Level 'Failed'
    exit 1
}

Write-RMMLog "Lenovo Commercial Vantage removed successfully." -Level 'Success'
exit 0
