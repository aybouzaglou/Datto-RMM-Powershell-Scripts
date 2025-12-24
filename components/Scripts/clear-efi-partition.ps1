<#
.SYNOPSIS
    Clear EFI System Partition - Free space for Windows 11 updates

.DESCRIPTION
    Frees up space on the EFI System Partition (ESP) by removing:
    - Unused font files from EFI\Microsoft\Boot\Fonts
    - Update capsule files from EFI\Microsoft\Boot\UpdateCapsule


.COMPONENT
    Category=Scripts ; Level=Medium(3) ; Timeout=300s ; Build=1.0.0

.INPUTS
    usrDriveLetter(String) ; usrSkipFonts(Boolean) ; usrSkipCapsules(Boolean) ; usrRebootAfter(Boolean)

.REQUIRES
    LocalSystem ; PSVersion >=5.0 ; Windows 10/11 UEFI systems

.OUTPUTS
    Structured RMM output with SUCCESS/FAILED/WARNING/STATUS prefixes

.EXITCODES
    0=Success ; 1=NoActionNeeded ; 2=Error ; 10=Permission

.ENVIRONMENT VARIABLES
    usrDriveLetter (String): Drive letter to mount ESP (default: Y)
    usrSkipFonts (Boolean): Skip font deletion (default: false)
    usrSkipCapsules (Boolean): Skip capsule deletion (default: false)
    usrRebootAfter (Boolean): Reboot system after completion (default: false)

.NOTES
    Version:        1.0.0
    Author:         Abraham Bouzaglou 
    Creation Date:  12/18/2025
    Purpose:        Free ESP space for Windows Update compatibility
#>

$script:SuccessCount = 0
$script:FailCount = 0
$script:WarningCount = 0
$script:BytesFreed = 0

############################################################################################################
#                                    HELPER FUNCTIONS                                                      #
############################################################################################################

function Get-InputVariable {
    param(
        [string]$Name,
        [ValidateSet('String', 'Boolean', 'Integer')][string]$Type = 'String',
        [object]$Default = '',
        [switch]$Required
    )
    $val = Get-Item "env:$Name" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value
    if ([string]::IsNullOrWhiteSpace($val)) {
        if ($Required) {
            Write-Output "FAILED   Input variable '$Name' required but not supplied"
            $script:FailCount++
            throw "Input '$Name' required but not supplied"
        }
        return $Default
    }
    switch ($Type) {
        'Boolean' { return ($val -eq 'true' -or $val -eq '1' -or $val -eq 'yes') }
        'Integer' { try { return [int]$val } catch { return $Default } }
        default { return $val }
    }
}

function Get-FolderSize {
    param([string]$Path)
    if (Test-Path $Path) {
        $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [long]$size
    }
    return 0
}

function Remove-FilesInFolder {
    param(
        [string]$Path,
        [string]$Filter = "*",
        [string]$Description
    )

    if (-not (Test-Path $Path)) {
        Write-Output "STATUS   $Description folder not found: $Path"
        return $false
    }

    $files = Get-ChildItem -Path $Path -Filter $Filter -File -Force -ErrorAction SilentlyContinue
    $fileCount = ($files | Measure-Object).Count

    if ($fileCount -eq 0) {
        Write-Output "STATUS   No files to remove in $Description"
        return $true
    }

    $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
    Write-Output "DETECT   Found $fileCount files in $Description ($([math]::Round($totalSize/1KB, 2)) KB)"

    $removedCount = 0
    $removedSize = 0

    foreach ($file in $files) {
        try {
            $fileSize = $file.Length
            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            $removedCount++
            $removedSize += $fileSize
            $script:BytesFreed += $fileSize
        }
        catch {
            Write-Output "WARNING  Could not remove: $($file.Name) - $($_.Exception.Message)"
            $script:WarningCount++
        }
    }

    if ($removedCount -gt 0) {
        Write-Output "SUCCESS  Removed $removedCount files from $Description ($([math]::Round($removedSize/1KB, 2)) KB freed)"
        $script:SuccessCount++
    }

    return $true
}

############################################################################################################
#                                    PRE-FLIGHT VALIDATION                                                #
############################################################################################################

# Admin check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "FAILED   This script requires administrator privileges"
    exit 10
}

# UEFI check
$firmware = $null
try {
    $firmware = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' -ErrorAction SilentlyContinue
}
catch {
    # Non-critical failure, system might not have the path
    $null = $_
}

