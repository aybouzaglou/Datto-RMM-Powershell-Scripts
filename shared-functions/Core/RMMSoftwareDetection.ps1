<#
.SYNOPSIS
RMM Software Detection Functions - Fast software detection avoiding Win32_Product

.DESCRIPTION
Provides fast, reliable software detection methods optimized for Datto RMM environment:
- Registry-based software detection (avoids MSI repair triggers)
- Manufacturer detection for targeted operations
- Multiple detection methods for comprehensive coverage
- Fast execution suitable for monitor scripts
- Structured software information objects

.NOTES
Version: 3.0.0
Author: Datto RMM Function Library
Compatible: PowerShell 2.0+, Datto RMM Environment
Avoids: Win32_Product WMI class (causes MSI repair)
#>

function Get-RMMSoftware {
    <#
    .SYNOPSIS
    Fast software detection using registry instead of Win32_Product
    
    .PARAMETER Name
    Software name to search for (supports wildcards)
    
    .PARAMETER Publisher
    Publisher name to filter by (optional)
    
    .PARAMETER ExactMatch
    Whether to require exact name match (default: false, uses wildcard)
    
    .EXAMPLE
    $chrome = Get-RMMSoftware -Name "Google Chrome"
    $hpSoftware = Get-RMMSoftware -Name "*HP*" -Publisher "*HP*"
    $office = Get-RMMSoftware -Name "Microsoft Office*" -ExactMatch $false
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [string]$Publisher,
        
        [switch]$ExactMatch
    )
    
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    $foundSoftware = @()
    
    foreach ($regPath in $regPaths) {
        try {
            if (Test-Path $regPath) {
                $subKeys = Get-ChildItem $regPath -ErrorAction SilentlyContinue
                
                foreach ($subKey in $subKeys) {
                    try {
                        $software = Get-ItemProperty $subKey.PSPath -ErrorAction SilentlyContinue
                        
                        if ($software.DisplayName) {
                            $nameMatch = if ($ExactMatch) {
                                $software.DisplayName -eq $Name
                            } else {
                                $software.DisplayName -like "*$Name*"
                            }
                            
                            $publisherMatch = if ($Publisher) {
                                $software.Publisher -like "*$Publisher*"
                            } else {
                                $true
                            }
                            
                            if ($nameMatch -and $publisherMatch) {
                                $foundSoftware += [PSCustomObject]@{
                                    DisplayName = $software.DisplayName
                                    Publisher = $software.Publisher
                                    Version = $software.DisplayVersion
                                    InstallDate = $software.InstallDate
                                    UninstallString = $software.UninstallString
                                    QuietUninstallString = $software.QuietUninstallString
                                    RegistryPath = $subKey.PSPath
                                    Architecture = if ($regPath -like "*WOW6432Node*") { "x86" } else { "x64" }
                                }
                            }
                        }
                    }
                    catch {
                        # Skip problematic registry entries
                        continue
                    }
                }
            }
        }
        catch {
            Write-RMMLog "Error accessing registry path $regPath`: $($_.Exception.Message)" -Level Warning
        }
    }
    
    if ($foundSoftware.Count -gt 0) {
        Write-RMMLog "Found $($foundSoftware.Count) software entries matching '$Name'" -Level Detect
    }
    
    return $foundSoftware
}

function Test-RMMSoftwareInstalled {
    <#
    .SYNOPSIS
    Quick test if software is installed (boolean result)
    
    .PARAMETER Name
    Software name to check for
    
    .PARAMETER Publisher
    Publisher name to filter by (optional)
    
    .PARAMETER MinVersion
    Minimum version required (optional)
    
    .EXAMPLE
    if (Test-RMMSoftwareInstalled -Name "Google Chrome") {
        Write-RMMLog "Chrome is installed" -Level Info
    }
    
    if (Test-RMMSoftwareInstalled -Name "Adobe Reader" -MinVersion "20.0") {
        Write-RMMLog "Adobe Reader 20.0+ is installed" -Level Info
    }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [string]$Publisher,
        
        [string]$MinVersion
    )
    
    $software = Get-RMMSoftware -Name $Name -Publisher $Publisher
    
    if (-not $software) {
        return $false
    }
    
    if ($MinVersion) {
        foreach ($app in $software) {
            if ($app.Version) {
                try {
                    $installedVersion = [Version]$app.Version
                    $requiredVersion = [Version]$MinVersion
                    if ($installedVersion -ge $requiredVersion) {
                        return $true
                    }
                }
                catch {
                    # Version comparison failed, assume it meets requirement
                    Write-RMMLog "Could not compare versions for $($app.DisplayName)" -Level Warning
                    return $true
                }
            }
        }
        return $false
    }
    
    return $true
}

