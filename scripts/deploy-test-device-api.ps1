# Deploy Test Device Setup via Datto RMM API
# This script uses the Datto RMM API to deploy and execute the test device setup

<#
.SYNOPSIS
    Deploys test device setup using Datto RMM API
.DESCRIPTION
    Automates the deployment of test device setup components using the Datto RMM API.
    Creates components, deploys to test device, executes, and collects results.
.PARAMETER ApiKey
    Datto RMM API key
.PARAMETER ApiSecret
    Datto RMM API secret
.PARAMETER ApiUrl
    Datto RMM API base URL
.PARAMETER TestDeviceId
    Device ID of the Windows VM to use for testing
.PARAMETER ComponentPath
    Path to the component script file
.EXAMPLE
    .\deploy-test-device-api.ps1 -ApiKey "key" -ApiSecret "secret" -TestDeviceId "12345" -ComponentPath "components/Scripts/Setup-TestDevice.ps1"
.NOTES
    Author: Datto RMM Automation Team
    Version: 1.0
    Created: 2025-07-14
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,
    
    [Parameter(Mandatory = $true)]
    [string]$ApiSecret,
    
    [Parameter(Mandatory = $false)]
    [string]$ApiUrl = "https://concord-api.centrastage.net/api",
    
    [Parameter(Mandatory = $true)]
    [string]$TestDeviceId,
    
    [Parameter(Mandatory = $true)]
    [string]$ComponentPath,
    
    [Parameter(Mandatory = $false)]
    [string]$ComponentName = "Setup-TestDevice",
    
    [Parameter(Mandatory = $false)]
    [hashtable]$EnvironmentVariables = @{
        TestResultsPath = "C:\TestResults"
        CleanupOldResults = "7"
        Force = "false"
    }
)

# Import the Datto RMM API module from the CI/CD branch
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$apiModulePath = Join-Path $scriptPath "DattoRMMAPI.psm1"

if (-not (Test-Path $apiModulePath)) {
    Write-Error "DattoRMMAPI.psm1 module not found. Please ensure you have the CI/CD pipeline files."
    exit 1
}

Import-Module $apiModulePath -Force

# Initialize API connection
try {
    Write-Output "=== Datto RMM API Deployment ==="
    Write-Output "Initializing API connection..."
    
    Initialize-DattoRMMAPI -ApiKey $ApiKey -ApiSecret $ApiSecret -ApiUrl $ApiUrl
    Write-Output "✓ API connection initialized"
    
} catch {
    Write-Error "Failed to initialize API connection: $($_.Exception.Message)"
    exit 1
}

# Verify test device exists
try {
    Write-Output "`nVerifying test device..."
    $testDevice = Get-DattoDevice -DeviceId $TestDeviceId
    
    if ($testDevice) {
        Write-Output "✓ Test device found: $($testDevice.hostname) (ID: $TestDeviceId)"
        Write-Output "  OS: $($testDevice.operatingSystem)"
        Write-Output "  Status: $($testDevice.online)"
    } else {
        Write-Error "Test device not found with ID: $TestDeviceId"
        exit 1
    }
    
} catch {
    Write-Error "Failed to verify test device: $($_.Exception.Message)"
    exit 1
}

# Read component script content
try {
    Write-Output "`nReading component script..."
    
    if (-not (Test-Path $ComponentPath)) {
        Write-Error "Component script not found: $ComponentPath"
        exit 1
    }
    
    $scriptContent = Get-Content $ComponentPath -Raw
    Write-Output "✓ Component script loaded: $ComponentPath"
    Write-Output "  Size: $($scriptContent.Length) characters"
    
} catch {
    Write-Error "Failed to read component script: $($_.Exception.Message)"
    exit 1
}

# Check if component already exists
try {
    Write-Output "`nChecking for existing component..."
    $existingComponent = Get-DattoComponents | Where-Object { $_.name -eq $ComponentName }
    
    if ($existingComponent) {
        Write-Output "⚠ Component '$ComponentName' already exists (ID: $($existingComponent.id))"
        Write-Output "  Updating existing component..."
        
        $componentResult = Update-DattoComponent -ComponentId $existingComponent.id -ScriptContent $scriptContent -EnvironmentVariables $EnvironmentVariables
        $componentId = $existingComponent.id
    } else {
        Write-Output "✓ Component '$ComponentName' does not exist, creating new..."
        
        # Create new component
        $componentResult = New-DattoComponent -Name $ComponentName -Type "Scripts" -ScriptContent $scriptContent -EnvironmentVariables $EnvironmentVariables
        $componentId = $componentResult.id
    }
    
    Write-Output "✓ Component ready: $ComponentName (ID: $componentId)"
    
} catch {
    Write-Error "Failed to create/update component: $($_.Exception.Message)"
    exit 1
}

