<#
.SYNOPSIS
    Deploy Mark of the Web (MotW) Fix - Policy and/or Unblock Files

.DESCRIPTION
    Comprehensive solution for restoring File Explorer preview functionality for
    internet-downloaded files. Combines policy deployment and bulk file unblocking
    into a single configurable component.

    Available Operations (via FixOperation variable):
    - PolicyOnly:    Enable "Do not preserve zone information" policy (prevents MotW on NEW downloads)
    - UnblockOnly:   Remove MotW from existing downloaded files
    - Both:          Apply policy AND unblock existing files (recommended for full remediation)

    Policy Details:
    Configures the HKCU registry setting that corresponds to:
    User Configuration > Administrative Templates > Windows Components > Attachment Manager
    > Do not preserve zone information in file attachments

    Unblock Details:
    - Downloads mode: Targets common document types (PDF, Office docs) in Downloads folder
    - AllUserFiles mode: Recursively processes entire user profile

    Requirements:
    - Windows 10 1703+ or Windows 11
    - Run as User context for file access
    - No restart required

.COMPONENT
    Category: Scripts (Security/Windows Configuration)
    Execution: On-demand or scheduled
    Timeout: 15 minutes recommended (longer for AllUserFiles with Both operation)
    Changeable: Yes

.ENVIRONMENT VARIABLES
    Required:
    - FixOperation (String): "PolicyOnly", "UnblockOnly", or "Both" (default: Both)

    Optional (for Unblock operations):
    - UnblockMode (String): "Downloads" or "AllUserFiles" (default: Downloads)
    - CustomPath (String): Override target path for unblock operation
    - FileExtensions (String): Comma-separated extensions (default: pdf,docx,xlsx,pptx,doc,xls,ppt)

    Optional (general):
    - EnableLogging (Boolean): Enable detailed transcript logging (default: true)

.EXAMPLES
    Example 1 - Full remediation (recommended for initial deployment):
    FixOperation = "Both"
    UnblockMode = "Downloads"

    Example 2 - Policy only (for new machines/preventive):
    FixOperation = "PolicyOnly"

    Example 3 - Unblock only (policy already deployed):
    FixOperation = "UnblockOnly"
    UnblockMode = "AllUserFiles"

    Example 4 - Custom unblock path:
    FixOperation = "UnblockOnly"
    CustomPath = "D:\SharedFiles"
    FileExtensions = "pdf,docx"

.NOTES
    Version: 1.0.0
    Author: Datto RMM Self-Contained Architecture
    Compatible: PowerShell 5.0+, Windows 10 1703+, Windows 11
    Deployment: DIRECT (paste script content directly into Datto RMM)

    Exit Codes:
      0 = Success - All operations completed successfully
      1 = Partial success - Some operations had warnings/failures
      2 = Error - Critical failure during execution

    Deployment Strategy:
    Day 1: Deploy with FixOperation="Both" to all affected devices
    Ongoing: Deploy with FixOperation="PolicyOnly" to new devices

    Run Context: User (required for HKCU registry and file access)
#>

param(
    [string]$FixOperation = $env:FixOperation,
    [string]$UnblockMode = $env:UnblockMode,
    [string]$CustomPath = $env:CustomPath,
    [string]$FileExtensions = $env:FileExtensions,
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
            @('true', '1', 'yes') -contains $envValue.ToLowerInvariant()
        }
        default { $envValue }
    }
}

############################################################################################################
#                                    POLICY FUNCTIONS                                                      #
############################################################################################################

function Set-MotWPolicy {
    param(
        [string]$RegistryPath,
        [string]$RegistryName,
        [int]$RegistryValue
    )

    try {
        if (-not (Test-Path $RegistryPath)) {
            New-Item -Path $RegistryPath -Force -ErrorAction Stop | Out-Null
            Write-RMMLog "Created registry path: $RegistryPath" -Level Config
        }

        Set-ItemProperty -Path $RegistryPath -Name $RegistryName -Value $RegistryValue -Type DWord -Force -ErrorAction Stop
        Write-RMMLog "Set registry value: $RegistryName = $RegistryValue" -Level Success
        return $true
    }
    catch {
        Write-RMMLog "Failed to set registry value: $($_.Exception.Message)" -Level Error
        return $false
    }
}

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

