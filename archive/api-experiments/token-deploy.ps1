# Simple token-based deployment
# Get token from Postman, then use this script for deployment

param(
    [Parameter(Mandatory = $false)]
    [string]$Token,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "config/api-config.json"
)

Write-Output "=== Token-Based Datto RMM Deployment ==="
Write-Output ""

# Load configuration
if (-not (Test-Path $ConfigPath)) {
    Write-Error "❌ Configuration file not found: $ConfigPath"
    Write-Output "Please create the config file first."
    exit 1
}

try {
    $config = Get-Content $ConfigPath | ConvertFrom-Json
    $testDeviceId = $config.datto.testDeviceId
    Write-Output "✅ Configuration loaded"
    Write-Output "  Test Device ID: $testDeviceId"
} catch {
    Write-Error "❌ Failed to parse configuration: $($_.Exception.Message)"
    exit 1
}

# Get token
if (-not $Token) {
    Write-Output ""
    Write-Output "🔑 ACCESS TOKEN REQUIRED"
    Write-Output "========================"
    Write-Output ""
    Write-Output "To get your access token:"
    Write-Output "1. Open Postman"
    Write-Output "2. Set up OAuth 2.0 with these settings:"
    Write-Output "   - Grant Type: Authorization Code"
    Write-Output "   - Auth URL: https://concord-api.centrastage.net/api/auth/oauth/authorize"
    Write-Output "   - Access Token URL: https://concord-api.centrastage.net/api/auth/oauth/token"
    Write-Output "   - Client ID: public-client"
    Write-Output "   - Client Secret: public"
    Write-Output "   - Username: $($config.datto.apiKey)"
    Write-Output "   - Password: $($config.datto.apiSecret)"
    Write-Output "3. Click 'Get New Access Token'"
    Write-Output "4. Copy the token"
    Write-Output "5. Run this script with the token:"
    Write-Output ""
    Write-Output "   pwsh -File scripts/token-deploy.ps1 -Token 'YOUR_TOKEN_HERE'"
    Write-Output ""
    exit 1
}

# Validate token format
if ($Token.Length -lt 50) {
    Write-Error "❌ Token appears to be too short. Please check you copied the full token."
    exit 1
}

Write-Output "✅ Token provided: $($Token.Substring(0, [Math]::Min(20, $Token.Length)))..."
Write-Output ""

# Deploy using the token
try {
    $deployParams = @{
        AccessToken = $Token
        TestDeviceId = $testDeviceId
    }
    
    $scriptPath = Join-Path (Split-Path $MyInvocation.MyCommand.Definition) "deploy-with-token.ps1"
    & $scriptPath @deployParams
    
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Output ""
        Write-Output "🎉 Token-based deployment completed successfully!"
        Write-Output ""
        Write-Output "💡 TIP: Save your token for reuse (tokens typically last 100 hours)"
        Write-Output "You can rerun this command with the same token until it expires."
    } else {
        Write-Error "❌ Deployment failed with exit code: $exitCode"
    }
    
    exit $exitCode
    
} catch {
    Write-Error "❌ Deployment failed: $($_.Exception.Message)"
    exit 1
}
