# Secure API Deployment Script
# Uses local configuration file or environment variables (never commits credentials)

<#
.SYNOPSIS
    Secure deployment using local configuration or environment variables
.DESCRIPTION
    This script reads API credentials from secure local sources:
    1. Local config file (git-ignored)
    2. Environment variables
    3. Command line parameters (for testing only)
.PARAMETER ConfigPath
    Path to local configuration file (default: config/api-config.json)
.PARAMETER UseEnvironment
    Use environment variables instead of config file
.EXAMPLE
    # Using local config file (recommended)
    .\secure-api-deploy.ps1
    
    # Using environment variables
    .\secure-api-deploy.ps1 -UseEnvironment
    
    # Using specific config file
    .\secure-api-deploy.ps1 -ConfigPath "config/my-config.json"
.NOTES
    SECURITY: Never commit api-config.json to Git!
    The .gitignore file prevents accidental commits.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "config/api-config.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$UseEnvironment,
    
    [Parameter(Mandatory = $false)]
    [string]$ComponentPath = "components/Scripts/Setup-TestDevice.ps1"
)

Write-Output "=== Secure Datto RMM API Deployment ==="
Write-Output "Security: Using local configuration (not committed to Git)"
Write-Output ""

# Function to securely load configuration
function Get-SecureConfig {
    if ($UseEnvironment) {
        Write-Output "📋 Loading configuration from environment variables..."
        
        $config = @{
            datto = @{
                apiKey = $env:DATTO_API_KEY
                apiSecret = $env:DATTO_API_SECRET
                apiUrl = $env:DATTO_API_URL
                testDeviceId = $env:DATTO_TEST_DEVICE_ID
            }
        }
        
        # Validate environment variables
        if (-not $config.datto.apiKey) {
            Write-Error "❌ DATTO_API_KEY environment variable not set"
            Write-Output "Set it with: export DATTO_API_KEY='your-key'"
            exit 1
        }
        
        if (-not $config.datto.apiSecret) {
            Write-Error "❌ DATTO_API_SECRET environment variable not set"
            Write-Output "Set it with: export DATTO_API_SECRET='your-secret'"
            exit 1
        }
        
        if (-not $config.datto.testDeviceId) {
            Write-Error "❌ DATTO_TEST_DEVICE_ID environment variable not set"
            Write-Output "Set it with: export DATTO_TEST_DEVICE_ID='12345'"
            exit 1
        }
        
        # Set defaults
        if (-not $config.datto.apiUrl) {
            $config.datto.apiUrl = "https://concord-api.centrastage.net/api"
        }
        
        Write-Output "✅ Environment variables loaded successfully"
        return $config
        
    } else {
        Write-Output "📋 Loading configuration from local file: $ConfigPath"
        
        if (-not (Test-Path $ConfigPath)) {
            Write-Error "❌ Configuration file not found: $ConfigPath"
            Write-Output ""
            Write-Output "To create your configuration file:"
            Write-Output "1. Copy config/api-config.example.json to config/api-config.json"
            Write-Output "2. Edit config/api-config.json with your API credentials"
            Write-Output "3. The file is git-ignored for security"
            Write-Output ""
            Write-Output "Example:"
            Write-Output "cp config/api-config.example.json config/api-config.json"
            Write-Output "# Then edit config/api-config.json with your credentials"
            exit 1
        }
        
        try {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            Write-Output "✅ Configuration file loaded successfully"
            return $config
        } catch {
            Write-Error "❌ Failed to parse configuration file: $($_.Exception.Message)"
            Write-Output "Please check the JSON syntax in: $ConfigPath"
            exit 1
        }
    }
}

# Function to validate configuration
function Test-SecureConfig {
    param($config)
    
    Write-Output "🔍 Validating configuration..."
    
    if (-not $config.datto.apiKey -or $config.datto.apiKey -eq "YOUR-DATTO-API-KEY-HERE") {
        Write-Error "❌ API Key not configured properly"
        return $false
    }
    
    if (-not $config.datto.apiSecret -or $config.datto.apiSecret -eq "YOUR-DATTO-API-SECRET-HERE") {
        Write-Error "❌ API Secret not configured properly"
        return $false
    }
    
    if (-not $config.datto.testDeviceId -or $config.datto.testDeviceId -eq "YOUR-TEST-DEVICE-ID-HERE") {
        Write-Error "❌ Test Device ID not configured properly"
        return $false
    }
    
    # Mask sensitive data in output
    $maskedKey = $config.datto.apiKey.Substring(0, 4) + "..." + $config.datto.apiKey.Substring($config.datto.apiKey.Length - 4)
    $maskedSecret = $config.datto.apiSecret.Substring(0, 4) + "..." + $config.datto.apiSecret.Substring($config.datto.apiSecret.Length - 4)
    
    Write-Output "✅ Configuration validated:"
    Write-Output "  API Key: $maskedKey"
    Write-Output "  API Secret: $maskedSecret"
    Write-Output "  API URL: $($config.datto.apiUrl)"
    Write-Output "  Test Device: $($config.datto.testDeviceId)"
    
    return $true
}

# Load and validate configuration
try {
    $config = Get-SecureConfig
    
    if (-not (Test-SecureConfig -config $config)) {
        Write-Error "❌ Configuration validation failed"
        exit 1
    }
    
} catch {
    Write-Error "❌ Failed to load configuration: $($_.Exception.Message)"
    exit 1
}

# Check if component script exists
if (-not (Test-Path $ComponentPath)) {
    Write-Error "❌ Component script not found: $ComponentPath"
    exit 1
}

Write-Output ""
Write-Output "🚀 Starting secure API deployment..."

# Call the quick deployment script with loaded credentials
try {
    $deployParams = @{
        ApiKey = $config.datto.apiKey
        ApiSecret = $config.datto.apiSecret
        TestDeviceId = $config.datto.testDeviceId
    }
    
    # Add optional parameters if they exist in config
    if ($config.datto.apiUrl) {
        $deployParams.ApiUrl = $config.datto.apiUrl
    }
    
    # Execute deployment
    $scriptPath = Join-Path (Split-Path $MyInvocation.MyCommand.Definition) "quick-api-deploy.ps1"
    & $scriptPath @deployParams
    
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Output ""
        Write-Output "🎉 Secure deployment completed successfully!"
        Write-Output ""
        Write-Output "Security Notes:"
        Write-Output "✅ API credentials were loaded from secure local source"
        Write-Output "✅ No credentials were committed to Git"
        Write-Output "✅ Configuration file is git-ignored"
    } else {
        Write-Error "❌ Deployment failed with exit code: $exitCode"
    }
    
    exit $exitCode
    
} catch {
    Write-Error "❌ Deployment failed: $($_.Exception.Message)"
    exit 1
}
