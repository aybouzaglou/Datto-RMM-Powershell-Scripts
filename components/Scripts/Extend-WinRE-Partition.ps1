<#
.SYNOPSIS
    WinRE Partition Extension - Datto RMM Edition

.DESCRIPTION
    Extends Windows Recovery Environment (WinRE) partition by 250MB to address CVE-2024-20666.
    Microsoft KB5034441/KB5034440 requires additional WinRE partition space for the security update.

    This script:
    - Examines the current WinRE partition configuration
    - Backs up existing WinRE partition content (auto-generates backup path if not specified)
    - Shrinks the OS partition to create space
    - Extends or recreates the WinRE partition with additional 250MB
    - Re-enables WinRE after the operation

    Based on Microsoft's official script with modifications for Datto RMM deployment.

.COMPONENT
    Category=Scripts ; Level=High(5) ; Timeout=900s ; Build=1.0.0

.INPUTS
    usrBackupFolder(String) ; usrForceReboot(Boolean)

.REQUIRES
    LocalSystem ; PSVersion >=5.0 ; Windows 10/11 or Server 2019+

.OUTPUTS
    Structured RMM output with SUCCESS/FAILED/WARNING/STATUS/CONFIG/DETECT/METRIC prefixes

.EXITCODES
    0=Success ; 1=NoActionNeeded ; 2=Error ; 10=Permission ; 12=Validation

.ENVIRONMENT VARIABLES
    usrBackupFolder (String): Path to backup old WinRE partition content. If not set, auto-generates C:\WinRE-Backup-yyyyMMdd-HHmmss
    usrForceReboot (Boolean): Schedule reboot after successful completion (default: false)

.NOTES
    Version:        1.0.0
    Author:         Adapted from Microsoft script for Datto RMM
    Creation Date:  12/18/2025
    Purpose:        RMM-friendly WinRE partition extension for CVE-2024-20666 remediation

    Original Source: Microsoft - Licensed under MIT License

    IMPORTANT:
    - Reboot the device before running to ensure pending partition actions are finalized
    - This script modifies disk partitions - ensure proper backups exist
    - Test thoroughly in a lab environment before production deployment

.LINK
    https://support.microsoft.com/en-us/topic/kb5028997-instructions-to-manually-resize-your-partition-to-install-the-winre-update-400faa27-9343-461c-ada9-24c8229763bf
#>

# PSScriptAnalyzer suppressions for intentional design patterns
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification='Global counters needed for cross-function metrics tracking in RMM environment')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='Variables are used across different script sections')]

############################################################################################################
#                                    EMBEDDED FUNCTION LIBRARY                                            #
############################################################################################################

# Global counters for structured reporting
$global:SuccessCount = 0
$global:FailCount = 0
$global:WarningCount = 0

# Input variable validation helper for Datto RMM environment variables
function Get-InputVariable {
    param(
        [string]$Name,
        [ValidateSet('String','Boolean','Integer')][string]$Type='String',
        [object]$Default='',
        [switch]$Required
    )
    $val = Get-Item "env:$Name" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value
    if ([string]::IsNullOrWhiteSpace($val)) {
        if ($Required) {
            Write-Output "FAILED   Input variable '$Name' required but not supplied"
            $global:FailCount++
            throw "Input '$Name' required but not supplied"
        }
        return $Default
    }
    switch ($Type) {
        'Boolean'  { return ($val -eq 'true' -or $val -eq '1' -or $val -eq 'yes') }
        'Integer'  {
            try { return [int]$val }
            catch { return $Default }
        }
        default    { return $val }
    }
}

