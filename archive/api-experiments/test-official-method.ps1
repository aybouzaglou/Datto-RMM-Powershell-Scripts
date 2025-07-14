# Test using the exact official Datto RMM method
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,
    
    [Parameter(Mandatory = $true)]
    [string]$ApiSecret
)

Write-Output "=== Testing Official Datto RMM Authentication Method ==="
Write-Output "Using the exact code from powershell_token.ps1"
Write-Output ""

#requires -Version 3.0
function New-AemApiAccessToken
{
    param
    (
        [string]$apiUrl,
        [string]$apiKey,
        [string]$apiSecretKey
    )

    Write-Output "Function parameters:"
    Write-Output "  API URL: $apiUrl"
    Write-Output "  API Key: $($apiKey.Substring(0, [Math]::Min(8, $apiKey.Length)))..."
    Write-Output "  API Secret: $($apiSecretKey.Substring(0, [Math]::Min(8, $apiSecretKey.Length)))..."
    Write-Output ""

    # Specify security protocols
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
        Write-Output "✓ Security protocols set"
    } catch {
        Write-Warning "Could not set security protocols (PowerShell Core on macOS): $($_.Exception.Message)"
        Write-Output "Continuing without setting security protocols..."
    }

    # Convert password to secure string
    $securePassword = ConvertTo-SecureString -String 'public' -AsPlainText -Force
    Write-Output "✓ Secure password created"

    # Define parameters for Invoke-WebRequest cmdlet
    $params = @{
        Credential	=	New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('public-client', $securePassword)
        Uri			=	'{0}/auth/oauth/token' -f $apiUrl
        Method      =	'POST'
        ContentType = 	'application/x-www-form-urlencoded'
        Body        = 	'grant_type=password&username={0}&password={1}' -f $apiKey, $apiSecretKey
    }
    
    Write-Output "Request parameters:"
    Write-Output "  URI: $($params.Uri)"
    Write-Output "  Method: $($params.Method)"
    Write-Output "  ContentType: $($params.ContentType)"
    Write-Output "  Body: grant_type=password&username=***&password=***"
    Write-Output "  Credential: public-client / public"
    Write-Output ""
    
    Write-Output "Making request..."

    # Request access token
    try {
        $response = Invoke-WebRequest @params
        Write-Output "✓ Request successful!"
        Write-Output "  Status Code: $($response.StatusCode)"
        Write-Output "  Content Length: $($response.Content.Length)"
        
        $tokenData = $response | ConvertFrom-Json
        $accessToken = $tokenData.access_token
        
        Write-Output "✓ Token extracted: $($accessToken.Substring(0, [Math]::Min(20, $accessToken.Length)))..."
        
        return $accessToken
    }
    catch {
        Write-Output "❌ Request failed: $($_.Exception.Message)"
        
        if ($_.Exception.Response) {
            Write-Output "  Status Code: $($_.Exception.Response.StatusCode)"
            Write-Output "  Status Description: $($_.Exception.Response.StatusDescription)"
            
            try {
                $responseStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($responseStream)
                $responseBody = $reader.ReadToEnd()
                Write-Output "  Response Body: $responseBody"
            } catch {
                Write-Output "  Could not read response body"
            }
        }
        
        return $_.Exception
    }
}

# Define parameters (using exact format from official example)
$params = @{
    apiUrl         	=	'https://concord-api.centrastage.net/api'
    apiKey         	=	$ApiKey
    apiSecretKey  	=	$ApiSecret
}

Write-Output "Calling New-AemApiAccessToken with official parameters..."
Write-Output ""

# Call New-AemApiAccessToken function using defined parameters 
$result = New-AemApiAccessToken @params

if ($result -is [string] -and $result.Length -gt 50) {
    Write-Output ""
    Write-Output "🎉 SUCCESS! Official method works!"
    Write-Output "Access Token: $($result.Substring(0, 20))..."
    
    # Test the token with an API call
    Write-Output ""
    Write-Output "Testing token with API call..."
    
    try {
        $headers = @{
            'Authorization' = "Bearer $result"
            'Accept' = 'application/json'
        }
        
        $accountInfo = Invoke-RestMethod -Uri "https://concord-api.centrastage.net/api/v2/account" -Headers $headers -Method Get
        Write-Output "✅ API call successful!"
        Write-Output "Account: $($accountInfo.companyName)"
        
    } catch {
        Write-Output "❌ API call failed: $($_.Exception.Message)"
    }
    
} else {
    Write-Output ""
    Write-Output "❌ FAILED: Official method did not work"
    Write-Output "Result: $result"
}
