<#
.SYNOPSIS
File Operations Utility Functions - File and directory operations for Datto RMM scripts

.DESCRIPTION
Provides file and directory utility functions optimized for Datto RMM environment:
- Safe file operations with error handling
- Directory creation and cleanup
- File verification and integrity checks
- Archive extraction and compression
- Temporary file management
- Process cleanup and termination

.NOTES
Version: 3.0.0
Author: Datto RMM Function Library
Compatible: PowerShell 5.0+, Datto RMM Environment
#>

function New-RMMDirectory {
    <#
    .SYNOPSIS
    Creates directories with proper error handling and logging
    
    .PARAMETER Path
    Directory path to create
    
    .PARAMETER Force
    Force creation even if parent directories don't exist
    
    .EXAMPLE
    New-RMMDirectory -Path "C:\ProgramData\MyApp\Logs"
    New-RMMDirectory -Path "C:\Temp\WorkingDir" -Force
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [switch]$Force
    )
    
    try {
        if (Test-Path $Path) {
            Write-RMMLog "Directory already exists: $Path" -Level Info
            return $true
        }
        
        Write-RMMLog "Creating directory: $Path" -Level Status
        
        if ($Force) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        } else {
            New-Item -Path $Path -ItemType Directory | Out-Null
        }
        
        Write-RMMLog "Successfully created directory: $Path" -Level Success
        return $true
    }
    catch {
        Write-RMMLog "Failed to create directory $Path`: $($_.Exception.Message)" -Level Failed
        return $false
    }
}

function Remove-RMMDirectory {
    <#
    .SYNOPSIS
    Safely removes directories with retry logic
    
    .PARAMETER Path
    Directory path to remove
    
    .PARAMETER Recurse
    Remove directory and all contents
    
    .PARAMETER MaxRetries
    Maximum number of retry attempts
    
    .PARAMETER RetryDelaySeconds
    Delay between retry attempts
    
    .EXAMPLE
    Remove-RMMDirectory -Path "C:\Temp\OldFiles" -Recurse
    Remove-RMMDirectory -Path "C:\Temp\Locked" -Recurse -MaxRetries 5
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [switch]$Recurse,
        
        [int]$MaxRetries = 3,
        
        [int]$RetryDelaySeconds = 2
    )
    
    if (-not (Test-Path $Path)) {
        Write-RMMLog "Directory does not exist: $Path" -Level Info
        return $true
    }
    
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        $attempt++
        
        try {
            Write-RMMLog "Attempting to remove directory: $Path (Attempt $attempt)" -Level Status
            
            if ($Recurse) {
                Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            } else {
                Remove-Item -Path $Path -Force -ErrorAction Stop
            }
            
            Write-RMMLog "Successfully removed directory: $Path" -Level Success
            return $true
        }
        catch {
            Write-RMMLog "Attempt $attempt failed to remove $Path`: $($_.Exception.Message)" -Level Warning
            
            if ($attempt -lt $MaxRetries) {
                Write-RMMLog "Waiting ${RetryDelaySeconds}s before retry..." -Level Info
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }
    
    Write-RMMLog "Failed to remove directory after $MaxRetries attempts: $Path" -Level Failed
    return $false
}