# Universal timeout wrapper for safe partition operations
function Invoke-WithTimeout {
    param(
        [scriptblock]$Code,
        [int]$TimeoutSec = 300,
        [string]$OperationName = "Operation"
    )
    try {
        Write-Output "STATUS   Starting: $OperationName (${TimeoutSec}s timeout)"
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

# Extract numbers from string
function ExtractNumbers([string]$str) {
    $cleanString = $str -replace "[^0-9]"
    return [long]$cleanString
}

# Get partition info using WMI
# Return an array: [total size, free space]
function Get-PartitionInfo([string[]]$partitionPath) {
    $volume = Get-WmiObject -Class Win32_Volume | Where-Object { $partitionPath -contains $_.DeviceID }
    return $volume.Capacity, $volume.FreeSpace
}

# Get WinRE status without logging (logging handled by caller)
function Get-WinREStatus {
    $WinREInfo = Reagentc /info
    $Status = $false
    $Location = ""

    foreach ($line in $WinREInfo) {
        $params = $line.Split(':')
        if ($params.Count -lt 2) { continue }

        if (($params[1].Trim() -ieq "Enabled") -Or ($params[1].Trim() -ieq "Disabled")) {
            $Status = $params[1].Trim() -ieq "Enabled"
        }
        if ($params[1].Trim() -like "\\?\GLOBALROOT*") {
            $Location = $params[1].Trim()
        }
    }

    return @{Status = $Status; Location = $Location}
}

############################################################################################################
#                                    PRE-FLIGHT VALIDATION                                                #
############################################################################################################

# Admin check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "FAILED   This script requires administrator privileges"
    $global:FailCount++
    exit 10
}

############################################################################################################
#                                    PROCESS ENVIRONMENT VARIABLES                                        #
############################################################################################################

Write-Output "STATUS   Processing Datto RMM input variables..."

# Backup folder - auto-generate if not provided
$BackupFolder = Get-InputVariable -Name "usrBackupFolder" -Type "String"
if ([string]::IsNullOrWhiteSpace($BackupFolder)) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $BackupFolder = "C:\WinRE-Backup-$timestamp"
    Write-Output "CONFIG   Auto-generated backup folder: $BackupFolder"
} else {
    Write-Output "CONFIG   User-specified backup folder: $BackupFolder"
}

# Force reboot option
$ForceReboot = Get-InputVariable -Name "usrForceReboot" -Type "Boolean" -Default $false
Write-Output "CONFIG   Force reboot after completion: $ForceReboot"

############################################################################################################
#                                    MAIN EXECUTION                                                        #
############################################################################################################

Write-Output ""
Write-Output "STATUS   Start time: $([DateTime]::Now)"
Write-Output "STATUS   Examining the system..."

$NeedShrink = $true
$NeedCreateNew = $false
$NeedBackup = $false
$exitCode = 0

# Get WinRE partition info
$WinREInfo = Get-WinREStatus
$WinREStatus = $WinREInfo.Status
$WinRELocation = $WinREInfo.Location

Write-Output "DETECT   Windows RE status: $(if ($WinREStatus) {'Enabled'} else {'Disabled'})"

# If WinRE is disabled, get location from ReAgent.xml instead
# This is common when WinRE update failed due to insufficient partition space
if (!$WinREStatus) {
    Write-Output "STATUS   WinRE is disabled - reading location from ReAgent.xml..."

    # Get System directory and ReAgent xml file
    $system32Path = [System.Environment]::SystemDirectory
    $ReAgentXmlPath = Join-Path -Path $system32Path -ChildPath "\Recovery\ReAgent.xml"

    if (Test-Path $ReAgentXmlPath) {
        try {
            [xml]$xml = Get-Content -Path $ReAgentXmlPath
            $winreGuid = $xml.WindowsRE.ImageLocation.guid
            $winreOffset = $xml.WindowsRE.ImageLocation.offset
            $winrePath = $xml.WindowsRE.ImageLocation.path

            if ($winreGuid -and $winreGuid -ne "{00000000-0000-0000-0000-000000000000}") {
                # Construct the location path similar to what reagentc /info would return
                $WinRELocation = "\\?\GLOBALROOT\device\harddisk0\partition$winreOffset$winrePath"
                Write-Output "DETECT   WinRE location from ReAgent.xml: $WinRELocation"
                Write-Output "STATUS   WinRE is disabled but partition location identified - proceeding with resize"
            } else {
                Write-Output "FAILED   WinRE location not configured in ReAgent.xml"
                Write-Output "FAILED   GUID: $winreGuid, Offset: $winreOffset"
                $global:FailCount++
                exit 2
            }
        } catch {
            Write-Output "FAILED   Error reading ReAgent.xml: $($_.Exception.Message)"
            $global:FailCount++
            exit 2
        }
    } else {
        Write-Output "FAILED   ReAgent.xml not found at: $ReAgentXmlPath"
        $global:FailCount++
        exit 2
    }
} else {
    Write-Output "DETECT   Windows RE location: $WinRELocation"
}

