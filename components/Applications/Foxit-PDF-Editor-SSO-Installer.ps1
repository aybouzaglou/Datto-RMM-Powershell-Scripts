<# foxit pdf editor msi installer :: build 3/2025, november 2025
   script variables: usrAction/sel (install/upgrade/uninstall) :: @usrFoxitKillSITE/Bln :: @usrMsiFileName/str

   PURPOSE: Installs Foxit PDF Editor+ (subscription version) using MSI file attached to Datto RMM component

   DEPLOYMENT METHOD:
   1. Download Foxit PDF Editor+ MSI from Foxit (subscription/2025.x version for SSO support)
   2. Attach the MSI file to this component in Datto RMM
   3. Set usrMsiFileName variable to the exact filename (e.g., "FoxitPDFEditor20252_L10N_Setup.msi")
   4. Run the component to deploy

   SSO ACTIVATION REQUIREMENT:
   This script installs Foxit PDF Editor silently. Users must complete SSO activation
   on first launch by clicking "Activate" > "Sign In" > "SSO Login" and entering their
   organizational email. SSO must be pre-configured in Foxit Admin Console by IT administrators.

   IMPORTANT: Use PDF Editor+ (2025.x subscription version), NOT PDF Editor 14 (perpetual version)
   Only the subscription version properly supports SSO activation.

   this script, like all datto RMM Component scripts unless otherwise explicitly stated, is the copyrighted property of Datto, Inc.;
   it may not be shared, sold, or distributed beyond the Datto RMM product, whole or in part, even with modifications applied, for
   any reason. this includes on reddit, on discord, or as part of other RMM tools. PCSM is the one exception to this rule.

   the moment you edit this script it becomes your own risk and support will not provide assistance with it.#>

write-host "Software: Foxit PDF Editor+ (SSO Version - MSI)"
write-host "========================================"

#region Functions & variables ----------------------------------------------------------------------------------

# Software action
if (!$env:usrAction) {
    $env:usrAction="install"
}
write-host "- Action: $env:usrAction"

# MSI filename - default or from site variable
if (!$env:usrMsiFileName) {
    $env:usrMsiFileName="FoxitPDFEditor20252_L10N_Setup.msi"
    write-host "- Using default MSI filename: $env:usrMsiFileName"
} else {
    write-host "- Using custom MSI filename: $env:usrMsiFileName"
}

function getGUID ($softwareTitle) {
    # Search for installed software by title and return uninstall info
    ("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall","HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall") | % {
        gci -Path $_ -ea 0 | % { Get-ItemProperty $_.PSPath } | ? { $_.DisplayName -match $softwareTitle } | % {
            if ($_.UninstallString -match 'msiexec') {
                # Return MSI GUID
                return "MSI!$($_.PSChildName)"
            } else {
                # Return command
                return $_.QuietUninstallString
            }
        }
    }
}

#region Uninstall ----------------------------------------------------------------------------------------------

if ($env:usrAction -eq 'Uninstall') {
    write-host `r
    write-host "- Uninstalling Foxit PDF Editor..."

    getGUID "Foxit PDF Editor|Foxit PhantomPDF" | % {
        if ($_ -match 'MSI') {
            $varGUID=$_.split('!')[-1]
            write-host "- Uninstalling via MSI GUID: $varGUID"
            $exitCode = (start-process msiexec -ArgumentList "/x $varGUID /qn /norestart" -wait -PassThru).ExitCode
            write-host ": Uninstall completed with exit code $exitCode"
        } else {
            write-host "- Uninstalling via QuietUninstallString"
            cmd /c $_
        }
    }

    if (!$(getGUID "Foxit PDF Editor|Foxit PhantomPDF")) {
        write-host ": Foxit PDF Editor has been removed successfully."
    } else {
        write-host "! WARNING: Foxit PDF Editor may still be present on the system."
    }

    exit 0
}

#region Process clash detection --------------------------------------------------------------------------------

write-host `r
write-host "- Checking for running processes..."

$varProcesses=(get-process).name

# Check for installer
if ($varProcesses -contains 'msiexec') {
    $msiProcesses = Get-Process msiexec -ea 0
    if ($msiProcesses) {
        write-host "! NOTICE: MSI installer is already running."
        write-host "  Another installation may be in progress."
    }
}

# Check for Foxit PDF Editor running
if ($varProcesses -contains 'FoxitPDFEditor' -or $varProcesses -contains 'FoxitPhantomPDF') {
    write-host "! WARNING: Foxit PDF Editor is currently running."

    if ($env:usrFoxitKillSITE -eq 'true') {
        write-host "  usrFoxitKillSITE is set to 'true' - forcibly closing application..."
        Stop-Process -name "FoxitPDFEditor","FoxitPhantomPDF" -Force -ea 0
        start-sleep -seconds 3
        write-host ": Foxit PDF Editor has been closed."
    } else {
        write-host "! ERROR: Cannot install while Foxit PDF Editor is running."
        write-host "  Please close the application manually, or set usrFoxitKillSITE='true'"
        write-host "  at the Site or Global level to automatically close it."
        write-host "- Installation aborted."
        exit 1
    }
} else {
    write-host ": No Foxit processes running."
}

#region Locate MSI file ----------------------------------------------------------------------------------------

write-host `r
write-host "- Locating MSI installer..."

# Check current directory first (where Datto RMM extracts attachments)
$msiPath = Join-Path $PWD $env:usrMsiFileName

if (!(Test-Path $msiPath)) {
    write-host "! ERROR: MSI file not found: $msiPath"
    write-host `r
    write-host "  TROUBLESHOOTING:"
    write-host "  1. Ensure you've attached the MSI file to this component in Datto RMM"
    write-host "  2. Verify the filename matches exactly: $env:usrMsiFileName"
    write-host "  3. If using a different filename, set the usrMsiFileName site variable"
    write-host `r
    write-host "  Expected MSI: Foxit PDF Editor+ subscription version (2025.x)"
    write-host "  Download from: Foxit Admin Console or official Foxit website"
    write-host `r
    write-host "- Installation cannot continue. Exiting."
    exit 1
}