$isUEFI = $false
try {
    # Alternative UEFI detection via bcdedit
    $bcdeditOutput = bcdedit /enum firmware 2>&1
    if ($bcdeditOutput -notmatch "error") {
        $isUEFI = $true
    }
}
catch {
    # Alternative detection failed
    $null = $_
}

if (-not $isUEFI -and $null -eq $firmware) {
    # Final check using Win32_DiskPartition
    $espPartition = Get-CimInstance -Query "SELECT * FROM Win32_DiskPartition WHERE Type LIKE '%EFI%'" -ErrorAction SilentlyContinue
    if ($null -eq $espPartition) {
        Write-Output "WARNING  This system may not be UEFI-based or has no EFI System Partition"
        Write-Output "STATUS   Proceeding anyway - mountvol will fail if ESP doesn't exist"
        $script:WarningCount++
    }
}

############################################################################################################
#                                    PROCESS ENVIRONMENT VARIABLES                                        #
############################################################################################################

Write-Output "STATUS   Processing input variables..."

$DriveLetter = Get-InputVariable -Name "usrDriveLetter" -Type "String" -Default "Y"
$SkipFonts = Get-InputVariable -Name "usrSkipFonts" -Type "Boolean" -Default $false
$SkipCapsules = Get-InputVariable -Name "usrSkipCapsules" -Type "Boolean" -Default $false
$RebootAfter = Get-InputVariable -Name "usrRebootAfter" -Type "Boolean" -Default $false

# Validate drive letter (single letter only)
$DriveLetter = $DriveLetter.Trim().ToUpper()
if ($DriveLetter.Length -gt 1) {
    $DriveLetter = $DriveLetter.Substring(0, 1)
}
if ($DriveLetter -notmatch '^[A-Z]$') {
    $DriveLetter = "Y"
}

Write-Output "CONFIG   Drive letter for ESP mount: $DriveLetter"
Write-Output "CONFIG   Skip fonts cleanup: $SkipFonts"
Write-Output "CONFIG   Skip capsules cleanup: $SkipCapsules"
Write-Output "CONFIG   Reboot after completion: $RebootAfter"

if ($SkipFonts -and $SkipCapsules) {
    Write-Output "FAILED   Both cleanup operations are disabled - nothing to do"
    exit 1
}

############################################################################################################
#                                    MAIN EXECUTION                                                        #
############################################################################################################

Write-Output ""
Write-Output "STATUS   Start time: $([DateTime]::Now)"
Write-Output "STATUS   Mounting EFI System Partition..."

$MountPoint = "${DriveLetter}:"
$wasMounted = $false

# Check if drive letter is already in use
if (Test-Path $MountPoint) {
    Write-Output "WARNING  Drive $MountPoint is already in use"
    Write-Output "STATUS   Checking if it's the ESP..."

    # Check if it's already the ESP
    $testPath = Join-Path $MountPoint "EFI\Microsoft\Boot"
    if (Test-Path $testPath) {
        Write-Output "STATUS   Drive $MountPoint appears to be the ESP already mounted"
        $wasMounted = $true
    }
    else {
        Write-Output "FAILED   Drive $MountPoint is in use but doesn't appear to be the ESP"
        Write-Output "STATUS   Try a different drive letter via usrDriveLetter variable"
        exit 2
    }
}

if (-not $wasMounted) {
    # Mount the EFI System Partition
    try {
        $mountResult = mountvol $MountPoint /s 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Output "FAILED   Failed to mount ESP: $mountResult"
            exit 2
        }
        Write-Output "SUCCESS  ESP mounted to $MountPoint"
        $script:SuccessCount++
    }
    catch {
        Write-Output "FAILED   Exception mounting ESP: $($_.Exception.Message)"
        exit 2
    }
}

# Verify mount was successful
$BootPath = Join-Path $MountPoint "EFI\Microsoft\Boot"
if (-not (Test-Path $BootPath)) {
    Write-Output "FAILED   Cannot find EFI boot path: $BootPath"
    Write-Output "STATUS   The EFI System Partition structure is unexpected"

    if (-not $wasMounted) {
        Write-Output "STATUS   Unmounting ESP..."
        mountvol $MountPoint /d 2>&1 | Out-Null
    }
    exit 2
}

Write-Output "DETECT   EFI boot path found: $BootPath"

