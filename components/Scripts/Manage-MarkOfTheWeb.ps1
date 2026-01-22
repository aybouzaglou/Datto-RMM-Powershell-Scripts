<#
.SYNOPSIS
    Manage Mark of the Web (MotW) - Consolidated policy and file unblock operations

.DESCRIPTION
    Consolidated Datto RMM component that handles Mark of the Web (MotW) management for Windows.
    Combines policy configuration and file unblocking into a single script with input variables.
    
    This script addresses File Explorer preview issues caused by MotW tagging on internet downloads.
    It can both prevent future MotW tagging via registry policy and remove existing MotW tags from files.
    
    Features:
    - Enable "Do Not Preserve Zone Information" policy to prevent MotW on NEW downloads
    - Unblock existing files with flexible scope (Downloads folder or entire user profile)
    - Configurable file patterns for targeted unblocking
    - Support for custom path targeting
    - Comprehensive logging and verification
    - User context execution support

.COMPONENT
    Category: Scripts (General Automation/Maintenance)
    Execution: On-demand or scheduled
    Timeout: 15 minutes recommended (longer for full profile scans)
    Run Context: User (recommended for HKCU registry access and user file access)

.ENVIRONMENT VARIABLES
    - EnablePolicy (String): Enable registry policy to prevent MotW on new downloads (default: "true")
      Values: "true" or "false"
      
    - UnblockFiles (String): Remove MotW from existing files (default: "true")
      Values: "true" or "false"
      
    - UnblockScope (String): Scope for file unblocking (default: "Downloads")
      Values: "Downloads" (Downloads folder only) or "UserProfile" (entire user profile with recursion)
      Note: UserProfile scope can be time-consuming for large profiles
      
    - FilePatterns (String): Comma-separated file patterns to unblock (default: "*.pdf,*.docx,*.xlsx,*.pptx,*.doc,*.xls")
      Examples: "*.pdf,*.docx" or "*.pdf,*.doc,*.xls,*.xlsx,*.pptx"
      
    - CustomPath (String): Optional custom path for unblocking (overrides UnblockScope)
      Examples: "C:\Users\Public\Documents" or "$env:USERPROFILE\Desktop"

.EXAMPLES
    Scenario 1 - Enable policy only (prevent future MotW tagging):
    EnablePolicy = true
    UnblockFiles = false
    
    Scenario 2 - Unblock Downloads folder only:
    EnablePolicy = false
    UnblockFiles = true
    UnblockScope = Downloads
    FilePatterns = *.pdf,*.docx,*.xlsx
    
    Scenario 3 - Full remediation (policy + unblock):
    EnablePolicy = true
    UnblockFiles = true
    UnblockScope = Downloads
    
    Scenario 4 - Custom path with specific patterns:
    EnablePolicy = false
    UnblockFiles = true
    CustomPath = C:\SharedDocs
    FilePatterns = *.pdf,*.doc

.NOTES
    Version:        1.0.0
    Author:         Datto RMM Script
    Compatible:     PowerShell 5.0+, Windows 10 1703+, Windows 11
    Deployment:     Direct to Datto RMM
    
    Exit Codes:
    0 = Success (all enabled operations completed successfully)
    1 = Failure (one or more enabled operations failed)
    2 = Configuration error (invalid input variables)
    
    Performance:
    - Policy enable: <1 minute
    - Unblock Downloads: 2-3 minutes for ~500 files
    - Unblock UserProfile: Varies by file count (can be 10+ minutes)
#>

# Datto RMM copies any files attached to this component into the script's working directory.
# Reference attachments by filename; see docs/Datto-RMM-File-Attachment-Guide.md for details.

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
        'Failed' { 'FAILED  ' }
        'Error' { 'ERROR   ' }
        'Warning' { 'WARNING ' }
        'Status' { 'STATUS  ' }
        'Config' { 'CONFIG  ' }
        'Detect' { 'DETECT  ' }
        default { 'INFO    ' }
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] $prefix$Message"
    Write-Output $logMessage
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

############################################################################################################
#                                    OPERATION FUNCTIONS                                                   #
############################################################################################################