function Invoke-PolicyDeployment {
    Write-RMMLog "----------------------------------------------" -Level Status
    Write-RMMLog "OPERATION: Deploy MotW Bypass Policy" -Level Status
    Write-RMMLog "----------------------------------------------" -Level Status

    $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments"
    $RegName = "SaveZoneInformation"
    $RegValue = 1

    Write-RMMLog "Registry Path: $RegPath" -Level Config
    Write-RMMLog "Setting: $RegName = $RegValue (Do not preserve zone information)" -Level Config

    # Check current state
    $currentExists = Test-Path $RegPath
    if ($currentExists) {
        $currentValue = (Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction SilentlyContinue).$RegName
        if ($null -ne $currentValue) {
            Write-RMMLog "Current policy value: $currentValue" -Level Detect
            if ($currentValue -eq $RegValue) {
                Write-RMMLog "Policy is already configured correctly" -Level Success
                return $true
            }
        }
    }

    # Apply policy
    Write-RMMLog "Applying MotW bypass policy..." -Level Status
    $setResult = Set-MotWPolicy -RegistryPath $RegPath -RegistryName $RegName -RegistryValue $RegValue

    if (-not $setResult) {
        Write-RMMLog "Failed to apply MotW policy" -Level Failed
        return $false
    }

    # Verify
    $verifyResult = Test-MotWPolicy -RegistryPath $RegPath -RegistryName $RegName -ExpectedValue $RegValue

    if ($verifyResult) {
        Write-RMMLog "Policy deployed successfully - new downloads will not be tagged with MotW" -Level Success
        return $true
    }
    else {
        Write-RMMLog "Policy verification failed" -Level Failed
        return $false
    }
}

############################################################################################################
#                                    UNBLOCK FUNCTIONS                                                     #
############################################################################################################

function Test-FileHasMotW {
    param([string]$FilePath)

    try {
        $streams = Get-Item -Path $FilePath -Stream * -ErrorAction SilentlyContinue
        return $streams.Stream -contains 'Zone.Identifier'
    }
    catch {
        return $false
    }
}

function Invoke-UnblockByPattern {
    param(
        [string]$TargetPath,
        [string]$Pattern,
        [bool]$Recurse = $false
    )

    $results = @{
        Found = 0
        Unblocked = 0
        Failed = 0
        Skipped = 0
    }

    try {
        $getChildParams = @{
            Path = $TargetPath
            Filter = $Pattern
            File = $true
            ErrorAction = 'SilentlyContinue'
        }

        if ($Recurse) {
            $getChildParams.Recurse = $true
        }

        $files = Get-ChildItem @getChildParams

        if ($null -eq $files -or @($files).Count -eq 0) {
            return $results
        }

        $results.Found = @($files).Count

        foreach ($file in $files) {
            try {
                if (Test-FileHasMotW -FilePath $file.FullName) {
                    Unblock-File -Path $file.FullName -ErrorAction Stop
                    $results.Unblocked++
                }
                else {
                    $results.Skipped++
                }
            }
            catch {
                Write-RMMLog "Failed to unblock file '$($file.FullName)': $($_.Exception.Message)" -Level Warning
                $results.Failed++
            }
        }
    }
    catch {
        Write-RMMLog "Error processing pattern $Pattern`: $($_.Exception.Message)" -Level Error
    }

    return $results
}

