# Quick API Deployment Script for Datto RMM
# Simplified script to get you started with API-based deployment

<#
.SYNOPSIS
    Quick deployment of test device setup using Datto RMM API
.DESCRIPTION
    Simplified script to deploy the test device setup component using the Datto RMM API.
    This gets you started with API-based deployment without complex error handling.
.PARAMETER ApiKey
    Your Datto RMM API key
.PARAMETER ApiSecret  
    Your Datto RMM API secret
.PARAMETER TestDeviceId
    Device ID of your Windows VM (find this in RMM console URL)
.EXAMPLE
    .\quick-api-deploy.ps1 -ApiKey "your-key" -ApiSecret "your-secret" -TestDeviceId "12345"
.NOTES
    This is a simplified version to get started. Use the full deploy-test-device-api.ps1 for production.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,
    
    [Parameter(Mandatory = $true)]
    [string]$ApiSecret,
    
    [Parameter(Mandatory = $true)]
    [string]$TestDeviceId
)

# Configuration
$ApiUrl = "https://concord-api.centrastage.net/api"
$ComponentName = "Setup-TestDevice-API"

Write-Output "=== Quick Datto RMM API Deployment ==="
Write-Output "API URL: $ApiUrl"
Write-Output "Target Device: $TestDeviceId"
Write-Output "Component: $ComponentName"
Write-Output ""

# Step 1: Get OAuth access token (using official Datto method)
Write-Output "1. Getting OAuth access token..."
try {
    # Set TLS 1.2 for macOS/PowerShell Core compatibility
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {
        # PowerShell Core on macOS might not support this, continue anyway
        Write-Warning "Could not set SecurityProtocol, continuing..."
    }

    # Convert password to secure string (from official example)
    $securePassword = ConvertTo-SecureString -String 'public' -AsPlainText -Force

    # Define parameters for Invoke-WebRequest cmdlet (from official example)
    $tokenParams = @{
        Credential  = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('public-client', $securePassword)
        Uri         = "$ApiUrl/auth/oauth/token"
        Method      = 'POST'
        ContentType = 'application/x-www-form-urlencoded'
        Body        = "grant_type=password&username=$ApiKey&password=$ApiSecret"
    }

    # Request access token (using official method)
    $tokenResponse = Invoke-WebRequest @tokenParams | ConvertFrom-Json
    $accessToken = $tokenResponse.access_token

    Write-Output "✓ OAuth token obtained successfully (official method)"
} catch {
    Write-Error "❌ Failed to get OAuth token: $($_.Exception.Message)"
    Write-Output "Please check your API credentials and try again."
    exit 1
}

# Step 2: Set up headers with Bearer token
Write-Output "`n2. Setting up API headers..."
$headers = @{
    'Authorization' = "Bearer $accessToken"
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
}

Write-Output "✓ Authentication headers configured"

# Step 3: Test API connection
Write-Output "`n3. Testing API connection..."
try {
    $testUri = "$ApiUrl/v2/account"
    $accountInfo = Invoke-RestMethod -Uri $testUri -Headers $headers -Method Get
    Write-Output "✓ API connection successful"
    Write-Output "  Account: $($accountInfo.companyName)"
} catch {
    Write-Error "❌ API connection failed: $($_.Exception.Message)"
    Write-Output "Please check your API credentials and try again."
    exit 1
}

# Step 4: Verify test device exists
Write-Output "`n4. Verifying test device..."
try {
    $deviceUri = "$ApiUrl/v2/device/$TestDeviceId"
    $device = Invoke-RestMethod -Uri $deviceUri -Headers $headers -Method Get
    Write-Output "✓ Test device found: $($device.hostname)"
    Write-Output "  OS: $($device.operatingSystem)"
    Write-Output "  Online: $($device.online)"
} catch {
    Write-Error "❌ Test device not found: $TestDeviceId"
    Write-Output "Please check the device ID and try again."
    exit 1
}

# Step 5: Read component script
Write-Output "`n5. Reading component script..."
$scriptPath = "components/Scripts/Setup-TestDevice.ps1"
if (-not (Test-Path $scriptPath)) {
    Write-Error "❌ Component script not found: $scriptPath"
    Write-Output "Please ensure you're running this from the repository root."
    exit 1
}