function Enable-MotWPolicy {
    <#
    .SYNOPSIS
        Enable "Do Not Preserve Zone Information" policy for the current user
    .DESCRIPTION
        Sets SaveZoneInformation=1 in HKCU to prevent MotW tagging on new downloads
    #>
    
    Write-RMMLog "=============================================="
    Write-RMMLog "Operation: Enable MotW Policy" -Level Status
    Write-RMMLog "=============================================="
    
    $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments"
    $RegName = "SaveZoneInformation"
    $RegValue = 1
    
    try {
        # Create registry path if doesn't exist
        if (!(Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force -ErrorAction Stop | Out-Null
            Write-RMMLog "Created registry path: $RegPath" -Level Info
        }

        # Set the policy
        Set-ItemProperty -Path $RegPath -Name $RegName -Value $RegValue -Type DWord -Force
        Write-RMMLog "Policy enabled: SaveZoneInformation = 1" -Level Success

        # Verify setting applied
        $CurrentValue = (Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction SilentlyContinue).SaveZoneInformation
        
        if ($CurrentValue -eq 1) {
            Write-RMMLog "Policy successfully verified" -Level Success
            Write-RMMLog "New downloads will no longer be tagged with Mark of the Web" -Level Info
            return $true
        } else {
            Write-RMMLog "Policy verification failed - current value: $CurrentValue" -Level Error
            return $false
        }
    }
    catch {
        Write-RMMLog "Policy enable failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Unblock-MotWFiles {
    <#
    .SYNOPSIS
        Remove Mark of the Web from existing files
    .DESCRIPTION
        Unblocks files based on scope (Downloads/UserProfile/Custom) and file patterns
    #>
    param(
        [string]$Scope,
        [string[]]$Patterns,
        [string]$CustomPath
    )
    
    Write-RMMLog "=============================================="
    Write-RMMLog "Operation: Unblock Files" -Level Status
    Write-RMMLog "=============================================="
    
    # Determine target path
    $TargetPath = $null
    if (![string]::IsNullOrWhiteSpace($CustomPath)) {
        # Expand environment variables in custom path
        $TargetPath = [Environment]::ExpandEnvironmentVariables($CustomPath)
        Write-RMMLog "Using custom path: $TargetPath" -Level Config
    }
    elseif ($Scope -eq "UserProfile") {
        $TargetPath = $env:USERPROFILE
        Write-RMMLog "Using user profile: $TargetPath" -Level Config
    }
    else {
        # Default to Downloads
        $TargetPath = "$env:USERPROFILE\Downloads"
        Write-RMMLog "Using Downloads folder: $TargetPath" -Level Config
    }
    
    # Validate target path exists
    if (!(Test-Path $TargetPath)) {
        Write-RMMLog "Target path does not exist: $TargetPath" -Level Error
        return $false
    }
    
    Write-RMMLog "File patterns: $($Patterns -join ', ')" -Level Config
    
    # Performance warning for full profile scan
    if ($Scope -eq "UserProfile" -or (![string]::IsNullOrWhiteSpace($CustomPath) -and $TargetPath -eq $env:USERPROFILE)) {
        Write-RMMLog "WARNING: Full profile scan may take several minutes" -Level Warning
        Write-RMMLog "This operation will recursively scan all subdirectories" -Level Warning
    }
    
    try {
        $TotalUnblocked = 0
        $RecurseOption = @{}
        
        # Add -Recurse for UserProfile scope or when CustomPath matches USERPROFILE
        if ($Scope -eq "UserProfile" -or (![string]::IsNullOrWhiteSpace($CustomPath) -and $TargetPath -eq $env:USERPROFILE)) {
            $RecurseOption['Recurse'] = $true
            Write-RMMLog "Recursive scan enabled" -Level Info
        }
        
        # For Downloads or other scopes, use patterns
        # For UserProfile, unblock all files (ignore patterns)
        if ($Scope -eq "UserProfile" -or (![string]::IsNullOrWhiteSpace($CustomPath) -and $TargetPath -eq $env:USERPROFILE)) {
            Write-RMMLog "Starting bulk unblock operation (all files)..." -Level Status
            
            # Get all files recursively and unblock
            $Files = Get-ChildItem -Path $TargetPath -File -Recurse -ErrorAction SilentlyContinue | 
                Where-Object { Test-Path $_.FullName -PathType Leaf }
            
            if ($Files) {
                $FileCount = @($Files).Count
                Write-RMMLog "Found $FileCount files to process" -Level Info
                
                $Files | Unblock-File -ErrorAction SilentlyContinue
                $TotalUnblocked = $FileCount
                Write-RMMLog "Processed $FileCount files" -Level Success
            }
            else {
                Write-RMMLog "No files found to unblock" -Level Warning
            }
        }
        else {
            # Pattern-based unblocking for Downloads or custom paths
            Write-RMMLog "Starting pattern-based unblock operation..." -Level Status
            
            foreach ($Pattern in $Patterns) {
                $Pattern = $Pattern.Trim()
                Write-RMMLog "Processing pattern: $Pattern" -Level Info
                
                $Files = Get-ChildItem -Path $TargetPath -Filter $Pattern -File @RecurseOption -ErrorAction SilentlyContinue
                
                if ($Files) {
                    $FileCount = @($Files).Count
                    $Files | Unblock-File -ErrorAction SilentlyContinue
                    $TotalUnblocked += $FileCount
                    Write-RMMLog "Unblocked $FileCount $Pattern files" -Level Success
                }
                else {
                    Write-RMMLog "No $Pattern files found" -Level Info
                }
            }
        }
        
        Write-RMMLog "=============================================="
        Write-RMMLog "Unblock operation completed" -Level Success
        Write-RMMLog "Total files unblocked: $TotalUnblocked" -Level Success
        Write-RMMLog "Target path: $TargetPath" -Level Info
        Write-RMMLog "=============================================="
        
        return $true
    }
    catch {
        Write-RMMLog "Unblock operation failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

############################################################################################################
#                                    MAIN SCRIPT LOGIC                                                    #
############################################################################################################

$ErrorActionPreference = "Stop"

# Script header
Write-RMMLog "=============================================="
Write-RMMLog "Mark of the Web (MotW) Management Script" -Level Status
Write-RMMLog "Version: 1.0.0" -Level Status
Write-RMMLog "=============================================="
Write-RMMLog "Component Category: Scripts" -Level Config
Write-RMMLog "Start Time: $(Get-Date)" -Level Config
Write-RMMLog "User Context: $env:USERNAME" -Level Config
Write-RMMLog ""

# Process environment variables
$EnablePolicy = Get-RMMVariable -Name "EnablePolicy" -Type "Boolean" -Default $true
$UnblockFiles = Get-RMMVariable -Name "UnblockFiles" -Type "Boolean" -Default $true
$UnblockScope = Get-RMMVariable -Name "UnblockScope" -Default "Downloads"
$FilePatterns = Get-RMMVariable -Name "FilePatterns" -Default "*.pdf,*.docx,*.xlsx,*.pptx,*.doc,*.xls"
$CustomPath = Get-RMMVariable -Name "CustomPath" -Default ""

Write-RMMLog "Configuration:" -Level Config
Write-RMMLog "- Enable Policy: $EnablePolicy" -Level Config
Write-RMMLog "- Unblock Files: $UnblockFiles" -Level Config
Write-RMMLog "- Unblock Scope: $UnblockScope" -Level Config
Write-RMMLog "- File Patterns: $FilePatterns" -Level Config
if (![string]::IsNullOrWhiteSpace($CustomPath)) {
    Write-RMMLog "- Custom Path: $CustomPath" -Level Config
}
Write-RMMLog ""

# Validate configuration
if (!$EnablePolicy -and !$UnblockFiles) {
    Write-RMMLog "Configuration error: Both EnablePolicy and UnblockFiles are disabled" -Level Error
    Write-RMMLog "At least one operation must be enabled" -Level Error
    exit 2
}

# Validate UnblockScope
if ($UnblockFiles -and [string]::IsNullOrWhiteSpace($CustomPath)) {
    if ($UnblockScope -notin @("Downloads", "UserProfile")) {
        Write-RMMLog "Configuration error: Invalid UnblockScope '$UnblockScope'" -Level Error
        Write-RMMLog "Valid values: 'Downloads' or 'UserProfile'" -Level Error
        exit 2
    }
}

# Parse file patterns
$PatternArray = @()
if ($UnblockFiles -and $UnblockScope -ne "UserProfile") {
    $PatternArray = $FilePatterns.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($PatternArray.Count -eq 0) {
        Write-RMMLog "Configuration error: FilePatterns is empty" -Level Error
        exit 2
    }
}

# Main execution
$exitCode = 0
$PolicySuccess = $true
$UnblockSuccess = $true

try {
    # Operation 1: Enable Policy
    if ($EnablePolicy) {
        Write-RMMLog "Executing: Enable MotW Policy" -Level Status
        $PolicySuccess = Enable-MotWPolicy
        
        if (!$PolicySuccess) {
            Write-RMMLog "Policy operation failed" -Level Error
            $exitCode = 1
        }
        Write-RMMLog ""
    }
    else {
        Write-RMMLog "Skipping: Enable MotW Policy (disabled)" -Level Info
        Write-RMMLog ""
    }
    
    # Operation 2: Unblock Files
    if ($UnblockFiles) {
        Write-RMMLog "Executing: Unblock Files" -Level Status
        $UnblockSuccess = Unblock-MotWFiles -Scope $UnblockScope -Patterns $PatternArray -CustomPath $CustomPath
        
        if (!$UnblockSuccess) {
            Write-RMMLog "Unblock operation failed" -Level Error
            $exitCode = 1
        }
        Write-RMMLog ""
    }
    else {
        Write-RMMLog "Skipping: Unblock Files (disabled)" -Level Info
        Write-RMMLog ""
    }
    
}
catch {
    Write-RMMLog "Unexpected error during execution: $($_.Exception.Message)" -Level Error
    Write-RMMLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    $exitCode = 1
}
finally {
    # Final summary
    Write-RMMLog "=============================================="
    Write-RMMLog "Execution Summary" -Level Status
    Write-RMMLog "=============================================="
    
    if ($EnablePolicy) {
        $policyStatus = if ($PolicySuccess) { "SUCCESS" } else { "FAILED" }
        Write-RMMLog "Policy Enable: $policyStatus" -Level $(if ($PolicySuccess) { "Success" } else { "Error" })
    }
    
    if ($UnblockFiles) {
        $unblockStatus = if ($UnblockSuccess) { "SUCCESS" } else { "FAILED" }
        Write-RMMLog "File Unblock: $unblockStatus" -Level $(if ($UnblockSuccess) { "Success" } else { "Error" })
    }
    
    Write-RMMLog ""
    Write-RMMLog "Final exit code: $exitCode" -Level Status
    Write-RMMLog "End Time: $(Get-Date)" -Level Status
    Write-RMMLog "=============================================="
    
    exit $exitCode
}