function Copy-RMMFile {
    <#
    .SYNOPSIS
    Copies files with verification and error handling
    
    .PARAMETER Source
    Source file path
    
    .PARAMETER Destination
    Destination file path
    
    .PARAMETER VerifyHash
    Verify file integrity using hash comparison
    
    .PARAMETER OverwriteExisting
    Whether to overwrite existing files
    
    .EXAMPLE
    Copy-RMMFile -Source "C:\Source\file.exe" -Destination "C:\Dest\file.exe" -VerifyHash
    Copy-RMMFile -Source "\\Server\Share\installer.msi" -Destination "C:\Temp\installer.msi"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Source,
        
        [Parameter(Mandatory=$true)]
        [string]$Destination,
        
        [switch]$VerifyHash,
        
        [bool]$OverwriteExisting = $true
    )
    
    try {
        if (-not (Test-Path $Source)) {
            throw "Source file does not exist: $Source"
        }
        
        # Check if destination exists
        if ((Test-Path $Destination) -and -not $OverwriteExisting) {
            Write-RMMLog "Destination file exists and overwrite disabled: $Destination" -Level Warning
            return $false
        }
        
        # Ensure destination directory exists
        $destDir = Split-Path $Destination -Parent
        if (-not (Test-Path $destDir)) {
            New-RMMDirectory -Path $destDir -Force | Out-Null
        }
        
        Write-RMMLog "Copying file from $Source to $Destination" -Level Status
        
        # Get source file hash if verification requested
        $sourceHash = if ($VerifyHash) {
            Get-FileHash -Path $Source -Algorithm SHA256 -ErrorAction Stop
        } else { $null }
        
        # Perform copy
        Copy-Item -Path $Source -Destination $Destination -Force
        
        # Verify copy was successful
        if (-not (Test-Path $Destination)) {
            throw "Destination file was not created: $Destination"
        }
        
        # Verify file integrity if requested
        if ($VerifyHash) {
            $destHash = Get-FileHash -Path $Destination -Algorithm SHA256 -ErrorAction Stop
            if ($sourceHash.Hash -ne $destHash.Hash) {
                throw "File hash verification failed. Source: $($sourceHash.Hash), Destination: $($destHash.Hash)"
            }
            Write-RMMLog "File integrity verified successfully" -Level Success
        }
        
        $sourceSize = (Get-Item $Source).Length
        $destSize = (Get-Item $Destination).Length
        Write-RMMLog "File copied successfully. Size: $destSize bytes" -Level Success
        
        return $true
    }
    catch {
        Write-RMMLog "File copy failed: $($_.Exception.Message)" -Level Failed
        return $false
    }
}

function Expand-RMMArchive {
    <#
    .SYNOPSIS
    Extracts archives with support for multiple formats
    
    .PARAMETER ArchivePath
    Path to the archive file
    
    .PARAMETER DestinationPath
    Directory to extract to
    
    .PARAMETER OverwriteExisting
    Whether to overwrite existing files
    
    .PARAMETER ArchiveType
    Archive type (auto-detected if not specified)
    
    .EXAMPLE
    Expand-RMMArchive -ArchivePath "C:\Temp\archive.zip" -DestinationPath "C:\Temp\Extracted"
    Expand-RMMArchive -ArchivePath "C:\Temp\files.cab" -DestinationPath "C:\Temp\CAB" -ArchiveType CAB
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ArchivePath,
        
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath,
        
        [bool]$OverwriteExisting = $true,
        
        [ValidateSet('ZIP','CAB','Auto')]
        [string]$ArchiveType = 'Auto'
    )
    
    try {
        if (-not (Test-Path $ArchivePath)) {
            throw "Archive file does not exist: $ArchivePath"
        }
        
        # Auto-detect archive type
        if ($ArchiveType -eq 'Auto') {
            $extension = [System.IO.Path]::GetExtension($ArchivePath).ToLower()
            $ArchiveType = switch ($extension) {
                '.zip' { 'ZIP' }
                '.cab' { 'CAB' }
                default { 'ZIP' }  # Default to ZIP
            }
        }
        
        Write-RMMLog "Extracting $ArchiveType archive: $ArchivePath" -Level Status
        Write-RMMLog "Destination: $DestinationPath" -Level Status
        
        # Ensure destination directory exists
        New-RMMDirectory -Path $DestinationPath -Force | Out-Null
        
        switch ($ArchiveType) {
            'ZIP' {
                # Use .NET Framework for ZIP extraction (PowerShell 5.0+ compatible)
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $DestinationPath)
            }
            'CAB' {
                # Use expand.exe for CAB files
                $expandArgs = "`"$ArchivePath`" -F:* `"$DestinationPath`""
                $process = Start-Process -FilePath "expand.exe" -ArgumentList $expandArgs -Wait -PassThru -NoNewWindow
                if ($process.ExitCode -ne 0) {
                    throw "CAB extraction failed with exit code: $($process.ExitCode)"
                }
            }
        }
        
        # Verify extraction
        $extractedFiles = Get-ChildItem -Path $DestinationPath -Recurse -File
        Write-RMMLog "Successfully extracted $($extractedFiles.Count) files" -Level Success
        
        return $true
    }
    catch {
        Write-RMMLog "Archive extraction failed: $($_.Exception.Message)" -Level Failed
        return $false
    }
}

