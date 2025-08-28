<#
.SYNOPSIS
  Deploy a preconfigured .rdp file to Public Desktop and all user profiles' Desktops via Datto RMM.

.DESCRIPTION
  Generates an .rdp file pointing to a given RDS server IP/hostname (no RD Web or Gateway) and copies it to:
  - C:\Users\Public\Desktop
  - Each existing profile under C:\Users\<User>\Desktop (excluding system profiles)

.PARAMETERS (Datto RMM Input Variables)
  usrRdsAddress       RDS server IP or hostname (required). Example: 203.0.113.25 or rds.company.local
  usrRdpFilename      Optional filename for the .rdp (default: "RDS-Remote-Desktop.rdp")
  usrFriendlyName     Optional friendly name stored inside the file (default: same as filename without extension)
  usrCreatePerUser    "true" | "false" to copy to each user profile Desktop (default: "true")
  usrUseAllScreens       "true" | "false" to use all monitors (multimon) (default: "true")

.BEHAVIOR
  - Username prefill: Not used. Username field is left blank so the client prompts. AD-friendly defaults are applied.
  - Authentication defaults: Uses secure defaults for AD-backed RDS: prompt for credentials=1, authentication level=2, CredSSP enabled=1.

.NOTES
  - No RD Web or Gateway is configured; direct RDP to the provided address.
  - Idempotent: always overwrites existing file.
  - Logs to %ProgramData%\RMM\Logs
  - Exit Codes: 0 = Success; non-zero = Failure
#>

# region Setup -------------------------------------------------------------------------------------------------
$ErrorActionPreference = 'Stop'
$StartTime = Get-Date
$LogRoot = Join-Path $env:ProgramData 'RMM\Logs'
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
$Epoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$LogFile = Join-Path $LogRoot "Deploy-RDP-$Epoch.log"

function Write-RMMLog {
  param([string]$Message,[string]$Level='INFO')
  $stamp = (Get-Date).ToString('s')
  $line = "[$stamp][$Level] $Message"
  Write-Output $line
  try { Add-Content -Path $LogFile -Value $line } catch { Write-Output "[WARN] Failed to write to log file: $($_.Exception.Message)" }
}
# endregion Setup ----------------------------------------------------------------------------------------------

# region Inputs ------------------------------------------------------------------------------------------------
$RdsAddress     = $env:usrRdsAddress
$RdpFilename    = $env:usrRdpFilename
$FriendlyName   = $env:usrFriendlyName
$CreatePerUser  = $env:usrCreatePerUser
$UseAllScreens  = $env:usrUseAllScreens

if ([string]::IsNullOrWhiteSpace($CreatePerUser)) { $CreatePerUser = 'true' }
if ([string]::IsNullOrWhiteSpace($RdpFilename))  { $RdpFilename = 'RDS-Remote-Desktop.rdp' }
if ([string]::IsNullOrWhiteSpace($UseAllScreens)) { $UseAllScreens = 'true' }

if ([string]::IsNullOrWhiteSpace($RdsAddress)) {
  Write-RMMLog "usrRdsAddress is required (IP or hostname)." 'ERROR'
  exit 2
}

if ([string]::IsNullOrWhiteSpace($FriendlyName)) {
  $FriendlyName = [IO.Path]::GetFileNameWithoutExtension($RdpFilename)
}

Write-RMMLog "Configuration: Address='$RdsAddress' File='$RdpFilename' FriendlyName='$FriendlyName' PerUserCopy=$CreatePerUser UseAllScreens=$UseAllScreens"
# endregion Inputs ---------------------------------------------------------------------------------------------

# region Build RDP content -------------------------------------------------------------------------------------
# Minimal, sane defaults for direct RDP to host/IP with credential prompt, CredSSP, full screen.
# Reference: https://learn.microsoft.com/windows-server/remote/remote-desktop-services/clients/rdp-files
$useMultiMon = if ($UseAllScreens -eq 'true') { 1 } else { 0 }
$usernameLine = "username:s="