function Get-RMMManufacturer {
    <#
    .SYNOPSIS
    Detects system manufacturer for targeted operations
    
    .PARAMETER IncludeModel
    Whether to include model information
    
    .EXAMPLE
    $manufacturer = Get-RMMManufacturer
    $systemInfo = Get-RMMManufacturer -IncludeModel
    #>
    param(
        [switch]$IncludeModel
    )
    
    try {
        $system = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop
        
        $result = [PSCustomObject]@{
            Manufacturer = $system.Manufacturer
            Model = if ($IncludeModel) { $system.Model } else { $null }
            IsHP = $system.Manufacturer -match "HP|Hewlett"
            IsDell = $system.Manufacturer -match "Dell"
            IsLenovo = $system.Manufacturer -match "Lenovo"
            IsMicrosoft = $system.Manufacturer -match "Microsoft"
            IsVMware = $system.Manufacturer -match "VMware"
        }
        
        Write-RMMLog "Detected manufacturer: $($result.Manufacturer)" -Level Detect
        
        return $result
    }
    catch {
        Write-RMMLog "Failed to detect manufacturer: $($_.Exception.Message)" -Level Warning
        return [PSCustomObject]@{
            Manufacturer = "Unknown"
            Model = $null
            IsHP = $false
            IsDell = $false
            IsLenovo = $false
            IsMicrosoft = $false
            IsVMware = $false
        }
    }
}

function Get-RMMUserSoftware {
    <#
    .SYNOPSIS
    Searches for software installed at user level (inspired by Datto experts)

    .DESCRIPTION
    Comprehensive user-level software detection using registry scanning.
    Based on expert Datto RMM monitor patterns for maximum performance.

    .PARAMETER SoftwareName
    Software name to search for (supports regex patterns)

    .PARAMETER IncludeSystemLevel
    Also search system-level installations

    .EXAMPLE
    $userSoftware = Get-RMMUserSoftware -SoftwareName "Chrome"
    $allChrome = Get-RMMUserSoftware -SoftwareName "Chrome" -IncludeSystemLevel
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SoftwareName,

        [switch]$IncludeSystemLevel
    )

    $results = @()

    try {
        # Search user-level software (Datto expert pattern)
        Get-ChildItem "Registry::HKEY_USERS\" -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer } | ForEach-Object {
            foreach ($node in @("Software", "Software\WOW6432Node")) {
                $uninstallPath = "Registry::$_\$node\Microsoft\Windows\CurrentVersion\Uninstall"

                if (Test-Path $uninstallPath -ErrorAction SilentlyContinue) {
                    try {
                        # Get user context information
                        $domainName = (Get-ItemProperty "Registry::$_\Volatile Environment" -Name USERDOMAIN -ErrorAction SilentlyContinue).USERDOMAIN
                        $username = (Get-ItemProperty "Registry::$_\Volatile Environment" -Name USERNAME -ErrorAction SilentlyContinue).USERNAME

                        Get-ChildItem $uninstallPath -ErrorAction SilentlyContinue | ForEach-Object {
                            $app = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue

                            if ($app.DisplayName -and $app.DisplayName -match [regex]::Escape($SoftwareName)) {
                                $results += [PSCustomObject]@{
                                    DisplayName = $app.DisplayName
                                    Version = $app.DisplayVersion
                                    Publisher = $app.Publisher
                                    InstallDate = $app.InstallDate
                                    InstallLocation = $app.InstallLocation
                                    UninstallString = $app.UninstallString
                                    UserContext = if ($domainName -and $username) { "$domainName\$username" } else { "Unknown User" }
                                    InstallLevel = "User-Level"
                                    Architecture = if ($node -like "*WOW6432Node*") { "x86" } else { "x64" }
                                    RegistryPath = $_.PSPath
                                }
                            }
                        }
                    } catch {
                        # Skip problematic user profiles
                        continue
                    }
                }
            }
        }

        # Include system-level if requested
        if ($IncludeSystemLevel) {
            $systemSoftware = Get-RMMSoftware -Name $SoftwareName
            foreach ($app in $systemSoftware) {
                $results += [PSCustomObject]@{
                    DisplayName = $app.DisplayName
                    Version = $app.Version
                    Publisher = $app.Publisher
                    InstallDate = $app.InstallDate
                    InstallLocation = $app.InstallLocation
                    UninstallString = $app.UninstallString
                    UserContext = "System-Level"
                    InstallLevel = "System-Level"
                    Architecture = $app.Architecture
                    RegistryPath = $app.RegistryPath
                }
            }
        }

        Write-RMMLog "Found $($results.Count) user-level software installations matching '$SoftwareName'" -Level Info
        return $results

    } catch {
        Write-RMMLog "Error searching user-level software: $($_.Exception.Message)" -Level Warning
        return @()
    }
}

