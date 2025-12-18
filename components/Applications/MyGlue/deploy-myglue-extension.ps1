<#
.SYNOPSIS
    Deploys the MyGlue browser extension to Google Chrome and Microsoft Edge.

.DESCRIPTION
    This script deploys the MyGlue extension to Chrome and Edge by adding it to the
    ExtensionInstallForcelist policy in the registry.
    It supports both System-wide (HKLM) and User-level (HKCU) deployment based on permissions.
    In Datto RMM (System context), it defaults to System-wide deployment.

.PARAMETER MyGlueExtensionID
    The ID of the MyGlue extension. Default: bfcdaalpeodhimbiipneeaoeogkkminc

.NOTES
    Author: Datto RMM Script Specialist
    Date: 2025-12-15
    Context: System or User
#>

# ==============================================================================
# EMBEDDED SHARED FUNCTIONS
# ==============================================================================

# Global counters for tracking script execution metrics
if (-not (Get-Variable -Name "RMMSuccessCount" -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:RMMSuccessCount = 0
}
if (-not (Get-Variable -Name "RMMFailCount" -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:RMMFailCount = 0
}
if (-not (Get-Variable -Name "RMMWarningCount" -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:RMMWarningCount = 0
}

function Write-RMMLog {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Success','Failed','Warning','Status','Config','Detect','Metric','Info')]
        [string]$Level,

        [bool]$UpdateCounters = $true
    )

    # Handle empty messages for spacing
    if ([string]::IsNullOrEmpty($Message)) {
        Write-Host ""
        return
    }

    $prefix = switch ($Level) {
        'Success' { 'SUCCESS '; if ($UpdateCounters) { $Global:RMMSuccessCount++ } }
        'Failed'  { 'FAILED  '; if ($UpdateCounters) { $Global:RMMFailCount++ } }
        'Warning' { 'WARNING '; if ($UpdateCounters) { $Global:RMMWarningCount++ } }
        'Status'  { 'STATUS  ' }
        'Config'  { 'CONFIG  ' }
        'Detect'  { 'DETECT  ' }
        'Metric'  { 'METRIC  ' }
        'Info'    { 'INFO    ' }
    }
    
    Write-Host "$prefix$Message"
}

function Get-RMMVariable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [ValidateSet('String','Boolean','Integer')]
        [string]$Type = 'String',
        
        [object]$Default = '',
        
        [switch]$Required
    )
    
    $val = Get-Item "env:$Name" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value
    
    if ([string]::IsNullOrWhiteSpace($val)) {
        if ($Required) {
            Write-RMMLog "Input variable '$Name' required but not supplied" -Level Failed
            throw "Input '$Name' required but not supplied"
        }
        return $Default
    }
    
    switch ($Type) {
        'Boolean' { 
            return ($val -eq 'true' -or $val -eq '1' -or $val -eq 'yes')
        }
        'Integer' { 
            try {
                return [int]$val
            }
            catch {
                Write-RMMLog "Invalid integer value for '$Name': $val" -Level Warning
                return $Default
            }
        }
        default { 
            return $val 
        }
    }
}

# ==============================================================================
# MAIN SCRIPT LOGIC
# ==============================================================================

# Constants
$DEFAULT_EXTENSION_ID = "bfcdaalpeodhimbiipneeaoeogkkminc"
$UPDATE_URL = "https://clients2.google.com/service/update2/crx"