# Get System directory and ReAgent xml file (if not already set)
if (-not $system32Path) {
    $system32Path = [System.Environment]::SystemDirectory
}
if (-not $ReAgentXmlPath) {
    $ReAgentXmlPath = Join-Path -Path $system32Path -ChildPath "\Recovery\ReAgent.xml"
}

Write-Output "DETECT   System directory: $system32Path"
Write-Output "DETECT   ReAgent xml: $ReAgentXmlPath"

if (!(Test-Path $ReAgentXmlPath)) {
    Write-Output "FAILED   ReAgent.xml cannot be found at $ReAgentXmlPath"
    $global:FailCount++
    exit 2
}

# Get OS partition
Write-Output ""
Write-Output "STATUS   Collecting OS and WinRE partition info..."
$OSDrive = $system32Path.Substring(0,1)
$OSPartition = Get-Partition -DriveLetter $OSDrive

# Get WinRE partition
$WinRELocationItems = $WinRELocation.Split('\\')
foreach ($item in $WinRELocationItems) {
    if ($item -like "harddisk*") {
        $OSDiskIndex = ExtractNumbers($item)
    }
    if ($item -like "partition*") {
        $WinREPartitionIndex = ExtractNumbers($item)
    }
}

Write-Output "DETECT   OS Disk: $OSDiskIndex"
Write-Output "DETECT   OS Partition: $($OSPartition.PartitionNumber)"
Write-Output "DETECT   WinRE Partition: $WinREPartitionIndex"

$WinREPartition = Get-Partition -DiskNumber $OSDiskIndex -PartitionNumber $WinREPartitionIndex

$diskInfo = Get-Disk -number $OSDiskIndex
$diskType = $diskInfo.PartitionStyle
Write-Output "DETECT   Disk PartitionStyle: $diskType"

# Display WinRE partition size info
Write-Output "STATUS   WinRE partition size info:"
$WinREPartitionSizeInfo = Get-PartitionInfo($WinREPartition.AccessPaths)
Write-Output "CONFIG   Partition capacity: $($WinREPartitionSizeInfo[0])"
Write-Output "CONFIG   Partition free space: $($WinREPartitionSizeInfo[1])"
Write-Output "DETECT   WinRE Partition Offset: $($WinREPartition.Offset)"
Write-Output "DETECT   WinRE Partition Type: $($WinREPartition.Type)"
Write-Output "DETECT   OS partition size: $($OSPartition.Size)"
Write-Output "DETECT   OS partition Offset: $($OSPartition.Offset)"
$OSPartitionEnds = $OSPartition.Offset + $OSPartition.Size

Write-Output "DETECT   OS partition ends at: $OSPartitionEnds"
Write-Output "DETECT   WinRE partition starts at: $($WinREPartition.Offset)"

$WinREIsOnSystemPartition = $false
if ($diskType -ieq "MBR") {
    if ($WinREPartition.IsActive) {
        Write-Output "DETECT   WinRE is on System partition"
        $WinREIsOnSystemPartition = $true
    }
}

