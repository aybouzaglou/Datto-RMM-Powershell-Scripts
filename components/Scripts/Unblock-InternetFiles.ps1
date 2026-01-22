<#
.SYNOPSIS
    Bulk Unblock Internet-Downloaded Files

.DESCRIPTION
    Removes Mark of the Web (MotW) Zone.Identifier alternate data streams from files
    downloaded from the internet. This restores File Explorer preview functionality
    and removes security warnings for existing downloaded files.

    Operation Modes:
    - Downloads: Unblock common document types in user's Downloads folder (default)
    - AllUserFiles: Unblock all files recursively in user profile (slower, more thorough)

    File Types Targeted (Downloads mode):
    - Documents: *.pdf, *.doc, *.docx, *.xls, *.xlsx, *.ppt, *.pptx
    - Additional extensions can be configured via environment variable

    Features:
    - Non-destructive operation (only removes Zone.Identifier ADS)
    - Progress tracking and detailed logging
    - Configurable target paths and file extensions
    - Error handling for locked or inaccessible files

    Requirements:
    - Run as User context to access user files
    - Windows 10/11

.COMPONENT
    Category: Scripts (Security/Windows Configuration)
    Execution: On-demand or scheduled
    Timeout: 15 minutes recommended (longer for AllUserFiles mode)
    Changeable: Yes

.ENVIRONMENT VARIABLES
    Optional:
    - OperationMode (String): "Downloads" or "AllUserFiles" (default: Downloads)
    - CustomPath (String): Override target path (default: based on OperationMode)
    - FileExtensions (String): Comma-separated list of extensions (default: pdf,docx,xlsx,pptx,doc,xls,ppt)
    - EnableLogging (Boolean): Enable detailed RMM transcript logging (default: true)

.EXAMPLES
    Environment Variables in Datto RMM:

    Example 1 - Unblock Downloads folder (default):
    OperationMode = "Downloads"
    EnableLogging = true

    Example 2 - Unblock entire user profile:
    OperationMode = "AllUserFiles"
    EnableLogging = true

    Example 3 - Custom path with specific extensions:
    CustomPath = "C:\Users\jdoe\Documents\Projects"
    FileExtensions = "pdf,docx,xlsx"

.NOTES
    Version: 1.0.0
    Author: Datto RMM Self-Contained Architecture
    Compatible: PowerShell 5.0+, Windows 10/11
    Deployment: DIRECT (paste script content directly into Datto RMM)

    Exit Codes:
      0 = Success - Files unblocked successfully
      1 = Partial success - Some files could not be unblocked
      2 = Error - Critical failure during execution

    Performance Notes:
    - Downloads mode: Typically completes in <1 minute
    - AllUserFiles mode: May take 5-15 minutes depending on file count
    - Set Datto RMM timeout appropriately for AllUserFiles mode

    Run Context: User (required to access user files)
#>

param(
    [string]$OperationMode = $env:OperationMode,
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
            $envValue -eq 'true' -or $envValue -eq '1' -or $envValue -eq 'yes'
        }
        default { $envValue }
    }
}

# Function to test if file has MotW
function Test-FileHasMotW {
    param([string]$FilePath)

    try {
        $streams = Get-Item -Path $FilePath -Stream * -ErrorAction SilentlyContinue
        return ($streams | Where-Object { $_.Stream -eq 'Zone.Identifier' }) -ne $null
    }
    catch {
        return $false
    }
}

# Function to unblock files by pattern
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
                $results.Failed++
                Write-RMMLog "Failed to unblock: $($file.Name) - $($_.Exception.Message)" -Level Warning
            }
        }
    }
    catch {
        Write-RMMLog "Error processing pattern $Pattern`: $($_.Exception.Message)" -Level Error
    }

    return $results
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
    Start-Transcript -Path "$LogPath\Unblock-InternetFiles-$(Get-Date -Format 'yyyyMMdd-HHmmss').log" -Append
}

Write-RMMLog "=============================================="
Write-RMMLog "Bulk Unblock Internet-Downloaded Files v1.0.0" -Level Status
Write-RMMLog "=============================================="
Write-RMMLog "Component Category: Scripts (Security/Windows Configuration)" -Level Config
Write-RMMLog "Start Time: $(Get-Date)" -Level Config
Write-RMMLog ""

# Process configuration
$OperationMode = Get-RMMVariable -Name "OperationMode" -Default "Downloads"
$CustomPath = Get-RMMVariable -Name "CustomPath" -Default ""
$FileExtensions = Get-RMMVariable -Name "FileExtensions" -Default "pdf,docx,xlsx,pptx,doc,xls,ppt"