# Helper Function: Deploy Extension
function Deploy-ExtensionToRegistry {
    param (
        [string]$RegistryPath,
        [string]$ExtensionValue,
        [string]$BrowserName,
        [string]$Scope
    )

    try {
        if (-not (Test-Path $RegistryPath)) {
            New-Item -Path $RegistryPath -Force | Out-Null
            Write-RMMLog "Created $BrowserName policy registry path ($Scope)" -Level Info
        }

        # Check if already installed
        $existingValues = Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue
        if ($existingValues) {
            $isInstalled = $existingValues.PSObject.Properties.Value | Where-Object { $_ -eq $ExtensionValue }
            if ($isInstalled) {
                Write-RMMLog "$BrowserName Extension already deployed ($Scope)" -Level Success
                return $true
            }
        }

        # Get the next available index
        $index = 1
        if ($existingValues) {
            $existingIndexes = $existingValues.PSObject.Properties.Name | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
            if ($existingIndexes) {
                $index = ($existingIndexes | Measure-Object -Maximum).Maximum + 1
            }
        }

        New-ItemProperty -Path $RegistryPath -Name $index -Value $ExtensionValue -PropertyType String -Force | Out-Null
        Write-RMMLog "Added $BrowserName extension at index $index ($Scope)" -Level Success
        return $true
    }
    catch {
        Write-RMMLog "Failed to deploy to $BrowserName ($Scope): $($_.Exception.Message)" -Level Failed
        return $false
    }
}

# Helper Function: Verify Extension
function Verify-ExtensionDeployment {
    param (
        [string]$RegistryPath,
        [string]$ExtensionValue,
        [string]$BrowserName
    )
    
    try {
        if (-not (Test-Path $RegistryPath)) {
            return $false
        }
        
        $existingValues = Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue
        $isFound = $existingValues.PSObject.Properties.Value | Where-Object { $_ -eq $ExtensionValue }
        
        return [bool]$isFound
    }
    catch {
        return $false
    }
}

try {
    Write-RMMLog "Starting MyGlue Extension Deployment" -Level Status

    # Get Configuration
    $extensionId = Get-RMMVariable -Name "MyGlueExtensionID" -Default $DEFAULT_EXTENSION_ID
    Write-RMMLog "Using Extension ID: $extensionId" -Level Config

    # Check Permissions
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-RMMLog "Running in User Context. Deployment will be limited to Current User." -Level Warning
        $hive = "HKCU:"
        $scope = "Current User"
    } else {
        Write-RMMLog "Running in System/Admin Context. Deployment will be System-wide." -Level Info
        $hive = "HKLM:"
        $scope = "System-wide"
    }

    $errors = 0

    # -------------------------------------------------------------------------
    # Chrome Deployment
    # -------------------------------------------------------------------------
    $chromePath = "$hive\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
    # Research confirms standard format is ID;UpdateURL for both Chrome and Edge
    $chromeValue = "$extensionId;$UPDATE_URL"
    
    if (Deploy-ExtensionToRegistry -RegistryPath $chromePath -ExtensionValue $chromeValue -BrowserName "Chrome" -Scope $scope) {
        # Verify
        if (Verify-ExtensionDeployment -RegistryPath $chromePath -ExtensionValue $chromeValue -BrowserName "Chrome") {
            Write-RMMLog "Chrome deployment verified" -Level Success
        } else {
            Write-RMMLog "Chrome deployment verification failed" -Level Failed
            $errors++
        }
    } else {
        $errors++
    }

    # -------------------------------------------------------------------------
    # Edge Deployment
    # -------------------------------------------------------------------------
    $edgePath = "$hive\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
    # Edge needs ID;UpdateURL
    $edgeValue = "$extensionId;$UPDATE_URL"
    
    if (Deploy-ExtensionToRegistry -RegistryPath $edgePath -ExtensionValue $edgeValue -BrowserName "Edge" -Scope $scope) {
        # Verify
        if (Verify-ExtensionDeployment -RegistryPath $edgePath -ExtensionValue $edgeValue -BrowserName "Edge") {
            Write-RMMLog "Edge deployment verified" -Level Success
        } else {
            Write-RMMLog "Edge deployment verification failed" -Level Failed
            $errors++
        }
    } else {
        $errors++
    }

    # -------------------------------------------------------------------------
    # Final Result
    # -------------------------------------------------------------------------
    if ($errors -eq 0) {
        Write-RMMLog "Deployment completed successfully for all browsers" -Level Status
        exit 0
    } else {
        Write-RMMLog "Deployment completed with $errors errors" -Level Failed
        exit 1
    }
}
catch {
    Write-RMMLog "Fatal error during deployment: $($_.Exception.Message)" -Level Failed
    exit 1
}
