# Datto RMM Function Library Reference

## Core Functions

### RMMLogging.ps1

#### Write-RMMLog

Writes standardized log messages for Datto RMM scripts.

**Syntax:**

```powershell
Write-RMMLog -Message <String> -Level <String> [-UpdateCounters <Boolean>]
```

**Parameters:**

- `Message` (String, Required): The message to log
- `Level` (String, Required): Log level - Success, Failed, Warning, Status, Config, Detect, Metric, Info
- `UpdateCounters` (Boolean, Optional): Whether to update global counters (default: true)

**Examples:**

```powershell
Write-RMMLog "Software installation completed" -Level Success
Write-RMMLog "Failed to download installer" -Level Failed
Write-RMMLog "HP manufacturer detected" -Level Detect
```

#### Start-RMMTranscript

Starts transcript logging with standardized paths for Datto RMM.

**Syntax:**

```powershell
Start-RMMTranscript -LogName <String> [-LogDirectory <String>] [-Append <Boolean>]
```

**Parameters:**

- `LogName` (String, Required): Name for the log file (without extension)
- `LogDirectory` (String, Optional): Directory for log files (default: C:\ProgramData\DattoRMM)
- `Append` (Boolean, Optional): Whether to append to existing log (default: true)

**Examples:**

```powershell
Start-RMMTranscript -LogName "SoftwareInstall"
Start-RMMTranscript -LogName "SystemMaintenance" -LogDirectory "C:\Logs"
```

#### Write-RMMMonitorResult

Writes monitor results with proper markers for Datto RMM Custom Monitor components.

**Syntax:**

```powershell
Write-RMMMonitorResult -Status <String> -Message <String> [-ExitCode <Int>]
```

**Parameters:**

- `Status` (String, Required): Monitor status - OK, WARNING, CRITICAL
- `Message` (String, Required): Status message to display in RMM
- `ExitCode` (Int, Optional): Exit code (0 for OK, any non-zero for alert state)

**Examples:**

```powershell
Write-RMMMonitorResult -Status "OK" -Message "All services running normally" -ExitCode 0
Write-RMMMonitorResult -Status "CRITICAL" -Message "Service XYZ is stopped" -ExitCode 1
```

### RMMValidation.ps1

#### Get-RMMVariable

Gets and validates Datto RMM environment variables with type conversion.

**Syntax:**

```powershell
Get-RMMVariable -Name <String> [-Type <String>] [-Default <Object>] [-Required]
```

**Parameters:**

- `Name` (String, Required): Environment variable name
- `Type` (String, Optional): Expected data type - String, Boolean, Integer (default: String)
- `Default` (Object, Optional): Default value if variable is not set
- `Required` (Switch, Optional): Whether the variable is required

**Examples:**

```powershell
$customList = Get-RMMVariable -Name "customwhitelist" -Type "String"
$skipWindows = Get-RMMVariable -Name "skipwindows" -Type "Boolean" -Default $false
$timeout = Get-RMMVariable -Name "timeout" -Type "Integer" -Default 300 -Required
```

#### Invoke-RMMTimeout

Universal timeout wrapper for safe operations in Datto RMM environment.

**Syntax:**

```powershell
Invoke-RMMTimeout -Code <ScriptBlock> [-TimeoutSec <Int>] [-OperationName <String>]
```

**Parameters:**

- `Code` (ScriptBlock, Required): Script block to execute with timeout protection
- `TimeoutSec` (Int, Optional): Timeout in seconds (default: 300)
- `OperationName` (String, Optional): Name of the operation for logging

**Examples:**

```powershell
$result = Invoke-RMMTimeout -Code {
    Get-AppxPackage -AllUsers
} -TimeoutSec 60 -OperationName "Get AppX Packages"
```

#### Test-RMMSystemRequirements

Validates system requirements for script execution.

**Syntax:**

```powershell
Test-RMMSystemRequirements [-MinPSVersion <Double>] [-MinDiskSpaceGB <Double>] [-RequiredServices <String[]>] [-RequiredFeatures <String[]>]
```

**Parameters:**

- `MinPSVersion` (Double, Optional): Minimum PowerShell version required
- `MinDiskSpaceGB` (Double, Optional): Minimum free disk space in GB
- `RequiredServices` (String[], Optional): Array of required services that must be running
- `RequiredFeatures` (String[], Optional): Array of required Windows features

