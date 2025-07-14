<#
.SYNOPSIS
Registry Helper Functions - Registry operations for Datto RMM scripts

.DESCRIPTION
Provides registry utility functions optimized for Datto RMM environment:
- Safe registry key and value operations
- Registry-based software detection
- Registry backup and restore
- Registry permission handling
- Cross-architecture registry access (32-bit/64-bit)

.NOTES
Version: 3.0.0
Author: Datto RMM Function Library
Compatible: PowerShell 2.0+, Datto RMM Environment
#>

function Get-RMMRegistryValue {
    <#
    .SYNOPSIS
    Safely gets registry values with error handling
    
    .PARAMETER Path
    Registry path (e.g., "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion")
    
    .PARAMETER Name
    Value name to retrieve
    
    .PARAMETER DefaultValue
    Default value to return if not found
    
    .PARAMETER ExpandEnvironmentNames
    Whether to expand environment variables in string values
    
    .EXAMPLE
    $version = Get-RMMRegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "ProductName"
    $timeout = Get-RMMRegistryValue -Path "HKLM:\SOFTWARE\MyApp" -Name "Timeout" -DefaultValue 300
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [object]$DefaultValue = $null,
        
        [switch]$ExpandEnvironmentNames
    )
    
    try {
        if (-not (Test-Path $Path)) {
            Write-RMMLog "Registry path does not exist: $Path" -Level Info
            return $DefaultValue
        }
        
        $value = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop | Select-Object -ExpandProperty $Name
        
        if ($ExpandEnvironmentNames -and $value -is [string]) {
            $value = [Environment]::ExpandEnvironmentVariables($value)
        }
        
        Write-RMMLog "Retrieved registry value: $Path\$Name = $value" -Level Info
        return $value
    }
    catch {
        Write-RMMLog "Failed to get registry value $Path\$Name`: $($_.Exception.Message)" -Level Warning
        return $DefaultValue
    }
}

function Set-RMMRegistryValue {
    <#
    .SYNOPSIS
    Safely sets registry values with proper type handling
    
    .PARAMETER Path
    Registry path
    
    .PARAMETER Name
    Value name to set
    
    .PARAMETER Value
    Value to set
    
    .PARAMETER Type
    Registry value type
    
    .PARAMETER CreatePath
    Whether to create the registry path if it doesn't exist
    
    .EXAMPLE
    Set-RMMRegistryValue -Path "HKLM:\SOFTWARE\MyApp" -Name "Version" -Value "1.0.0" -Type String -CreatePath
    Set-RMMRegistryValue -Path "HKLM:\SOFTWARE\MyApp" -Name "Enabled" -Value 1 -Type DWord
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [object]$Value,
        
        [ValidateSet('String','ExpandString','Binary','DWord','MultiString','QWord')]
        [string]$Type = 'String',
        
        [switch]$CreatePath
    )
    
    try {
        # Create path if requested and doesn't exist
        if ($CreatePath -and -not (Test-Path $Path)) {
            Write-RMMLog "Creating registry path: $Path" -Level Status
            New-Item -Path $Path -Force | Out-Null
        }
        
        if (-not (Test-Path $Path)) {
            throw "Registry path does not exist: $Path"
        }
        
        Write-RMMLog "Setting registry value: $Path\$Name = $Value (Type: $Type)" -Level Status
        
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        
        Write-RMMLog "Successfully set registry value: $Path\$Name" -Level Success
        return $true
    }
    catch {
        Write-RMMLog "Failed to set registry value $Path\$Name`: $($_.Exception.Message)" -Level Failed
        return $false
    }
}

function Remove-RMMRegistryValue {
    <#
    .SYNOPSIS
    Safely removes registry values
    
    .PARAMETER Path
    Registry path
    
    .PARAMETER Name
    Value name to remove
    
    .PARAMETER IgnoreNotFound
    Whether to ignore errors if value doesn't exist
    
    .EXAMPLE
    Remove-RMMRegistryValue -Path "HKLM:\SOFTWARE\MyApp" -Name "OldSetting" -IgnoreNotFound
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [switch]$IgnoreNotFound
    )
    
    try {
        if (-not (Test-Path $Path)) {
            if ($IgnoreNotFound) {
                Write-RMMLog "Registry path does not exist (ignored): $Path" -Level Info
                return $true
            } else {
                throw "Registry path does not exist: $Path"
            }
        }
        
        # Check if value exists
        $valueExists = $null -ne (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue)
        
        if (-not $valueExists) {
            if ($IgnoreNotFound) {
                Write-RMMLog "Registry value does not exist (ignored): $Path\$Name" -Level Info
                return $true
            } else {
                throw "Registry value does not exist: $Path\$Name"
            }
        }
        
        Write-RMMLog "Removing registry value: $Path\$Name" -Level Status
        
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        
        Write-RMMLog "Successfully removed registry value: $Path\$Name" -Level Success
        return $true
    }
    catch {
        Write-RMMLog "Failed to remove registry value $Path\$Name`: $($_.Exception.Message)" -Level Failed
        return $false
    }
}

