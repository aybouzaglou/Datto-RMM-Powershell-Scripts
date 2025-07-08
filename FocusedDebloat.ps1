<#
.SYNOPSIS
Removes Dell, HP, Lenovo, and Windows bloatware from Windows systems
.DESCRIPTION
This focused debloat script removes:
- Dell manufacturer bloatware
- HP manufacturer bloatware
- Lenovo manufacturer bloatware
- Windows built-in bloatware (AppX packages)
- Does NOT modify registry settings
- Does NOT remove Microsoft Office
.PARAMETER customwhitelist
Optional array of app names to preserve during removal
.INPUTS
None
.OUTPUTS
C:\ProgramData\Debloat\Debloat.log
.NOTES
  Version:        1.0.0
  Author:         Modified from Andrew Taylor's script
  Creation Date:  07/01/2025
  Purpose:        Focused bloatware removal for RMM deployment
  
  Original Author: Andrew Taylor (@AndrewTaylor_2)
  Original Source: andrewstaylor.com
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

# Check for Datto RMM environment variables and use them if available
if ($env:customwhitelist) {
    $customwhitelist = $env:customwhitelist -split ','
    Write-Output "Using Datto RMM customwhitelist: $($customwhitelist -join ', ')"
}

# Skip flags from Datto RMM environment variables (using string comparisons)
$skipWindows = $env:skipwindows
$skipHP = $env:skiphp
$skipDell = $env:skipdell
$skipLenovo = $env:skiplenovo

Write-Output "Datto RMM Configuration:"
Write-Output "- Skip Windows bloat: $skipWindows"
Write-Output "- Skip HP bloat: $skipHP"
Write-Output "- Skip Dell bloat: $skipDell"
Write-Output "- Skip Lenovo bloat: $skipLenovo"

# Detect manufacturer to optimize bloatware removal
Write-Output ""
Write-Output "Detecting system manufacturer..."
$manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
Write-Output "Detected manufacturer: $manufacturer"

# Determine which manufacturer bloatware to remove based on detection
$detectedHP = $manufacturer -match "HP|Hewlett"
$detectedDell = $manufacturer -match "Dell"
$detectedLenovo = $manufacturer -match "Lenovo"

Write-Output ""
Write-Output "Manufacturer Detection Results:"
Write-Output "- HP detected: $detectedHP"
Write-Output "- Dell detected: $detectedDell"
Write-Output "- Lenovo detected: $detectedLenovo"

# Override skip flags based on manufacturer detection (unless explicitly set to skip)
if ($detectedHP -and $skipHP -ne "true") {
    $skipHP = "false"
    Write-Output "- Will process HP bloatware (manufacturer detected)"
} elseif (-not $detectedHP -and $skipHP -ne "true") {
    $skipHP = "true"
    Write-Output "- Will skip HP bloatware (not HP manufacturer)"
}

if ($detectedDell -and $skipDell -ne "true") {
    $skipDell = "false"
    Write-Output "- Will process Dell bloatware (manufacturer detected)"
} elseif (-not $detectedDell -and $skipDell -ne "true") {
    $skipDell = "true"
    Write-Output "- Will skip Dell bloatware (not Dell manufacturer)"
}

if ($detectedLenovo -and $skipLenovo -ne "true") {
    $skipLenovo = "false"
    Write-Output "- Will process Lenovo bloatware (manufacturer detected)"
} elseif (-not $detectedLenovo -and $skipLenovo -ne "true") {
    $skipLenovo = "true"
    Write-Output "- Will skip Lenovo bloatware (not Lenovo manufacturer)"
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
    Write-Output "$DebloatFolder exists. Skipping."
}
Else {
    Write-Output "The folder '$DebloatFolder' doesn't exist. This folder will be used for storing logs created after the script runs. Creating now."
    Start-Sleep 1
    New-Item -Path "$DebloatFolder" -ItemType Directory
    Write-Output "The folder $DebloatFolder was successfully created."
}

Start-Transcript -Path "C:\ProgramData\Debloat\Debloat.log"

Write-Output "Starting Focused Debloat Script v1.0.0"
Write-Output "Focus: Dell/HP/Lenovo bloat + Windows bloat removal"
Write-Output "Registry modifications: DISABLED"
Write-Output "Office removal: DISABLED"

############################################################################################################
#                                    Windows Bloatware Removal                                            #
############################################################################################################

