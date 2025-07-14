# Datto RMM API Integration Module
# This module provides functions to interact with the Datto RMM API

#Requires -Version 5.1

# Base configuration
$script:DattoApiBase = "https://concord-api.centrastage.net/api/v2"
$script:ApiKey = $null
$script:Headers = @{
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
}

<#
.SYNOPSIS
    Initializes the Datto RMM API connection
.DESCRIPTION
    Sets up authentication and base configuration for Datto RMM API calls
.PARAMETER ApiKey
    The API key for authentication
.EXAMPLE
    Initialize-DattoRMMAPI -ApiKey "your-api-key"
#>
function Initialize-DattoRMMAPI {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )
    
    $script:ApiKey = $ApiKey
    $script:Headers['Authorization'] = "Bearer $ApiKey"
    
    Write-Verbose "Datto RMM API initialized successfully"
}

<#
.SYNOPSIS
    Gets all components from Datto RMM
.DESCRIPTION
    Retrieves a list of all components available in the Datto RMM system
.EXAMPLE
    Get-DattoComponents
#>
function Get-DattoComponents {
    try {
        $uri = "$script:DattoApiBase/components"
        $response = Invoke-RestMethod -Uri $uri -Headers $script:Headers -Method Get
        return $response
    }
    catch {
        Write-Error "Failed to retrieve components: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Gets a specific component by ID
.DESCRIPTION
    Retrieves details of a specific component from Datto RMM
.PARAMETER ComponentId
    The ID of the component to retrieve
.EXAMPLE
    Get-DattoComponent -ComponentId "12345"
#>
function Get-DattoComponent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComponentId
    )
    
    try {
        $uri = "$script:DattoApiBase/components/$ComponentId"
        $response = Invoke-RestMethod -Uri $uri -Headers $script:Headers -Method Get
        return $response
    }
    catch {
        Write-Error "Failed to retrieve component $ComponentId: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Creates a new component in Datto RMM
.DESCRIPTION
    Creates a new PowerShell component in the Datto RMM system
.PARAMETER Name
    The name of the component
.PARAMETER Description
    The description of the component
.PARAMETER ScriptContent
    The PowerShell script content
.PARAMETER Category
    The category for the component
.EXAMPLE
    New-DattoComponent -Name "System Info" -Description "Gets system information" -ScriptContent $scriptContent -Category "Information"
#>
function New-DattoComponent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$Description,
        
        [Parameter(Mandatory = $true)]
        [string]$ScriptContent,
        
        [Parameter(Mandatory = $false)]
        [string]$Category = "Custom"
    )
    
    try {
        $body = @{
            name = $Name
            description = $Description
            script = $ScriptContent
            category = $Category
            scriptType = "PowerShell"
        } | ConvertTo-Json -Depth 10
        
        $uri = "$script:DattoApiBase/components"
        $response = Invoke-RestMethod -Uri $uri -Headers $script:Headers -Method Post -Body $body
        
        Write-Verbose "Component '$Name' created successfully with ID: $($response.id)"
        return $response
    }
    catch {
        Write-Error "Failed to create component '$Name': $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Updates an existing component in Datto RMM
.DESCRIPTION
    Updates an existing PowerShell component in the Datto RMM system
.PARAMETER ComponentId
    The ID of the component to update
.PARAMETER Name
    The new name of the component
.PARAMETER Description
    The new description of the component
.PARAMETER ScriptContent
    The new PowerShell script content
.EXAMPLE
    Update-DattoComponent -ComponentId "12345" -Name "Updated System Info" -Description "Updated description" -ScriptContent $newScriptContent
#>
function Update-DattoComponent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComponentId,
        
        [Parameter(Mandatory = $false)]
        [string]$Name,
        
        [Parameter(Mandatory = $false)]
        [string]$Description,
        
        [Parameter(Mandatory = $false)]
        [string]$ScriptContent
    )
    
    try {
        # Get existing component first
        $existingComponent = Get-DattoComponent -ComponentId $ComponentId
        
        $body = @{
            name = if ($Name) { $Name } else { $existingComponent.name }
            description = if ($Description) { $Description } else { $existingComponent.description }
            script = if ($ScriptContent) { $ScriptContent } else { $existingComponent.script }
        } | ConvertTo-Json -Depth 10
        
        $uri = "$script:DattoApiBase/components/$ComponentId"
        $response = Invoke-RestMethod -Uri $uri -Headers $script:Headers -Method Put -Body $body
        
        Write-Verbose "Component '$ComponentId' updated successfully"
        return $response
    }
    catch {
        Write-Error "Failed to update component '$ComponentId': $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Executes a component on specified devices
.DESCRIPTION
    Runs a component on one or more devices in Datto RMM
.PARAMETER ComponentId
    The ID of the component to execute
.PARAMETER DeviceIds
    Array of device IDs to execute the component on
.PARAMETER SiteId
    Optional site ID to limit execution to devices in a specific site
.EXAMPLE
    Invoke-DattoComponent -ComponentId "12345" -DeviceIds @("device1", "device2")
#>
function Invoke-DattoComponent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComponentId,
        
        [Parameter(Mandatory = $true)]
        [string[]]$DeviceIds,
        
        [Parameter(Mandatory = $false)]
        [string]$SiteId
    )
    
    try {
        $body = @{
            componentId = $ComponentId
            deviceIds = $DeviceIds
        }
        
        if ($SiteId) {
            $body.siteId = $SiteId
        }
        
        $bodyJson = $body | ConvertTo-Json -Depth 10
        
        $uri = "$script:DattoApiBase/jobs"
        $response = Invoke-RestMethod -Uri $uri -Headers $script:Headers -Method Post -Body $bodyJson
        
        Write-Verbose "Component execution job created with ID: $($response.jobId)"
        return $response
    }
    catch {
        Write-Error "Failed to execute component '$ComponentId': $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Gets the status of a job
.DESCRIPTION
    Retrieves the status and results of a job execution
.PARAMETER JobId
    The ID of the job to check
.EXAMPLE
    Get-DattoJobStatus -JobId "job123"
#>
function Get-DattoJobStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$JobId
    )
    
    try {
        $uri = "$script:DattoApiBase/jobs/$JobId"
        $response = Invoke-RestMethod -Uri $uri -Headers $script:Headers -Method Get
        return $response
    }
    catch {
        Write-Error "Failed to retrieve job status for '$JobId': $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Gets all devices from Datto RMM
.DESCRIPTION
    Retrieves a list of all devices in the Datto RMM system
.PARAMETER SiteId
    Optional site ID to filter devices by site
.EXAMPLE
    Get-DattoDevices
    Get-DattoDevices -SiteId "site123"
#>
function Get-DattoDevices {
    param(
        [Parameter(Mandatory = $false)]
        [string]$SiteId
    )
    
    try {
        $uri = "$script:DattoApiBase/devices"
        if ($SiteId) {
            $uri += "?siteId=$SiteId"
        }
        
        $response = Invoke-RestMethod -Uri $uri -Headers $script:Headers -Method Get
        return $response
    }
    catch {
        Write-Error "Failed to retrieve devices: $($_.Exception.Message)"
        throw
    }
}

# Export functions
Export-ModuleMember -Function Initialize-DattoRMMAPI, Get-DattoComponents, Get-DattoComponent, 
                             New-DattoComponent, Update-DattoComponent, Invoke-DattoComponent, 
                             Get-DattoJobStatus, Get-DattoDevices