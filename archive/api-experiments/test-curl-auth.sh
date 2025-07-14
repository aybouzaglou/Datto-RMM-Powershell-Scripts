#!/bin/bash

# Test Datto RMM API authentication using curl (official method)

if [ $# -ne 2 ]; then
    echo "Usage: $0 <API_KEY> <API_SECRET>"
    echo "Example: $0 'your-api-key' 'your-api-secret'"
    exit 1
fi

API_KEY="$1"
API_SECRET="$2"
API_URL="https://concord-api.centrastage.net/api"

echo "=== Datto RMM API Authentication Test (curl) ==="
echo "Using official curl method from curl_token.bat"
echo ""
echo "API URL: $API_URL"
echo "API Key: ${API_KEY:0:8}..."
echo "API Secret: ${API_SECRET:0:8}..."
echo ""

echo "Making token request..."
echo "Command: curl --request POST --user public-client:public --header \"Content-Type: application/x-www-form-urlencoded\" --data \"grant_type=password&username=***&password=***\" --url $API_URL/auth/oauth/token"
echo ""

# Make the request (using exact format from official example)
RESPONSE=$(curl --silent --show-error --request POST \
    --user public-client:public \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data "grant_type=password&username=$API_KEY&password=$API_SECRET" \
    --url "$API_URL/auth/oauth/token" \
    --write-out "HTTPSTATUS:%{http_code}")

# Extract HTTP status code
HTTP_STATUS=$(echo "$RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | sed -E 's/HTTPSTATUS:[0-9]*$//')

echo "HTTP Status: $HTTP_STATUS"
echo "Response: $RESPONSE_BODY"
echo ""

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ SUCCESS: Authentication successful!"
    
    # Extract access token using jq if available, otherwise use basic parsing
    if command -v jq &> /dev/null; then
        ACCESS_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.access_token')
        echo "Access Token: ${ACCESS_TOKEN:0:20}..."
        
        # Test the token with an API call
        echo ""
        echo "Testing token with API call..."
        
        API_RESPONSE=$(curl --silent --show-error \
            --header "Authorization: Bearer $ACCESS_TOKEN" \
            --header "Accept: application/json" \
            --url "$API_URL/v2/account" \
            --write-out "HTTPSTATUS:%{http_code}")
        
        API_HTTP_STATUS=$(echo "$API_RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
        API_RESPONSE_BODY=$(echo "$API_RESPONSE" | sed -E 's/HTTPSTATUS:[0-9]*$//')
        
        echo "API Call Status: $API_HTTP_STATUS"
        
        if [ "$API_HTTP_STATUS" = "200" ]; then
            echo "✅ API call successful!"
            COMPANY_NAME=$(echo "$API_RESPONSE_BODY" | jq -r '.companyName')
            echo "Account: $COMPANY_NAME"
            echo ""
            echo "🎉 CURL METHOD WORKS PERFECTLY!"
            echo "Access token: $ACCESS_TOKEN"
        else
            echo "❌ API call failed"
            echo "Response: $API_RESPONSE_BODY"
        fi
    else
        echo "Access Token: $RESPONSE_BODY"
        echo ""
        echo "✅ CURL METHOD WORKS!"
        echo "Install 'jq' for better JSON parsing: brew install jq"
    fi
    
else
    echo "❌ FAILED: Authentication failed"
    echo "Status: $HTTP_STATUS"
    echo "Response: $RESPONSE_BODY"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check API credentials are correct"
    echo "2. Verify API access is enabled in Datto RMM"
    echo "3. Ensure user has API permissions"
fi
