#requires -version 3.0
<#
.SYNOPSIS
    Microsoft .NET Framework Repair Tool Component (With Component Files)
.DESCRIPTION
    Executes NetFxRepairTool.exe and RenTS.exe from component files to repair .NET Framework issues
.VERSION
    2.0
.CONTEXT
    System context required for .NET repairs
.EXIT CODES
    0 = Success (Green)
    1 = Warnings (Amber) 
    2 = Failure (Red)
.NOTES
    NetFxRepairTool.exe and RenTS.exe must be uploaded as component files
#>

# Input Variables - Configure these in Datto RMM component settings
$DebugMode = if($env:DebugMode -eq "true") { $true } else { $false }
$RunRenTS = if($env:RunRenTS -eq "true") { $true } else { $false }
$LogPath = if($env:LogPath) { $env:LogPath } else { "$env:TEMP\DotNetRepair" }

# Initialize logging
$TranscriptPath = "$LogPath\DotNetRepair_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
if(!(Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }
Start-Transcript -Path $TranscriptPath

try {
    Write-Host "=== .NET Framework Repair Tool Started ===" -ForegroundColor Green
    Write-Host "Debug Mode: $DebugMode" -ForegroundColor Yellow
    Write-Host "Run RenTS: $RunRenTS" -ForegroundColor Yellow
    Write-Host "Log Path: $LogPath" -ForegroundColor Yellow
    Write-Host "Working Directory: $PWD" -ForegroundColor Gray
    
    # Verify component files exist
    function Test-ComponentFiles {
        $NetFxTool = ".\NetFxRepairTool.exe"
        $RenTSTool = ".\RenTS.exe"
        
        Write-Host "Checking component files..." -ForegroundColor Yellow
        
        if(!(Test-Path $NetFxTool)) {
            Write-Host "ERROR: NetFxRepairTool.exe not found in component directory" -ForegroundColor Red
            throw "NetFxRepairTool.exe missing from component files"
        }
        
        if($RunRenTS -and !(Test-Path $RenTSTool)) {
            Write-Host "ERROR: RenTS.exe not found in component directory" -ForegroundColor Red
            throw "RenTS.exe missing from component files"
        }
        
        Write-Host "✓ NetFxRepairTool.exe found: $(Get-Item $NetFxTool | Select-Object -ExpandProperty Length) bytes" -ForegroundColor Green
        if($RunRenTS) {
            Write-Host "✓ RenTS.exe found: $(Get-Item $RenTSTool | Select-Object -ExpandProperty Length) bytes" -ForegroundColor Green
        }
        
        return @{
            NetFxTool = $NetFxTool
            RenTSTool = $RenTSTool
        }
    }
    
    # Function to run .NET repair
    function Invoke-DotNetRepair {
        param([string]$ToolPath, [string]$OutputPath)
        
        $LogFile = "$OutputPath\FixDotNet.log"
        $Arguments = "/q /l `"$OutputPath`""
        
        Write-Host "Running .NET Framework Repair..." -ForegroundColor Yellow
        Write-Host "Command: $ToolPath $Arguments" -ForegroundColor Gray
        
        try {
            $Process = Start-Process -FilePath $ToolPath -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
            
            Write-Host "NetFxRepairTool.exe completed with exit code: $($Process.ExitCode)" -ForegroundColor Yellow
            
            # Process log files (handle both CAB and direct log scenarios)
            $CabFiles = Get-ChildItem -Path $OutputPath -Filter "FixDotNet*.cab" -ErrorAction SilentlyContinue
            
            if($CabFiles) {
                Write-Host "Found $($CabFiles.Count) CAB file(s) to extract" -ForegroundColor Yellow
                foreach($CabFile in $CabFiles) {
                    Write-Host "Extracting log from: $($CabFile.Name)" -ForegroundColor Yellow
                    $ExtractArgs = "`"$($CabFile.FullName)`" -F:FixDotNet.log `"$OutputPath`""
                    $ExtractProcess = Start-Process -FilePath "expand.exe" -ArgumentList $ExtractArgs -Wait -PassThru -NoNewWindow
                    
                    if($ExtractProcess.ExitCode -eq 0) {
                        Write-Host "Successfully extracted log from $($CabFile.Name)" -ForegroundColor Green
                    } else {
                        Write-Host "Warning: Failed to extract log from $($CabFile.Name)" -ForegroundColor Yellow
                    }
                }
            } else {
                Write-Host "No CAB files found - checking for direct log file" -ForegroundColor Yellow
            }
            
            # Analyze repair results
            return Test-RepairResults -LogFile $LogFile -ProcessExitCode $Process.ExitCode
            
        } catch {
            Write-Host "Failed to run NetFxRepairTool.exe: $($_.Exception.Message)" -ForegroundColor Red
            return 2  # Failure
        }
    }
    
    # Function to run RenTS.exe (if enabled)
    function Invoke-RenTSRepair {
        param([string]$ToolPath)
        
        Write-Host "Running RenTS.exe for additional .NET cleanup..." -ForegroundColor Yellow
        
        try {
            # RenTS.exe typically runs without parameters for automatic repair
            $Process = Start-Process -FilePath $ToolPath -Wait -PassThru -NoNewWindow
            
            Write-Host "RenTS.exe completed with exit code: $($Process.ExitCode)" -ForegroundColor Yellow
            
            # RenTS success is typically 0, but check for common failure codes
            if($Process.ExitCode -eq 0) {
                Write-Host "RenTS.exe completed successfully" -ForegroundColor Green
                return 0
            } elseif($Process.ExitCode -eq 1) {
                Write-Host "RenTS.exe completed with warnings" -ForegroundColor Yellow
                return 1
            } else {
                Write-Host "RenTS.exe failed with exit code: $($Process.ExitCode)" -ForegroundColor Red
                return 2
            }
            
        } catch {
            Write-Host "Failed to run RenTS.exe: $($_.Exception.Message)" -ForegroundColor Red
            return 2  # Failure
        }
    }
    
    # Function to analyze repair results
    function Test-RepairResults {
        param([string]$LogFile, [int]$ProcessExitCode)
        
        if(Test-Path $LogFile) {
            Write-Host "=== Repair Log Analysis ===" -ForegroundColor Cyan
            $LogContent = Get-Content $LogFile -ErrorAction SilentlyContinue
            
            if($LogContent) {
                $InfoLines = $LogContent | Where-Object { $_ -match "INFO" }
                $ErrorLines = $LogContent | Where-Object { $_ -match "ERROR" }
                $WarningLines = $LogContent | Where-Object { $_ -match "WARNING" }
                $SuccessLines = $LogContent | Where-Object { $_ -match "SUCCESS|COMPLETED|FIXED" }
                
                if($DebugMode) {
                    Write-Host "Full log content:" -ForegroundColor Gray
                    $LogContent | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
                }
                
                if($SuccessLines) {
                    Write-Host "SUCCESS Messages:" -ForegroundColor Green
                    $SuccessLines | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
                }
                
                if($InfoLines) {
                    Write-Host "INFO Messages:" -ForegroundColor Cyan
                    $InfoLines | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
                }
                
                if($WarningLines) {
                    Write-Host "WARNING Messages:" -ForegroundColor Yellow
                    $WarningLines | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
                }
                
                if($ErrorLines) {
                    Write-Host "ERROR Messages:" -ForegroundColor Red
                    $ErrorLines | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
                    return 2  # Failure
                }
                
                # Determine result based on process exit code and log content
                if($ProcessExitCode -eq 0 -and $SuccessLines) {
                    return 0  # Success
                } elseif($ProcessExitCode -eq 0 -and $WarningLines) {
                    return 1  # Warnings
                } elseif($ProcessExitCode -eq 0) {
                    return 0  # Success (no explicit errors)
                } else {
                    return 2  # Failure
                }
            } else {
                Write-Host "Log file is empty or unreadable" -ForegroundColor Yellow
                return 1  # Warning
            }
        } else {
            Write-Host "No log file generated - repair may have failed" -ForegroundColor Yellow
            return if($ProcessExitCode -eq 0) { 1 } else { 2 }
        }
    }
    
    # Main execution flow
    $ComponentFiles = Test-ComponentFiles
    
    # Run primary .NET repair
    $NetFxResult = Invoke-DotNetRepair -ToolPath $ComponentFiles.NetFxTool -OutputPath $LogPath
    
    # Run RenTS if enabled and primary repair didn't fail
    $RenTSResult = 0
    if($RunRenTS -and $NetFxResult -ne 2) {
        $RenTSResult = Invoke-RenTSRepair -ToolPath $ComponentFiles.RenTSTool
    }
    
    # Determine final result (worst case between both tools)
    $FinalResult = [Math]::Max($NetFxResult, $RenTSResult)
    
    # Final status reporting
    $StatusText = switch($FinalResult) {
        0 { "SUCCESS: .NET Framework repair completed successfully" }
        1 { "WARNING: .NET Framework repair completed with warnings" }
        2 { "FAILURE: .NET Framework repair failed" }
        default { "UNKNOWN: Unexpected result code $FinalResult" }
    }
    
    Write-Host "=== Final Status ===" -ForegroundColor Cyan
    Write-Host $StatusText -ForegroundColor $(if($FinalResult -eq 0){"Green"}elseif($FinalResult -eq 1){"Yellow"}else{"Red"})
    Write-Host "NetFxRepairTool Result: $NetFxResult" -ForegroundColor Gray
    if($RunRenTS) { Write-Host "RenTS Result: $RenTSResult" -ForegroundColor Gray }
    Write-Host "Log files available at: $LogPath" -ForegroundColor Gray
    
    Stop-Transcript
    exit $FinalResult
    
} catch {
    Write-Host "CRITICAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    
    Stop-Transcript
    exit 2
}