function Invoke-UnblockOperation {
    param(
        [string]$Mode,
        [string]$TargetPath,
        [string[]]$FilePatterns
    )

    Write-RMMLog "----------------------------------------------" -Level Status
    Write-RMMLog "OPERATION: Unblock Existing Files" -Level Status
    Write-RMMLog "----------------------------------------------" -Level Status
    Write-RMMLog "Mode: $Mode" -Level Config
    Write-RMMLog "Target Path: $TargetPath" -Level Config

    if (-not (Test-Path $TargetPath)) {
        Write-RMMLog "Target path does not exist: $TargetPath" -Level Failed
        return $false
    }

    $totalFound = 0
    $totalUnblocked = 0
    $totalFailed = 0
    $totalSkipped = 0

    $useRecurse = ($Mode -eq "AllUserFiles")

    if ($Mode -eq "AllUserFiles") {
        Write-RMMLog "Scanning entire user profile recursively (this may take several minutes)..." -Level Status

        $results = Invoke-UnblockByPattern -TargetPath $TargetPath -Pattern "*" -Recurse $true

        $totalFound = $results.Found
        $totalUnblocked = $results.Unblocked
        $totalFailed = $results.Failed
        $totalSkipped = $results.Skipped
    }
    else {
        Write-RMMLog "File patterns: $($FilePatterns -join ', ')" -Level Config

        foreach ($pattern in $FilePatterns) {
            $results = Invoke-UnblockByPattern -TargetPath $TargetPath -Pattern $pattern -Recurse $false

            $totalFound += $results.Found
            $totalUnblocked += $results.Unblocked
            $totalFailed += $results.Failed
            $totalSkipped += $results.Skipped

            if ($results.Found -gt 0) {
                Write-RMMLog "$pattern - Found: $($results.Found), Unblocked: $($results.Unblocked)" -Level Info
            }
        }
    }

    Write-RMMLog ""
    Write-RMMLog "Unblock Summary:" -Level Status
    Write-RMMLog "- Files found: $totalFound" -Level Info
    Write-RMMLog "- Files unblocked: $totalUnblocked" -Level Success
    Write-RMMLog "- Files skipped (no MotW): $totalSkipped" -Level Info
    Write-RMMLog "- Files failed: $totalFailed" -Level $(if ($totalFailed -gt 0) { 'Warning' } else { 'Info' })

    if ($totalFailed -gt 0) {
        Write-RMMLog "Some files could not be unblocked" -Level Warning
        return $false
    }

    if ($totalUnblocked -gt 0) {
        Write-RMMLog "Successfully removed MotW from $totalUnblocked files" -Level Success
    }
    elseif ($totalFound -eq 0) {
        Write-RMMLog "No matching files found" -Level Info
    }
    else {
        Write-RMMLog "All files were already unblocked" -Level Success
    }

    return $true
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
    Start-Transcript -Path "$LogPath\Deploy-MotW-Fix-$(Get-Date -Format 'yyyyMMdd-HHmmss').log" -Append
}

Write-RMMLog "=============================================="
Write-RMMLog "Deploy Mark of the Web (MotW) Fix v1.0.0" -Level Status
Write-RMMLog "=============================================="
Write-RMMLog "Component Category: Scripts (Security/Windows Configuration)" -Level Config
Write-RMMLog "Start Time: $(Get-Date)" -Level Config
Write-RMMLog "Computer: $env:COMPUTERNAME" -Level Config
Write-RMMLog "User: $env:USERNAME" -Level Config
Write-RMMLog ""

# Apply defaults for empty parameters (preserves command-line values if provided)
if ([string]::IsNullOrWhiteSpace($FixOperation)) { $FixOperation = "Both" }
if ([string]::IsNullOrWhiteSpace($UnblockMode)) { $UnblockMode = "Downloads" }
if ([string]::IsNullOrWhiteSpace($FileExtensions)) { $FileExtensions = "pdf,docx,xlsx,pptx,doc,xls,ppt" }