$rdpContent = @(
  "full address:s=$RdsAddress"
  "prompt for credentials:i=1"
  "authentication level:i=2"
  "enablecredsspsupport:i=1"
  "screen mode id:i=2"              # 2 = Full screen
  "use multimon:i=$useMultiMon"
  "smart sizing:i=1"
  "session bpp:i=32"
  "redirectprinters:i=1"
  "redirectdrives:i=0"
  "audiomode:i=0"                    # Bring to this computer
  "allow font smoothing:i=1"
  "disable wallpaper:i=1"
  "disable themes:i=0"
  "disable full window drag:i=1"
  "disable menu anims:i=1"
  "bitmapcachepersistenable:i=1"
  "drivestoredirect:s:"
  "promptcredentialonce:i=0"
  $usernameLine
  "pcb:s=$FriendlyName"
)

# Validate content minimally
if (-not ($rdpContent -match "^full address:s=.*")) {
  Write-RMMLog "Failed to build RDP content (full address missing)." 'ERROR'
  exit 3
}
# endregion Build RDP content ----------------------------------------------------------------------------------

# region Write to Public Desktop --------------------------------------------------------------------------------
$publicDesktop = Join-Path $env:Public 'Desktop'
try { New-Item -ItemType Directory -Path $publicDesktop -Force | Out-Null } catch { Write-RMMLog "Failed to ensure Public Desktop folder: $($_.Exception.Message)" 'WARN' }
$publicRdpPath = Join-Path $publicDesktop $RdpFilename

try {
  Write-RMMLog "Writing RDP file to Public Desktop: $publicRdpPath" 'STATUS'
  $rdpContent | Out-File -FilePath $publicRdpPath -Encoding ASCII -Force
  if (-not (Test-Path $publicRdpPath)) { throw "File not created: $publicRdpPath" }
  Write-RMMLog "Public Desktop RDP created/updated: $publicRdpPath" 'SUCCESS'
} catch {
  Write-RMMLog "Failed to write to Public Desktop: $($_.Exception.Message)" 'ERROR'
  exit 4
}
# endregion Write to Public Desktop ---------------------------------------------------------------------------

# region Copy to each user profile Desktop ---------------------------------------------------------------------
if ($CreatePerUser -eq 'true') {
  try {
    $usersRoot = 'C:\\Users'
    $exclude = @('Public','Default','Default User','All Users','WDAGUtilityAccount','DefaultAppPool')
    $profiles = Get-ChildItem -Path $usersRoot -Directory -ErrorAction SilentlyContinue |
      Where-Object { $exclude -notcontains $_.Name }

    foreach ($p in $profiles) {
      $desktop = Join-Path $p.FullName 'Desktop'
      try { if (-not (Test-Path $desktop)) { New-Item -ItemType Directory -Path $desktop -Force | Out-Null } } catch { Write-RMMLog "Failed to ensure Desktop folder for '$($p.Name)': $($_.Exception.Message)" 'WARN' }
      $dest = Join-Path $desktop $RdpFilename
      try {
        Write-RMMLog "Copying to user Desktop: $dest" 'STATUS'
        Copy-Item -Path $publicRdpPath -Destination $dest -Force
        if (-not (Test-Path $dest)) { throw "Copy failed: $dest" }
        Write-RMMLog "Updated: $dest" 'SUCCESS'
      } catch {
        Write-RMMLog "Failed to copy to '$($p.Name)' Desktop: $($_.Exception.Message)" 'WARN'
      }
    }
  } catch {
    Write-RMMLog "User profile enumeration failed: $($_.Exception.Message)" 'ERROR'
    # Don't hard fail if Public Desktop already succeeded; continue
  }
} else {
  Write-RMMLog "Per-user copy disabled by usrCreatePerUser=$CreatePerUser"
}
# endregion Copy to each user profile Desktop ------------------------------------------------------------------

# region Finish -------------------------------------------------------------------------------------------------
Write-RMMLog "Completed in $([int]((Get-Date) - $StartTime).TotalSeconds)s"
Write-RMMLog "Done."
# Surface helpful tail of the log to Datto RMM output
try {
  Write-Output "---- Deploy-RDP Log (tail) ----"
  if (Test-Path $LogFile) {
    (Get-Content -Path $LogFile -Tail 80 -ErrorAction SilentlyContinue) | ForEach-Object { Write-Output $_ }
  } else {
    Write-Output "Log file not found: $LogFile"
  }
  Write-Output "-------------------------------"
} catch { Write-RMMLog "Failed to output log tail: $($_.Exception.Message)" 'WARN' }
exit 0
# endregion Finish ---------------------------------------------------------------------------------------------