$scriptContent = Get-Content $scriptPath -Raw
Write-Output "✓ Component script loaded ($($scriptContent.Length) characters)"

# Step 6: Create or update component
Write-Output "`n6. Creating/updating component..."
try {
    # Check if component exists
    $componentsUri = "$ApiUrl/v2/account/components"
    $existingComponents = Invoke-RestMethod -Uri $componentsUri -Headers $headers -Method Get
    $existingComponent = $existingComponents | Where-Object { $_.name -eq $ComponentName }

    $componentData = @{
        name = $ComponentName
        description = "Test device setup deployed via API"
        category = "Scripts"
        script = $scriptContent
        environmentVariables = @{
            TestResultsPath = "C:\TestResults"
            CleanupOldResults = "7"
        }
    }

    if ($existingComponent) {
        Write-Output "⚠ Component exists, updating..."
        $updateUri = "$ApiUrl/v2/component/$($existingComponent.uid)"
        $component = Invoke-RestMethod -Uri $updateUri -Headers $headers -Method Put -Body ($componentData | ConvertTo-Json -Depth 3)
        $componentId = $existingComponent.uid
    } else {
        Write-Output "✓ Creating new component..."
        $component = Invoke-RestMethod -Uri $componentsUri -Headers $headers -Method Post -Body ($componentData | ConvertTo-Json -Depth 3)
        $componentId = $component.uid
    }

    Write-Output "✓ Component ready: $ComponentName (ID: $componentId)"

} catch {
    Write-Error "❌ Failed to create component: $($_.Exception.Message)"
    Write-Output "Response: $($_.Exception.Response)"
    exit 1
}

# Step 7: Deploy to test device
Write-Output "`n7. Deploying to test device..."
try {
    $jobData = @{
        componentUid = $componentId
        deviceUids = @($TestDeviceId)
        name = "API Test Device Setup"
        description = "Automated test device setup via API"
    }

    $jobsUri = "$ApiUrl/v2/device/$TestDeviceId/quickjob"
    $job = Invoke-RestMethod -Uri $jobsUri -Headers $headers -Method Put -Body ($jobData | ConvertTo-Json -Depth 3)
    $jobId = $job.uid

    Write-Output "✓ Deployment job started: $jobId"

} catch {
    Write-Error "❌ Failed to start deployment job: $($_.Exception.Message)"
    exit 1
}

# Step 8: Monitor job (simplified)
Write-Output "`n8. Monitoring job execution..."
Write-Output "Job ID: $jobId"
Write-Output ""
Write-Output "You can monitor the job progress in your Datto RMM console:"
Write-Output "- Go to Jobs section"
Write-Output "- Look for job: 'API Test Device Setup'"
Write-Output "- Check execution status and logs"
Write-Output ""

# Wait a bit and check initial status
Start-Sleep -Seconds 10
try {
    $jobStatusUri = "$ApiUrl/v2/job/$jobId"
    $jobStatus = Invoke-RestMethod -Uri $jobStatusUri -Headers $headers -Method Get
    Write-Output "Current job status: $($jobStatus.status)"

    if ($jobStatus.status -eq "completed") {
        Write-Output "✓ Job completed successfully!"
        Write-Output "Exit code: $($jobStatus.exitCode)"
    } elseif ($jobStatus.status -eq "active") {
        Write-Output "⏳ Job is still running..."
        Write-Output "Check the RMM console for real-time updates."
    } else {
        Write-Output "Status: $($jobStatus.status)"
    }

} catch {
    Write-Warning "Could not check job status immediately. Check RMM console."
}

Write-Output "`n=== Deployment Summary ==="
Write-Output "✓ API connection established"
Write-Output "✓ Test device verified: $TestDeviceId"
Write-Output "✓ Component created/updated: $ComponentName (ID: $componentId)"
Write-Output "✓ Deployment job started: $jobId"
Write-Output ""
Write-Output "Next steps:"
Write-Output "1. Check job execution in Datto RMM console"
Write-Output "2. Verify C:\TestResults directory was created on test device"
Write-Output "3. Deploy test components using the same API approach"
Write-Output "4. Set up GitHub Actions for automated deployment"
Write-Output ""
Write-Output "🎉 API-based deployment is working!"
