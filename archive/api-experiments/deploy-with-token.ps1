# Deploy using access token from Postman
# This script uses a pre-obtained OAuth token for deployment

param(
    [Parameter(Mandatory = $true)]
    [string]$AccessToken,
    
    [Parameter(Mandatory = $true)]
    [string]$TestDeviceId,
    
    [Parameter(Mandatory = $false)]
    [string]$ComponentPath = "components/Scripts/Setup-TestDevice.ps1"
)

$ApiUrl = "https://concord-api.centrastage.net/api"
$ComponentName = "Setup-TestDevice-API"

Write-Output "=== Datto RMM API Deployment with Token ==="
Write-Output "API URL: $ApiUrl"
Write-Output "Target Device: $TestDeviceId"
Write-Output "Component: $ComponentName"
Write-Output "Token: $($AccessToken.Substring(0, [Math]::Min(20, $AccessToken.Length)))..."
Write-Output ""

# Set up headers with Bearer token
$headers = @{
    'Authorization' = "Bearer $AccessToken"
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
}

# Step 1: Test API connection
Write-Output "1. Testing API connection..."
try {
    $testUri = "$ApiUrl/v2/account"
    $accountInfo = Invoke-RestMethod -Uri $testUri -Headers $headers -Method Get
    Write-Output "✅ API connection successful"
    Write-Output "  Account: $($accountInfo.companyName)"
    Write-Output "  Account ID: $($accountInfo.uid)"
} catch {
    Write-Error "❌ API connection failed: $($_.Exception.Message)"
    Write-Output "Please check your access token and try again."
    exit 1
}

# Step 2: Verify test device exists
Write-Output "`n2. Verifying test device..."
try {
    $deviceUri = "$ApiUrl/v2/device/$TestDeviceId"
    $device = Invoke-RestMethod -Uri $deviceUri -Headers $headers -Method Get
    Write-Output "✅ Test device found: $($device.hostname)"
    Write-Output "  OS: $($device.operatingSystem)"
    Write-Output "  Online: $($device.online)"
} catch {
    Write-Error "❌ Test device not found: $TestDeviceId"
    Write-Output "Please check the device ID and try again."
    exit 1
}

# Step 3: Read component script
Write-Output "`n3. Reading component script..."
if (-not (Test-Path $ComponentPath)) {
    Write-Error "❌ Component script not found: $ComponentPath"
    exit 1
}

$scriptContent = Get-Content $ComponentPath -Raw
Write-Output "✅ Component script loaded ($($scriptContent.Length) characters)"

# Step 4: Create or update component
Write-Output "`n4. Creating/updating component..."
try {
    # Check if component exists
    $componentsUri = "$ApiUrl/v2/account/components"
    $existingComponents = Invoke-RestMethod -Uri $componentsUri -Headers $headers -Method Get
    $existingComponent = $existingComponents | Where-Object { $_.name -eq $ComponentName }
    
    $componentData = @{
        name = $ComponentName
        description = "Test device setup deployed via API with token"
        category = "Scripts"
        script = $scriptContent
        environmentVariables = @{
            TestResultsPath = "C:\TestResults"
            CleanupOldResults = "7"
        }
    }
    
    if ($existingComponent) {
        Write-Output "⚠️ Component exists, updating..."
        $updateUri = "$ApiUrl/v2/component/$($existingComponent.uid)"
        $component = Invoke-RestMethod -Uri $updateUri -Headers $headers -Method Put -Body ($componentData | ConvertTo-Json -Depth 3)
        $componentId = $existingComponent.uid
    } else {
        Write-Output "✅ Creating new component..."
        $component = Invoke-RestMethod -Uri $componentsUri -Headers $headers -Method Post -Body ($componentData | ConvertTo-Json -Depth 3)
        $componentId = $component.uid
    }
    
    Write-Output "✅ Component ready: $ComponentName (ID: $componentId)"
    
} catch {
    Write-Error "❌ Failed to create component: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode
        Write-Output "Status Code: $statusCode"
    }
    exit 1
}

# Step 5: Deploy to test device
Write-Output "`n5. Deploying to test device..."
try {
    $jobData = @{
        componentUid = $componentId
        name = "API Test Device Setup (Token)"
        description = "Automated test device setup via API using token"
    }
    
    $jobsUri = "$ApiUrl/v2/device/$TestDeviceId/quickjob"
    $job = Invoke-RestMethod -Uri $jobsUri -Headers $headers -Method Put -Body ($jobData | ConvertTo-Json -Depth 3)
    $jobId = $job.uid
    
    Write-Output "✅ Deployment job started: $jobId"
    
} catch {
    Write-Error "❌ Failed to start deployment job: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode
        Write-Output "Status Code: $statusCode"
    }
    exit 1
}

# Step 6: Monitor job (simplified)
Write-Output "`n6. Monitoring job execution..."

# Wait a bit and check initial status
Start-Sleep -Seconds 10
try {
    $jobStatusUri = "$ApiUrl/v2/job/$jobId"
    $jobStatus = Invoke-RestMethod -Uri $jobStatusUri -Headers $headers -Method Get
    Write-Output "Current job status: $($jobStatus.status)"
    
    if ($jobStatus.status -eq "completed") {
        Write-Output "✅ Job completed successfully!"
        if ($jobStatus.exitCode) {
            Write-Output "Exit code: $($jobStatus.exitCode)"
        }
    } elseif ($jobStatus.status -eq "active") {
        Write-Output "⏳ Job is still running..."
        Write-Output "Check the RMM console for real-time updates."
    } else {
        Write-Output "Status: $($jobStatus.status)"
    }
    
} catch {
    Write-Warning "Could not check job status immediately. Check RMM console."
}

Write-Output ""
Write-Output "🎉 Deployment completed!"
Write-Output ""
Write-Output "Next steps:"
Write-Output "1. Check the job status in Datto RMM console"
Write-Output "2. Verify test environment setup on device: $TestDeviceId"
Write-Output "3. Look for C:\TestResults directory on the target device"
Write-Output ""
Write-Output "Job ID: $jobId"
Write-Output "Component ID: $componentId"

exit 0