if ($skipWindows -ne "true") {
    Write-Output "Windows bloatware removal: ENABLED"

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

Write-Output "Starting Windows bloatware removal..."

# Remove provisioned packages
$provisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -in $Bloatware -and $_.DisplayName -notin $appstoignore -and $_.DisplayName -notlike 'MicrosoftWindows.Voice*' -and $_.DisplayName -notlike 'Microsoft.LanguageExperiencePack*' -and $_.DisplayName -notlike 'MicrosoftWindows.Speech*' }
foreach ($appxprov in $provisioned) {
    $packagename = $appxprov.PackageName
    $displayname = $appxprov.DisplayName
    Write-Output "Removing $displayname AppX Provisioning Package"
    try {
        Remove-AppxProvisionedPackage -PackageName $packagename -Online -ErrorAction SilentlyContinue
        Write-Output "Removed $displayname AppX Provisioning Package"
    }
    catch {
        Write-Output "Unable to remove $displayname AppX Provisioning Package"
    }
}

# Remove installed packages
$appxinstalled = Get-AppxPackage -AllUsers | Where-Object { $_.Name -in $Bloatware -and $_.Name -notin $appstoignore  -and $_.Name -notlike 'MicrosoftWindows.Voice*' -and $_.Name -notlike 'Microsoft.LanguageExperiencePack*' -and $_.Name -notlike 'MicrosoftWindows.Speech*'}
foreach ($appxapp in $appxinstalled) {
    $packagename = $appxapp.PackageFullName
    $displayname = $appxapp.Name
    Write-Output "$displayname AppX Package exists"
    Write-Output "Removing $displayname AppX Package"
    try {
        Remove-AppxPackage -Package $packagename -AllUsers -ErrorAction SilentlyContinue
        Write-Output "Removed $displayname AppX Package"
    }
    catch {
        Write-Output "$displayname AppX Package does not exist"
    }
}

    Write-Output "Windows bloatware removal completed."
} else {
    Write-Output "Windows bloatware removal: SKIPPED (skipwindows=true)"
}

############################################################################################################
#                                        HP Bloatware Removal                                             #
############################################################################################################

if ($skipHP -ne "true") {
    Write-Output "HP bloatware removal: ENABLED"
    Write-Output "Starting HP bloatware removal..."

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
    $app = Get-CimInstance -Query "SELECT * FROM Win32_Product WHERE name = '$HPWin32App'" -ErrorAction SilentlyContinue
    if ($app) {
        Write-Output "Removing $HPWin32App"
        try {
            $app | Invoke-CimMethod -MethodName Uninstall
            Write-Output "Removed $HPWin32App"
        }
        catch {
            Write-Output "Failed to remove $HPWin32App"
        }
    }
}

    Write-Output "HP bloatware removal completed."
} else {
    Write-Output "HP bloatware removal: SKIPPED (skiphp=true)"
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

# Calculate runtime
$endUtc = [datetime]::UtcNow
$runtime = $endUtc - $startUtc
$runtimeMinutes = [math]::Round($runtime.TotalMinutes, 2)

Write-Output ""
Write-Output "=============================================="
Write-Output "Focused Debloat Script Completed Successfully"
Write-Output "=============================================="
Write-Output "Runtime: $runtimeMinutes minutes"
Write-Output "Log saved to: C:\ProgramData\Debloat\Debloat.log"
Write-Output ""
Write-Output "Summary of actions taken:"
if ($skipWindows -ne "true") { Write-Output "- Removed Windows bloatware (AppX packages)" } else { Write-Output "- Windows bloatware removal: SKIPPED" }
if ($skipHP -ne "true") { Write-Output "- Removed HP manufacturer bloatware" } else { Write-Output "- HP bloatware removal: SKIPPED" }
if ($skipDell -ne "true") { Write-Output "- Removed Dell manufacturer bloatware" } else { Write-Output "- Dell bloatware removal: SKIPPED" }
if ($skipLenovo -ne "true") { Write-Output "- Removed Lenovo manufacturer bloatware" } else { Write-Output "- Lenovo bloatware removal: SKIPPED" }
Write-Output "- Registry modifications: SKIPPED (as requested)"
Write-Output "- Office removal: SKIPPED (as requested)"
Write-Output ""
Write-Output "Script completed at: $(Get-Date)"

Stop-Transcript