if ($diskType -ieq "GPT") {
    if ($WinREPartition.Type -ieq "System") {
        Write-Output "DETECT   WinRE is on System partition"
        $WinREIsOnSystemPartition = $true
    }
}

# Checking the BackupFolder
Write-Output ""
Write-Output "CONFIG   Backup Directory: [$BackupFolder]"

$NeedBackup = $true

if ($WinREIsOnSystemPartition) {
    $NeedBackup = $false
    Write-Output "STATUS   WinRE is on System partition which will be preserved. No need to backup content"
} else {
    if (Test-Path $BackupFolder) {
        $items = Get-ChildItem -Path $BackupFolder
        if ($items) {
            Write-Output "FAILED   Existing backup directory is not empty: $BackupFolder"
            $global:FailCount++
            exit 2
        }
    } else {
        Write-Output "STATUS   Creating backup directory..."
        try {
            $item = New-Item -Path $BackupFolder -ItemType Directory -ErrorAction Stop
            if ($item) {
                Write-Output "SUCCESS  Backup directory created: $BackupFolder"
                $global:SuccessCount++
            } else {
                Write-Output "FAILED   Failed to create backup directory: $BackupFolder"
                $global:FailCount++
                exit 2
            }
        } catch {
            Write-Output "FAILED   Error creating backup directory: $_"
            $global:FailCount++
            exit 2
        }
    }
}

############################################################################################################
#                                    VERIFICATION CHECKS                                                   #
############################################################################################################

Write-Output ""
Write-Output "STATUS   Verifying if the WinRE partition needs to be extended..."

if (!(($diskType -ieq "MBR") -Or ($diskType -ieq "GPT"))) {
    Write-Output "FAILED   Unexpected disk partition style: $diskType"
    $global:FailCount++
    exit 2
}

# WinRE partition must be after OS partition for the repartition
if ($WinREPartitionIndex -eq $OSPartition.PartitionNumber) {
    Write-Output "STATUS   WinRE and OS are on the same partition - no extension needed"
    $global:SuccessCount++
    exit 1
}

$supportedSize = Get-PartitionSupportedSize -DriveLetter $OSDrive

# If there is enough free space, skip extension
if ($WinREPartitionSizeInfo[1] -ge 250MB) {
    Write-Output "SUCCESS  WinRE partition already has >=250MB free space ($($WinREPartitionSizeInfo[1]) bytes) - no extension needed"
    $global:SuccessCount++
    exit 1
}

if ($WinREPartition.Offset -lt $OSPartitionEnds) {
    Write-Output "STATUS   WinRE partition is before OS partition - need to create new WinRE partition after OS"
    $NeedCreateNew = $true
    $NeedShrink = $true

    # Calculate the size of repartition
    $targetWinREPartitionSize = $WinREPartitionSizeInfo[0] + 250MB
    $shrinkSize = [Math]::Ceiling($targetWinREPartitionSize / 1MB) * 1MB
    $targetOSPartitionSize = $OSPartition.Size - $shrinkSize

    if ($targetOSPartitionSize -lt $supportedSize.SizeMin) {
        Write-Output "FAILED   Target OS partition size after shrinking would be smaller than supported minimum"
        $global:FailCount++
        exit 2
    }
} else {
    if ($WinREIsOnSystemPartition) {
        Write-Output "FAILED   WinRE partition is after OS partition but is also System partition - unexpected layout"
        $global:FailCount++
        exit 2
    }

    if (!($WinREPartitionIndex -eq ($OSPartition.PartitionNumber + 1))) {
        Write-Output "FAILED   WinRE partition is not immediately after OS partition - cannot extend"
        $global:FailCount++
        exit 2
    }

    # Calculate the size of repartition
    $shrinkSize = 250MB
    $targetOSPartitionSize = $OSPartition.Size - $shrinkSize
    $targetWinREPartitionSize = $WinREPartitionSizeInfo[0] + 250MB

    $UnallocatedSpace = $WinREPartition.Offset - $OSPartitionEnds

    # If there is unallocated space, consider using it
    if ($UnallocatedSpace -ge 250MB) {
        Write-Output "DETECT   Found unallocated space between OS and WinRE partition: $UnallocatedSpace"
        Write-Output "STATUS   Using unallocated space - no need to shrink OS partition"
        $NeedShrink = $false
        $targetOSPartitionSize = 0
    } else {
        $shrinkSize = [Math]::Ceiling((250MB - $UnallocatedSpace) / 1MB) * 1MB
        if ($shrinkSize -gt 250MB) {
            $shrinkSize = 250MB
        }
        $targetOSPartitionSize = $OSPartition.Size - $shrinkSize

        if ($targetOSPartitionSize -lt $supportedSize.SizeMin) {
            Write-Output "FAILED   Target OS partition size after shrinking would be smaller than supported minimum"
            $global:FailCount++
            exit 2
        }
    }
}