# Get initial free space
try {
    $volume = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = '$MountPoint'"
    if ($volume) {
        $initialFree = $volume.FreeSpace
        Write-Output "DETECT   Initial ESP free space: $([math]::Round($initialFree / 1MB, 2)) MB"
    }
}
catch {
    Write-Output "STATUS   Could not determine initial free space"
}

Write-Output ""

############################################################################################################
#                                    CLEANUP OPERATIONS                                                    #
############################################################################################################

# 1. Clear Fonts folder
if (-not $SkipFonts) {
    Write-Output "STATUS   Cleaning up boot fonts..."
    $FontsPath = Join-Path $BootPath "Fonts"
    Remove-FilesInFolder -Path $FontsPath -Filter "*.*" -Description "Boot Fonts"
}

Write-Output ""

# 2. Clear UpdateCapsule folder
if (-not $SkipCapsules) {
    Write-Output "STATUS   Cleaning up update capsules..."
    $CapsulePath = Join-Path $BootPath "UpdateCapsule"

    if (Test-Path $CapsulePath) {
        # Remove .bin files specifically
        Remove-FilesInFolder -Path $CapsulePath -Filter "*.bin" -Description "Update Capsules (.bin)"

        # Also check for other files that might be present
        $otherFiles = Get-ChildItem -Path $CapsulePath -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -ne '.bin' }
        if ($otherFiles) {
            Write-Output "DETECT   Found $($otherFiles.Count) additional files in UpdateCapsule folder"
            foreach ($file in $otherFiles) {
                Write-Output "STATUS   Other file: $($file.Name) ($([math]::Round($file.Length/1KB, 2)) KB)"
            }
        }
    }
    else {
        Write-Output "STATUS   UpdateCapsule folder not found (this is normal)"
    }
}

############################################################################################################
#                                    CLEANUP AND REPORT                                                    #
############################################################################################################

Write-Output ""

# Get final free space
try {
    # Refresh volume info
    Start-Sleep -Seconds 1
    $volume = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = '$MountPoint'"
    if ($volume -and $initialFree) {
        $finalFree = $volume.FreeSpace
        $spaceGained = $finalFree - $initialFree
        Write-Output "DETECT   Final ESP free space: $([math]::Round($finalFree / 1MB, 2)) MB"
        if ($spaceGained -gt 0) {
            Write-Output "METRIC   Space freed: $([math]::Round($spaceGained / 1KB, 2)) KB"
        }
    }
}
catch {
    Write-Output "STATUS   Could not determine final free space"
}

# Unmount ESP if we mounted it
if (-not $wasMounted) {
    Write-Output ""
    Write-Output "STATUS   Unmounting EFI System Partition..."
    try {
        $unmountResult = mountvol $MountPoint /d 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Output "WARNING  Could not unmount ESP: $unmountResult"
            Write-Output "STATUS   The drive letter may remain assigned until reboot"
            $script:WarningCount++
        }
        else {
            Write-Output "SUCCESS  ESP unmounted from $MountPoint"
            $script:SuccessCount++
        }
    }
    catch {
        Write-Output "WARNING  Exception unmounting ESP: $($_.Exception.Message)"
        $script:WarningCount++
    }
}

############################################################################################################
#                                    EXECUTION SUMMARY                                                     #
############################################################################################################

Write-Output ""
Write-Output "METRIC   Total bytes freed: $script:BytesFreed ($([math]::Round($script:BytesFreed / 1KB, 2)) KB)"
Write-Output "METRIC   Execution Summary - Success: $script:SuccessCount, Failed: $script:FailCount, Warnings: $script:WarningCount"
Write-Output "STATUS   End time: $([DateTime]::Now)"

# Handle Reboot if requested
if ($RebootAfter -and $script:FailCount -eq 0) {
    Write-Output "STATUS   Reboot requested. Restarting system in 10 seconds..."
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}

if ($script:FailCount -gt 0) {
    Write-Output "FAILED   Operation completed with errors"
    exit 2
}
elseif ($script:BytesFreed -eq 0 -and $script:WarningCount -eq 0) {
    Write-Output "STATUS   No files needed cleanup"
    exit 1
}
elseif ($script:WarningCount -gt 0) {
    Write-Output "WARNING  Operation completed with warnings"
    exit 0
}
else {
    Write-Output "SUCCESS  EFI System Partition cleanup completed"
    Write-Output ""
    Write-Output "STATUS   Please retry Windows Update"
    exit 0
}
