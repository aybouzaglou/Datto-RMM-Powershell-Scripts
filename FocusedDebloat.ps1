<#
.SYNOPSIS
Windows Debloat - Datto RMM Edition
.DESCRIPTION
Removes manufacturer-specific and Windows bloatware with intelligent detection:
- Automatic manufacturer detection (HP/Dell/Lenovo)
- Only processes relevant bloatware for detected manufacturer
- Windows built-in bloatware (AppX packages)
- Enhanced removal methods with timeout protection
- Structured logging for monitoring integration
- Does NOT modify registry settings
- Does NOT remove Microsoft Office
.COMPONENT
Category=Applications ; Level=Medium(3) ; Timeout=900s ; Build=1.1.0
.INPUTS
customwhitelist(String) ; skipwindows(Boolean) ; skiphp(Boolean) ; skipdell(Boolean) ; skiplenovo(Boolean)
.REQUIRES
LocalSystem ; PSVersion >=2.0
.PARAMETER customwhitelist
Optional array of app names to preserve during removal
.OUTPUTS
C:\ProgramData\Debloat\Debloat.log
.EXITCODES
0=Success ; 1=Partial ; 2=Error ; 10=Permission ; 11=Timeout
.NOTES
  Version:        1.1.0
  Author:         Modified from Andrew Taylor's script for Datto RMM
  Creation Date:  07/01/2025
  Modified:       07/08/2025
  Purpose:        Production-ready bloatware removal for RMM deployment

  Original Author: Andrew Taylor (@AndrewTaylor_2)
  Original Source: andrewstaylor.com

  CHANGELOG:
  1.1.0 - Added manufacturer detection, timeout protection, structured logging
  1.0.0 - Initial focused debloat version
#>

############################################################################################################
#                                         Initial Setup                                                    #
############################################################################################################

# Datto RMM Environment Variables Support
# Set these in Datto RMM as environment variables:
# - customwhitelist: Comma-separated list of apps to preserve (optional)
# - skipwindows: Set to "true" to skip Windows bloatware removal (optional)
# - skiphp: Set to "true" to skip HP bloatware removal (optional)
# - skipdell: Set to "true" to skip Dell bloatware removal (optional)
# - skiplenovo: Set to "true" to skip Lenovo bloatware removal (optional)

param (
    [string[]]$customwhitelist
)

############################################################################################################
#                                    Core Functions & Counters                                            #
############################################################################################################

# Global counters for structured reporting
$global:SuccessCount = 0
$global:FailCount = 0
$global:WarningCount = 0

# Universal timeout wrapper for safe operations
function Invoke-WithTimeout {
    param(
        [scriptblock]$Code,
        [int]$TimeoutSec = 300,
        [string]$OperationName = "Operation"
    )
    try {
        $job = Start-Job $Code
        if (Wait-Job $job -Timeout $TimeoutSec) {
            $result = Receive-Job $job
            Remove-Job $job -Force
            return $result
        } else {
            Stop-Job $job -Force
            Remove-Job $job -Force
            throw "Operation '$OperationName' exceeded ${TimeoutSec}s timeout"
        }
    }
    catch {
        Write-Output "FAILED   Timeout wrapper error for '$OperationName': $($_.Exception.Message)"
        $global:FailCount++
        throw
    }
}

# Input variable validation helper
function Get-InputVariable {
    param(
        [string]$Name,
        [ValidateSet('String','Boolean')][string]$Type='String',
        [object]$Default='',
        [switch]$Required
    )
    $val = Get-Item "env:$Name" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value
    if ([string]::IsNullOrWhiteSpace($val)) {
        if ($Required) {
            Write-Output "ERROR    Input variable '$Name' required but not supplied"
            throw "Input '$Name' required but not supplied"
        }
        return $Default
    }
    switch ($Type) {
        'Boolean'  { return ($val -eq 'true') }
        default    { return $val }
    }
}

# Process Datto RMM environment variables with validation
Write-Output "STATUS   Processing Datto RMM input variables..."

# Handle custom whitelist
$customwhitelistEnv = Get-InputVariable -Name "customwhitelist" -Type "String"
if ($customwhitelistEnv) {
    $customwhitelist = $customwhitelistEnv -split ','
    Write-Output "INPUT    Using Datto RMM customwhitelist: $($customwhitelist -join ', ')"
}

# Process skip flags with validation
$skipWindows = Get-InputVariable -Name "skipwindows" -Type "Boolean" -Default $false
$skipHP = Get-InputVariable -Name "skiphp" -Type "Boolean" -Default $false
$skipDell = Get-InputVariable -Name "skipdell" -Type "Boolean" -Default $false
$skipLenovo = Get-InputVariable -Name "skiplenovo" -Type "Boolean" -Default $false

Write-Output "CONFIG   Datto RMM Configuration:"
Write-Output "CONFIG   - Skip Windows bloat: $skipWindows"
Write-Output "CONFIG   - Skip HP bloat: $skipHP"
Write-Output "CONFIG   - Skip Dell bloat: $skipDell"
Write-Output "CONFIG   - Skip Lenovo bloat: $skipLenovo"

