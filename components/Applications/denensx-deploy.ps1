# Changelog
# v1.2:
# - Added new Cert Subject for Secure Industries, Inc.
# - Added support for overriding with the Site variables
# Usage: powershell -executionpolicy bypass -f ./DefensX_Datto.ps1 [-defensxkey <deployment_key>] [-systemcomponent] [-disableuninstall] [-uninstall]
#
# Optional command line params, this has to be the first line in the script.
param (
  [string]$defensxkey,
  [switch]$systemcomponent = $false,
  [switch]$disableuninstall = $false,
  [switch]$uninstall = $false
)

write-host "DefensX Agent"
write-host "====================="

#--------------------------------------------------------------------------------------------------

# Define the URL and output path
$downloadUrl = "https://cloud.defensx.com/defensx-installer/latest.msi"
$msiPath = Join-Path $env:TEMP "DefensX-Installer.msi"
$usrAction = "$env:usrAction"
$usrKey = "$env:usrDefensXKey"
$usrDisableUninstall = "$env:usrDisableUninstall"
$usrSystemComponent = "$env:usrSystemComponent"

$siteKey = "$env:DEFENSX_KEY"
$siteDisableUninstall = "$env:DEFENSX_DISABLE_UNINSTALL"
$siteSystemComponent = "$env:DEFENSX_SYSTEM_COMPONENT"

$DX_Uninstall = $false

if ($usrAction -eq 'uninstall') {
    $DX_Uninstall = $true
} elseif ($uninstall) {
    $DX_Uninstall = $true
}

$DX_Key = ""

try {
    if ($usrKey) {
        $DX_Key = $usrKey
    } elseif ($siteKey) {
        $DX_Key = $siteKey
    } elseif (! [string]::IsNullOrEmpty($defensxkey)) {
        $DX_Key = $defensxkey
    }

    if (! [string]::IsNullOrEmpty($usrDisableUninstall)) {
        $disableuninstall = if ($usrDisableUninstall -eq "1") { $true } else { $false }
    } elseif ($siteDisableUninstall -and ($siteDisableUninstall -eq "1" -or $siteDisableUninstall -eq "true")) {
        $disableuninstall = $true
    }
    if (! [string]::IsNullOrEmpty($usrSystemComponent)) {
        $systemcomponent = if ($usrSystemComponent -eq "1") { $true } else { $false }
    } elseif ($siteSystemComponent -and ($siteSystemComponent -eq "1" -or $siteSystemComponent -eq "true")) {
        $systemcomponent = $true
    }
} catch {
    $ErrorMessage = $_.Exception.Message
    write-error "An error occurred while parsing the variables: $($_.Exception.Message)"
    exit 1
}

# SilentlyContinue or Continue, set to "Continue" to enable verbose logging.
$DebugPreference = "SilentlyContinue"

# Find poorly written code faster with the most stringent setting.
Set-StrictMode -Version Latest

function TestKey-Short {
    $chars = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'
    $pattern = "^[${chars}]{1,}$"

    return $DX_Key -match $pattern
}

function TestKey-Long {
    $pattern = '^([A-Za-z0-9-_]+\.){2}[A-Za-z0-9-_]+\s*$'
    return $DX_Key -match $pattern
}


function TestKey {
    if ($DX_Key.length -eq 16) {
        if (-Not (TestKey-Short)) {
            throw "The short key doesn't match the pattern. Please check the provided key to the script."
        }
    } elseif ($DX_Key.length -eq 224) {
        if (-Not (TestKey-Long)) {
            throw "The long key doesn't match the pattern. Please check the provided key to the script."
        }
    } elseif ($DX_Key.length -eq 0) {
        throw "The key is missing. Please provide the DEFENSX_KEY either Site or User variable to the script."
    } else {
        throw "The key doesn't match any pattern. Please check the provided key to the script."
    }
}

function verifyPackage ($file, [string[]]$cert_subject) {
    write-host "Verifying digital signature of $file..."
        
    # Build the certificate chain
    $varChain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    try {
        $varChain.Build((Get-AuthenticodeSignature -FilePath "$file").SignerCertificate) | out-null
    } catch [System.Management.Automation.MethodInvocationException] {
        write-host "- ERROR: $file installer did not contain a valid digital certificate."
        exit 1
    }
    
    # Check the certificate subjects against the chain
    $verificationPassed = $false
    foreach ($subject in $cert_subject) {
        write-host "Checking Cert Subject: $subject"
        $varOutput = ($varChain.ChainElements | ForEach-Object {$_.Certificate} | Where-Object {$_.Subject -match "$subject"})
            
        if ($varOutput -and $varOutput.Subject -and $varOutput.Subject.Contains($subject)) {
            $verificationPassed = $true
            break
        }
    }
    
    if (-not $verificationPassed) {
        write-host "No matching certificate subject found."
        write-host "- ERROR: $file did not pass verification checks for its digital signature."
        exit 2
    } else {
        write-host "- Digital Signature verification passed."
    }
}    

function getDefensXGUID () { 
    ("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall") | ForEach-Object {
        Get-ChildItem -Path $_ | ForEach-Object {
            $properties = Get-ItemProperty $_.PSPath
            if ($properties.PSObject.Properties['DisplayName'] -and $properties.DisplayName -match "DefensX Agent") {
                if ($properties.PSChildName -match '}$') {
                    $properties.PSChildName
                }
            }
        }
    }
}

#--------------------------------------------------------------------------------------------------
function main () {
    if ($DX_Uninstall) {
        write-host "Uninstalling DefensX Agent..."
        $DefensXGUID = getDefensXGUID
        if ($DefensXGUID -eq $null) {
            write-host "DefensX Agent not found. Nothing to uninstall."
        } else {
            write-host "DefensX Agent found (GUID: $DefensXGUID) Uninstalling..."
            try {
                msiexec /x $DefensXGUID /qn /norestart
                write-host "Uninstall completed."
            } catch {
                write-host "Error when uninstalling Agent: $($error | select *)"
                exit 1
            }
        }
    } else {
        TestKey

        $DISABLE_UNINSTALL = if ($disableuninstall) { "1" } else { "0" }
        $SYSTEM_COMPONENT = if ($systemcomponent) { "1" } else { "0" }
        
        # Download the MSI file
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $msiPath -UseBasicParsing

        # check the signature
        $certSubjects = @("Secure Industries Inc.", "Secure Industries, Inc.")
        verifyPackage -file $msiPath -cert_subject $certSubjects

        # Install the MSI with parameters
        $msiParams = @{
        FilePath = "msiexec.exe"
        ArgumentList = "/i `"$msiPath`" KEY=$DX_Key DISABLE_UNINSTALL=$DISABLE_UNINSTALL SYSTEM_COMPONENT=$SYSTEM_COMPONENT /quiet"
        Wait = $true
        }

        Start-Process @msiParams

        write-host "DefensX installation completed successfully."
    }

}

try {
    main
} catch {
    $ErrorMessage = $_.Exception.Message
    write-error "An error occurred: $($_.Exception.Message)"
    exit 3
}

exit 0