**Examples:**

```powershell
if (-not (Test-RMMSystemRequirements -MinPSVersion 3.0 -MinDiskSpaceGB 1)) {
    exit 10
}
```

### RMMSoftwareDetection.ps1

#### Get-RMMSoftware

Fast software detection using registry instead of Win32_Product.

**Syntax:**

```powershell
Get-RMMSoftware -Name <String> [-Publisher <String>] [-ExactMatch]
```

**Parameters:**

- `Name` (String, Required): Software name to search for (supports wildcards)
- `Publisher` (String, Optional): Publisher name to filter by
- `ExactMatch` (Switch, Optional): Whether to require exact name match (default: false, uses wildcard)

**Examples:**

```powershell
$chrome = Get-RMMSoftware -Name "Google Chrome"
$hpSoftware = Get-RMMSoftware -Name "*HP*" -Publisher "*HP*"
$office = Get-RMMSoftware -Name "Microsoft Office*" -ExactMatch $false
```

#### Test-RMMSoftwareInstalled

Quick test if software is installed (boolean result).

**Syntax:**

```powershell
Test-RMMSoftwareInstalled -Name <String> [-Publisher <String>] [-MinVersion <String>]
```

**Parameters:**

- `Name` (String, Required): Software name to check for
- `Publisher` (String, Optional): Publisher name to filter by
- `MinVersion` (String, Optional): Minimum version required

**Examples:**

```powershell
if (Test-RMMSoftwareInstalled -Name "Google Chrome") {
    Write-RMMLog "Chrome is installed" -Level Info
}

if (Test-RMMSoftwareInstalled -Name "Adobe Reader" -MinVersion "20.0") {
    Write-RMMLog "Adobe Reader 20.0+ is installed" -Level Info
}
```

#### Get-RMMManufacturer

Detects system manufacturer for targeted operations.

**Syntax:**

```powershell
Get-RMMManufacturer [-IncludeModel]
```

**Parameters:**

- `IncludeModel` (Switch, Optional): Whether to include model information

**Examples:**

```powershell
$manufacturer = Get-RMMManufacturer
$systemInfo = Get-RMMManufacturer -IncludeModel
```

## Utility Functions

### NetworkUtils.ps1

#### Invoke-RMMDownload

Downloads files with timeout protection and verification.

**Syntax:**

```powershell
Invoke-RMMDownload -Url <String> -OutputPath <String> [-TimeoutSec <Int>] [-UserAgent <String>] [-VerifySize <Long>] [-OverwriteExisting <Boolean>]
```

**Parameters:**

- `Url` (String, Required): URL to download from
- `OutputPath` (String, Required): Local path to save the file
- `TimeoutSec` (Int, Optional): Download timeout in seconds (default: 300)
- `UserAgent` (String, Optional): User agent string for the request
- `VerifySize` (Long, Optional): Verify downloaded file size is greater than this value in bytes
- `OverwriteExisting` (Boolean, Optional): Whether to overwrite existing files (default: true)

**Examples:**

```powershell
Invoke-RMMDownload -Url "https://example.com/installer.exe" -OutputPath "$env:TEMP\installer.exe"
Invoke-RMMDownload -Url "https://example.com/file.zip" -OutputPath "C:\Temp\file.zip" -TimeoutSec 600 -VerifySize 1000000
```

#### Test-RMMUrl

Tests if a URL is accessible and returns response information.

**Syntax:**

```powershell
Test-RMMUrl -Url <String> [-TimeoutSec <Int>] [-Method <String>]
```

**Parameters:**

- `Url` (String, Required): URL to test
- `TimeoutSec` (Int, Optional): Request timeout in seconds (default: 30)
- `Method` (String, Optional): HTTP method to use - HEAD, GET, POST (default: HEAD)

**Examples:**

```powershell
if (Test-RMMUrl -Url "https://example.com/file.exe") {
    Write-RMMLog "URL is accessible" -Level Info
}

$urlInfo = Test-RMMUrl -Url "https://example.com/api" -Method GET
```

### FileOperations.ps1

#### New-RMMDirectory

Creates directories with proper error handling and logging.

**Syntax:**

```powershell
New-RMMDirectory -Path <String> [-Force]
```

**Parameters:**

- `Path` (String, Required): Directory path to create
- `Force` (Switch, Optional): Force creation even if parent directories don't exist

