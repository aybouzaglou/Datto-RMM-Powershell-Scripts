<#
.SYNOPSIS
Datto RMM Launcher for FocusedDebloat Script - Auto-downloads latest version from GitHub
.DESCRIPTION
This launcher script automatically downloads and executes the latest version of the 
FocusedDebloat script from GitHub, ensuring you always run the most current version
without needing to manually update the script in Datto RMM.

Features:
- Downloads latest script version from GitHub automatically
- Passes through all Datto RMM environment variables
- Supports all original script parameters
- Provides detailed logging and error handling
- Cleans up temporary files after execution

.PARAMETER customwhitelist
Optional array of app names to preserve during removal
.INPUTS
Datto RMM Environment Variables:
- customwhitelist: Comma-separated list of apps to preserve (optional)
- skipwindows: Set to "true" to skip Windows bloatware removal (optional)
- skiphp: Set to "true" to skip HP bloatware removal (optional)
- skipdell: Set to "true" to skip Dell bloatware removal (optional)
- skiplenovo: Set to "true" to skip Lenovo bloatware removal (optional)
.OUTPUTS
C:\ProgramData\Debloat\Debloat.log (via the main script)
.NOTES
  Version:        1.0.0
  Author:         Datto RMM Launcher
  Creation Date:  07/01/2025
  Purpose:        Auto-download and execute latest FocusedDebloat script
  
  GitHub Repository: https://github.com/aybouzaglou/Datto-RMM-Powershell-Scripts
#>

############################################################################################################
#                                    Datto RMM Auto-Launcher                                              #
############################################################################################################

param (
    [string[]]$customwhitelist
)

# Script configuration
$githubRepo = "aybouzaglou/Datto-RMM-Powershell-Scripts"
$scriptFileName = "FocusedDebloat.ps1"
$scriptUrl = "https://raw.githubusercontent.com/$githubRepo/main/$scriptFileName"
$tempPath = "$env:TEMP\$scriptFileName"
$logPath = "C:\ProgramData\Debloat"

# Ensure log directory exists
if (-not (Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}

# Start logging
$launcherLog = "$logPath\Launcher.log"
Start-Transcript -Path $launcherLog -Append

Write-Output "=============================================="
Write-Output "Datto RMM FocusedDebloat Launcher v1.0.0"
Write-Output "=============================================="
Write-Output "Timestamp: $(Get-Date)"
Write-Output "GitHub Repository: https://github.com/$githubRepo"
Write-Output "Script URL: $scriptUrl"
Write-Output ""

# Check for Datto RMM environment variables and display configuration
Write-Output "Datto RMM Environment Variables:"
Write-Output "- customwhitelist: $env:customwhitelist"
Write-Output "- skipwindows: $env:skipwindows"
Write-Output "- skiphp: $env:skiphp"
Write-Output "- skipdell: $env:skipdell"
Write-Output "- skiplenovo: $env:skiplenovo"
Write-Output ""

try {
    Write-Output "Downloading latest FocusedDebloat script from GitHub..."
    Write-Output "Source: $scriptUrl"
    Write-Output "Destination: $tempPath"
    
    # Download the latest script with error handling
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Datto-RMM-Launcher/1.0")
    $webClient.DownloadFile($scriptUrl, $tempPath)
    
    # Verify download was successful
    if (-not (Test-Path $tempPath)) {
        throw "Downloaded file not found at $tempPath"
    }
    
    $fileSize = (Get-Item $tempPath).Length
    Write-Output "Download completed successfully. File size: $fileSize bytes"
    
    # Verify the downloaded file contains expected PowerShell content
    $firstLine = Get-Content $tempPath -TotalCount 1
    if ($firstLine -notlike "*#*" -and $firstLine -notlike "*<#*") {
        Write-Warning "Downloaded file may not be a valid PowerShell script. First line: $firstLine"
    }
    
    Write-Output ""
    Write-Output "Executing downloaded FocusedDebloat script..."
    Write-Output "=============================================="
    
    # Prepare parameters for the main script
    $scriptParams = @{}
    if ($customwhitelist) {
        $scriptParams['customwhitelist'] = $customwhitelist
    }
    
    # Execute the downloaded script with all parameters
    & $tempPath @scriptParams
    
    $exitCode = $LASTEXITCODE
    Write-Output ""
    Write-Output "=============================================="
    Write-Output "FocusedDebloat script execution completed."
    Write-Output "Exit code: $exitCode"
    
    if ($exitCode -eq 0 -or $null -eq $exitCode) {
        Write-Output "Script executed successfully."
    } else {
        Write-Warning "Script may have encountered issues. Check the main script log for details."
    }
    
}
catch {
    Write-Error "Failed to download or execute FocusedDebloat script:"
    Write-Error "Error: $($_.Exception.Message)"
    Write-Error "Line: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Error "Position: $($_.InvocationInfo.PositionMessage)"
    
    # Additional troubleshooting information
    Write-Output ""
    Write-Output "Troubleshooting Information:"
    Write-Output "- Check internet connectivity"
    Write-Output "- Verify GitHub repository is accessible"
    Write-Output "- Ensure PowerShell execution policy allows script execution"
    Write-Output "- Check Windows Defender or antivirus blocking"
    
    Stop-Transcript
    exit 1
}
finally {
    # Clean up temporary file
    if (Test-Path $tempPath) {
        try {
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
            Write-Output "Temporary file cleaned up: $tempPath"
        }
        catch {
            Write-Warning "Could not remove temporary file: $tempPath"
        }
    }
}

Write-Output ""
Write-Output "Launcher execution completed at: $(Get-Date)"
Write-Output "Launcher log saved to: $launcherLog"
Write-Output "Main script log available at: C:\ProgramData\Debloat\Debloat.log"

Stop-Transcript
