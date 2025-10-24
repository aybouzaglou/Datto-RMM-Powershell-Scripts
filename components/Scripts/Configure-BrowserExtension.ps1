<#
.SYNOPSIS
Configure Browser Extension Settings - Chrome and Edge Extension Deployment

.DESCRIPTION
Self-contained script for deploying and configuring browser extensions (Chrome/Edge) via Group Policy registry settings.
Configures extension installation, managed storage settings, branding, and security features.

All settings are configured with default values in the script. Only the CIPP Tenant ID is passed as an
environment variable since it changes per customer tenant.

To customize defaults: Edit the configuration section below before deploying to Datto RMM.

Features:
- Force installation of extensions
- Configure notification preferences
- Set CIPP reporting options
- Custom branding (company name, logo, colors)
- URL allowlist management
- Debug logging and detection configuration

.COMPONENT
Category: Scripts (Security/Browser Management)
Execution: On-demand or scheduled
Timeout: 5 minutes recommended
Changeable: Yes (can be changed to Applications category if needed)

.ENVIRONMENT VARIABLES
Required:
- cippTenantId (String): Tenant ID/Domain for CIPP reporting (e.g., "contoso.onmicrosoft.com" or GUID)

Optional:
- enableRMMLogging (Boolean): Enable detailed RMM transcript logging (default: true)

.EXAMPLES
Environment Variables in Datto RMM:
cippTenantId = "contoso.onmicrosoft.com"
enableRMMLogging = true

.NOTES
Version: 1.0.1
Author: Datto RMM Self-Contained Architecture
Compatible: PowerShell 2.0+, Datto RMM Environment
Deployment: DIRECT (paste script content directly into Datto RMM)
Requires: Administrative privileges for registry modifications

Exit Codes:
  0 = Success
  1 = Missing required tenant ID
  2 = Registry configuration error
  3 = Partial success (one browser configured)

To Customize: Edit the "CONFIGURATION SECTION" below before deploying to Datto RMM.
#>

param(
    [string]$cippTenantId = $env:cippTenantId,
    [bool]$enableRMMLogging = ($env:enableRMMLogging -ne "false")
)

############################################################################################################
#                                    CONFIGURATION SECTION                                                 #
#                        EDIT THESE VALUES BEFORE DEPLOYING TO DATTO RMM                                  #
############################################################################################################

# Extension IDs
$chromeExtensionId = "benimdeioplgkhanklclahllklceahbe"
$chromeUpdateUrl = "https://clients2.google.com/service/update2/crx"

$edgeExtensionId = "knepjpocdagponkonnbggpcnhnaikajg"
$edgeUpdateUrl = "https://edge.microsoft.com/extensionwebstorebase/v1/crx"

# Extension Configuration Settings
$showNotifications = 1       # 0 = Disabled, 1 = Enabled (default: 1)
$enableValidPageBadge = 0    # 0 = Disabled, 1 = Enabled (default: 0)
$enablePageBlocking = 1      # 0 = Disabled, 1 = Enabled (default: 1)
$forceToolbarPin = 1         # 0 = Not pinned, 1 = Force pinned (default: 1)
$installationMode = "force_installed"

# CIPP Reporting Configuration
$enableCippReporting = 1     # 0 = Disabled, 1 = Enabled (default: 1)
$cippServerUrl = "https://cipp.cyberdrain.com"  # Your CIPP server URL (include https://)
# Note: $cippTenantId comes from environment variable (set per tenant in Datto RMM)

# Detection Configuration
$customRulesUrl = ""         # Custom rules URL (leave blank if not using)
$updateInterval = 24         # Update interval in hours, 1-168 (default: 24)
$urlAllowlist = @()          # Example: @("https://example1.com", "https://*.example2.com")
$enableDebugLogging = 0      # 0 = Disabled, 1 = Enabled (default: 0)

# Custom Branding Settings
$companyName = "CyberDrain"
$companyURL = "https://cyberdrain.com"
$productName = "Check - Phishing Protection"
$supportEmail = ""           # Support email (optional)
$primaryColor = "#F77F00"    # Hex color code
$logoUrl = ""                # Logo URL with https:// (optional, recommended 48x48px)