write-host ": Found MSI file: $msiPath"

# Get file details
$msiFile = Get-Item $msiPath
write-host ": File size: $([math]::Round($msiFile.Length / 1MB, 2)) MB"
write-host ": Last modified: $($msiFile.LastWriteTime)"

#region MSI Installation ---------------------------------------------------------------------------------------

write-host `r
write-host "========================================"
write-host "IMPORTANT: SSO ACTIVATION REQUIRED"
write-host "========================================"
write-host "After installation completes, users must activate Foxit PDF Editor+"
write-host "using their organizational SSO credentials on first launch:"
write-host "  1. Open Foxit PDF Editor"
write-host "  2. Click 'Activate' > 'Sign In' > 'SSO Login'"
write-host "  3. Enter organizational email address"
write-host "  4. Complete authentication via your identity provider"
write-host `r
write-host "SSO must be configured in Foxit Admin Console by IT administrators."
write-host "========================================"
write-host `r

# Build MSI installation command
# Using standard silent installation flags
# Reference: https://kb.foxit.com/s/articles/360040660271-Command-line-Deployments-of-Foxit-PDF-Editor

$msiArgs = @(
    "/i"
    "`"$msiPath`""
    "/qn"                    # Quiet mode, no user interaction
    "/norestart"             # Do not restart after installation
    "/L*v"                   # Verbose logging
    "`"$PWD\foxit-install.log`""
)

write-host "- Installing Foxit PDF Editor+ (MSI)..."
write-host ": Command: msiexec $($msiArgs -join ' ')"
write-host `r

$installer = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow

#region Process exit codes -------------------------------------------------------------------------------------

write-host `r
write-host "- Installation completed."
write-host "- Exit code: $($installer.ExitCode)"

switch ($installer.ExitCode) {
    0 {
        write-host ": SUCCESS: Installation completed successfully!"
        write-host `r
        write-host "NEXT STEPS:"
        write-host "- Foxit PDF Editor+ has been installed"
        write-host "- Users must complete SSO activation on first launch"
        write-host "- Ensure organizational SSO is configured in Foxit Admin Console"
    }
    1603 {
        write-host "! ERROR: Fatal error during installation (code 1603)"
        write-host "  This typically indicates:"
        write-host "  - Incompatible version already installed"
        write-host "  - Insufficient permissions"
        write-host "  - Corrupted MSI file"
        write-host `r
        write-host "  RECOMMENDED ACTION:"
        write-host "  1. Run this component with usrAction='Uninstall'"
        write-host "  2. Reboot the system"
        write-host "  3. Re-run installation"
    }
    1618 {
        write-host "! ERROR: Another installation is already in progress (code 1618)"
        write-host "  Please wait for other installations to complete and try again."
    }
    1619 {
        write-host "! ERROR: Installation package could not be opened (code 1619)"
        write-host "  The MSI file may be corrupted or invalid."
        write-host "  Please re-download the MSI and attach it to the component."
    }
    1641 {
        write-host ": SUCCESS: Installation completed; system is restarting (code 1641)"
        write-host "  The system will restart automatically to complete installation."
    }
    3010 {
        write-host ": SUCCESS: Installation completed; restart required (code 3010)"
        write-host "  Please restart the system to complete installation."
    }
    1602 {
        write-host "! ERROR: Installation cancelled by user (code 1602)"
        write-host "  This should not happen in silent mode. Check logs."
    }
    default {
        write-host "! NOTICE: Unhandled exit code ($($installer.ExitCode))"
        write-host "  Please review the installation log for details."
    }
}

#region Display installation log -------------------------------------------------------------------------------

write-host `r
write-host "========================================"
write-host "INSTALLATION LOG"
write-host "========================================"

if (Test-Path "$PWD\foxit-install.log") {
    write-host "Log file: $PWD\foxit-install.log"
    write-host "Last 50 lines:"
    write-host "----------------------------------------"

    $logContent = Get-Content "$PWD\foxit-install.log" | Select-Object -Last 50
    $logContent | % { write-host $_ }

    write-host "----------------------------------------"
    write-host `r
    write-host "Full log available at: $PWD\foxit-install.log"
} else {
    write-host "! WARNING: Installation log not found at $PWD\foxit-install.log"
    write-host "  Installation may have failed before logging started."
}

write-host `r
write-host "========================================"
write-host "Installation process complete."
write-host "Remember: Users must activate via SSO on first launch."
write-host "========================================"

# Exit with installer's exit code for Datto RMM monitoring
exit $installer.ExitCode
