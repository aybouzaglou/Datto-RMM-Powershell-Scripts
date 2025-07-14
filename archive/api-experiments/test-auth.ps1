# Test Datto RMM API Authentication
# Simple script to debug authentication issues

param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,
    
    [Parameter(Mandatory = $true)]
    [string]$ApiSecret
)

$ApiUrl = "https://concord-api.centrastage.net/api"

Write-Output "=== Datto RMM API Authentication Test ==="
Write-Output "API URL: $ApiUrl"
Write-Output "API Key: $($ApiKey.Substring(0, [Math]::Min(8, $ApiKey.Length)))..."
Write-Output "API Secret: $($ApiSecret.Substring(0, [Math]::Min(8, $ApiSecret.Length)))..."
Write-Output ""

# Test 1: Try the OAuth token request with detailed error info
Write-Output "Test 1: OAuth Token Request"
Write-Output "------------------------"

try {
    # Try Method 1: Authorization Code flow (like Postman)
    Write-Output "Trying Method 1: Authorization Code flow (Postman method)..."

    # Step 1: Get authorization code by simulating the browser flow
    $authUri = "$ApiUrl/auth/oauth/authorize"
    $tokenUri = "$ApiUrl/auth/oauth/token"

    # For PowerShell automation, we'll use the client credentials flow instead
    # which is more suitable for server-to-server authentication

    $tokenAuthString = "public-client:public"
    $tokenAuthBytes = [System.Text.Encoding]::ASCII.GetBytes($tokenAuthString)
    $tokenAuthBase64 = [System.Convert]::ToBase64String($tokenAuthBytes)

    $tokenHeaders = @{
        'Authorization' = "Basic $tokenAuthBase64"
        'Content-Type' = 'application/x-www-form-urlencoded'
    }

    # Try client_credentials grant type first (better for automation)
    $tokenBody = "grant_type=client_credentials&username=$ApiKey&password=$ApiSecret"

    Write-Output "Token URI: $tokenUri"
    Write-Output "Grant Type: client_credentials"
    Write-Output ""

    try {
        $tokenResponse = Invoke-RestMethod -Uri $tokenUri -Method Post -Body $tokenBody -Headers $tokenHeaders
        $accessToken = $tokenResponse.access_token
        Write-Output "✓ Method 1 SUCCESS (client_credentials)"
    } catch {
        Write-Output "❌ Method 1 FAILED: $($_.Exception.Message)"

        # Try Method 2: Password grant (original approach)
        Write-Output ""
        Write-Output "Trying Method 2: Password grant flow..."

        $tokenBody2 = "grant_type=password&username=$ApiKey&password=$ApiSecret"

        try {
            $tokenResponse = Invoke-RestMethod -Uri $tokenUri -Method Post -Body $tokenBody2 -Headers $tokenHeaders
            $accessToken = $tokenResponse.access_token
            Write-Output "✓ Method 2 SUCCESS (password grant)"
        } catch {
            Write-Output "❌ Method 2 FAILED: $($_.Exception.Message)"

            # Try Method 3: Direct Basic Auth (some APIs support this)
            Write-Output ""
            Write-Output "Trying Method 3: Direct Basic Auth..."

            $directHeaders = @{
                'Authorization' = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$ApiKey`:$ApiSecret")))"
                'Content-Type' = 'application/json'
                'Accept' = 'application/json'
            }

            $testUri = "$ApiUrl/v2/account"
            Write-Output "Direct API call to: $testUri"

            try {
                $accountInfo = Invoke-RestMethod -Uri $testUri -Headers $directHeaders -Method Get
                Write-Output "✓ Method 3 SUCCESS: Direct Basic Auth works!"
                Write-Output "Account: $($accountInfo.companyName)"
                return
            } catch {
                Write-Output "❌ Method 3 FAILED: $($_.Exception.Message)"

                # Try Method 4: Simulate Postman's exact flow
                Write-Output ""
                Write-Output "Trying Method 4: Postman simulation..."
                Write-Output "Note: This requires manual authorization step in browser"
                Write-Output "For automation, we need a different approach..."

                throw "All automated authentication methods failed. Postman works because it handles the interactive OAuth flow."
            }
        }
    }
    
    Write-Output "✓ SUCCESS: OAuth token obtained"
    Write-Output "Token: $($accessToken.Substring(0, [Math]::Min(20, $accessToken.Length)))..."
    
    # Test 2: Try an API call with the token
    Write-Output ""
    Write-Output "Test 2: API Call with Token"
    Write-Output "---------------------------"
    
    $apiHeaders = @{
        'Authorization' = "Bearer $accessToken"
        'Content-Type' = 'application/json'
        'Accept' = 'application/json'
    }
    
    $testUri = "$ApiUrl/v2/account"
    Write-Output "Test URI: $testUri"
    Write-Output "Making API call..."
    
    $accountInfo = Invoke-RestMethod -Uri $testUri -Headers $apiHeaders -Method Get
    Write-Output "✓ SUCCESS: API call successful"
    Write-Output "Account: $($accountInfo.companyName)"
    
} catch {
    Write-Output "❌ FAILED: $($_.Exception.Message)"
    
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode
        $statusDescription = $_.Exception.Response.StatusDescription
        Write-Output "Status Code: $statusCode"
        Write-Output "Status Description: $statusDescription"
        
        try {
            $responseStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($responseStream)
            $responseBody = $reader.ReadToEnd()
            Write-Output "Response Body: $responseBody"
        } catch {
            Write-Output "Could not read response body"
        }
    }
    
    Write-Output ""
    Write-Output "Troubleshooting Tips:"
    Write-Output "1. Verify API key and secret are correct"
    Write-Output "2. Check that API access is enabled in Datto RMM"
    Write-Output "3. Ensure the user account has API permissions"
    Write-Output "4. Verify you're using the correct API URL for your platform"
    Write-Output ""
    Write-Output "API URL should match your Datto RMM platform:"
    Write-Output "- Concord: https://concord-api.centrastage.net/api"
    Write-Output "- Merlot: https://merlot-api.centrastage.net/api"
    Write-Output "- Pinotage: https://pinotage-api.centrastage.net/api"
    Write-Output "- Vidal: https://vidal-api.centrastage.net/api"
    Write-Output "- Zinfandel: https://zinfandel-api.centrastage.net/api"
    Write-Output "- Syrah: https://syrah-api.centrastage.net/api"
}