############################################################################################################
#                                    REPORT EXECUTION PLAN                                                 #
############################################################################################################

Write-Output ""
Write-Output "STATUS   Summary of proposed changes:"

if ($NeedCreateNew) {
    Write-Output "CONFIG   Note: WinRE partition is before OS partition - will create new WinRE partition after OS"
    Write-Output "CONFIG   Will shrink OS partition by $shrinkSize"
    Write-Output "CONFIG   Current OS partition size: $($OSPartition.Size)"
    Write-Output "CONFIG   Target OS partition size after shrinking: $targetOSPartitionSize"
    Write-Output "CONFIG   New WinRE partition size: $targetWinREPartitionSize"

    if ($WinREIsOnSystemPartition) {
        Write-Output "CONFIG   Existing WinRE partition is System partition - will be preserved"
    } else {
        Write-Output "CONFIG   Existing WinRE partition will be deleted"
        Write-Output "CONFIG   WinRE partition: Disk [$OSDiskIndex] Partition [$WinREPartitionIndex]"
        Write-Output "CONFIG   Current WinRE partition size: $($WinREPartitionSizeInfo[0])"
    }
} else {
    if ($NeedShrink) {
        Write-Output "CONFIG   Will shrink OS partition by $shrinkSize"
        Write-Output "CONFIG   Current OS partition size: $($OSPartition.Size)"
        Write-Output "CONFIG   Target OS partition size after shrinking: $targetOSPartitionSize"
        if ($UnallocatedSpace -ge 0) {
            Write-Output "CONFIG   Unallocated space to use: $UnallocatedSpace"
        }
    } else {
        Write-Output "CONFIG   Will use 250MB from unallocated space between OS and WinRE partition"
    }

    Write-Output "CONFIG   Will extend WinRE partition by 250MB"
    Write-Output "CONFIG   WinRE partition: Disk [$OSDiskIndex] Partition [$WinREPartitionIndex]"
    Write-Output "CONFIG   Current WinRE partition size: $($WinREPartitionSizeInfo[0])"
    Write-Output "CONFIG   Target WinRE partition size: $targetWinREPartitionSize"
    Write-Output "STATUS   WinRE will be temporarily disabled during partition operations"

    if ($UnallocatedSpace -ge 100MB) {
        Write-Output "WARNING  More than 100MB of unallocated space detected between OS and WinRE partitions"
        $global:WarningCount++
    }
}

if ($NeedBackup) {
    Write-Output ""
    Write-Output "CONFIG   WinRE partition contents will be backed up to: $BackupFolder"
}

Write-Output ""
Write-Output "STATUS   Note: Please ensure the device was rebooted before running this script"
Write-Output "STATUS   Proceeding with partition operations..."
Write-Output ""
Write-Output "WARNING  Do not interrupt execution or restart the system during this operation"
$global:WarningCount++