# Validate operation mode
$validModes = @("Downloads", "AllUserFiles")
if ($OperationMode -notin $validModes) {
    Write-RMMLog "Invalid OperationMode: $OperationMode. Using default: Downloads" -Level Warning
    $OperationMode = "Downloads"
}

# Determine target path
if (-not [string]::IsNullOrWhiteSpace($CustomPath)) {
    $TargetPath = $CustomPath
}
else {
    $TargetPath = switch ($OperationMode) {
        "Downloads" { "$env:USERPROFILE\Downloads" }
        "AllUserFiles" { $env:USERPROFILE }
    }
}

# Parse file extensions
$ExtensionList = $FileExtensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
$FilePatterns = $ExtensionList | ForEach-Object { "*.$_" }

Write-RMMLog "Configuration:" -Level Config
Write-RMMLog "- Operation Mode: $OperationMode" -Level Config
Write-RMMLog "- Target Path: $TargetPath" -Level Config
Write-RMMLog "- File Extensions: $($ExtensionList -join ', ')" -Level Config
Write-RMMLog "- Current User: $env:USERNAME" -Level Config
Write-RMMLog "- Computer Name: $env:COMPUTERNAME" -Level Config
Write-RMMLog ""

# Validate target path
if (-not (Test-Path $TargetPath)) {
    Write-RMMLog "Target path does not exist: $TargetPath" -Level Failed
    if ($EnableLogging) { Stop-Transcript }
    exit 2
}

Write-RMMLog "Target path verified: $TargetPath" -Level Detect
Write-RMMLog ""

# Main execution
$exitCode = 0
$totalFound = 0
$totalUnblocked = 0
$totalFailed = 0
$totalSkipped = 0

try {
    Write-RMMLog "Starting bulk unblock operation..." -Level Status
    Write-RMMLog ""

    $useRecurse = ($OperationMode -eq "AllUserFiles")

    if ($OperationMode -eq "AllUserFiles") {
        Write-RMMLog "AllUserFiles mode: Scanning entire user profile recursively..." -Level Status
        Write-RMMLog "This may take several minutes depending on file count" -Level Info
        Write-RMMLog ""

        # For AllUserFiles mode, unblock ALL files (not just specific extensions)
        $results = Invoke-UnblockByPattern -TargetPath $TargetPath -Pattern "*" -Recurse $true

        $totalFound = $results.Found
        $totalUnblocked = $results.Unblocked
        $totalFailed = $results.Failed
        $totalSkipped = $results.Skipped

        Write-RMMLog "Processed all files in user profile" -Level Status
    }
    else {
        # Downloads mode: process specific file patterns
        foreach ($pattern in $FilePatterns) {
            Write-RMMLog "Processing pattern: $pattern" -Level Status

            $results = Invoke-UnblockByPattern -TargetPath $TargetPath -Pattern $pattern -Recurse $false

            $totalFound += $results.Found
            $totalUnblocked += $results.Unblocked
            $totalFailed += $results.Failed
            $totalSkipped += $results.Skipped

            if ($results.Found -gt 0) {
                Write-RMMLog "  Found: $($results.Found), Unblocked: $($results.Unblocked), Skipped: $($results.Skipped), Failed: $($results.Failed)" -Level Info
            }
        }
    }

    Write-RMMLog ""
    Write-RMMLog "=============================================="
    Write-RMMLog "Unblock Operation Summary" -Level Status
    Write-RMMLog "=============================================="
    Write-RMMLog "Total files found: $totalFound" -Level Info
    Write-RMMLog "Files unblocked: $totalUnblocked" -Level Success
    Write-RMMLog "Files skipped (no MotW): $totalSkipped" -Level Info

    if ($totalFailed -gt 0) {
        Write-RMMLog "Files failed: $totalFailed" -Level Warning
        $exitCode = 1
    }
    else {
        Write-RMMLog "Files failed: 0" -Level Info
    }

    Write-RMMLog ""

    if ($totalUnblocked -gt 0) {
        Write-RMMLog "Bulk unblock operation completed successfully" -Level Success
        Write-RMMLog "Mark of the Web removed from $totalUnblocked files" -Level Info
        Write-RMMLog "File Explorer preview should now work for these files" -Level Info
    }
    elseif ($totalFound -eq 0) {
        Write-RMMLog "No matching files found in target path" -Level Info
    }
    elseif ($totalSkipped -eq $totalFound) {
        Write-RMMLog "All files were already unblocked (no MotW present)" -Level Success
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
    Write-RMMLog "Unblock Internet Files completed" -Level Status
    Write-RMMLog "Final exit code: $exitCode" -Level Status
    Write-RMMLog "End Time: $(Get-Date)" -Level Status
    Write-RMMLog "=============================================="

    if ($EnableLogging) {
        Stop-Transcript
    }
    exit $exitCode
}