function Stop-RMMProcess {
    <#
    .SYNOPSIS
    Safely stops processes with timeout and retry logic
    
    .PARAMETER ProcessName
    Name of the process to stop (without .exe)
    
    .PARAMETER TimeoutSec
    Timeout for graceful shutdown before force kill
    
    .PARAMETER Force
    Force kill immediately without graceful shutdown
    
    .EXAMPLE
    Stop-RMMProcess -ProcessName "notepad"
    Stop-RMMProcess -ProcessName "installer" -TimeoutSec 30 -Force
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProcessName,
        
        [int]$TimeoutSec = 10,
        
        [switch]$Force
    )
    
    try {
        $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        
        if (-not $processes) {
            Write-RMMLog "No processes found with name: $ProcessName" -Level Info
            return $true
        }
        
        Write-RMMLog "Found $($processes.Count) process(es) named '$ProcessName'" -Level Status
        
        foreach ($process in $processes) {
            try {
                Write-RMMLog "Stopping process: $ProcessName (PID: $($process.Id))" -Level Status
                
                if ($Force) {
                    $process.Kill()
                    Write-RMMLog "Force killed process: $ProcessName (PID: $($process.Id))" -Level Success
                } else {
                    # Try graceful shutdown first
                    $process.CloseMainWindow()
                    
                    # Wait for graceful shutdown
                    if (-not $process.WaitForExit($TimeoutSec * 1000)) {
                        Write-RMMLog "Graceful shutdown timed out, force killing: $ProcessName (PID: $($process.Id))" -Level Warning
                        $process.Kill()
                    }
                    
                    Write-RMMLog "Successfully stopped process: $ProcessName (PID: $($process.Id))" -Level Success
                }
            }
            catch {
                Write-RMMLog "Failed to stop process $ProcessName (PID: $($process.Id)): $($_.Exception.Message)" -Level Failed
            }
        }
        
        return $true
    }
    catch {
        Write-RMMLog "Error stopping processes named '$ProcessName': $($_.Exception.Message)" -Level Failed
        return $false
    }
}

function Get-RMMTempPath {
    <#
    .SYNOPSIS
    Gets a unique temporary file or directory path
    
    .PARAMETER Extension
    File extension for temporary files
    
    .PARAMETER IsDirectory
    Whether to create a directory path instead of file path
    
    .PARAMETER Prefix
    Prefix for the temporary name
    
    .EXAMPLE
    $tempFile = Get-RMMTempPath -Extension ".exe" -Prefix "installer"
    $tempDir = Get-RMMTempPath -IsDirectory -Prefix "extraction"
    #>
    param(
        [string]$Extension = "",
        
        [switch]$IsDirectory,
        
        [string]$Prefix = "RMM"
    )
    
    $tempBase = $env:TEMP
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $random = Get-Random -Minimum 1000 -Maximum 9999
    
    $tempName = "${Prefix}-${timestamp}-${random}"
    
    if ($IsDirectory) {
        $tempPath = Join-Path $tempBase $tempName
    } else {
        $tempPath = Join-Path $tempBase "$tempName$Extension"
    }
    
    Write-RMMLog "Generated temporary path: $tempPath" -Level Info
    return $tempPath
}

# Export functions for module loading
Export-ModuleMember -Function @(
    'New-RMMDirectory',
    'Remove-RMMDirectory',
    'Copy-RMMFile',
    'Expand-RMMArchive',
    'Stop-RMMProcess',
    'Get-RMMTempPath'
)