############################################################################################################
#                                    EXECUTE PARTITION OPERATIONS                                          #
############################################################################################################

Write-Output ""

# Load ReAgent.xml to clear Stage location
Write-Output "STATUS   Loading ReAgent.xml: $ReAgentXmlPath"
$xml = [xml](Get-Content -Path $ReAgentXmlPath)
$node = $xml.WindowsRE.ImageLocation

if (($node.path -eq "") -And ($node.guid -eq "{00000000-0000-0000-0000-000000000000}") -And ($node.offset -eq "0") -And ($node.id -eq "0")) {
    Write-Output "STATUS   Stage location info is empty"
} else {
    Write-Output "STATUS   Clearing stage location info..."
    $node.path = ""
    $node.offset = "0"
    $node.guid = "{00000000-0000-0000-0000-000000000000}"
    $node.id = "0"

    Write-Output "STATUS   Saving changes to ReAgent.xml..."
    $xml.Save($ReAgentXmlPath)
    Write-Output "SUCCESS  ReAgent.xml updated"
    $global:SuccessCount++
}

# Disable WinRE
Write-Output "STATUS   Disabling WinRE..."
reagentc /disable
if (!($LASTEXITCODE -eq 0)) {
    Write-Output "FAILED   Error disabling WinRE: exit code $LASTEXITCODE"
    $global:FailCount++
    exit 2
}
Write-Output "SUCCESS  WinRE disabled"
$global:SuccessCount++

# Verify WinRE.wim exists in expected location
$disableWinREPath = Join-Path -Path $system32Path -ChildPath "\Recovery\WinRE.wim"
Write-Output "STATUS   Verifying WinRE.wim exists at default location..."

if (!(Test-Path $disableWinREPath)) {
    Write-Output "FAILED   Cannot find WinRE.wim at: $disableWinREPath"
    $global:FailCount++

    # Re-enable WinRE
    Write-Output "STATUS   Re-enabling WinRE after error..."
    reagentc /enable
    if (!($LASTEXITCODE -eq 0)) {
        Write-Output "WARNING  Error re-enabling WinRE: exit code $LASTEXITCODE"
        $global:WarningCount++
    }
    exit 2
}

############################################################################################################
#                                    PERFORM REPARTITION                                                   #
############################################################################################################

Write-Output "STATUS   Performing repartition to extend WinRE partition..."

# 1. Resize the OS partition
if ($NeedShrink) {
    Write-Output "STATUS   Shrinking OS partition to create space for WinRE..."
    Write-Output "STATUS   Target OS partition size: $targetOSPartitionSize"

    try {
        Resize-Partition -DriveLetter $OSDrive -Size $targetOSPartitionSize -ErrorAction Stop
        Write-Output "SUCCESS  OS partition resized successfully"
        $global:SuccessCount++

        $OSPartitionAfterShrink = Get-Partition -DriveLetter $OSDrive
        Write-Output "DETECT   OS partition size after shrink: $($OSPartitionAfterShrink.Size)"
    } catch {
        Write-Output "FAILED   Error resizing OS partition: $($_.Exception.Message)"
        $global:FailCount++

        # Re-enable WinRE
        Write-Output "STATUS   Re-enabling WinRE after error..."
        reagentc /enable
        if (!($LASTEXITCODE -eq 0)) {
            Write-Output "WARNING  Error re-enabling WinRE: exit code $LASTEXITCODE"
            $global:WarningCount++
        }
        exit 2
    }
}

# 2. Delete the WinRE partition
Write-Output ""