# Detect manufacturer to optimize bloatware removal
Write-Output ""
Write-Output "STATUS   Detecting system manufacturer..."
try {
    $manufacturer = Invoke-WithTimeout -Code {
        (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    } -TimeoutSec 30 -OperationName "Manufacturer Detection"

    Write-Output "DETECT   Manufacturer: $manufacturer"

    # Determine which manufacturer bloatware to remove based on detection
    $detectedHP = $manufacturer -match "HP|Hewlett"
    $detectedDell = $manufacturer -match "Dell"
    $detectedLenovo = $manufacturer -match "Lenovo"

    Write-Output ""
    Write-Output "DETECT   Manufacturer Detection Results:"
    Write-Output "DETECT   - HP detected: $detectedHP"
    Write-Output "DETECT   - Dell detected: $detectedDell"
    Write-Output "DETECT   - Lenovo detected: $detectedLenovo"

    $global:SuccessCount++
}
catch {
    Write-Output "FAILED   Manufacturer detection failed: $($_.Exception.Message)"
    Write-Output "WARNING  Proceeding with manual skip flags only"
    $detectedHP = $false
    $detectedDell = $false
    $detectedLenovo = $false
    $global:WarningCount++
}

# Override skip flags based on manufacturer detection (unless explicitly set to skip)
Write-Output ""
Write-Output "CONFIG   Applying intelligent manufacturer filtering..."

if ($detectedHP -and -not $skipHP) {
    $skipHP = $false
    Write-Output "CONFIG   - Will process HP bloatware (manufacturer detected)"
} elseif (-not $detectedHP -and -not $skipHP) {
    $skipHP = $true
    Write-Output "CONFIG   - Will skip HP bloatware (not HP manufacturer)"
}

if ($detectedDell -and -not $skipDell) {
    $skipDell = $false
    Write-Output "CONFIG   - Will process Dell bloatware (manufacturer detected)"
} elseif (-not $detectedDell -and -not $skipDell) {
    $skipDell = $true
    Write-Output "CONFIG   - Will skip Dell bloatware (not Dell manufacturer)"
}

if ($detectedLenovo -and -not $skipLenovo) {
    $skipLenovo = $false
    Write-Output "CONFIG   - Will process Lenovo bloatware (manufacturer detected)"
} elseif (-not $detectedLenovo -and -not $skipLenovo) {
    $skipLenovo = $true
    Write-Output "CONFIG   - Will skip Lenovo bloatware (not Lenovo manufacturer)"
}

# Admin check removed - Datto RMM runs with admin privileges automatically

#Get the Current start time in UTC format
$startUtc = [datetime]::UtcNow
#no errors throughout
$ErrorActionPreference = 'silentlycontinue'
#no progressbars to slow down powershell transfers
$ProgressPreference = 'SilentlyContinue'

#Create Folder
$DebloatFolder = "C:\ProgramData\Debloat"
If (Test-Path $DebloatFolder) {
    Write-Output "STATUS   Log directory exists: $DebloatFolder"
}
Else {
    Write-Output "STATUS   Creating log directory: $DebloatFolder"
    try {
        New-Item -Path "$DebloatFolder" -ItemType Directory -Force | Out-Null
        Write-Output "SUCCESS  Created log directory: $DebloatFolder"
        $global:SuccessCount++
    }
    catch {
        Write-Output "FAILED   Could not create log directory: $($_.Exception.Message)"
        $global:FailCount++
    }
}

Start-Transcript -Path "C:\ProgramData\Debloat\Debloat.log"

Write-Output "=============================================="
Write-Output "STATUS   Starting Focused Debloat Script v1.1.0"
Write-Output "=============================================="
Write-Output "CONFIG   Focus: Manufacturer-specific + Windows bloat removal"
Write-Output "CONFIG   Registry modifications: DISABLED"
Write-Output "CONFIG   Office removal: DISABLED"
Write-Output "CONFIG   Execution time: $(Get-Date)"
Write-Output ""

############################################################################################################
#                                    Windows Bloatware Removal                                            #
############################################################################################################

if (-not $skipWindows) {
    Write-Output "STATUS   Windows bloatware removal: ENABLED"

# Apps to ignore (whitelist)
$appstoignore = @(
    #Critical Windows components
    "Microsoft.WindowsStore"
    "Microsoft.StorePurchaseApp"
    "Microsoft.WindowsCalculator"
    "Microsoft.WindowsCamera"
    "Microsoft.ScreenSketch"
    "Microsoft.Paint"
    "Microsoft.WindowsNotepad"
    "Microsoft.WindowsTerminal"
    "Microsoft.PowerAutomateDesktop"
    "Microsoft.Todos"
    "Microsoft.WindowsBackup"
    "Microsoft.SecHealthUI"
    "Microsoft.Windows.Cortana"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Microsoft.WindowsPhone"
    "Microsoft.WindowsMail"
    "Microsoft.WindowsCalendar"
    "Microsoft.WindowsPeople"
    "Microsoft.WindowsPhotos"
    "Microsoft.WindowsWeather"
    "Microsoft.WindowsNews"
    "Microsoft.WindowsSports"
    "Microsoft.WindowsTravel"
    "Microsoft.WindowsFinance"
    "Microsoft.WindowsFood"
    "Microsoft.WindowsHealth"
    "Microsoft.WindowsReading"
    "Microsoft.WindowsConnectedSearch"
    "Microsoft.WindowsCommunicationsApps"
    "Microsoft.WindowsContactSupport"
    "Microsoft.WindowsHolographicFirstRun"
    "Microsoft.WindowsMixedRealityPortal"
    "Microsoft.WindowsDefenderATPOnboardingPackage"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.MSPaint"
    "Microsoft.WindowsStore"
    "Microsoft.VCLibs.140.00"
    "Microsoft.Services.Store.Engagement"
    "Microsoft.StorePurchaseApp"
    "Microsoft.XboxGameCallableUI"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.YourPhone"
    "Microsoft.Windows.CloudExperienceHost"
    "Microsoft.Windows.ContentDeliveryManager"
    "Microsoft.Windows.PeopleExperienceHost"
    "Microsoft.Windows.ShellExperienceHost"
    "Microsoft.Windows.StartMenuExperienceHost"
    "Microsoft.WindowsStore"
    "Microsoft.MicrosoftEdge"
    "Microsoft.MicrosoftEdge.Stable"
    "Microsoft.MicrosoftEdgeDevToolsClient"
    "Microsoft.Win32WebViewHost"
    "Microsoft.Windows.SecHealthUI"
    "Microsoft.Windows.AssignedAccessLockApp"
    "Microsoft.Windows.CapturePicker"
    "Microsoft.Windows.CloudExperienceHost"
    "Microsoft.Windows.ContentDeliveryManager"
    "Microsoft.Windows.Cortana"
    "Microsoft.Windows.NarratorQuickStart"
    "Microsoft.Windows.ParentalControls"
    "Microsoft.Windows.PeopleExperienceHost"
    "Microsoft.Windows.PinningConfirmationDialog"
    "Microsoft.Windows.SecHealthUI"
    "Microsoft.Windows.SecondaryTileExperience"
    "Microsoft.Windows.SecureAssessmentBrowser"
    "Microsoft.Windows.ShellExperienceHost"
    "Microsoft.Windows.StartMenuExperienceHost"
    "Microsoft.Windows.XGpuEjectDialog"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCalculator"
    "Microsoft.WindowsCamera"
    "Microsoft.windowscommunicationsapps"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsNotepad"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.WindowsStore"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "MicrosoftWindows.Client.WebExperience"
    "MicrosoftWindows.UndockedDevKit"
    "Windows.CBSPreview"
    "windows.immersivecontrolpanel"
    "Windows.PrintDialog"
    "Microsoft.VCLibs.140.00"
    "Microsoft.VCLibs.140.00.UWPDesktop"
    "Microsoft.UI.Xaml.2.0"
    "Microsoft.UI.Xaml.2.1"
    "Microsoft.UI.Xaml.2.3"
    "Microsoft.UI.Xaml.2.4"
    "Microsoft.UI.Xaml.2.7"
    "Microsoft.UI.Xaml.2.8"
    "Microsoft.NET.Native.Framework.1.6"
    "Microsoft.NET.Native.Framework.1.7"
    "Microsoft.NET.Native.Framework.2.0"
    "Microsoft.NET.Native.Framework.2.1"
    "Microsoft.NET.Native.Framework.2.2"
    "Microsoft.NET.Native.Runtime.1.6"
    "Microsoft.NET.Native.Runtime.1.7"
    "Microsoft.NET.Native.Runtime.2.0"
    "Microsoft.NET.Native.Runtime.2.1"
    "Microsoft.NET.Native.Runtime.2.2"
    "Microsoft.Services.Store.Engagement"
    "Microsoft.StorePurchaseApp"
    "Microsoft.WindowsAppRuntime.1.0"
    "Microsoft.WindowsAppRuntime.1.1"
    "Microsoft.WindowsAppRuntime.1.2"
    "Microsoft.WindowsAppRuntime.1.3"
    "Microsoft.WindowsAppRuntime.1.4"
    "Microsoft.DesktopAppInstaller"
    "Microsoft.Winget.Source"
    "Microsoft.WindowsPackageManagerServer"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.Paint"
    "Microsoft.ScreenSketch"
    "Microsoft.PowerAutomateDesktop"
    "Microsoft.Todos"
    "Microsoft.WindowsBackup"
    "Microsoft.SecHealthUI"
    "Microsoft.Windows.Cortana"
    "Microsoft.WindowsTerminal"
    "Microsoft.WindowsNotepad"
    "Microsoft.WindowsCalculator"
    "Microsoft.WindowsStore"
    "Microsoft.WindowsCamera"
    "Microsoft.ScreenSketch"
    "Microsoft.Paint"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.MSPaint"
    "Microsoft.WindowsStore"
    "Microsoft.StorePurchaseApp"
    "Microsoft.VCLibs.140.00"
    "Microsoft.Services.Store.Engagement"
    "Microsoft.XboxGameCallableUI"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.YourPhone"
    "Microsoft.Windows.CloudExperienceHost"
    "Microsoft.Windows.ContentDeliveryManager"
    "Microsoft.Windows.PeopleExperienceHost"
    "Microsoft.Windows.ShellExperienceHost"
    "Microsoft.Windows.StartMenuExperienceHost"
    "Microsoft.WindowsStore"
    "Microsoft.MicrosoftEdge"
    "Microsoft.MicrosoftEdge.Stable"
    "Microsoft.MicrosoftEdgeDevToolsClient"
    "Microsoft.Win32WebViewHost"
    "Microsoft.Windows.SecHealthUI"
    "Microsoft.Windows.AssignedAccessLockApp"
    "Microsoft.Windows.CapturePicker"
    "Microsoft.Windows.CloudExperienceHost"
    "Microsoft.Windows.ContentDeliveryManager"
    "Microsoft.Windows.Cortana"
    "Microsoft.Windows.NarratorQuickStart"
    "Microsoft.Windows.ParentalControls"
    "Microsoft.Windows.PeopleExperienceHost"
    "Microsoft.Windows.PinningConfirmationDialog"
    "Microsoft.Windows.SecHealthUI"
    "Microsoft.Windows.SecondaryTileExperience"
    "Microsoft.Windows.SecureAssessmentBrowser"
    "Microsoft.Windows.ShellExperienceHost"
    "Microsoft.Windows.StartMenuExperienceHost"
    "Microsoft.Windows.XGpuEjectDialog"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCalculator"
    "Microsoft.WindowsCamera"
    "Microsoft.windowscommunicationsapps"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsNotepad"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.WindowsStore"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "MicrosoftWindows.Client.WebExperience"
    "MicrosoftWindows.UndockedDevKit"
    "Windows.CBSPreview"
    "windows.immersivecontrolpanel"
    "Windows.PrintDialog"
)

# Add custom whitelist if provided
if ($customwhitelist) {
    $appstoignore += $customwhitelist
    Write-Output "Added custom whitelist: $($customwhitelist -join ', ')"
}

##Bloat list for Windows AppX packages
$Bloatware = @(
#Unnecessary Windows 10/11 AppX Apps
"*ActiproSoftwareLLC*"
"*AdobeSystemsIncorporated.AdobePhotoshopExpress*"
"*BubbleWitch3Saga*"
"*CandyCrush*"
"*DevHome*"
"*Disney*"
"*Dolby*"
"*Duolingo-LearnLanguagesforFree*"
"*EclipseManager*"
"*Facebook*"
"*Flipboard*"
"*gaming*"
"*Minecraft*"
"*PandoraMediaInc*"
"*Royal Revolt*"
"*Speed Test*"
"*Spotify*"
"*Sway*"
"*Twitter*"
"*Wunderlist*"
"AD2F1837.HPPrinterControl"
"AppUp.IntelGraphicsExperience"
"C27EB4BA.DropboxOEM*"
"Disney.37853FC22B2CE"
"DolbyLaboratories.DolbyAccess"
"DolbyLaboratories.DolbyAudio"
"E0469640.SmartAppearance"
"Microsoft.549981C3F5F10"
"Microsoft.AV1VideoExtension"
"Microsoft.BingNews"
"Microsoft.BingSearch"
"Microsoft.BingWeather"
"Microsoft.GetHelp"
"Microsoft.Getstarted"
"Microsoft.HEIFImageExtension"
"Microsoft.Messaging"
"Microsoft.Microsoft3DViewer"
"Microsoft.MicrosoftOfficeHub"
"Microsoft.MicrosoftSolitaireCollection"
"Microsoft.MixedReality.Portal"
"Microsoft.Office.OneNote"
"Microsoft.OneConnect"
"Microsoft.People"
"Microsoft.Print3D"
"Microsoft.SkypeApp"
"Microsoft.Wallet"
"Microsoft.WebMediaExtensions"
"Microsoft.WebpImageExtension"
"Microsoft.WindowsAlarms"
"Microsoft.WindowsFeedbackHub"
"Microsoft.WindowsMaps"
"Microsoft.WindowsSoundRecorder"
"Microsoft.Xbox.TCUI"
"Microsoft.XboxApp"
"Microsoft.XboxGameOverlay"
"Microsoft.XboxGamingOverlay"
"Microsoft.XboxIdentityProvider"
"Microsoft.XboxSpeechToTextOverlay"
"Microsoft.ZuneMusic"
"Microsoft.ZuneVideo"
"MicrosoftTeams"
"SpotifyAB.SpotifyMusic"
"king.com.CandyCrushSaga"
"king.com.CandyCrushSodaSaga"
"*Clipchamp*"
"*TikTok*"
"*Prime Video*"
"*Whatsapp*"
"*LinkedIN*"
"*PowerAutomateDesktop*"
"*Todos*"
"*DevHome*"
"*Clipchamp*"
"*Family*"
"*QuickAssist*"
"*People*"
"*Whiteboard*"
"*WindowsBackup*"
"*Teams*"
"*Chat*"
"*McAfee*"
)

Write-Output "STATUS   Starting Windows bloatware removal..."

# Remove provisioned packages with timeout protection
Write-Output "STATUS   Processing AppX provisioned packages..."
try {
    $provisioned = Invoke-WithTimeout -Code {
        Get-AppxProvisionedPackage -Online | Where-Object {
            $_.DisplayName -in $Bloatware -and
            $_.DisplayName -notin $appstoignore -and
            $_.DisplayName -notlike 'MicrosoftWindows.Voice*' -and
            $_.DisplayName -notlike 'Microsoft.LanguageExperiencePack*' -and
            $_.DisplayName -notlike 'MicrosoftWindows.Speech*'
        }
    } -TimeoutSec 60 -OperationName "Get Provisioned Packages"

    Write-Output "METRIC   Found $($provisioned.Count) provisioned packages to remove"

    foreach ($appxprov in $provisioned) {
        $packagename = $appxprov.PackageName
        $displayname = $appxprov.DisplayName
        Write-Output "STATUS   Removing provisioned package: $displayname"
        try {
            Invoke-WithTimeout -Code {
                Remove-AppxProvisionedPackage -PackageName $packagename -Online -ErrorAction Stop
            } -TimeoutSec 120 -OperationName "Remove $displayname"

            Write-Output "SUCCESS  Removed provisioned package: $displayname"
            $global:SuccessCount++
        }
        catch {
            Write-Output "FAILED   Unable to remove provisioned package $displayname`: $($_.Exception.Message)"
            $global:FailCount++
        }
    }
}
catch {
    Write-Output "FAILED   Error getting provisioned packages: $($_.Exception.Message)"
    $global:FailCount++
}

# Remove installed packages with timeout protection
Write-Output "STATUS   Processing installed AppX packages..."
try {
    $appxinstalled = Invoke-WithTimeout -Code {
        Get-AppxPackage -AllUsers | Where-Object {
            $_.Name -in $Bloatware -and
            $_.Name -notin $appstoignore -and
            $_.Name -notlike 'MicrosoftWindows.Voice*' -and
            $_.Name -notlike 'Microsoft.LanguageExperiencePack*' -and
            $_.Name -notlike 'MicrosoftWindows.Speech*'
        }
    } -TimeoutSec 60 -OperationName "Get Installed Packages"

    Write-Output "METRIC   Found $($appxinstalled.Count) installed packages to remove"

    foreach ($appxapp in $appxinstalled) {
        $packagename = $appxapp.PackageFullName
        $displayname = $appxapp.Name
        Write-Output "STATUS   Removing installed package: $displayname"
        try {
            Invoke-WithTimeout -Code {
                Remove-AppxPackage -Package $packagename -AllUsers -ErrorAction Stop
            } -TimeoutSec 120 -OperationName "Remove $displayname"

            Write-Output "SUCCESS  Removed installed package: $displayname"
            $global:SuccessCount++
        }
        catch {
            Write-Output "FAILED   Unable to remove installed package $displayname`: $($_.Exception.Message)"
            $global:FailCount++
        }
    }
}
catch {
    Write-Output "FAILED   Error getting installed packages: $($_.Exception.Message)"
    $global:FailCount++
}

    Write-Output "RESULT   Windows bloatware removal completed"
    Write-Output "METRIC   Windows_Apps_Processed=$($global:SuccessCount + $global:FailCount)"
} else {
    Write-Output "STATUS   Windows bloatware removal: SKIPPED (skipwindows=true)"
}

############################################################################################################
#                                        HP Bloatware Removal                                             #
############################################################################################################

if (-not $skipHP) {
    Write-Output "STATUS   HP bloatware removal: ENABLED"
    Write-Output "STATUS   Starting HP bloatware removal..."
    $hpStartCount = $global:SuccessCount

# HP specific AppX packages to remove
$HPApps = @(
    "AD2F1837.HPJumpStarts"
    "AD2F1837.HPPCHardwareDiagnosticsWindows"
    "AD2F1837.HPPowerManager"
    "AD2F1837.HPPrivacySettings"
    "AD2F1837.HPSupportAssistant"
    "AD2F1837.HPSureShieldAI"
    "AD2F1837.HPSystemInformation"
    "AD2F1837.HPQuickDrop"
    "AD2F1837.HPWorkWell"
    "AD2F1837.myHP"
    "AD2F1837.HPDesktopSupportUtilities"
    "AD2F1837.HPQuickTouch"
    "AD2F1837.HPEasyClean"
    "AD2F1837.HPSystemInformation"
    "RealtekSemiconductorCorp.HPAudioControl"
)

foreach ($HPApp in $HPApps) {
    if (Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $HPApp -ErrorAction SilentlyContinue) {
        Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $HPApp | Remove-AppxProvisionedPackage -Online
        Write-Output "Removed provisioned package for $HPApp."
    }
    else {
        Write-Output "Provisioned package for $HPApp not found."
    }

    if (Get-AppxPackage -allusers -Name $HPApp -ErrorAction SilentlyContinue) {
        Get-AppxPackage -allusers -Name $HPApp | Remove-AppxPackage -AllUsers
        Write-Output "Removed $HPApp."
    }
    else {
        Write-Output "$HPApp not found."
    }
}

# HP Win32 applications to remove
$HPWin32Apps = @(
    "HP Audio Control"
    "HP Connection Optimizer"
    "HP Documentation"
    "HP One Agent"
    "HP JumpStart Bridge"
    "HP JumpStart Launch"
    "HP My Display"
    "HP Notifications"
    "HP Omen Gaming Hub"
    "HP PC Hardware Diagnostics"
    "HP Performance Advisor"
    "HP Presence Video"
    "HP Privacy Settings"
    "HP QuickDrop"
    "HP Smart"
    "HP Support Assistant"
    "HP Sure Admin"
    "HP Sure Click"
    "HP Sure Recover"
    "HP Sure Run"
    "HP Sure Sense"
    "HP Sure Start"
    "HP System Event Utility"
    "HP System Information"
    "HP Touchpoint Analytics"
    "HP Touchpoint Manager"
    "HP Wolf Security"
    "HP WorkWell"
    "HP ZCentral Connect"
    "HP ZCentral Remote Boost"
    "HP Display Center"
    "HP Easy Clean"
    "HP Hotkey Support"
    "HP Audio Switch"
    "HP Sure Apps"
    "HP Wolf Pro Security"
    "HP Wolf Enterprise Security"
    "HP Wolf Security Application Support"
    "HP Wolf Security - Console"
    "HP Client Security Manager"
    "HP Device Access Manager"
    "HP Hotkey UWP Service"
    "HP Programmable Key"
    "HP Security Update Service"
    "HP System Default Settings"
    "HP Sure Click Secure Browser"
    "HP Sure Sense Installer"
    "HP Sure Start"
    "HP Touchpoint Analytics Client"
    "HP Velocity"
    "HP Wolf Security"
    "HP Wolf Security - Console"
    "HP Wolf Security Application Support"
    "HP ZBook Create G7 Notebook PC"
    "HP ZBook Firefly 14 G7 Mobile Workstation"
    "HP ZBook Firefly 15 G7 Mobile Workstation"
    "HP ZBook Fury 15 G7 Mobile Workstation"
    "HP ZBook Fury 17 G7 Mobile Workstation"
    "HP ZBook Power G7 Mobile Workstation"
    "HP ZBook Studio G7 Mobile Workstation"
    "HP ZCentral 4R Workstation"
    "HP ZCentral Remote Boost Receiver"
    "HP ZCentral Remote Boost Sender"
    "RealtekSemiconductorCorp.HPAudioControl"
)

Write-Output "Removing HP Win32 applications..."
foreach ($HPWin32App in $HPWin32Apps) {
    Write-Output "Searching for: $HPWin32App"

    # Method 1: Try Win32_Product (CIM)
    $app = Get-CimInstance -Query "SELECT * FROM Win32_Product WHERE name = '$HPWin32App'" -ErrorAction SilentlyContinue
    if ($app) {
        Write-Output "Found $HPWin32App via Win32_Product - Removing..."
        try {
            $app | Invoke-CimMethod -MethodName Uninstall
            Write-Output "Removed $HPWin32App via Win32_Product"
            continue
        }
        catch {
            Write-Output "Failed to remove $HPWin32App via Win32_Product: $($_.Exception.Message)"
        }
    }

    # Method 2: Try WMI Win32_Product
    $wmiApp = Get-WmiObject -Class Win32_Product -Filter "Name = '$HPWin32App'" -ErrorAction SilentlyContinue
    if ($wmiApp) {
        Write-Output "Found $HPWin32App via WMI - Removing..."
        try {
            $wmiApp.Uninstall()
            Write-Output "Removed $HPWin32App via WMI"
            continue
        }
        catch {
            Write-Output "Failed to remove $HPWin32App via WMI: $($_.Exception.Message)"
        }
    }

    # Method 3: Try registry-based uninstall
    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $found = $false
    foreach ($keyPath in $uninstallKeys) {
        $regApps = Get-ItemProperty $keyPath -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $HPWin32App }
        foreach ($regApp in $regApps) {
            if ($regApp.UninstallString) {
                Write-Output "Found $HPWin32App in registry - Attempting uninstall..."
                try {
                    $uninstallString = $regApp.UninstallString
                    if ($uninstallString -like "*msiexec*") {
                        # MSI uninstall
                        $productCode = $uninstallString -replace ".*\{([^}]+)\}.*", '{$1}'
                        if ($productCode -match "^\{[A-F0-9-]+\}$") {
                            Write-Output "Using MSI uninstall for $HPWin32App"
                            Start-Process "msiexec.exe" -ArgumentList "/x $productCode /quiet /norestart" -Wait -NoNewWindow
                            Write-Output "Attempted MSI uninstall for $HPWin32App"
                            $found = $true
                            break
                        }
                    } else {
                        # Standard uninstall
                        Write-Output "Using standard uninstall for $HPWin32App"
                        if ($uninstallString -like "*uninstall*" -or $uninstallString -like "*setup*") {
                            Start-Process cmd.exe -ArgumentList "/c `"$uninstallString`" /S /silent" -Wait -NoNewWindow -ErrorAction SilentlyContinue
                            Write-Output "Attempted standard uninstall for $HPWin32App"
                            $found = $true
                            break
                        }
                    }
                }
                catch {
                    Write-Output "Failed registry uninstall for ${HPWin32App}: $($_.Exception.Message)"
                }
            }
        }
        if ($found) { break }
    }

    if (-not $found) {
        Write-Output "$HPWin32App not found in any detection method"
    }
}

    $hpProcessed = $global:SuccessCount - $hpStartCount
    Write-Output "RESULT   HP bloatware removal completed"
    Write-Output "METRIC   HP_Apps_Processed=$hpProcessed"
} else {
    Write-Output "STATUS   HP bloatware removal: SKIPPED (skiphp=true)"
}

############################################################################################################
#                                       Dell Bloatware Removal                                            #
############################################################################################################

if ($skipDell -ne "true") {
    Write-Output "Dell bloatware removal: ENABLED"
    Write-Output "Starting Dell bloatware removal..."

# Dell specific AppX packages to remove
$DellApps = @(
    "DellInc.DellOptimizer"
    "DellInc.DellCommandUpdate"
    "DellInc.DellDigitalDelivery"
    "DellInc.DellSupportAssistforPCs"
    "DellInc.PartnerPromo"
    "DellInc.DellCustomerConnect"
    "DellInc.DellUpdate"
    "DellInc.DellCinemaColor"
    "DellInc.DellCinemaSound"
    "DellInc.DellCinemaGuide"
    "DellInc.DellProductRegistration"
    "DellInc.MyDell"
    "DellInc.DellMobileConnect"
    "DellInc.DellOptimizer"
    "DellInc.DellPowerManager"
    "DellInc.DellDigitalDelivery"
    "DellInc.DellSupportAssistforPCs"
    "DellInc.PartnerPromo"
    "DellInc.DellCustomerConnect"
    "DellInc.DellUpdate"
    "DellInc.DellCinemaColor"
    "DellInc.DellCinemaSound"
    "DellInc.DellCinemaGuide"
    "DellInc.DellProductRegistration"
    "DellInc.MyDell"
    "DellInc.DellMobileConnect"
)

foreach ($DellApp in $DellApps) {
    if (Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $DellApp -ErrorAction SilentlyContinue) {
        Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $DellApp | Remove-AppxProvisionedPackage -Online
        Write-Output "Removed provisioned package for $DellApp."
    }
    else {
        Write-Output "Provisioned package for $DellApp not found."
    }

    if (Get-AppxPackage -allusers -Name $DellApp -ErrorAction SilentlyContinue) {
        Get-AppxPackage -allusers -Name $DellApp | Remove-AppxPackage -AllUsers
        Write-Output "Removed $DellApp."
    }
    else {
        Write-Output "$DellApp not found."
    }
}

# Dell Win32 applications to remove
$DellWin32Apps = @(
    "Dell Optimizer"
    "Dell Command | Update"
    "Dell Digital Delivery"
    "Dell SupportAssist"
    "Dell Customer Connect"
    "Dell Update"
    "Dell Cinema Color"
    "Dell Cinema Sound"
    "Dell Cinema Guide"
    "Dell Product Registration"
    "My Dell"
    "Dell Mobile Connect"
    "Dell Power Manager"
    "Dell Optimizer Core"
    "Dell SupportAssist Remediation"
    "Dell SupportAssist OS Recovery Plugin for Dell Update"
    "Dell Peripheral Manager"
    "Dell Pair"
    "Dell Display Manager"
    "Dell Webcam Central"
    "Dell Backup and Recovery"
    "Dell DataSafe Local Backup"
    "Dell DataSafe Online"
    "Dell Dock"
    "Dell Edoc Viewer"
    "Dell Getting Started Guide"
    "Dell Help & Support"
    "Dell Inspiron"
    "Dell OptiPlex"
    "Dell Precision"
    "Dell Stage"
    "Dell Stage Remote"
    "Dell Support Center"
    "Dell Touchpad"
    "Dell Vostro"
    "Dell Webcam Manager"
    "Dell WLAN and Bluetooth Client Installation"
    "DellTypeCStatus"
)

Write-Output "Removing Dell Win32 applications..."
foreach ($DellWin32App in $DellWin32Apps) {
    $app = Get-CimInstance -Query "SELECT * FROM Win32_Product WHERE name = '$DellWin32App'" -ErrorAction SilentlyContinue
    if ($app) {
        Write-Output "Removing $DellWin32App"
        try {
            $app | Invoke-CimMethod -MethodName Uninstall
            Write-Output "Removed $DellWin32App"
        }
        catch {
            Write-Output "Failed to remove $DellWin32App"
        }
    }
}

    Write-Output "Dell bloatware removal completed."
} else {
    Write-Output "Dell bloatware removal: SKIPPED (skipdell=true)"
}

############################################################################################################
#                                      Lenovo Bloatware Removal                                           #
############################################################################################################

if ($skipLenovo -ne "true") {
    Write-Output "Lenovo bloatware removal: ENABLED"
    Write-Output "Starting Lenovo bloatware removal..."

# Lenovo specific AppX packages to remove
$LenovoApps = @(
    "E046963F.LenovoCompanion"
    "E046963F.LenovoSettingsforEnterprise"
    "LenovoCorporation.LenovoID"
    "LenovoCorporation.LenovoSettings"
    "LenovoCorporation.LenovoWelcome"
    "LenovoCorporation.LenovoCompanion"
    "E046963F.LenovoCompanion"
    "4505Fortemedia.FMAPOControl"
    "LenovoCorporation.LenovoID"
    "LenovoCorporation.LenovoSettings"
    "LenovoCorporation.LenovoWelcome"
    "LenovoCorporation.LenovoCompanion"
    "E046963F.LenovoCompanion"
    "E046963F.LenovoSettingsforEnterprise"
    "LenovoCorporation.LenovoID"
    "LenovoCorporation.LenovoSettings"
    "LenovoCorporation.LenovoWelcome"
    "LenovoCorporation.LenovoCompanion"
    "E046963F.LenovoCompanion"
    "4505Fortemedia.FMAPOControl"
    "LenovoCorporation.LenovoID"
    "LenovoCorporation.LenovoSettings"
    "LenovoCorporation.LenovoWelcome"
    "LenovoCorporation.LenovoCompanion"
    "E046963F.LenovoCompanion"
    "E046963F.LenovoSettingsforEnterprise"
)

foreach ($LenovoApp in $LenovoApps) {
    if (Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $LenovoApp -ErrorAction SilentlyContinue) {
        Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $LenovoApp | Remove-AppxProvisionedPackage -Online
        Write-Output "Removed provisioned package for $LenovoApp."
    }
    else {
        Write-Output "Provisioned package for $LenovoApp not found."
    }

    if (Get-AppxPackage -allusers -Name $LenovoApp -ErrorAction SilentlyContinue) {
        Get-AppxPackage -allusers -Name $LenovoApp | Remove-AppxPackage -AllUsers
        Write-Output "Removed $LenovoApp."
    }
    else {
        Write-Output "$LenovoApp not found."
    }
}

# Lenovo Win32 applications to remove
$LenovoWin32Apps = @(
    "Lenovo Vantage"
    "Lenovo Companion"
    "Lenovo Settings"
    "Lenovo Welcome"
    "Lenovo ID"
    "Lenovo Smart Appearance"
    "Lenovo Smart Appearance Components"
    "Lenovo Smart Meeting"
    "Lenovo Smart Noise Cancellation"
    "Lenovo View"
    "Lenovo Now"
    "Lenovo Hotkeys"
    "Lenovo Power Management Driver"
    "Lenovo System Interface Foundation"
    "Lenovo Message Center Plus"
    "Lenovo Dependency Package"
    "Lenovo Active Protection System"
    "Lenovo Auto Scroll Utility"
    "Lenovo Bluetooth with Enhanced Data Rate Software"
    "Lenovo Communications Utility"
    "Lenovo Customer Feedback Program"
    "Lenovo Fingerprint Manager"
    "Lenovo FusionEngine"
    "Lenovo Mobile Broadband Activation"
    "Lenovo OneKey Recovery"
    "Lenovo Power2Go"
    "Lenovo PowerDVD"
    "Lenovo ReadyComm 5"
    "Lenovo Registration"
    "Lenovo SimpleTap"
    "Lenovo SplendidHD"
    "Lenovo System Update"
    "Lenovo ThinkVantage GPS"
    "Lenovo ThinkVantage Password Manager"
    "Lenovo ThinkVantage System Health Indicator"
    "Lenovo ThinkVantage Toolbox"
    "Lenovo User Guide"
    "Lenovo Warranty Information"
    "Lenovo Web Start"
    "Lenovo Welcome"
    "Lenovo Yoga PhoneCompanion"
    "Lenovo Zone"
    "ThinkPad UltraNav Driver"
    "ThinkVantage Access Connections"
    "ThinkVantage Communications Utility"
    "ThinkVantage Fingerprint Software"
    "ThinkVantage GPS"
    "ThinkVantage Password Manager"
    "ThinkVantage Productivity Center"
    "ThinkVantage Rescue and Recovery"
    "ThinkVantage System Health Indicator"
    "ThinkVantage System Migration Assistant"
    "ThinkVantage Toolbox"
    "Ai Meeting Manager Service"
    "ImController"
    "Lenovo Commercial Vantage"
    "Lenovo Vantage Service"
    "TrackPoint Quick Menu"
    "X-Rite Color Assistant"
)

Write-Output "Removing Lenovo Win32 applications..."
foreach ($LenovoWin32App in $LenovoWin32Apps) {
    $app = Get-CimInstance -Query "SELECT * FROM Win32_Product WHERE name = '$LenovoWin32App'" -ErrorAction SilentlyContinue
    if ($app) {
        Write-Output "Removing $LenovoWin32App"
        try {
            $app | Invoke-CimMethod -MethodName Uninstall
            Write-Output "Removed $LenovoWin32App"
        }
        catch {
            Write-Output "Failed to remove $LenovoWin32App"
        }
    }
}

# Stop Lenovo processes that might interfere
$LenovoProcesses = @(
    "SmartAppearanceSVC"
    "UDClientService"
    "ModuleCoreService"
    "ProtectedModuleHost"
    "FaceBeautify"
    "AIMeetingManager"
    "DADUpdater"
    "CommercialVantage"
)

Write-Output "Stopping Lenovo processes..."
foreach ($process in $LenovoProcesses) {
    $runningProcess = Get-Process -Name $process -ErrorAction SilentlyContinue
    if ($runningProcess) {
        Write-Output "Stopping process: $process"
        try {
            Stop-Process -Name $process -Force -ErrorAction SilentlyContinue
            Write-Output "Stopped process: $process"
        }
        catch {
            Write-Output "Failed to stop process: $process"
        }
    }
}

    Write-Output "Lenovo bloatware removal completed."
} else {
    Write-Output "Lenovo bloatware removal: SKIPPED (skiplenovo=true)"
}

############################################################################################################
#                                           Completion                                                    #
############################################################################################################

# Calculate runtime and final metrics
$endUtc = [datetime]::UtcNow
$runtime = $endUtc - $startUtc
$runtimeMinutes = [math]::Round($runtime.TotalMinutes, 2)
$totalProcessed = $global:SuccessCount + $global:FailCount + $global:WarningCount

Write-Output ""
Write-Output "=============================================="
Write-Output "STATUS   Focused Debloat Script Completion"
Write-Output "=============================================="
Write-Output "METRIC   Runtime_Minutes=$runtimeMinutes"
Write-Output "METRIC   Total_Success=$global:SuccessCount"
Write-Output "METRIC   Total_Failed=$global:FailCount"
Write-Output "METRIC   Total_Warnings=$global:WarningCount"
Write-Output "METRIC   Total_Processed=$totalProcessed"
Write-Output "CONFIG   Log saved to: C:\ProgramData\Debloat\Debloat.log"
Write-Output ""
Write-Output "SUMMARY  Actions taken:"
if (-not $skipWindows) { Write-Output "SUMMARY  - Processed Windows bloatware (AppX packages)" } else { Write-Output "SUMMARY  - Windows bloatware removal: SKIPPED" }
if (-not $skipHP) { Write-Output "SUMMARY  - Processed HP manufacturer bloatware" } else { Write-Output "SUMMARY  - HP bloatware removal: SKIPPED" }
if (-not $skipDell) { Write-Output "SUMMARY  - Processed Dell manufacturer bloatware" } else { Write-Output "SUMMARY  - Dell bloatware removal: SKIPPED" }
if (-not $skipLenovo) { Write-Output "SUMMARY  - Processed Lenovo manufacturer bloatware" } else { Write-Output "SUMMARY  - Lenovo bloatware removal: SKIPPED" }
Write-Output "SUMMARY  - Registry modifications: SKIPPED (as requested)"
Write-Output "SUMMARY  - Office removal: SKIPPED (as requested)"
Write-Output ""
Write-Output "STATUS   Script completed at: $(Get-Date)"

# Determine exit code based on results
if ($global:FailCount -eq 0 -and $global:WarningCount -eq 0) {
    Write-Output "RESULT   Complete success - all operations completed successfully"
    $exitCode = 0
} elseif ($global:FailCount -eq 0 -and $global:WarningCount -gt 0) {
    Write-Output "RESULT   Success with warnings - $global:WarningCount warnings encountered"
    $exitCode = 1
} elseif ($global:SuccessCount -ge $global:FailCount) {
    Write-Output "RESULT   Partial success - $global:SuccessCount successes, $global:FailCount failures"
    $exitCode = 1
} else {
    Write-Output "RESULT   Multiple failures - $global:FailCount failures, $global:SuccessCount successes"
    $exitCode = 2
}

Write-Output "STATUS   Exiting with code: $exitCode"
Stop-Transcript
exit $exitCode