# Validate FixOperation
$validOperations = @("PolicyOnly", "UnblockOnly", "Both")
if ($FixOperation -notin $validOperations) {
    Write-RMMLog "Invalid FixOperation: $FixOperation. Valid options: $($validOperations -join ', ')" -Level Warning
    Write-RMMLog "Defaulting to: Both" -Level Warning
    $FixOperation = "Both"
}

# Validate UnblockMode
$validModes = @("Downloads", "AllUserFiles")
if ($UnblockMode -notin $validModes) {
    Write-RMMLog "Invalid UnblockMode: $UnblockMode. Using default: Downloads" -Level Warning
    $UnblockMode = "Downloads"
}

# Determine unblock target path
if (-not [string]::IsNullOrWhiteSpace($CustomPath)) {
    $UnblockPath = $CustomPath
}
else {
    $UnblockPath = switch ($UnblockMode) {
        "Downloads" { "$env:USERPROFILE\Downloads" }
        "AllUserFiles" { $env:USERPROFILE }
    }
}

# Parse file extensions
$ExtensionList = $FileExtensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
$FilePatterns = $ExtensionList | ForEach-Object { "*.$_" }

Write-RMMLog "Configuration:" -Level Config
Write-RMMLog "- Fix Operation: $FixOperation" -Level Config
if ($FixOperation -ne "PolicyOnly") {
    Write-RMMLog "- Unblock Mode: $UnblockMode" -Level Config
    Write-RMMLog "- Unblock Path: $UnblockPath" -Level Config
    Write-RMMLog "- File Extensions: $($ExtensionList -join ', ')" -Level Config
}
Write-RMMLog ""

# Detect Windows version
$osBuild = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).BuildNumber
Write-RMMLog "Windows Build: $osBuild" -Level Detect
Write-RMMLog ""

# Main execution
$exitCode = 0
$policySuccess = $true
$unblockSuccess = $true

try {
    # Execute Policy Deployment
    if ($FixOperation -eq "PolicyOnly" -or $FixOperation -eq "Both") {
        $policySuccess = Invoke-PolicyDeployment
        if (-not $policySuccess) {
            $exitCode = 1
        }
        Write-RMMLog ""
    }

    # Execute Unblock Operation
    if ($FixOperation -eq "UnblockOnly" -or $FixOperation -eq "Both") {
        $unblockSuccess = Invoke-UnblockOperation -Mode $UnblockMode -TargetPath $UnblockPath -FilePatterns $FilePatterns
        if (-not $unblockSuccess -and $exitCode -eq 0) {
            $exitCode = 1
        }
        Write-RMMLog ""
    }

    # Final status
    Write-RMMLog "=============================================="
    Write-RMMLog "Operation Results" -Level Status
    Write-RMMLog "=============================================="

    if ($FixOperation -eq "PolicyOnly" -or $FixOperation -eq "Both") {
        if ($policySuccess) {
            Write-RMMLog "Policy Deployment: SUCCESS" -Level Success
        }
        else {
            Write-RMMLog "Policy Deployment: FAILED" -Level Failed
        }
    }

    if ($FixOperation -eq "UnblockOnly" -or $FixOperation -eq "Both") {
        if ($unblockSuccess) {
            Write-RMMLog "Unblock Files: SUCCESS" -Level Success
        }
        else {
            Write-RMMLog "Unblock Files: PARTIAL/WARNING" -Level Warning
        }
    }

    if ($policySuccess -and $unblockSuccess) {
        Write-RMMLog ""
        Write-RMMLog "All operations completed successfully" -Level Success
        Write-RMMLog "File Explorer preview should now work for internet-downloaded files" -Level Info
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
    Write-RMMLog "MotW Fix completed" -Level Status
    Write-RMMLog "Final exit code: $exitCode" -Level Status
    Write-RMMLog "End Time: $(Get-Date)" -Level Status
    Write-RMMLog "=============================================="

    if ($EnableLogging) {
        Stop-Transcript
    }
    exit $exitCode
}
