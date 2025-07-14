#requires -Version 3.0
function New-AemApiAccessToken
{
	param
	(
		[string]$apiUrl,
		[string]$apiKey,
		[string]$apiSecretKey
	)

	# Specify security protocols
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'

	# Convert password to secure string
	$securePassword = ConvertTo-SecureString -String 'public' -AsPlainText -Force

	# Define parameters for Invoke-WebRequest cmdlet
	$params = @{
		Credential	=	New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('public-client', $securePassword)
		Uri			=	'{0}/auth/oauth/token' -f $apiUrl
		Method      =	'POST'
		ContentType = 	'application/x-www-form-urlencoded'
		Body        = 	'grant_type=password&username={0}&password={1}' -f $apiKey, $apiSecretKey
	}
	
	# Request access token
	try {(Invoke-WebRequest @params | ConvertFrom-Json).access_token}
	catch {$_.Exception}
}

# Define parameters
$params = @{
	apiUrl         	=	'[API URL]'
	apiKey         	=	'[API Key]'
	apiSecretKey  	=	'[API Secret Key]'
}

# Call New-AemApiAccessToken function using defined parameters 
New-AemApiAccessToken @params