function Test-RMMMultipleSoftware {
    <#
    .SYNOPSIS
    Tests multiple software installations with flexible alert logic (Datto expert pattern)

    .DESCRIPTION
    Advanced software detection supporting multiple search terms with configurable
    alert conditions. Based on expert Datto RMM monitor patterns.

    .PARAMETER SoftwareList
    Array of software names to search for

    .PARAMETER AlertMethod
    Alert method: "EQ" (alert if found), "NE" (alert if not found)

    .PARAMETER IncludeUserLevel
    Include user-level software installations

    .EXAMPLE
    $result = Test-RMMMultipleSoftware -SoftwareList @("Chrome", "Firefox") -AlertMethod "NE"
    $result = Test-RMMMultipleSoftware -SoftwareList @("Malware", "Adware") -AlertMethod "EQ" -IncludeUserLevel
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$SoftwareList,

        [ValidateSet("EQ", "NE")]
        [string]$AlertMethod = "NE",

        [switch]$IncludeUserLevel
    )

    $results = @()
    $alertTriggered = $false
    $alertMessages = @()

    foreach ($softwareName in $SoftwareList) {
        $softwareFound = $false
        $foundDetails = @()

        # Search system-level
        $systemSoftware = Get-RMMSoftware -Name $softwareName
        if ($systemSoftware) {
            $softwareFound = $true
            $foundDetails += "System-Level: $($systemSoftware[0].DisplayName)"
        }

        # Search user-level if requested
        if ($IncludeUserLevel) {
            $userSoftware = Get-RMMUserSoftware -SoftwareName $softwareName
            if ($userSoftware) {
                $softwareFound = $true
                foreach ($app in $userSoftware) {
                    $foundDetails += "User-Level ($($app.UserContext)): $($app.DisplayName)"
                }
            }
        }

        # Apply alert logic (Datto expert pattern)
        $shouldAlert = $false
        if ($AlertMethod -eq "EQ" -and $softwareFound) {
            $shouldAlert = $true
            $alertMessages += "Software '$softwareName' is installed: $($foundDetails -join '; ')"
        } elseif ($AlertMethod -eq "NE" -and -not $softwareFound) {
            $shouldAlert = $true
            $alertMessages += "Software '$softwareName' is not installed"
        }

        if ($shouldAlert) {
            $alertTriggered = $true
        }

        $results += [PSCustomObject]@{
            SoftwareName = $softwareName
            Found = $softwareFound
            Details = $foundDetails
            ShouldAlert = $shouldAlert
        }
    }

    return [PSCustomObject]@{
        Results = $results
        AlertTriggered = $alertTriggered
        AlertMessages = $alertMessages
        Summary = "$($results.Count) software items checked, $($results | Where-Object { $_.Found }).Count found"
    }
}

function Remove-RMMSoftware {
    <#
    .SYNOPSIS
    Safely removes software using multiple methods with timeout protection

    .PARAMETER SoftwareName
    Name of software to remove

    .PARAMETER TimeoutSec
    Timeout for removal operation

    .PARAMETER UseQuietUninstall
    Prefer quiet uninstall string if available

    .EXAMPLE
    Remove-RMMSoftware -SoftwareName "HP Wolf Security" -TimeoutSec 300
    Remove-RMMSoftware -SoftwareName "Bloatware App" -UseQuietUninstall
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SoftwareName,

        [int]$TimeoutSec = 300,

        [switch]$UseQuietUninstall
    )

    $software = Get-RMMSoftware -Name $SoftwareName

    if (-not $software) {
        Write-RMMLog "Software '$SoftwareName' not found for removal" -Level Warning
        return $false
    }

    $removed = $false
    
    foreach ($app in $software) {
        Write-RMMLog "Attempting to remove: $($app.DisplayName)" -Level Status
        
        try {
            $uninstallString = if ($UseQuietUninstall -and $app.QuietUninstallString) {
                $app.QuietUninstallString
            } else {
                $app.UninstallString
            }
            
            if ([string]::IsNullOrWhiteSpace($uninstallString)) {
                Write-RMMLog "No uninstall string found for $($app.DisplayName)" -Level Warning
                continue
            }
            
            # Parse uninstall string
            if ($uninstallString -match '^"([^"]+)"(.*)$') {
                $executable = $matches[1]
                $arguments = $matches[2].Trim()
            } else {
                $parts = $uninstallString -split ' ', 2
                $executable = $parts[0]
                $arguments = if ($parts.Length -gt 1) { $parts[1] } else { "" }
            }
            
            # Add silent flags if not present
            if ($arguments -notmatch "/S|/silent|/quiet|/q") {
                $arguments += " /S /silent"
            }
            
            Write-RMMLog "Executing: $executable $arguments" -Level Status
            
            $result = Invoke-RMMTimeout -Code {
                Start-Process -FilePath $executable -ArgumentList $arguments -Wait -NoNewWindow -PassThru
            } -TimeoutSec $TimeoutSec -OperationName "Uninstall $($app.DisplayName)"
            
            if ($result.ExitCode -eq 0 -or $result.ExitCode -eq 3010) {
                Write-RMMLog "Successfully removed: $($app.DisplayName)" -Level Success
                $removed = $true
            } else {
                Write-RMMLog "Uninstall returned exit code $($result.ExitCode) for $($app.DisplayName)" -Level Warning
            }
        }
        catch {
            Write-RMMLog "Failed to remove $($app.DisplayName): $($_.Exception.Message)" -Level Failed
        }
    }
    
    return $removed
}

# Export functions for module loading
Export-ModuleMember -Function @(
    'Get-RMMSoftware',
    'Test-RMMSoftwareInstalled',
    'Get-RMMManufacturer',
    'Remove-RMMSoftware'
)