**Examples:**

```powershell
New-RMMDirectory -Path "C:\ProgramData\MyApp\Logs"
New-RMMDirectory -Path "C:\Temp\WorkingDir" -Force
```

#### Copy-RMMFile

Copies files with verification and error handling.

**Syntax:**

```powershell
Copy-RMMFile -Source <String> -Destination <String> [-VerifyHash] [-OverwriteExisting <Boolean>]
```

**Parameters:**

- `Source` (String, Required): Source file path
- `Destination` (String, Required): Destination file path
- `VerifyHash` (Switch, Optional): Verify file integrity using hash comparison
- `OverwriteExisting` (Boolean, Optional): Whether to overwrite existing files

**Examples:**

```powershell
Copy-RMMFile -Source "C:\Source\file.exe" -Destination "C:\Dest\file.exe" -VerifyHash
Copy-RMMFile -Source "\\Server\Share\installer.msi" -Destination "C:\Temp\installer.msi"
```

#### Stop-RMMProcess

Safely stops processes with timeout and retry logic.

**Syntax:**

```powershell
Stop-RMMProcess -ProcessName <String> [-TimeoutSec <Int>] [-Force]
```

**Parameters:**

- `ProcessName` (String, Required): Name of the process to stop (without .exe)
- `TimeoutSec` (Int, Optional): Timeout for graceful shutdown before force kill
- `Force` (Switch, Optional): Force kill immediately without graceful shutdown

**Examples:**

```powershell
Stop-RMMProcess -ProcessName "notepad"
Stop-RMMProcess -ProcessName "installer" -TimeoutSec 30 -Force
```

### RegistryHelpers.ps1

#### Get-RMMRegistryValue

Safely gets registry values with error handling.

**Syntax:**

```powershell
Get-RMMRegistryValue -Path <String> -Name <String> [-DefaultValue <Object>] [-ExpandEnvironmentNames]
```

**Parameters:**

- `Path` (String, Required): Registry path
- `Name` (String, Required): Value name to retrieve
- `DefaultValue` (Object, Optional): Default value to return if not found
- `ExpandEnvironmentNames` (Switch, Optional): Whether to expand environment variables in string values

**Examples:**

```powershell
$version = Get-RMMRegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "ProductName"
$timeout = Get-RMMRegistryValue -Path "HKLM:\SOFTWARE\MyApp" -Name "Timeout" -DefaultValue 300
```

#### Get-RMMUninstallInfo

Gets software uninstall information from registry (fast alternative to Win32_Product).

**Syntax:**

```powershell
Get-RMMUninstallInfo [-DisplayName <String>] [-Publisher <String>] [-IncludeSystemComponents]
```

**Parameters:**

- `DisplayName` (String, Optional): Software display name to search for (supports wildcards, default: "*")
- `Publisher` (String, Optional): Publisher name to filter by
- `IncludeSystemComponents` (Switch, Optional): Whether to include system components

**Examples:**

```powershell
$chrome = Get-RMMUninstallInfo -DisplayName "*Google Chrome*"
$hpSoftware = Get-RMMUninstallInfo -DisplayName "*HP*" -Publisher "*HP*"
```

## Global Variables

When shared functions are loaded, these global variables are available:

- `$Global:RMMFunctionsLoaded` (Boolean): Whether functions loaded successfully
- `$Global:RMMFunctionsVersion` (String): Version of the function library
- `$Global:RMMFunctionsSource` (String): Source repository and branch
- `$Global:RMMSuccessCount` (Int): Count of successful operations
- `$Global:RMMFailCount` (Int): Count of failed operations
- `$Global:RMMWarningCount` (Int): Count of warnings
- `$Global:RMMFunctionsStatus` (Object): Detailed status information

## Error Handling

All functions include comprehensive error handling and will:

- Log errors using Write-RMMLog
- Return appropriate default values or $false/$null on failure
- Throw exceptions only for critical errors that should stop execution
- Provide detailed error messages for troubleshooting

## Performance Considerations

- Monitor scripts should embed only minimal functions needed for speed
- Use `-UpdateCounters $false` in monitor logging functions to avoid counter overhead
- ⚠️ **DEPRECATED**: Cache system (modern scripts embed functions directly)
- ⚠️ **DEPRECATED**: Offline mode (modern scripts are self-contained)
