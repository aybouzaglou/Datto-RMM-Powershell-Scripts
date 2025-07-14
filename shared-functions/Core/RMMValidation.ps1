<#
.SYNOPSIS
RMM Validation Functions - Input validation and environment checks for Datto RMM scripts

.DESCRIPTION
Provides validation functions for Datto RMM environment variables, parameters, and system requirements:
- Environment variable validation with type conversion
- Parameter validation with required/optional handling
- System requirement checks (OS version, disk space, etc.)
- Timeout wrapper for safe operations
- Pre-flight validation helpers

.NOTES
Version: 3.0.0
Author: Datto RMM Function Library
Compatible: PowerShell 2.0+, Datto RMM Environment
#>

function Get-RMMVariable {
    <#
    .SYNOPSIS
    Gets and validates Datto RMM environment variables with type conversion
    
    .PARAMETER Name
    Environment variable name
    
    .PARAMETER Type
    Expected data type: String, Boolean, Integer
    
    .PARAMETER Default
    Default value if variable is not set
    
    .PARAMETER Required
    Whether the variable is required
    
    .EXAMPLE
    $customList = Get-RMMVariable -Name "customwhitelist" -Type "String"
    $skipWindows = Get-RMMVariable -Name "skipwindows" -Type "Boolean" -Default $false
    $timeout = Get-RMMVariable -Name "timeout" -Type "Integer" -Default 300 -Required
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [ValidateSet('String','Boolean','Integer')]
        [string]$Type = 'String',
        
        [object]$Default = '',
        
        [switch]$Required
    )
    
    $val = Get-Item "env:$Name" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value
    
    if ([string]::IsNullOrWhiteSpace($val)) {
        if ($Required) {
            Write-RMMLog "Input variable '$Name' required but not supplied" -Level Failed
            throw "Input '$Name' required but not supplied"
        }
        return $Default
    }
    
    switch ($Type) {
        'Boolean' { 
            return ($val -eq 'true' -or $val -eq '1' -or $val -eq 'yes')
        }
        'Integer' { 
            try {
                return [int]$val
            }
            catch {
                Write-RMMLog "Invalid integer value for '$Name': $val" -Level Warning
                return $Default
            }
        }
        default { 
            return $val 
        }
    }
}

function Test-RMMVariable {
    <#
    .SYNOPSIS
    Tests if a Datto RMM variable meets validation criteria
    
    .PARAMETER VariableName
    Name of the environment variable
    
    .PARAMETER VariableValue
    Value to validate (can be from environment or parameter)
    
    .PARAMETER Required
    Whether the variable is required
    
    .PARAMETER ValidValues
    Array of valid values (for validation)
    
    .EXAMPLE
    if (-not (Test-RMMVariable -VariableName "SoftwareName" -VariableValue $env:SoftwareName -Required)) {
        exit 12
    }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VariableName,
        
        [object]$VariableValue,
        
        [switch]$Required,
        
        [string[]]$ValidValues
    )
    
    if ([string]::IsNullOrWhiteSpace($VariableValue)) {
        if ($Required) {
            Write-RMMLog "Required variable '$VariableName' is missing or empty" -Level Failed
            return $false
        }
        return $true
    }
    
    if ($ValidValues -and $VariableValue -notin $ValidValues) {
        Write-RMMLog "Variable '$VariableName' has invalid value '$VariableValue'. Valid values: $($ValidValues -join ', ')" -Level Failed
        return $false
    }
    
    Write-RMMLog "Variable '$VariableName' validated successfully: $VariableValue" -Level Config
    return $true
}

function Invoke-RMMTimeout {
    <#
    .SYNOPSIS
    Universal timeout wrapper for safe operations in Datto RMM environment
    
    .PARAMETER Code
    Script block to execute with timeout protection
    
    .PARAMETER TimeoutSec
    Timeout in seconds (default: 300)
    
    .PARAMETER OperationName
    Name of the operation for logging
    
    .EXAMPLE
    $result = Invoke-RMMTimeout -Code {
        Get-AppxPackage -AllUsers
    } -TimeoutSec 60 -OperationName "Get AppX Packages"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$Code,
        
        [int]$TimeoutSec = 300,
        
        [string]$OperationName = "Operation"
    )
    
    try {
        Write-RMMLog "Starting timeout-protected operation: $OperationName (${TimeoutSec}s timeout)" -Level Status
        
        $job = Start-Job $Code
        if (Wait-Job $job -Timeout $TimeoutSec) {
            $result = Receive-Job $job
            Remove-Job $job -Force
            Write-RMMLog "Operation '$OperationName' completed successfully" -Level Success
            return $result
        } else {
            Stop-Job $job -Force
            Remove-Job $job -Force
            throw "Operation '$OperationName' exceeded ${TimeoutSec}s timeout"
        }
    }
    catch {
        Write-RMMLog "Timeout wrapper error for '$OperationName': $($_.Exception.Message)" -Level Failed
        throw
    }
}