if ($WinREIsOnSystemPartition) {
    Write-Output "STATUS   Existing WinRE partition is System partition - skipping deletion"
} else {
    # Backup content if requested
    if ($NeedBackup) {
        $sourcePath = $WinREPartition.AccessPaths[0]
        Write-Output "STATUS   Backing up WinRE partition content from [$sourcePath] to [$BackupFolder]..."

        $items = Get-ChildItem -LiteralPath $sourcePath -Force
        foreach ($item in $items) {
            if ($item.Name -ieq "System Volume Information") { continue }

            $sourceItemPath = Join-Path -Path $sourcePath -ChildPath $item.Name
            $destItemPath = Join-Path -Path $BackupFolder -ChildPath $item.Name

            try {
                Write-Output "STATUS   Copying: $($item.Name)"
                Copy-Item -LiteralPath $sourceItemPath -Destination $destItemPath -Recurse -Force
            } catch {
                Write-Output "FAILED   Error during backup copy: $_"
                $global:FailCount++
                exit 2
            }
        }

        Write-Output "SUCCESS  Backup completed"
        $global:SuccessCount++
        Write-Output ""
    }

    Write-Output "STATUS   Deleting WinRE partition: Disk [$OSDiskIndex] Partition [$WinREPartitionIndex]..."

    try {
        Remove-Partition -DiskNumber $OSDiskIndex -PartitionNumber $WinREPartitionIndex -Confirm:$false -ErrorAction Stop
        Write-Output "SUCCESS  WinRE partition deleted"
        $global:SuccessCount++
    } catch {
        Write-Output "FAILED   Error deleting WinRE partition: $($_.Exception.Message)"
        $global:FailCount++
        exit 2
    }
}

# Short sleep for partition change to complete
Start-Sleep -Seconds 5

# 3. Create a new WinRE partition
Write-Output ""
Write-Output "STATUS   Creating new WinRE partition..."
Write-Output "CONFIG   Target size: $targetWinREPartitionSize"

if ($diskType -ieq "GPT") {
    try {
        $partition = New-Partition -DiskNumber $OSDiskIndex -Size $targetWinREPartitionSize -GptType "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}" -ErrorAction Stop
        $newPartitionIndex = $partition.PartitionNumber
        Write-Output "SUCCESS  GPT partition created: Partition [$newPartitionIndex]"
        $global:SuccessCount++

        # Short sleep before formatting
        Start-Sleep -Seconds 2

        Write-Output "STATUS   Formatting new partition as NTFS..."
        $result = Format-Volume -Partition $partition -FileSystem NTFS -Confirm:$false -ErrorAction Stop
        Write-Output "SUCCESS  Partition formatted successfully"
        $global:SuccessCount++
    } catch {
        Write-Output "FAILED   Error creating/formatting GPT partition: $($_.Exception.Message)"
        $global:FailCount++
        exit 2
    }
} else {
    # MBR disk - use diskpart
    $targetWinREPartitionSizeInMb = [int]($targetWinREPartitionSize / 1MB)
    $diskpartScript = @"
select disk $OSDiskIndex
create partition primary size=$targetWinREPartitionSizeInMb id=27
format quick fs=ntfs label="Recovery"
set id=27
"@

    $TempPath = $env:Temp
    $diskpartScriptFile = Join-Path -Path $TempPath -ChildPath "ExtendWinRE_MBR_Script.txt"

    Write-Output "STATUS   Creating diskpart script for MBR disk..."
    $diskpartScript | Out-File -FilePath $diskpartScriptFile -Encoding ascii

    Write-Output "STATUS   Executing diskpart script..."
    try {
        $diskpartOutput = diskpart /s $diskpartScriptFile

        if ($diskpartOutput -match "DiskPart successfully") {
            Write-Output "SUCCESS  Diskpart script executed successfully"
            $global:SuccessCount++
        } else {
            Write-Output "FAILED   Diskpart script failed: $diskpartOutput"
            $global:FailCount++
            exit 2
        }

        Write-Output "STATUS   Cleaning up temporary diskpart script..."
        Remove-Item $diskpartScriptFile -ErrorAction SilentlyContinue
    } catch {
        Write-Output "FAILED   Error executing diskpart: $_"
        $global:FailCount++
        exit 2
    }

    $vol = Get-Volume -FileSystemLabel "Recovery"
    $newPartitionIndex = (Get-Partition | Where-Object { $_.AccessPaths -contains $vol.Path }).PartitionNumber
}

