# Postman-style OAuth Flow for Datto RMM API
# This script implements the exact OAuth flow that Postman uses

param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,
    
    [Parameter(Mandatory = $true)]
    [string]$ApiSecret
)

$ApiUrl = "https://concord-api.centrastage.net/api"

Write-Output "=== Postman-Style OAuth Flow Test ==="
Write-Output "This mimics exactly what Postman does for Datto RMM API"
Write-Output ""

# Step 1: Prepare OAuth parameters (exactly like Postman)
$authUrl = "$ApiUrl/auth/oauth/authorize"
$tokenUrl = "$ApiUrl/auth/oauth/token"
$clientId = "public-client"
$clientSecret = "public"
$redirectUri = "https://oauth.pstmn.io/v1/callback"  # Postman's callback URL
$state = [System.Guid]::NewGuid().ToString()

Write-Output "OAuth Configuration (Postman style):"
Write-Output "Auth URL: $authUrl"
Write-Output "Token URL: $tokenUrl"
Write-Output "Client ID: $clientId"
Write-Output "Client Secret: $clientSecret"
Write-Output "Redirect URI: $redirectUri"
Write-Output ""

# Step 2: Try to get token using Resource Owner Password Credentials
# (This is what some APIs support for automation)
Write-Output "Attempting Resource Owner Password Credentials flow..."

try {
    # Create Basic Auth header for client authentication
    $clientAuthString = "$clientId`:$clientSecret"
    $clientAuthBytes = [System.Text.Encoding]::ASCII.GetBytes($clientAuthString)
    $clientAuthBase64 = [System.Convert]::ToBase64String($clientAuthBytes)
    
    $headers = @{
        'Authorization' = "Basic $clientAuthBase64"
        'Content-Type' = 'application/x-www-form-urlencoded'
        'Accept' = 'application/json'
    }
    
    # Try Resource Owner Password Credentials Grant
    $body = @{
        grant_type = "password"
        username = $ApiKey
        password = $ApiSecret
        client_id = $clientId
        client_secret = $clientSecret
    }
    
    $bodyString = ($body.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Web.HttpUtility]::UrlEncode($_.Value))" }) -join "&"
    
    Write-Output "Making token request..."
    Write-Output "Body: grant_type=password&username=***&password=***&client_id=$clientId&client_secret=***"
    
    $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $bodyString -Headers $headers
    
    if ($tokenResponse.access_token) {
        Write-Output "✅ SUCCESS: Got access token!"
        $accessToken = $tokenResponse.access_token
        Write-Output "Token: $($accessToken.Substring(0, [Math]::Min(20, $accessToken.Length)))..."
        
        # Test the token with an API call
        Write-Output ""
        Write-Output "Testing token with API call..."
        
        $apiHeaders = @{
            'Authorization' = "Bearer $accessToken"
            'Accept' = 'application/json'
        }
        
        $accountInfo = Invoke-RestMethod -Uri "$ApiUrl/v2/account" -Headers $apiHeaders -Method Get
        Write-Output "✅ API call successful!"
        Write-Output "Account: $($accountInfo.companyName)"
        Write-Output "Account ID: $($accountInfo.uid)"
        
        return $accessToken
    }
    
} catch {
    Write-Output "❌ Resource Owner Password Credentials failed: $($_.Exception.Message)"
    
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode
        Write-Output "Status Code: $statusCode"
        
        try {
            $responseStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($responseStream)
            $responseBody = $reader.ReadToEnd()
            Write-Output "Response: $responseBody"
        } catch {
            Write-Output "Could not read response body"
        }
    }
}

Write-Output ""
Write-Output "❌ Automated OAuth flow failed."
Write-Output ""
Write-Output "SOLUTION: Use Postman to get a token manually"
Write-Output "=========================================="
Write-Output ""
Write-Output "1. Open Postman"
Write-Output "2. Create new request"
Write-Output "3. Go to Authorization tab"
Write-Output "4. Select OAuth 2.0"
Write-Output "5. Configure:"
Write-Output "   - Grant Type: Authorization Code"
Write-Output "   - Auth URL: $authUrl"
Write-Output "   - Access Token URL: $tokenUrl"
Write-Output "   - Client ID: $clientId"
Write-Output "   - Client Secret: $clientSecret"
Write-Output "   - Username: $ApiKey"
Write-Output "   - Password: $ApiSecret"
Write-Output "6. Click 'Get New Access Token'"
Write-Output "7. Copy the token and use it in our scripts"
Write-Output ""
Write-Output "Alternative: Check if Datto RMM has a different API authentication method"
Write-Output "for server-to-server automation (like API keys without OAuth)."
