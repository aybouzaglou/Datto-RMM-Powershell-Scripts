<#
.SYNOPSIS
Configure Browser Extension Settings - Chrome and Edge Extension Deployment

.DESCRIPTION
Self-contained script for deploying and configuring browser extensions (Chrome/Edge) via Group Policy registry settings.
Configures extension installation, managed storage settings, branding, and security features.

Designed for phishing protection and security browser extensions with customizable settings:
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
Chrome Configuration:
- chromeExtensionId (String): Chrome extension ID (required)
- chromeUpdateUrl (String): Chrome update URL (default: https://clients2.google.com/service/update2/crx)

Edge Configuration:
- edgeExtensionId (String): Edge extension ID (required)
- edgeUpdateUrl (String): Edge update URL (default: https://edge.microsoft.com/extensionwebstorebase/v1/crx)

Extension Configuration:
- showNotifications (Integer): Show notifications - 0=disabled, 1=enabled (default: 1)
- enableValidPageBadge (Integer): Show valid page badge - 0=disabled, 1=enabled (default: 0)
- enablePageBlocking (Integer): Enable page blocking - 0=disabled, 1=enabled (default: 1)
- forceToolbarPin (Integer): Force pin to toolbar - 0=no, 1=yes (default: 1)
- installationMode (String): Installation mode (default: force_installed)

CIPP Reporting:
- enableCippReporting (Integer): Enable CIPP reporting - 0=disabled, 1=enabled (default: 0)
- cippServerUrl (String): CIPP server URL (required if CIPP enabled)
- cippTenantId (String): Tenant ID/Domain (required if CIPP enabled)

Detection Configuration:
- customRulesUrl (String): Custom rules config URL (optional)
- updateInterval (Integer): Update interval in hours, 1-168 (default: 24)
- urlAllowlist (String): Comma-separated list of allowed URLs (optional)

Debug and Logging:
- enableDebugLogging (Integer): Enable debug logging - 0=disabled, 1=enabled (default: 0)
- enableRMMLogging (Boolean): Enable detailed RMM logging (default: true)

Custom Branding:
- companyName (String): Company name (default: CyberDrain)
- companyURL (String): Company URL with protocol (default: https://cyberdrain.com)
- productName (String): Product name (default: Check - Phishing Protection)
- supportEmail (String): Support email address (optional)
- primaryColor (String): Primary color hex code (default: #F77F00)
- logoUrl (String): Logo URL with https protocol (optional)

.EXAMPLES
Environment Variables:
chromeExtensionId = "benimdeioplgkhanklclahllklceahbe"
edgeExtensionId = "knepjpocdagponkonnbggpcnhnaikajg"
showNotifications = 1
enablePageBlocking = 1
companyName = "Contoso Corp"
companyURL = "https://contoso.com"
enableRMMLogging = true

.NOTES
Version: 1.0.0
Author: Datto RMM Self-Contained Architecture
Compatible: PowerShell 2.0+, Datto RMM Environment
Deployment: DIRECT (paste script content directly into Datto RMM)
Requires: Administrative privileges for registry modifications
Exit Codes:
  0 = Success
  1 = Missing required extension IDs
  2 = Registry configuration error
  3 = Validation error
#>

param(
    [string]$chromeExtensionId = $env:chromeExtensionId,
    [string]$edgeExtensionId = $env:edgeExtensionId,
    [bool]$enableRMMLogging = ($env:enableRMMLogging -ne "false")
)

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
            Get-ItemProperty -Path $urlAllowlistKey | ForEach-Object {
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
Write-RMMLog "Browser Extension Configuration v1.0.0" -Level Status
Write-RMMLog "=============================================="
Write-RMMLog "Component Category: Scripts (Security/Browser Management)" -Level Config
Write-RMMLog "Start Time: $(Get-Date)" -Level Config
Write-RMMLog ""

# Validate required parameters
$exitCode = 0

# Process Chrome extension ID
$chromeExtId = Get-RMMVariable -Name "chromeExtensionId" -Default ""
if ([string]::IsNullOrWhiteSpace($chromeExtId)) {
    $chromeExtId = "benimdeioplgkhanklclahllklceahbe"
    Write-RMMLog "Using default Chrome extension ID: $chromeExtId" -Level Config
} else {
    Write-RMMLog "Using configured Chrome extension ID: $chromeExtId" -Level Config
}

# Process Edge extension ID
$edgeExtId = Get-RMMVariable -Name "edgeExtensionId" -Default ""
if ([string]::IsNullOrWhiteSpace($edgeExtId)) {
    $edgeExtId = "knepjpocdagponkonnbggpcnhnaikajg"
    Write-RMMLog "Using default Edge extension ID: $edgeExtId" -Level Config
} else {
    Write-RMMLog "Using configured Edge extension ID: $edgeExtId" -Level Config
}

# Process all configuration variables
$showNotifications = Get-RMMVariable -Name "showNotifications" -Type "Integer" -Default 1
$enableValidPageBadge = Get-RMMVariable -Name "enableValidPageBadge" -Type "Integer" -Default 0
$enablePageBlocking = Get-RMMVariable -Name "enablePageBlocking" -Type "Integer" -Default 1
$forceToolbarPin = Get-RMMVariable -Name "forceToolbarPin" -Type "Integer" -Default 1
$enableCippReporting = Get-RMMVariable -Name "enableCippReporting" -Type "Integer" -Default 0
$cippServerUrl = Get-RMMVariable -Name "cippServerUrl" -Default ""
$cippTenantId = Get-RMMVariable -Name "cippTenantId" -Default ""
$customRulesUrl = Get-RMMVariable -Name "customRulesUrl" -Default ""
$updateInterval = Get-RMMVariable -Name "updateInterval" -Type "Integer" -Default 24
$enableDebugLogging = Get-RMMVariable -Name "enableDebugLogging" -Type "Integer" -Default 0
$installationMode = Get-RMMVariable -Name "installationMode" -Default "force_installed"

# Custom Branding Settings
$companyName = Get-RMMVariable -Name "companyName" -Default "CyberDrain"
$companyURL = Get-RMMVariable -Name "companyURL" -Default "https://cyberdrain.com"
$productName = Get-RMMVariable -Name "productName" -Default "Check - Phishing Protection"
$supportEmail = Get-RMMVariable -Name "supportEmail" -Default ""
$primaryColor = Get-RMMVariable -Name "primaryColor" -Default "#F77F00"
$logoUrl = Get-RMMVariable -Name "logoUrl" -Default ""

# URL Allowlist processing
$urlAllowlistString = Get-RMMVariable -Name "urlAllowlist" -Default ""
$urlAllowlist = @()
if (![string]::IsNullOrWhiteSpace($urlAllowlistString)) {
    $urlAllowlist = $urlAllowlistString -split ',' | ForEach-Object { $_.Trim() } | Where-Object { ![string]::IsNullOrWhiteSpace($_) }
    Write-RMMLog "Parsed $($urlAllowlist.Count) URLs from allowlist" -Level Config
}

# Validate CIPP configuration if enabled
if ($enableCippReporting -eq 1) {
    if ([string]::IsNullOrWhiteSpace($cippServerUrl) -or [string]::IsNullOrWhiteSpace($cippTenantId)) {
        Write-RMMLog "CIPP reporting enabled but cippServerUrl or cippTenantId not provided" -Level Warning
        Write-RMMLog "Disabling CIPP reporting" -Level Warning
        $enableCippReporting = 0
    } else {
        Write-RMMLog "CIPP reporting enabled: $cippServerUrl (Tenant: $cippTenantId)" -Level Config
    }
}

Write-RMMLog ""
Write-RMMLog "Configuration Summary:" -Level Config
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
    chromeExtensionId = $chromeExtId
    edgeExtensionId = $edgeExtId
}

# Main execution
try {
    Write-RMMLog "Starting browser extension configuration..." -Level Status

    # Define registry paths
    $chromeUpdateUrl = Get-RMMVariable -Name "chromeUpdateUrl" -Default "https://clients2.google.com/service/update2/crx"
    $chromeManagedStorageKey = "HKLM:\SOFTWARE\Policies\Google\Chrome\3rdparty\extensions\$chromeExtId\policy"
    $chromeExtensionSettingsKey = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionSettings\$chromeExtId"

    $edgeUpdateUrl = Get-RMMVariable -Name "edgeUpdateUrl" -Default "https://edge.microsoft.com/extensionwebstorebase/v1/crx"
    $edgeManagedStorageKey = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\3rdparty\extensions\$edgeExtId\policy"
    $edgeExtensionSettingsKey = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionSettings\$edgeExtId"

    # Configure Chrome extension
    Write-RMMLog "Configuring Chrome extension..." -Level Status
    $chromeSuccess = Configure-ExtensionSettings `
        -ExtensionId $chromeExtId `
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
        -ExtensionId $edgeExtId `
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