Write-Output "DETECT   New partition index: $newPartitionIndex"

# Re-enable WinRE
Write-Output "STATUS   Re-enabling WinRE..."
reagentc /enable
if (!($LASTEXITCODE -eq 0)) {
    Write-Output "WARNING  Error re-enabling WinRE: exit code $LASTEXITCODE"
    $global:WarningCount++
    $exitCode = 2
} else {
    Write-Output "SUCCESS  WinRE re-enabled"
    $global:SuccessCount++
}

############################################################################################################
#                                    FINAL STATUS                                                          #
############################################################################################################

Write-Output ""
Write-Output "STATUS   WinRE Information (Final):"
$FinalWinREInfo = Get-WinREStatus
$WinREStatus = $FinalWinREInfo.Status
$WinRELocation = $FinalWinREInfo.Location

Write-Output "DETECT   Windows RE status: $(if ($WinREStatus) {'Enabled'} else {'Disabled'})"
if ($WinRELocation) {
    Write-Output "DETECT   Windows RE location: $WinRELocation"
}

if (!$WinREStatus) {
    Write-Output "WARNING  WinRE is disabled after operation"
    $global:WarningCount++
}

$WinRELocationItems = $WinRELocation.Split('\\')
foreach ($item in $WinRELocationItems) {
    if ($item -like "partition*") {
        $WinREPartitionIndex = ExtractNumbers($item)
    }
}
Write-Output "DETECT   WinRE Partition Index: $WinREPartitionIndex"

$WinREPartition = Get-Partition -DiskNumber $OSDiskIndex -PartitionNumber $WinREPartitionIndex
$WinREPartitionSizeInfoAfter = Get-PartitionInfo($WinREPartition.AccessPaths)
Write-Output "CONFIG   Final WinRE partition capacity: $($WinREPartitionSizeInfoAfter[0])"
Write-Output "CONFIG   Final WinRE partition free space: $($WinREPartitionSizeInfoAfter[1])"

Write-Output ""
Write-Output "STATUS   OS Information (Final):"
$OSPartition = Get-Partition -DriveLetter $OSDrive
Write-Output "DETECT   OS partition size: $($OSPartition.Size)"
Write-Output "DETECT   OS partition Offset: $($OSPartition.Offset)"

if (!($WinREPartitionIndex -eq $newPartitionIndex)) {
    Write-Output "WARNING  WinRE installed to partition [$WinREPartitionIndex], but newly created partition is [$newPartitionIndex]"
    $global:WarningCount++
}

if ($NeedBackup) {
    Write-Output ""
    Write-Output "CONFIG   WinRE partition backup location: $BackupFolder"
}

############################################################################################################
#                                    OPTIONAL REBOOT                                                       #
############################################################################################################

if ($ForceReboot -and $exitCode -eq 0) {
    Write-Output ""
    Write-Output "STATUS   Scheduling system reboot in 60 seconds..."
    shutdown /r /t 60 /c "WinRE partition extended successfully - reboot scheduled by Datto RMM"
}

############################################################################################################
#                                    EXECUTION SUMMARY                                                     #
############################################################################################################

Write-Output ""
Write-Output "METRIC   Execution Summary - Success: $global:SuccessCount, Failed: $global:FailCount, Warnings: $global:WarningCount"
Write-Output "STATUS   End time: $([DateTime]::Now)"

if ($global:FailCount -gt 0) {
    Write-Output "FAILED   Operation completed with errors"
    exit 2
} elseif ($global:WarningCount -gt 0) {
    Write-Output "WARNING  Operation completed with warnings"
    exit 0
} else {
    Write-Output "SUCCESS  WinRE partition extended successfully"
    exit 0
}