<# foxit pdf editor downloader :: build 2/2025, november 2025
   script variables: usrAction/sel (install/upgrade/uninstall) :: @usrFoxitKillSITE/Bln

   CONVERTED FROM: Foxit Reader Component Script
   PURPOSE: Downloads and installs Foxit PDF Editor (latest version, 64-bit) for SSO activation

   SIMPLIFIED APPROACH:
   - Always downloads latest stable version (no hardcoded version numbers)
   - Defaults to 64-bit (modern deployment standard - it's 2025)
   - Uses Foxit's redirect URL for automatic version updates

   SSO ACTIVATION NOTE:
   This script installs Foxit PDF Editor silently. Users must complete SSO activation
   on first launch by clicking "Activate" > "Sign In" > "SSO Login" and entering their
   organizational email. SSO must be pre-configured in Foxit Admin Console by IT administrators.

   this script, like all datto RMM Component scripts unless otherwise explicitly stated, is the copyrighted property of Datto, Inc.;
   it may not be shared, sold, or distributed beyond the Datto RMM product, whole or in part, even with modifications applied, for
   any reason. this includes on reddit, on discord, or as part of other RMM tools. PCSM is the one exception to this rule.

   the moment you edit this script it becomes your own risk and support will not provide assistance with it.#>

write-host "Software: Foxit PDF Editor (SSO Version)"
write-host "========================================"

#region Functions & variables ----------------------------------------------------------------------------------

#software management/component update
if (!$env:usrAction) {
    $env:usrAction="install"
}
write-host "- Action: $env:usrAction"

#proxy not-a-function code, build 3/seagull :: copyright datto, inc.
if (([IntPtr]::size) -eq 4) {
    [xml]$varPlatXML= get-content "$env:ProgramFiles\CentraStage\CagService.exe.config" -ea 0
} else {
    [xml]$varPlatXML= get-content "${env:ProgramFiles(x86)}\CentraStage\CagService.exe.config" -ea 0
}
try {
    $script:varProxyLoc= ($varPlatXML.configuration.applicationSettings."CentraStage.Cag.Core.AppSettings".setting | ? {$_.Name -eq 'ProxyIp'}).value
    $script:varProxyPort=($varPlatXML.configuration.applicationSettings."CentraStage.Cag.Core.AppSettings".setting | ? {$_.Name -eq 'ProxyPort'}).value
    if ($($varPlatXML.configuration.applicationSettings."CentraStage.Cag.Core.AppSettings".setting | ? {$_.Name -eq 'ProxyType'}).value -gt 0) {
        if ($script:varProxyLoc -and $script:varProxyPort) {
            $useProxy=$true
        }
    }
} catch {
    $host.ui.WriteErrorLine(": NOTICE: Device appears to be configured to use a proxy server, but settings could not be read.")
}

function downloadFile { #downloadFile, build 33/2025 :: copyright datto, inc. :: modified for foxit pdf editor
    param (
        [parameter(mandatory=$false)]$url,
        [parameter(mandatory=$false)]$whitelist,
        [parameter(mandatory=$false)]$filename,
        [parameter(mandatory=$false,ValueFromPipeline=$true)]$pipe
    )

    function setUserAgent {
        $script:WebClient = New-Object System.Net.WebClient
    	$script:webClient.UseDefaultCredentials = $true
        $script:webClient.Headers.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f")
        $script:webClient.Headers.Add([System.Net.HttpRequestHeader]::UserAgent, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36');
        $script:webClient.Headers.Add("Referer", 'https://www.foxit.com/downloads/')
    }

    if (!$url) {$url=$pipe}
    if (!$whitelist) {$whitelist="the required web addresses."}
	if (!$filename) {$filename=$url.split('/')[-1]}

    try { #enable TLS 1.2
		[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
    } catch [system.exception] {
		write-host "- ERROR: Could not implement TLS 1.2 Support."
		write-host "  This can occur on Windows 7 devices lacking Service Pack 1."
		write-host "  Please install that before proceeding."
		exit 1
    }

	write-host "- Downloading: $url"

	if ($useProxy) {
        setUserAgent
        write-host ": Proxy location: $script:varProxyLoc`:$script:varProxyPort"
	    $script:WebClient.Proxy = New-Object System.Net.WebProxy("$script:varProxyLoc`:$script:varProxyPort",$true)
	    $script:WebClient.DownloadFile("$url","$filename")
		if (!(test-path $filename)) {$useProxy=$false}
    }

	if (!$useProxy) {
		setUserAgent #do it again so we can fallback if proxy fails
		$script:webClient.DownloadFile("$url","$filename")
	}

    if (!(test-path $filename)) {
        write-host "- ERROR: File $filename could not be downloaded."
        write-host "  Please ensure you are whitelisting $whitelist."
        write-host "- Operations cannot continue; exiting."
        exit 1
    } else {
        write-host "- Downloaded:  $filename"
    }
}

function verifyPackage ($file, $certificate, $thumbprint, $name, $url) { #verifyPackage build 4/seagull :: datto/kaseya
    if (!(test-path "$file")) {
        write-host "! ERROR: Downloaded file could not be found."
        write-host "  Please ensure firewall access to $url."
        exit 1
    }

    #construct chain
    $varChain=New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    try {
        $varChain.Build((Get-AuthenticodeSignature -FilePath "$file").SignerCertificate) | out-null
    } catch [System.Management.Automation.MethodInvocationException] {
        write-host "! ERROR: $name installer did not contain a valid digital certificate."
        write-host "  This could suggest a change in the way $name is packaged; it could"
        write-host "  also suggest tampering in the connection chain."
        write-host "- Please ensure $url is whitelisted and try again."
        write-host "  If this issue persists across different devices, please file a support ticket."
        exit 1
    }

    #check digsig status
    if ((Get-AuthenticodeSignature "$file").status.value__ -ne 0) {
        write-host "! ERROR: $name installer contained a digital signature, but it was invalid."
        write-host "  This strongly suggests that the file has been tampered with."
        write-host "  Please re-attempt download. If the issue persists, contact Support."
        exit 1
    }

    #inspect certificate thumbprints
    $varIntermediate=($varChain.ChainElements | % {$_.Certificate} | ? {$_.Subject -match "$certificate"}).Thumbprint
    if ($varIntermediate -ne $thumbprint) {
        write-host "! ERROR: $file did not pass verification checks for its digital signature."
        write-host "  This could suggest that the certificate used to sign the $name installer"
        write-host "  has changed; it could also suggest tampering in the connection chain."
        write-host `r
        if ($varIntermediate) {
            write-host ": We received: $varIntermediate"
            write-host "  We expected: $thumbprint"
            write-host "  Please report this issue."
        } else {
            write-host "  The installer's certificate authority has changed."
        }
        write-host "- Installation cannot continue. Exiting."
        exit 1
    } else {
        write-host ": Digital Signature verification passed."
    }
}

function getShortlink { # getShortlink, build 11/seagull :: copyright datto, inc. :: MODIFIED: uses GET instead of HEAD
    Param([Parameter(Mandatory=$true,ValueFromPipeline=$true)]$shortLink)

    try { #enable TLS 1.2
		[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
    } catch [system.exception] {
		write-host "- ERROR: Could not implement TLS 1.2 Support."
		write-host "  This can occur on Windows 7 devices lacking Service Pack 1."
		write-host "  Please install that before proceeding."
		exit 1
    }

    function setRequestData {
        $script:webRequest=[System.Net.HttpWebRequest]::Create("$shortlink")
        $script:webRequest.Method="GET"
    }

    write-host "- Short link:  $shortLink"

    if ($useProxy) {
        setRequestData
        write-host ": Proxy location: $script:varProxyLoc`:$script:varProxyPort"
        $script:webRequest::DefaultWebProxy = [System.Net.WebProxy]::new("$script:varProxyLoc`:$script:varProxyPort",$true)
        $longLink=($script:webRequest.GetResponse()).ResponseURI.AbsoluteURI
        if (!$longLink) {$useProxy=$false}
    }

    if (!$useProxy) {
        setRequestData
        $longLink=($script:webRequest.GetResponse()).ResponseURI.AbsoluteURI
    }

    write-host "- Long link:   $longLink"
    $longLink
}

function cdPnt ($codepoint) {
    #this is purely to keep the section below readable
    return $([Convert]::ToChar([int][Convert]::ToInt32($codepoint, 16)))
}

function getGUID ($softwareTitle) { #custom bespoke special birthday-boy version
    ("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall","HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall") | % {
        gci -Path $_ -ea 0 | % { Get-ItemProperty $_.PSPath } | ? { $_.DisplayName -match $softwareTitle } | % {
            if ($_.UninstallString -match 'msiexec') {
                #return MSI GUID
                return "MSI!$($_.PSChildName)"
            } else {
                #return command
                return $_.QuietUninstallString
            }
        }
    }
}

#region Uninstall ----------------------------------------------------------------------------------------------

if ($env:usrAction -eq 'Uninstall') {
    getGUID "Foxit PDF Editor|Foxit PhantomPDF" | % {
        if ($_ -match 'MSI') {
            $varGUID=$_.split('!')[-1]
            write-host "- Uninstalling Foxit PDF Editor [MSI] @ $varGUID..."
            write-host ": Concluded with exit code $((start-process msiexec -ArgumentList "/x$varGUID /qn /norestart" -wait -PassThru).ExitCode)"
        } else {
            write-host "- Uninstalling Foxit PDF Editor [EXE]..."
            cmd /c $_
        }
    }
    exit
}

#region Determine system language ------------------------------------------------------------------------------

$arrLang=@{
   '0406'=[psCustomObject]@{Name="Dansk | Danish"                                        ;code="da-DK"}
   '0407'=[psCustomObject]@{Name="Deutsch | German"                                      ;code="de"   }
   '0807'=[psCustomObject]@{Name="Deutsch (Schweiz) | German (Switzerland)"              ;code="de"   }
   '0409'=[psCustomObject]@{Name="English (International)"                               ;code="en"   }
   '0809'=[psCustomObject]@{Name="English (UK)"                                          ;code="en"   }
   '0C0A'=[psCustomObject]@{Name="Espa$(cdPnt 00f1)ol | Spanish"                         ;code="es"   }
   '040B'=[psCustomObject]@{Name="Suomalainen | Finnish"                                 ;code="fi-FI"}
   '040C'=[psCustomObject]@{Name="Fran$(cdPnt 00e7)ais | French"                         ;code="fr"   }
   '0C0C'=[psCustomObject]@{Name="Fran$(cdPnt 00e7)ais (Canada) | French Canadian"       ;code="fr"   }
   '0410'=[psCustomObject]@{Name="Italiano | Italian"                                    ;code="it"   }
   '0411'=[psCustomObject]@{Name="Japanese"                                              ;code="jp"   }
   '0412'=[psCustomObject]@{Name="Korean"                                                ;code="ko"   }
   '0414'=[psCustomObject]@{Name="Norsk (Bokm$(cdPnt 00e5)l) | Norwegian (Book)"         ;code="nb-NO"}
   '0814'=[psCustomObject]@{Name="Norsk (Nynorsk) | Norwegian (New)"                     ;code="nb-NO"}
   '0413'=[psCustomObject]@{Name="Nederlands | Dutch"                                    ;code="nl"   }
   '0415'=[psCustomObject]@{Name="Polski | Polish"                                       ;code="pl"   }
   '0416'=[psCustomObject]@{Name="Portugu$(cdPnt 00ea)s do Brasil | Brazilian Portuguese";code="pt"   }
   '0816'=[psCustomObject]@{Name="Portugu$(cdPnt 00ea)s | Portuguese"                    ;code="pt"   }
   '0419'=[psCustomObject]@{Name="Russian"                                               ;code="ru"   }
   '041D'=[psCustomObject]@{Name="Svenska | Swedish"                                     ;code="sv-SE"}
   '0804'=[psCustomObject]@{Name="Chinese (Mainland)"                                    ;code="zh"   }
   '0404'=[psCustomObject]@{Name="Chinese (Taiwan)"                                      ;code="zh-TW"}
   '0C04'=[psCustomObject]@{Name="Chinese (Hong Kong)"                                   ;code="zh-TW"}
}

$varLCID=(gp hklm:\system\controlset001\control\nls\language).Default

if ($($arrLang["$varLCID"].code)) {
    write-host "- System language: [$($arrLang["$varLCID"].Name)]."
    write-host "  Using language code [$($arrLang["$varLCID"].code)]."
    $varLang=$($arrLang["$varLCID"].code)
} else {
    write-host "- System language: Not found/supported."
    write-host "  Using language code 'en' (English)."
    $varLang='en'
}

#region Architecture logic -------------------------------------------------------------------------------------

# Modern Windows deployments: default to 64-bit (it's 2025, 32-bit is legacy)
$varArch = 64
write-host "- Architecture: 64-bit (default for modern deployments)"

#region Clash detection ----------------------------------------------------------------------------------------

#installer
$varProcesses=(get-process).name
if ($varProcesses -contains 'FoxitPDFEditorSetup' -or $varProcesses -contains 'FoxitPhantomPDFSetup') {
    write-host "! ERROR: The installer for Foxit PDF Editor is already running in memory."
    write-host "  Cannot continue; exiting."
    exit 1
}

#process
if ($varProcesses -contains 'FoxitPDFEditor' -or $varProcesses -contains 'FoxitPhantomPDF') {
    write-host "! ERROR: Foxit PDF Editor is running in memory. It must be closed in order to update it."
    if ($env:usrFoxitKillSITE -eq 'true') {
        write-host "  As usrFoxitKillSITE has been set with 'true' at the Site-/Global-level, it will be"
        write-host "  forcibly closed in order to facilitate installation."
        Stop-Process -name "FoxitPDFEditor","FoxitPhantomPDF" -Force -ea 0
        start-sleep -seconds 3
    } else {
        write-host "  As usrFoxitKillSITE has not been set with 'true' at the Site-/Global-level, installation"
        write-host "  will be aborted. Please try again later or set the variable to forcibly close Foxit and"
        write-host "  re-run the Component (or allow Software Management to run again)."
        exit 1
    }
}

#region Download -----------------------------------------------------------------------------------------------

<#
    FOXIT PDF EDITOR DOWNLOAD NOTES:

    Using Foxit's redirect URL to always download the latest version automatically.
    This eliminates the need to hardcode version numbers - the script always gets the newest release.

    SSO ACTIVATION:
    SSO requires user interaction on first launch:
    1. User opens Foxit PDF Editor
    2. Clicks "Activate" > "Sign In" > "SSO Login"
    3. Enters organizational email address
    4. Completes authentication through identity provider

    SSO must be pre-configured in Foxit Admin Console by IT administrators.
#>

write-host `r
write-host "- Downloading Foxit PDF Editor+ (2025 Subscription Version)..."

# Use Foxit's cloud API to download PDF Editor+ (subscription version with 2025.x numbering)
# This is the correct version for SSO activation
$varLink = "https://pheecws-na2.foxit.com/cpdfapi/v1/app/download?product=Foxit-PDF-Editor-Suite-Pro-Teams&version=&language=ML&arch=x$varArch&package=exe"

write-host "- Product: PDF Editor+ (Subscription/SSO compatible)"
$varLink | downloadFile -whitelist "https://pheecws-na2.foxit.com" -filename "foxitEditor.exe"
verifyPackage "foxitEditor.exe" "DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1" "7B0F360B775F76C94A12CA48445AA2D2A875701C" "Foxit PDF Editor" "https://cdn01.foxitsoftware.com"
write-host `r

#region Configure and initiate installation --------------------------------------------------------------------

# SSO activation happens at first launch by user - no command line parameter available
$varArgs="/quiet /log `"$PWD\foxit-editor.log`""

write-host "========================================"
write-host "IMPORTANT: SSO ACTIVATION REQUIRED"
write-host "========================================"
write-host "After installation completes, users must activate Foxit PDF Editor"
write-host "using their organizational SSO credentials on first launch:"
write-host "  1. Open Foxit PDF Editor"
write-host "  2. Click 'Activate' > 'Sign In' > 'SSO Login'"
write-host "  3. Enter organizational email address"
write-host "  4. Complete authentication via your identity provider"
write-host `r
write-host "SSO must be configured in Foxit Admin Console by IT administrators."
write-host "========================================"
write-host `r

#execute
write-host "- Installing Foxit PDF Editor..."
$varInstaller=Start-Process -FilePath "foxitEditor.exe" -ArgumentList "$varArgs /lang $varLang" -Wait -PassThru -NoNewWindow

switch ($varInstaller.exitCode) {
    0 {
        write-host ": Code 0: Installation succeeded!"
        write-host `r
        write-host "NEXT STEPS:"
        write-host "- Foxit PDF Editor has been installed successfully"
        write-host "- Users must complete SSO activation on first launch"
        write-host "- Ensure users have access to organizational SSO identity provider"
    } 1603 {
        write-host "! ERROR: Code 1603 (catastrophic failure in installation)."
        write-host "  This usually means an incompatible distribution of Foxit PDF Editor/PhantomPDF is installed"
        write-host "  which cannot be upgraded from cleanly using the binaries this script downloads."
        write-host "  Please (re-)run this Component with the usrAction flag"
        write-host "  set to 'Uninstall', reboot, and then attempt reinstallation."
    } 1618 {
        write-host "! NOTICE: Code 1618 (another installation is already in progress)."
        write-host "  Please wait for other installations to complete and try again."
    } 1641 {
        write-host ": Code 1641: Installation succeeded; reboot initiated."
        write-host "  The system is being restarted to complete installation."
    } 3010 {
        write-host ": Code 3010: Installation succeeded; reboot required."
        write-host "  Please restart the system to complete installation."
    } default {
        write-host "! NOTICE: Exit code unhandled ($_). Please scrutinise output log."
    }
}

write-host `r
write-host "  The last 100 lines have been placed into the StdErr stream."

if (test-path "$PWD\foxit-editor.log") {
    $host.ui.WriteErrorLine("------------------------------------------------")
    $host.ui.WriteErrorLine("INSTALLATION LOG (last 100 lines):")
    get-content "$PWD\foxit-editor.log" | select -last 100 | % {$host.ui.WriteErrorLine($_)}
    $host.ui.WriteErrorLine("------------------------------------------------")
} else {
    write-host "! ERROR: Installation log not found."
    write-host "  Please check the device. An issue may have occurred."
    exit 1
}

write-host `r
write-host "Installation complete. Remember: Users must activate via SSO on first launch."