############################################################################################################
#                                    EMBEDDED FUNCTION LIBRARY                                            #
############################################################################################################

# Embedded logging function
function Write-RMMLog {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory=$false)]
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

# Function to configure extension settings
function Configure-ExtensionSettings {
    param (
        [string]$ExtensionId,
        [string]$UpdateUrl,
        [string]$ManagedStorageKey,
        [string]$ExtensionSettingsKey,
        [hashtable]$Config
    )

    try {
        Write-RMMLog "Configuring extension: $ExtensionId" -Level Status

        # Create and configure managed storage key
        if (!(Test-Path $ManagedStorageKey)) {
            New-Item -Path $ManagedStorageKey -Force | Out-Null
            Write-RMMLog "Created managed storage key: $ManagedStorageKey" -Level Config
        }

        # Set extension configuration settings
        New-ItemProperty -Path $ManagedStorageKey -Name "showNotifications" -PropertyType DWord -Value $Config.showNotifications -Force | Out-Null
        New-ItemProperty -Path $ManagedStorageKey -Name "enableValidPageBadge" -PropertyType DWord -Value $Config.enableValidPageBadge -Force | Out-Null
        New-ItemProperty -Path $ManagedStorageKey -Name "enablePageBlocking" -PropertyType DWord -Value $Config.enablePageBlocking -Force | Out-Null
        New-ItemProperty -Path $ManagedStorageKey -Name "enableCippReporting" -PropertyType DWord -Value $Config.enableCippReporting -Force | Out-Null
        New-ItemProperty -Path $ManagedStorageKey -Name "cippServerUrl" -PropertyType String -Value $Config.cippServerUrl -Force | Out-Null
        New-ItemProperty -Path $ManagedStorageKey -Name "cippTenantId" -PropertyType String -Value $Config.cippTenantId -Force | Out-Null
        New-ItemProperty -Path $ManagedStorageKey -Name "customRulesUrl" -PropertyType String -Value $Config.customRulesUrl -Force | Out-Null
        New-ItemProperty -Path $ManagedStorageKey -Name "updateInterval" -PropertyType DWord -Value $Config.updateInterval -Force | Out-Null
        New-ItemProperty -Path $ManagedStorageKey -Name "enableDebugLogging" -PropertyType DWord -Value $Config.enableDebugLogging -Force | Out-Null

        Write-RMMLog "Configured extension settings" -Level Success

        # Create and configure URL allow list
        if ($Config.urlAllowlist.Count -gt 0) {
            $urlAllowlistKey = "$ManagedStorageKey\urlAllowlist"
            if (!(Test-Path $urlAllowlistKey)) {
                New-Item -Path $urlAllowlistKey -Force | Out-Null
            }

            # Clear any existing properties
            Get-ItemProperty -Path $urlAllowlistKey -ErrorAction SilentlyContinue | ForEach-Object {
                $_.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                    Remove-ItemProperty -Path $urlAllowlistKey -Name $_.Name -Force -ErrorAction SilentlyContinue
                }
            }

            # Set URL allow list properties with names starting from 1
            for ($i = 0; $i -lt $Config.urlAllowlist.Count; $i++) {
                $propertyName = ($i + 1).ToString()
                $propertyValue = $Config.urlAllowlist[$i]
                New-ItemProperty -Path $urlAllowlistKey -Name $propertyName -PropertyType String -Value $propertyValue -Force | Out-Null
            }

            Write-RMMLog "Configured URL allowlist with $($Config.urlAllowlist.Count) entries" -Level Success
        }

        # Create and configure custom branding
        $customBrandingKey = "$ManagedStorageKey\customBranding"
        if (!(Test-Path $customBrandingKey)) {
            New-Item -Path $customBrandingKey -Force | Out-Null
        }

        # Set custom branding settings
        New-ItemProperty -Path $customBrandingKey -Name "companyName" -PropertyType String -Value $Config.companyName -Force | Out-Null
        New-ItemProperty -Path $customBrandingKey -Name "companyURL" -PropertyType String -Value $Config.companyURL -Force | Out-Null
        New-ItemProperty -Path $customBrandingKey -Name "productName" -PropertyType String -Value $Config.productName -Force | Out-Null
        New-ItemProperty -Path $customBrandingKey -Name "supportEmail" -PropertyType String -Value $Config.supportEmail -Force | Out-Null
        New-ItemProperty -Path $customBrandingKey -Name "primaryColor" -PropertyType String -Value $Config.primaryColor -Force | Out-Null
        New-ItemProperty -Path $customBrandingKey -Name "logoUrl" -PropertyType String -Value $Config.logoUrl -Force | Out-Null

        Write-RMMLog "Configured custom branding" -Level Success

        # Create and configure extension settings
        if (!(Test-Path $ExtensionSettingsKey)) {
            New-Item -Path $ExtensionSettingsKey -Force | Out-Null
        }

        # Set extension settings
        New-ItemProperty -Path $ExtensionSettingsKey -Name "installation_mode" -PropertyType String -Value $Config.installationMode -Force | Out-Null
        New-ItemProperty -Path $ExtensionSettingsKey -Name "update_url" -PropertyType String -Value $UpdateUrl -Force | Out-Null

        Write-RMMLog "Configured extension installation settings" -Level Success

        # Add toolbar pinning if enabled
        if ($Config.forceToolbarPin -eq 1) {
            if ($ExtensionId -eq $Config.edgeExtensionId) {
                New-ItemProperty -Path $ExtensionSettingsKey -Name "toolbar_state" -PropertyType String -Value "force_shown" -Force | Out-Null
                Write-RMMLog "Configured Edge toolbar pinning" -Level Success
            } elseif ($ExtensionId -eq $Config.chromeExtensionId) {
                New-ItemProperty -Path $ExtensionSettingsKey -Name "toolbar_pin" -PropertyType String -Value "force_pinned" -Force | Out-Null
                Write-RMMLog "Configured Chrome toolbar pinning" -Level Success
            }
        }

        Write-RMMLog "Completed configuration for extension $ExtensionId" -Level Success
        return $true

    } catch {
        Write-RMMLog "Error configuring extension $ExtensionId`: $($_.Exception.Message)" -Level Error
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

if ($enableRMMLogging) {
    Start-Transcript -Path "$LogPath\BrowserExtension-$(Get-Date -Format 'yyyyMMdd-HHmmss').log" -Append
}

Write-RMMLog "=============================================="
Write-RMMLog "Browser Extension Configuration v1.0.1" -Level Status
Write-RMMLog "=============================================="
Write-RMMLog "Component Category: Scripts (Security/Browser Management)" -Level Config
Write-RMMLog "Start Time: $(Get-Date)" -Level Config
Write-RMMLog ""

# Validate required tenant ID
$exitCode = 0

if ([string]::IsNullOrWhiteSpace($cippTenantId)) {
    Write-RMMLog "REQUIRED: cippTenantId environment variable must be set in Datto RMM" -Level Failed
    Write-RMMLog "This should be your tenant domain (e.g., contoso.onmicrosoft.com) or GUID" -Level Failed
    if ($enableRMMLogging) { Stop-Transcript }
    exit 1
}

Write-RMMLog "CIPP Tenant ID: $cippTenantId" -Level Config

# Validate CIPP configuration if enabled
if ($enableCippReporting -eq 1) {
    if ([string]::IsNullOrWhiteSpace($cippServerUrl)) {
        Write-RMMLog "CIPP reporting enabled but cippServerUrl not configured in script" -Level Warning
        Write-RMMLog "Disabling CIPP reporting" -Level Warning
        $enableCippReporting = 0
    } else {
        Write-RMMLog "CIPP reporting enabled: $cippServerUrl" -Level Config
    }
}

Write-RMMLog ""
Write-RMMLog "Configuration Summary:" -Level Config
Write-RMMLog "- Chrome Extension ID: $chromeExtensionId" -Level Config
Write-RMMLog "- Edge Extension ID: $edgeExtensionId" -Level Config
Write-RMMLog "- Show Notifications: $showNotifications" -Level Config
Write-RMMLog "- Enable Valid Page Badge: $enableValidPageBadge" -Level Config
Write-RMMLog "- Enable Page Blocking: $enablePageBlocking" -Level Config
Write-RMMLog "- Force Toolbar Pin: $forceToolbarPin" -Level Config
Write-RMMLog "- Installation Mode: $installationMode" -Level Config
Write-RMMLog "- Enable CIPP Reporting: $enableCippReporting" -Level Config
Write-RMMLog "- Update Interval: $updateInterval hours" -Level Config
Write-RMMLog "- Enable Debug Logging: $enableDebugLogging" -Level Config
Write-RMMLog "- Company Name: $companyName" -Level Config
Write-RMMLog "- Company URL: $companyURL" -Level Config
Write-RMMLog "- Product Name: $productName" -Level Config
Write-RMMLog ""

# Build configuration hashtable
$config = @{
    showNotifications = $showNotifications
    enableValidPageBadge = $enableValidPageBadge
    enablePageBlocking = $enablePageBlocking
    forceToolbarPin = $forceToolbarPin
    enableCippReporting = $enableCippReporting
    cippServerUrl = $cippServerUrl
    cippTenantId = $cippTenantId
    customRulesUrl = $customRulesUrl
    updateInterval = $updateInterval
    urlAllowlist = $urlAllowlist
    enableDebugLogging = $enableDebugLogging
    companyName = $companyName
    companyURL = $companyURL
    productName = $productName
    supportEmail = $supportEmail
    primaryColor = $primaryColor
    logoUrl = $logoUrl
    installationMode = $installationMode
    chromeExtensionId = $chromeExtensionId
    edgeExtensionId = $edgeExtensionId
}

# Main execution
try {
    Write-RMMLog "Starting browser extension configuration..." -Level Status

    # Define registry paths
    $chromeManagedStorageKey = "HKLM:\SOFTWARE\Policies\Google\Chrome\3rdparty\extensions\$chromeExtensionId\policy"
    $chromeExtensionSettingsKey = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionSettings\$chromeExtensionId"

    $edgeManagedStorageKey = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\3rdparty\extensions\$edgeExtensionId\policy"
    $edgeExtensionSettingsKey = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionSettings\$edgeExtensionId"

    # Configure Chrome extension
    Write-RMMLog "Configuring Chrome extension..." -Level Status
    $chromeSuccess = Configure-ExtensionSettings `
        -ExtensionId $chromeExtensionId `
        -UpdateUrl $chromeUpdateUrl `
        -ManagedStorageKey $chromeManagedStorageKey `
        -ExtensionSettingsKey $chromeExtensionSettingsKey `
        -Config $config

    if (-not $chromeSuccess) {
        Write-RMMLog "Failed to configure Chrome extension" -Level Error
        $exitCode = 2
    }

    # Configure Edge extension
    Write-RMMLog "Configuring Edge extension..." -Level Status
    $edgeSuccess = Configure-ExtensionSettings `
        -ExtensionId $edgeExtensionId `
        -UpdateUrl $edgeUpdateUrl `
        -ManagedStorageKey $edgeManagedStorageKey `
        -ExtensionSettingsKey $edgeExtensionSettingsKey `
        -Config $config

    if (-not $edgeSuccess) {
        Write-RMMLog "Failed to configure Edge extension" -Level Error
        $exitCode = 2
    }

    # Final status
    if ($chromeSuccess -and $edgeSuccess) {
        Write-RMMLog "Browser extension configuration completed successfully" -Level Success
        $exitCode = 0
    } elseif ($chromeSuccess -or $edgeSuccess) {
        Write-RMMLog "Browser extension configuration completed with partial success" -Level Warning
        if ($exitCode -eq 0) { $exitCode = 3 }
    } else {
        Write-RMMLog "Browser extension configuration failed for all browsers" -Level Failed
        $exitCode = 2
    }

} catch {
    Write-RMMLog "Unexpected error during execution: $($_.Exception.Message)" -Level Error
    Write-RMMLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    $exitCode = 2
} finally {
    Write-RMMLog ""
    Write-RMMLog "=============================================="
    Write-RMMLog "Browser Extension Configuration completed" -Level Status
    Write-RMMLog "Final exit code: $exitCode" -Level Status
    Write-RMMLog "End Time: $(Get-Date)" -Level Status
    Write-RMMLog "=============================================="

    if ($enableRMMLogging) {
        Stop-Transcript
    }
    exit $exitCode
}
