<#
.SYNOPSIS
  Install OpenVPN Connect v3 silently and import an attached profile (.ovpn or .json/.onc) using the official CLI (ovpnconnector.exe).

.PARAMETERS (Datto RMM Input Variables)
  usrProfileFile         Filename of attached profile to import (default: first *.ovpn or *.json/*.onc found)
  usrProfileName         Friendly display name override (default: filename without extension)
  usrAutoConnect         "true" | "false" (default: "false")
  usrExpectedMsiSHA256   Optional MSI SHA256 to enforce
  usrAuthSign            "true" to enforce Authenticode subject contains "OpenVPN Technologies" (default: "false")

.NOTES
  - Uses Datto RMM File Attachment pattern (attachments available in working dir)
  - Logs to %ProgramData%\RMM\Logs
  - Exits 0 on success; non-zero on failure with reason
  - Import via: ovpnconnector.exe import --name "<ProfileName>" --source "<FullPathToProfile>"
  - Docs: https://openvpn.net/connect-docs/command-line-functionality-windows.html
#>

# region Helpers -----------------------------------------------------------------------------------------------

# Ensure TLS 1.2+
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$ErrorActionPreference = 'Stop'
$global:StartTime = Get-Date
$LogRoot = Join-Path $env:ProgramData 'RMM\Logs'
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
$Epoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$LogFile = Join-Path $LogRoot "OpenVPNConnect-$Epoch.log"

# Reduce noisy progress bars in PS 5.1 web operations
$ProgressPreference = 'SilentlyContinue'

function Write-RMMLog {
  param([string]$Message,[string]$Level='INFO')
  $stamp = (Get-Date).ToString('s')
  $line = "[$stamp][$Level] $Message"
  Write-Output $line
  try { Add-Content -Path $LogFile -Value $line } catch {}
}

function Test-Admin {
  try {
    $wi = [Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = New-Object Security.Principal.WindowsPrincipal($wi)
    return $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

function Get-FileSHA256 {
  param([string]$Path)
  $sha = Get-FileHash -Algorithm SHA256 -Path $Path
  return $sha.Hash.ToLower()
}

function Test-AuthenticodeSubject {
  param([string]$Path,[string]$SubjectMatch)
  $sig = Get-AuthenticodeSignature -FilePath $Path
  if ($sig.Status -ne 'Valid') { return $false }
  return ($sig.SignerCertificate.Subject -like "*$SubjectMatch*")
}

function Invoke-DownloadWithRetry {
  param(
    [string]$Url,
    [string]$OutFile,
    [int]$MaxAttempts = 4,
    [int]$InitialDelaySec = 2
  )
  $attempt = 0
  while ($true) {
    $attempt++
    try {
      Write-RMMLog "Downloading: $Url (attempt $attempt/$MaxAttempts) -> $OutFile"
      $wc = New-Object System.Net.WebClient
      $wc.Headers['User-Agent'] = "DattoRMM-OpenVPNConnect/1.0"
      $wc.DownloadFile($Url, $OutFile)
      if (Test-Path $OutFile -PathType Leaf -ErrorAction SilentlyContinue) {
        $size = (Get-Item $OutFile).Length
        if ($size -gt 1000000) { # >1 MB sanity
          Write-RMMLog "Download completed, size=$size bytes"
          try { $wc.Dispose() } catch {}
          return
        } else {
          try { $wc.Dispose() } catch {}
          throw "Downloaded file too small ($size bytes)"
        }
      } else {
        try { $wc.Dispose() } catch {}
        throw "File not found after download"
      }
    } catch {
      if ($attempt -ge $MaxAttempts) {
        throw "Download failed after $MaxAttempts attempts: $($_.Exception.Message)"
      }
      $delay = [Math]::Min(30, $InitialDelaySec * [Math]::Pow(2, $attempt-1))
      Write-RMMLog "Download attempt failed: $($_.Exception.Message). Retrying in $delay sec..." 'WARN'
      Start-Sleep -Seconds $delay
    }
  }
}

# endregion Helpers --------------------------------------------------------------------------------------------

# region Inputs ------------------------------------------------------------------------------------------------

$ProfileFile        = $env:usrProfileFile
$ProfileName        = $env:usrProfileName
$AutoConnect        = $env:usrAutoConnect
$ExpectedMsiSHA256  = ''
if ($env:usrExpectedMsiSHA256) { $ExpectedMsiSHA256 = $env:usrExpectedMsiSHA256.ToLower() }
$EnforceAuthSign    = ($env:usrAuthSign -eq 'true')

if ([string]::IsNullOrWhiteSpace($AutoConnect)) { $AutoConnect = 'false' }

# Find attached profile if not provided
if ([string]::IsNullOrWhiteSpace($ProfileFile)) {
  $candidates = @()
  $candidates += Get-ChildItem -File -Filter *.ovpn -ErrorAction SilentlyContinue
  $candidates += Get-ChildItem -File -Filter *.json -ErrorAction SilentlyContinue
  $candidates += Get-ChildItem -File -Filter *.onc -ErrorAction SilentlyContinue
  if ($candidates.Count -eq 0) {
    Write-RMMLog "No attached .ovpn/.json/.onc profile found and usrProfileFile not provided." 'ERROR'
    exit 2
  }
  $ProfileFile = $candidates[0].FullName
} elseif (-not (Test-Path $ProfileFile)) {
  # If just a filename, look in current dir
  $candidate = Join-Path (Get-Location) $ProfileFile
  if (Test-Path $candidate) { $ProfileFile = $candidate } else {
    Write-RMMLog "Provided profile file not found: $ProfileFile" 'ERROR'
    exit 2
  }
}
if ([string]::IsNullOrWhiteSpace($ProfileName)) {
  $ProfileName = [IO.Path]::GetFileNameWithoutExtension($ProfileFile)
}

Write-RMMLog "Using profile file: $ProfileFile (name='$ProfileName', autoConnect=$AutoConnect)"

# endregion Inputs ---------------------------------------------------------------------------------------------

# region Download + Verify MSI ---------------------------------------------------------------------------------

$TempDir = Join-Path $env:ProgramData "RMM\Temp"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
$MsiName = "openvpn-connect-v3-windows.msi"
$MsiPath = Join-Path (Get-Location) $MsiName
$MsiDlPath = Join-Path $TempDir $MsiName

# Require elevation for installation
if (-not (Test-Admin)) {
  Write-RMMLog "This script must be run with administrative privileges (elevated)." 'ERROR'
  exit 1
}

# Prefer attached MSI if provided with the component
if (-not (Test-Path $MsiPath)) {
  Write-RMMLog "Attached MSI not found. Will download vendor MSI."
  Invoke-DownloadWithRetry -Url "https://openvpn.net/downloads/openvpn-connect-v3-windows.msi" -OutFile $MsiDlPath
} else {
  Write-RMMLog "Found attached MSI: $MsiPath"
  Copy-Item $MsiPath -Destination $MsiDlPath -Force
}

# Hash logging and optional enforcement
$hash = Get-FileSHA256 -Path $MsiDlPath
Write-RMMLog "MSI SHA256: $hash"
if ($ExpectedMsiSHA256 -and ($hash -ne $ExpectedMsiSHA256)) {
  Write-RMMLog "MSI SHA256 mismatch. Expected=$ExpectedMsiSHA256 Got=$hash" 'ERROR'
  exit 3
}

# Optional Authenticode subject enforcement
if ($EnforceAuthSign) {
  if (-not (Test-AuthenticodeSubject -Path $MsiDlPath -SubjectMatch 'OpenVPN Technologies')) {
    Write-RMMLog "Authenticode subject validation failed (expected contains 'OpenVPN Technologies')." 'ERROR'
    exit 3
  } else {
    Write-RMMLog "Authenticode subject validation passed."
  }
}

# endregion Download + Verify MSI ------------------------------------------------------------------------------

# region Install / Upgrade -------------------------------------------------------------------------------------

# Detect existing
$installedVersion = $null
$uninstKeys = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)
foreach ($k in $uninstKeys) {
  Get-ChildItem $k -ErrorAction SilentlyContinue | ForEach-Object {
    try {
      $dn = (Get-ItemProperty $_.PsPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
      if ($dn -and $dn -like 'OpenVPN Connect*') {
        $installedVersion = (Get-ItemProperty $_.PsPath -Name DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion
      }
    } catch {}
  }
}
$IsUpgrade = -not [string]::IsNullOrWhiteSpace($installedVersion)
if ($IsUpgrade) { Write-RMMLog "Detected existing OpenVPN Connect version: $installedVersion (upgrade scenario)" } else { Write-RMMLog "OpenVPN Connect not detected (fresh install)" }

# Install (msiexec handles upgrade if applicable)
$msiLog = Join-Path $LogRoot "OpenVPNConnect-Install-$Epoch.msilog"
$arguments = "/i `"$MsiDlPath`" /qn /norestart /log `"$msiLog`""
if ($IsUpgrade) {
  Write-RMMLog "Proceeding to upgrade OpenVPN Connect from version $installedVersion"
} else {
  Write-RMMLog "Proceeding with fresh installation of OpenVPN Connect"
}
Write-RMMLog "Installing via msiexec with args: $arguments"
$proc = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
Write-RMMLog "msiexec exit code: $($proc.ExitCode)"

if ($proc.ExitCode -ne 0) {
  Write-RMMLog "Installation failed. See msilog at: $msiLog" 'ERROR'
  exit 4
}

# Cleanup downloaded MSI
try {
  if (Test-Path $MsiDlPath) {
    Remove-Item -Path $MsiDlPath -Force -ErrorAction SilentlyContinue
    Write-RMMLog "Cleaned up downloaded MSI: $MsiDlPath"
  }
} catch { Write-RMMLog "Cleanup warning: $($_.Exception.Message)" 'WARN' }

# endregion Install / Upgrade ----------------------------------------------------------------------------------

# region Locate CLI --------------------------------------------------------------------------------------------

$OvpnConnector = @(
  "$env:ProgramFiles\OpenVPN Connect\ovpnconnector.exe",
  "$env:ProgramFiles(x86)\OpenVPN Connect\ovpnconnector.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $OvpnConnector) {
  Write-RMMLog "ovpnconnector.exe not found. Ensure OpenVPN Connect v3.3+ is installed." 'ERROR'
  exit 5
}
Write-RMMLog "Using CLI: $OvpnConnector"

# endregion Locate CLI -----------------------------------------------------------------------------------------

# region Profile Import via CLI --------------------------------------------------------------------------------

# Check CLI version (best-effort)
try {
  $verText = ''
  $null = & $OvpnConnector '--version' 2>&1 | ForEach-Object { $verText += ($_ + [Environment]::NewLine) }
  if (-not $verText) {
    $verText = (& $OvpnConnector 'version' 2>&1) -join [Environment]::NewLine
  }
  if ($verText) {
    $m = [regex]::Match($verText, '(\d+\.\d+(?:\.\d+)?)')
    if ($m.Success) {
      $ovpnVer = [version]$m.Groups[1].Value
      Write-RMMLog "Detected OpenVPN Connect CLI version: $ovpnVer"
      if ($ovpnVer -lt [version]'3.3.0.0') {
        Write-RMMLog "CLI version appears older than 3.3; some commands may not be available." 'WARN'
      }
    } else {
      Write-RMMLog "Unable to parse CLI version output; proceeding." 'WARN'
    }
  }
} catch { Write-RMMLog "Version check failed (non-fatal): $($_.Exception.Message)" 'WARN' }

# Determine if profile already exists (idempotent import)
$profileExists = $false
try {
  $listOutPre = & $OvpnConnector 'profile-list' 2>&1
  $listRCPre = $LASTEXITCODE
  if ($listRCPre -eq 0) {
    foreach ($line in $listOutPre) {
      if ($line -match [Regex]::Escape($ProfileName)) { $profileExists = $true; break }
    }
  } else {
    Write-RMMLog "profile-list pre-check returned RC=$listRCPre; proceeding to import." 'WARN'
  }
} catch { Write-RMMLog "profile-list pre-check failed: $($_.Exception.Message)" 'WARN' }

# Import only if not already present
if (-not $profileExists) {
  try {
    $cliArgs = @('import','--name', $ProfileName, '--source', $ProfileFile)
    Write-RMMLog "Running import: ovpnconnector.exe $($cliArgs -join ' ')" 'INFO'
    $importOut = & $OvpnConnector @cliArgs 2>&1
    $importRC = $LASTEXITCODE
    Write-RMMLog ("Import output:\n" + ($importOut -join [Environment]::NewLine))
    if ($importRC -ne 0) { throw "ovpnconnector import exit code $importRC" }
  } catch {
    Write-RMMLog "Profile import failed: $($_.Exception.Message)" 'ERROR'
    exit 6
  }
} else {
  Write-RMMLog "Profile '$ProfileName' already present. Skipping import."
}

# Verify profile exists
try {
  $listOut = & $OvpnConnector 'profile-list' 2>&1
  $listRC = $LASTEXITCODE
  if ($listRC -ne 0) { throw "profile-list RC=$listRC" }
  $found = $false
  foreach ($line in $listOut) { if ($line -match [Regex]::Escape($ProfileName)) { $found = $true; break } }
  if (-not $found) { throw "Imported profile not found in profile-list" }
  Write-RMMLog "Profile '$ProfileName' verified present."
} catch {
  Write-RMMLog "Profile verification warning: $($_.Exception.Message)" 'WARN'
}

# Optional connect
if ($AutoConnect -eq 'true') {
  try {
    Write-RMMLog "AutoConnect requested: connecting profile '$ProfileName'"
    $connOut = & $OvpnConnector 'profile-connect' '--name' $ProfileName 2>&1
    $connRC = $LASTEXITCODE
    Write-RMMLog ("Connect output:\n" + ($connOut -join [Environment]::NewLine))
    if ($connRC -ne 0) { throw "profile-connect RC=$connRC" }
  } catch {
    Write-RMMLog "AutoConnect failed: $($_.Exception.Message)" 'WARN'
  }
}

# endregion Profile Import via CLI -----------------------------------------------------------------------------

Write-RMMLog "Completed in $([int]((Get-Date) - $global:StartTime).TotalSeconds)s"
Write-RMMLog "Done."
# Surface helpful tail of the log to Datto RMM output
try {
  Write-Output "---- OpenVPN Connect Installer Log (tail) ----"
  if (Test-Path $LogFile) {
    (Get-Content -Path $LogFile -Tail 80 -ErrorAction SilentlyContinue) | ForEach-Object { Write-Output $_ }
  } else {
    Write-Output "Log file not found: $LogFile"
  }
  Write-Output "---------------------------------------------"
} catch {}
exit 0