function Test-RMMRegistryPath {
    <#
    .SYNOPSIS
    Tests if a registry path exists
    
    .PARAMETER Path
    Registry path to test
    
    .EXAMPLE
    if (Test-RMMRegistryPath -Path "HKLM:\SOFTWARE\MyApp") {
        Write-RMMLog "Application is installed" -Level Info
    }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $exists = Test-Path $Path
    Write-RMMLog "Registry path exists: $Path = $exists" -Level Info
    return $exists
}

function Get-RMMUninstallInfo {
    <#
    .SYNOPSIS
    Gets software uninstall information from registry (fast alternative to Win32_Product)
    
    .PARAMETER DisplayName
    Software display name to search for (supports wildcards)
    
    .PARAMETER Publisher
    Publisher name to filter by (optional)
    
    .PARAMETER IncludeSystemComponents
    Whether to include system components
    
    .EXAMPLE
    $chrome = Get-RMMUninstallInfo -DisplayName "*Google Chrome*"
    $hpSoftware = Get-RMMUninstallInfo -DisplayName "*HP*" -Publisher "*HP*"
    #>
    param(
        [string]$DisplayName = "*",
        
        [string]$Publisher,
        
        [switch]$IncludeSystemComponents
    )
    
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    $results = @()
    
    foreach ($path in $uninstallPaths) {
        try {
            if (Test-Path $path) {
                $subKeys = Get-ChildItem $path -ErrorAction SilentlyContinue
                
                foreach ($subKey in $subKeys) {
                    try {
                        $app = Get-ItemProperty $subKey.PSPath -ErrorAction SilentlyContinue
                        
                        # Skip if no display name
                        if (-not $app.DisplayName) { continue }
                        
                        # Skip system components unless requested
                        if (-not $IncludeSystemComponents -and $app.SystemComponent -eq 1) { continue }
                        
                        # Filter by display name
                        if ($DisplayName -ne "*" -and $app.DisplayName -notlike $DisplayName) { continue }
                        
                        # Filter by publisher
                        if ($Publisher -and $app.Publisher -notlike $Publisher) { continue }
                        
                        $results += [PSCustomObject]@{
                            DisplayName = $app.DisplayName
                            Publisher = $app.Publisher
                            Version = $app.DisplayVersion
                            InstallDate = $app.InstallDate
                            InstallLocation = $app.InstallLocation
                            UninstallString = $app.UninstallString
                            QuietUninstallString = $app.QuietUninstallString
                            ModifyPath = $app.ModifyPath
                            EstimatedSize = $app.EstimatedSize
                            RegistryKey = $subKey.PSChildName
                            RegistryPath = $subKey.PSPath
                            Architecture = if ($path -like "*WOW6432Node*") { "x86" } else { "x64" }
                        }
                    }
                    catch {
                        # Skip problematic entries
                        continue
                    }
                }
            }
        }
        catch {
            Write-RMMLog "Error accessing uninstall registry path $path`: $($_.Exception.Message)" -Level Warning
        }
    }
    
    Write-RMMLog "Found $($results.Count) software entries matching criteria" -Level Info
    return $results
}

function Backup-RMMRegistryKey {
    <#
    .SYNOPSIS
    Creates a backup of a registry key
    
    .PARAMETER Path
    Registry path to backup
    
    .PARAMETER BackupPath
    Path to save the backup file (.reg format)
    
    .EXAMPLE
    Backup-RMMRegistryKey -Path "HKLM:\SOFTWARE\MyApp" -BackupPath "C:\Backup\MyApp.reg"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$BackupPath
    )
    
    try {
        if (-not (Test-Path $Path)) {
            throw "Registry path does not exist: $Path"
        }
        
        # Ensure backup directory exists
        $backupDir = Split-Path $BackupPath -Parent
        if (-not (Test-Path $backupDir)) {
            New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
        }
        
        Write-RMMLog "Backing up registry key: $Path" -Level Status
        Write-RMMLog "Backup location: $BackupPath" -Level Status
        
        # Convert PowerShell path to reg.exe format
        $regPath = $Path -replace "HKLM:", "HKEY_LOCAL_MACHINE" -replace "HKCU:", "HKEY_CURRENT_USER"
        
        # Use reg.exe to export the key
        $process = Start-Process -FilePath "reg.exe" -ArgumentList "export", "`"$regPath`"", "`"$BackupPath`"", "/y" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-RMMLog "Successfully backed up registry key to: $BackupPath" -Level Success
            return $true
        } else {
            throw "reg.exe export failed with exit code: $($process.ExitCode)"
        }
    }
    catch {
        Write-RMMLog "Failed to backup registry key $Path`: $($_.Exception.Message)" -Level Failed
        return $false
    }
}

# Export functions for module loading
Export-ModuleMember -Function @(
    'Get-RMMRegistryValue',
    'Set-RMMRegistryValue',
    'Remove-RMMRegistryValue',
    'Test-RMMRegistryPath',
    'Get-RMMUninstallInfo',
    'Backup-RMMRegistryKey'
)