function Test-RMMSystemRequirements {
    <#
    .SYNOPSIS
    Validates system requirements for script execution
    
    .PARAMETER MinPSVersion
    Minimum PowerShell version required
    
    .PARAMETER MinDiskSpaceGB
    Minimum free disk space in GB
    
    .PARAMETER RequiredServices
    Array of required services that must be running
    
    .PARAMETER RequiredFeatures
    Array of required Windows features
    
    .EXAMPLE
    if (-not (Test-RMMSystemRequirements -MinPSVersion 3.0 -MinDiskSpaceGB 1)) {
        exit 10
    }
    #>
    param(
        [double]$MinPSVersion,
        [double]$MinDiskSpaceGB,
        [string[]]$RequiredServices,
        [string[]]$RequiredFeatures
    )
    
    $allValid = $true
    
    # Check PowerShell version
    if ($MinPSVersion) {
        $currentVersion = $PSVersionTable.PSVersion.Major + ($PSVersionTable.PSVersion.Minor / 10)
        if ($currentVersion -lt $MinPSVersion) {
            Write-RMMLog "PowerShell version $currentVersion is below required $MinPSVersion" -Level Failed
            $allValid = $false
        } else {
            Write-RMMLog "PowerShell version $currentVersion meets requirement" -Level Config
        }
    }
    
    # Check disk space
    if ($MinDiskSpaceGB) {
        try {
            $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
            $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            if ($freeSpaceGB -lt $MinDiskSpaceGB) {
                Write-RMMLog "Free disk space ${freeSpaceGB}GB is below required ${MinDiskSpaceGB}GB" -Level Failed
                $allValid = $false
            } else {
                Write-RMMLog "Free disk space ${freeSpaceGB}GB meets requirement" -Level Config
            }
        }
        catch {
            Write-RMMLog "Could not check disk space: $($_.Exception.Message)" -Level Warning
        }
    }
    
    # Check required services
    if ($RequiredServices) {
        foreach ($serviceName in $RequiredServices) {
            try {
                $service = Get-Service -Name $serviceName -ErrorAction Stop
                if ($service.Status -ne 'Running') {
                    Write-RMMLog "Required service '$serviceName' is not running (Status: $($service.Status))" -Level Failed
                    $allValid = $false
                } else {
                    Write-RMMLog "Required service '$serviceName' is running" -Level Config
                }
            }
            catch {
                Write-RMMLog "Required service '$serviceName' not found" -Level Failed
                $allValid = $false
            }
        }
    }
    
    return $allValid
}

function Test-RMMInternetConnectivity {
    <#
    .SYNOPSIS
    Tests internet connectivity for download operations
    
    .PARAMETER TestUrls
    URLs to test (default: common reliable endpoints)
    
    .PARAMETER TimeoutSec
    Timeout for each test in seconds
    
    .EXAMPLE
    if (-not (Test-RMMInternetConnectivity)) {
        Write-RMMLog "No internet connectivity available" -Level Warning
    }
    #>
    param(
        [string[]]$TestUrls = @('https://www.google.com', 'https://www.microsoft.com'),
        [int]$TimeoutSec = 10
    )
    
    foreach ($url in $TestUrls) {
        try {
            $request = [System.Net.WebRequest]::Create($url)
            $request.Timeout = $TimeoutSec * 1000
            $response = $request.GetResponse()
            $response.Close()
            Write-RMMLog "Internet connectivity confirmed via $url" -Level Config
            return $true
        }
        catch {
            Write-RMMLog "Failed to connect to $url`: $($_.Exception.Message)" -Level Warning
        }
    }
    
    Write-RMMLog "No internet connectivity detected" -Level Failed
    return $false
}

# Export functions for module loading
Export-ModuleMember -Function @(
    'Get-RMMVariable',
    'Test-RMMVariable', 
    'Invoke-RMMTimeout',
    'Test-RMMSystemRequirements',
    'Test-RMMInternetConnectivity'
)