# Deploy component to test device
try {
    Write-Output "`nDeploying component to test device..."
    
    $jobResult = Start-DattoJob -ComponentId $componentId -DeviceIds @($TestDeviceId) -JobName "Setup Test Device Environment"
    $jobId = $jobResult.id
    
    Write-Output "✓ Deployment job started: $jobId"
    Write-Output "  Component: $ComponentName"
    Write-Output "  Target: $TestDeviceId"
    
} catch {
    Write-Error "Failed to deploy component: $($_.Exception.Message)"
    exit 1
}

# Monitor job execution
try {
    Write-Output "`nMonitoring job execution..."
    $timeout = 600 # 10 minutes
    $startTime = Get-Date
    $jobCompleted = $false
    
    do {
        Start-Sleep -Seconds 10
        $jobStatus = Get-DattoJobStatus -JobId $jobId
        $elapsed = (Get-Date) - $startTime
        
        Write-Output "  Status: $($jobStatus.status) | Elapsed: $([math]::Round($elapsed.TotalSeconds))s"
        
        if ($jobStatus.status -in @("Completed", "Failed", "Cancelled")) {
            $jobCompleted = $true
            break
        }
        
        if ($elapsed.TotalSeconds -gt $timeout) {
            Write-Warning "Job execution timeout reached ($timeout seconds)"
            break
        }
        
    } while (-not $jobCompleted)
    
    if ($jobCompleted) {
        Write-Output "✓ Job completed with status: $($jobStatus.status)"
        
        # Get detailed job results
        $jobDetails = Get-DattoJobDetails -JobId $jobId
        Write-Output "  Exit Code: $($jobDetails.exitCode)"
        Write-Output "  Execution Time: $($jobDetails.executionTime)s"
        
        if ($jobDetails.exitCode -eq 0) {
            Write-Output "✓ Test device setup completed successfully!"
        } else {
            Write-Warning "Test device setup completed with warnings/errors (Exit Code: $($jobDetails.exitCode))"
        }
        
        # Display job output
        if ($jobDetails.output) {
            Write-Output "`n--- Job Output ---"
            Write-Output $jobDetails.output
            Write-Output "--- End Output ---"
        }
        
    } else {
        Write-Warning "Job monitoring timed out - job may still be running"
    }
    
} catch {
    Write-Error "Failed to monitor job execution: $($_.Exception.Message)"
    exit 1
}

# Verify test environment setup
try {
    Write-Output "`nVerifying test environment setup..."
    
    # Deploy validation component
    $validationScript = Join-Path (Split-Path $ComponentPath) "Validate-TestEnvironment.ps1"
    
    if (Test-Path $validationScript) {
        Write-Output "Running validation script..."
        
        $validationContent = Get-Content $validationScript -Raw
        $validationComponent = New-DattoComponent -Name "Validate-TestEnvironment-Temp" -Type "Scripts" -ScriptContent $validationContent
        
        $validationJob = Start-DattoJob -ComponentId $validationComponent.id -DeviceIds @($TestDeviceId) -JobName "Validate Test Environment"
        
        # Wait for validation to complete
        Start-Sleep -Seconds 30
        $validationStatus = Get-DattoJobStatus -JobId $validationJob.id
        $validationDetails = Get-DattoJobDetails -JobId $validationJob.id
        
        if ($validationDetails.exitCode -eq 0) {
            Write-Output "✓ Test environment validation passed!"
        } else {
            Write-Warning "Test environment validation failed or has warnings"
        }
        
        # Clean up temporary validation component
        Remove-DattoComponent -ComponentId $validationComponent.id
        
    } else {
        Write-Output "⚠ Validation script not found, skipping validation"
    }
    
} catch {
    Write-Warning "Failed to run validation: $($_.Exception.Message)"
}

# Summary
Write-Output "`n=== Deployment Summary ==="
Write-Output "Component: $ComponentName (ID: $componentId)"
Write-Output "Test Device: $TestDeviceId"
Write-Output "Job: $jobId"
Write-Output "Status: $($jobStatus.status)"

if ($jobDetails.exitCode -eq 0) {
    Write-Output "✓ Test device is ready for automated testing!"
    Write-Output ""
    Write-Output "Next steps:"
    Write-Output "1. Deploy test components using the same API approach"
    Write-Output "2. Set up GitHub Actions workflow for automated deployment"
    Write-Output "3. Configure CI/CD pipeline for continuous testing"
    
    exit 0
} else {
    Write-Output "❌ Test device setup needs attention"
    Write-Output "Check the job output above for details"
    
    exit 1
}
