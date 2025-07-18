$varSHA256_SFX="634BC6B969A35A76FC037212FADB36AF9F796E2D091A497E5378876C11F9CB51"
$varSHA256_CPAs="F0BFA2B80BA20A1087BB3977DF744D2F5050D6078EC080AA3CCD438CCB68B7B8"
$varVersion="1.0.6.5000v2"

#region Start ---------------------------------------------------------------------------------------------------------

@"
<-Start Diagnostic->
OneDrive Sync Status Monitor: Diagnostic Output
============================
: Script build:       $varBuild
: ODSyncUtil Version: $varVersion

"@ | write-host

#remove any lingering results files
remove-item "$env:PUBLIC\ODSyncLatest.txt" -Force -ea 0

#region Functions & Variables -----------------------------------------------------------------------------------------

$varExit=0
$varSysVer=[int](get-wmiObject win32_operatingSystem buildNumber).buildNumber

$varProgData=$((get-process aemagent).path | split-path | split-path)

#close diagnostics, write an alert, and exit...........................................................................
function writeAlert ($message, $code) {
    #set monitor status back to zero
    New-ItemProperty -Path "HKLM:\Software\CentraStage\ODSyncSGL" -Name "MonitorStatus" -PropertyType String -Value "0" -force | out-null

    #send alert
    write-host "- Exiting with code $code"
    write-host '<-End Diagnostic->'
    write-host '<-Start Result->'
    write-host "Status=$message"
    write-host '<-End Result->'

    #exit
    exit $code
}

#convert back-and-forth between ODSyncUtil's enums and plain-english readings thereof..................................
function convertStatusEnum ($enum) {
    if ($enum -is [int]) {
        switch ($enum) {
            0 {return "Synched"}
            1 {return "Synching/Signing in"}
            2 {return "Paused"}
            3 {return "Error"}
            4 {return "Warning"}
            5 {return "Offline"}
            default {return "Script Error"}
        }
    } else {
        switch ($enum) {
            'Synched' {return 0}
            'Synching/Signing in' {return 1}
            'Paused' {return 2}
            'Error' {return 3}
            'Warning' {return 4}
            'Offline' {return 5}
            default {return "Script Error"}
        }
    }
}

#calculate the SHA256 filehash of a given file and compare it against the file's expected checksum.....................
function compareSHA256 {
	param ([Parameter(ValueFromPipeline=$true)]$string,[string]$storedHash)
    try {
	    $varCalculatedHash=-Join ($([System.Security.Cryptography.SHA256]::Create()).ComputeHash((New-Object IO.StreamReader $input).BaseStream) | ForEach {"{0:x2}" -f $_})
    } catch {
        writeAlert "ERROR: Unable to parse input file for SHA256 verification. Please report this error." 1
    }
    if ($storedHash -match $varCalculatedHash) {
        write-host "- Filehash verified for file $executable`: $storedHash"
    } else {
        write-host "- ERROR: Filehash mismatch for file $input."
        write-host "  Expected value: $storedHash"
        write-host "  Received value: $varCalculatedHash"
        write-host "  Please report this error."
        writeAlert "ERROR: SHA256 mismatch on downloaded file. Please report this error." 1
    }
}

#detect proxy settings and pre-emptively load them in as parameters for subsequent download operations.................
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
    write-host "! NOTICE: Device appears to be configured to use a proxy server, but settings could not be read."
}

#download a file (downloadFile custom build)...........................................................................
function downloadFile {
    param (
        [parameter(mandatory=$false)]$url,
        [parameter(mandatory=$false)]$filename,
        [parameter(mandatory=$false,ValueFromPipeline=$true)]$pipe
    )

    function setUserAgent {
        $script:WebClient = New-Object System.Net.WebClient
    	$script:webClient.UseDefaultCredentials = $true
        $script:webClient.Headers.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f")
        $script:webClient.Headers.Add([System.Net.HttpRequestHeader]::UserAgent, 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705;)');
    }

    if (!$url) {$url=$pipe}
	if (!$filename) {$filename=$url.split('/')[-1]}
	
    try { #enable TLS 1.2
		[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
    } catch [system.exception] {
		writeAlert "ERROR: Unable to implement TLS 1.2 Support" 1
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
        write-host "! ERROR: Unable to download [$filename] from [$url]!"
        writeAlert "ERROR: Unable to download files. Please check alert diagnostic." 1
    }

    write-host ": File downloaded OK"
}

#verify a digital signature (verifyPackage custom build, jul 2025).....................................................
function verifyPackage ($file, $certificate, $thumbprint, $name, $url) { #custom build
    $varChain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    try {
        $varChain.Build((Get-AuthenticodeSignature -FilePath "$file").SignerCertificate) | out-null
    } catch [System.Management.Automation.MethodInvocationException] {
        write-host "! ERROR: Unable to verify signature for [$file]"
        $script:varCertError++
    }

    #check digsig status
    if ((Get-AuthenticodeSignature "$file").status.value__ -ne 0) {
        write-host "! ERROR: $name installer contained a digital signature, but it was invalid."
        write-host "  This strongly suggests that the file has been tampered with."
        write-host "  Please re-attempt download. If the issue persists, contact Support."
        $script:varCertError++
    }

    $varIntermediate=($varChain.ChainElements | ForEach-Object {$_.Certificate} | Where-Object {$_.Subject -match "$certificate"}).Thumbprint
    if ($varIntermediate -ne $thumbprint) {
        write-host "! ERROR: Unexpected signature for [$file]:"
        write-host "  Expected: $thumbprint"
        write-host "  Received: $varIntermediate"
        $script:varCertError++
    }
}

#region MIT licences for ODSyncUtil and createProcessAsUser -----------------------------------------------------------

<#
The MIT License (MIT)

createProcessAsUser Copyright (c) 2014 Justin Murray
ODSyncUtil Copyright (c) 2024 Rodney Viana

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

#region System Checks -------------------------------------------------------------------------------------------------

#OS version............................................................................................................
if ($varSysVer -lt "10240") {
    write-host "! ERROR: Unsupported operating system."
    write-host "  This device requires a minimum of Windows 10 or Server 2016;"
    write-host "  in tech terms, its kernel version must be higher than 10240."
    write-host "  This device's kernel version is: $varSysVer"
    write-host "  Please upgrade this device."
    writeAlert "Unsupported OS: Minimum of Windows 10/Server 2016 required." 1
}

#OS architecture.......................................................................................................
if ([intptr]::Size -eq 4) {
    #https://github.com/rodneyviana/ODSyncUtil/issues/18
    write-host "! ERROR: Unsupported architecture."
    write-host "  This device's operating system is either a 32-bit distribution or,"
    write-host "  as we have seen in some rare cases, the Dotnet Framework is configured"
    write-host "  to run in 32-bit mode, causing checks like the one this script performs"
    write-host "  to return a 32-bit architecture reading despite the host OS."
    write-host "  You can run the Health Check Component to confirm this suspicion."
    write-host "- Cannot continue; exiting."
    writeAlert "Unsupported architecture: A 64-bit version of Windows is required."
}

#folders...............................................................................................................
if (!(test-path "$env:public\CentraStage")) {
    write-host "- Created $env:Public\CentraStage directory"
    new-item "$env:public\CentraStage" -ItemType Directory -Force | out-null
}

write-host "- System verified OK"

#region Is Monitor Running? -------------------------------------------------------------------------------------------

try {
    gp "HKLM:\Software\CentraStage\ODSyncSGL" -ea 1 | out-null
} catch {
    write-host "- First run: Creating Registry key @ HKLM:\Software\CentraStage\ODSyncSGL"
    new-item "HKLM:\Software\CentraStage\ODSyncSGL" -Force | Out-Null
}

if ((gp "HKLM:\Software\CentraStage\ODSyncSGL" -ea 0).MonitorStatus -eq 1) {
    write-host "- Monitor exited: already running"
    write-host "  (Clear the flag at HKLM:\Software\CentraStage\ODSyncSGL!MonitorStatus to force-reset this)"
    exit
} else {
    New-ItemProperty -Path "HKLM:\Software\CentraStage\ODSyncSGL" -Name "MonitorStatus" -PropertyType String -Value "1" -force | out-null
}

#region Verification/Despatch/Download --------------------------------------------------------------------------------

#download..............................................................................................................
if (!(test-path "$varProgData\ODSync\$varVersion\ODSyncUtil.exe")) {
    new-item "$varProgData\ODSync\$varVersion" -Force -ItemType Directory | Out-Null
    "https://storage.centrastage.net/ODSync/ODSyncUtil%28$varVersion%29.exe" | downloadFile -filename ODSFX.exe
    "$PWD\ODSFX.exe" | compareSHA256 -storedHash $varSHA256_SFX
    start-process "$PWD\ODSFX.exe" -ArgumentList "-y -o$varProgData\ODSync\$varVersion" -Wait -NoNewWindow
}

#verify................................................................................................................
"ODSyncUtil.exe","OneDriveFlyoutPS.dll" | % {
    verifyPackage "$varProgData\ODSync\$varVersion\$_" "Sectigo RSA Code Signing CA" "94C95DA1E850BD85209A4A2AF3E1FB1604F9BB66" "$_"
}

"$varProgData\ODSync\$varVersion\CPAS.dll" | compareSHA256 -storedHash $varSHA256_CPAS

if ($script:varCertError) {
    remove-item "$varProgData\ODSync\$varVersion" -Force -Recurse
    write-host "! ERROR: The digital signatures for the core files used by this monitor were invalid."
    write-host "  These signatures are checked to ensure the files have not been replaced by a bad"
    write-host "  actor for blind execution by this script - but this is a very unlikely scenario."
    write-host "  If these alerts persist, please reach out to the Support team to work out the cause."
    writeAlert "ERROR: Unable to verify digital signatures. Deleting directory and re-deploying." 1
}

write-host "- ODSyncUtil.exe, OneDriveFlyoutPS.dll, and CPAS.dll files verified OK"
write-host `r

#region OneDriveFlyoutPS.dll ------------------------------------------------------------------------------------------

write-host "- Loading OneDrive Flyout DLL for ODSyncUtil..."
regsvr32 /i "$varProgData\ODSync\$varVersion\OneDriveFlyoutPS.dll" /s

#region Userland ODSyncUtil Code --------------------------------------------------------------------------------------

$varScriptBlock=@"
#run without loading in the DLL
cmd /c "$varProgData\ODSync\$varVersion\odsyncutil.exe" | out-file "$env:PUBLIC\ODSyncLatest.txt"

#if the output is empty, delete it, re-load the DLL, and try again
if ((get-content "$env:PUBLIC\ODSyncLatest.txt").length -lt 5) {
    remove-item "$env:PUBLIC\ODSyncLatest.txt" -force
    #shouldn't be necessary given the above, but better safe than sorry
    regsvr32 /i "$varProgData\ODSync\$varVersion\OneDriveFlyoutPS.dll" /s
    start-sleep -seconds 10
    #even if no user is logged on, we'll still make this file. if it's not there, that means this script block didn't execute.
    cmd /c "$varProgData\ODSync\$varVersion\odsyncutil.exe" | out-file "$env:PUBLIC\CentraStage\ODSyncLatest.txt"
}
"@

#load in CreateProcessASuser............................................................................................
Add-Type -path "$varProgData\ODSync\$varVersion\CPAS.dll"

#the actual code to launch something as the logged-in user.............................................................
try {
    write-host "============================"
    write-host "- startProcessAsCurrentUser exited OK:"
    [murrayju.ProcessExtensions.ProcessExtensions]::StartProcessAsCurrentUser("C:\Windows\System32\WindowsPowershell\v1.0\Powershell.exe", "-command $($varScriptBlock)", "C:\Windows\System32\WindowsPowershell\v1.0\", $false, -1)
    write-host "============================"
} catch {
    write-host "! ERROR: Unable to impersonate the logged-in user."
    write-host "  This diagnostic text will only be visible if this operation has never worked;"
    write-host "  the most likely reason why this would fail is that no user is logged on, in"
    write-host "  which case the Monitor will not alert as that does not require attention."
    write-host "  Regardless, for bookkeeping's sake, the error encountered was, in its entirety:"
    write-host `r
    write-host "$($_.Exception | select *)"
}

#region Parse JSON ----------------------------------------------------------------------------------------------------

$arrProfiles=@{}
if ((get-content "$env:PUBLIC\ODSyncLatest.txt").length -gt 5) {
    $varJSONObject=get-content "$env:PUBLIC\ODSyncLatest.txt" | convertFrom-Json

    $varJSONObject | % {
        #verification: if we have no 'QuotaLabel' value, throw this block out - it's not for the logged-in user
        if (!($_.QuotaLabel)) {
            write-host "- Data gathered for user $($_.Username), but the QuotaLabel field is blank."
            write-host "  This typically means that this user has a OneDrive profile on the device,"
            write-host "  but it isn't accessible to the user logged-in at this point in time."
            write-host "  Since this data block is thus 'idle', it will be ignored in the 'live' search."
            return
        }

        #make a 'profile' for this json object
        $varProfile=New-Object PSObject

        #populate a string for the monitor output
        $varString+="ACTIVE: $($_.Username) ($($_.ServiceName)): $(convertStatusEnum $($_.CurrentState)) ($(($_.QuotaLabel -split '\(')[1] -replace '\)') used) | "

        #produce an object to compare against the registry
        $varProfile | Add-Member -MemberType NoteProperty -Name "Name" -Value $_.Username
        $varProfile | Add-Member -MemberType NoteProperty -Name "ServiceName" -Value $_.ServiceName
        $varProfile | Add-Member -MemberType NoteProperty -Name "Status" -Value $(convertStatusEnum $($_.CurrentState))
        $varProfile | Add-Member -MemberType NoteProperty -Name "Used" -Value $(($_.QuotaLabel -split '\(')[1] -replace '\)')

        #if the current profile's status is in alert state, flip the error bit
        if ($_.CurrentState -gt 2) {
            write-host "! ERROR: A logged-on user has been detected with a Status value of [Error], [Warning] or [Offline]."
            write-host "  An alert will be raised."
            write-host `r
            $varExit=1
        }

        #commit the object to the array
        $arrProfiles+=@{"$($_.Sid):$($_.ServiceName)"=$varProfile}
    }
}

if ($arrProfiles.count -lt 1) {
    write-host ": No data could be gathered from the logged-on user."
    write-host "  Data will be supplemented by information from the Registry."
} else {
    write-host "- Contents of OneDrive user profile list as gathered from logged-in user:"
    ($arrProfiles | format-list | out-string).trim()
    write-host `r
}

remove-item "$env:PUBLIC\ODSyncLatest.txt" -Force

#region Compare & Contrast --------------------------------------------------------------------------------------------

write-host "- Checking Registry for stored user data..."

#add profiles (which weren't gathered by the 'active' search) to the string (as 'idle' profiles).......................
if (gp "HKLM:\Software\CentraStage\ODSyncSGL" -ea 0) {
    gp "HKLM:\Software\CentraStage\ODSyncSGL" | get-member -ea 0 | ? {$_.name -match '^S-1'} | % {
        $varName=$_.name
        if ($arrProfiles["$varName"]) {
            write-host ": User [$varName] found"
        } else {
            write-host ": User [$varName] found & added to profile list as stored data"
            $varObject=(gp "HKLM:\Software\CentraStage\ODSyncSGL").$varName -split '\|'
            $varString+="IDLE: $($varObject[0]) ($(($varName -split ':')[1])): $(convertStatusEnum $($varObject[1] -as [int])) ($($varObject[2]) used) | "

            #if this idle profile is in an error state, and if the user has configured it, flip the error bit
            if ($env:usrAlertOnIdleError -match 'true') {
                if ($varObject[1] -gt 2) {
                    write-host "! ERROR: A user who is not logged on has been detected with a Status value of [Error], [Warning] or [Offline]."
                    write-host "  As the usrAlertOnIdleError flag has been set to TRUE, an alert will be raised."
                    write-host "  Suppress warnings for users who are not logged on by changing usrAlertOnIdleError to FALSE."
                    $varExit=1
                }
            }
        }
    }
} else {
    write-host ": No stored profiles found in Registry"
}

#for each member of the 'active' search, forcibly replace all existing registry data...................................
$arrProfiles.getEnumerator() | % {
    New-ItemProperty "HKLM:\Software\CentraStage\ODSyncSGL" -Name $_.name -Value "$($_.value.name)|$(convertStatusEnum $($_.value.status))|$($_.value.used)" -Force | Out-Null
    $varSyncBack++
}

if ($varSyncBack) {
    write-host "- Stored Registry data overwritten with new live data OK"
} else {
    write-host "- Stored Registry data takes precedence for this script run"
}

#region Error Handling ------------------------------------------------------------------------------------------------

#check to see if onedrive is actually installed for any users..........................................................
Get-ChildItem "Registry::HKEY_USERS\" -ea 0 | ? { $_.PSIsContainer } | % {
    foreach ($node in ("Software","Software\WOW6432Node")) {
        if (test-path "Registry::$_\$node\Microsoft\Windows\CurrentVersion\Uninstall" -ea 0) {
            gci "Registry::$_\$node\Microsoft\Windows\CurrentVersion\Uninstall" | % {Get-ItemProperty $_.PSPath} | ? {$_.DisplayName -match '^Microsoft OneDrive$'} | % {
                $varODInst=$true           
            }
        }
    }
}

#zero profiles enumerated..............................................................................................
if ($arrProfiles.count -eq 0) {
    if (!$varODInst) {
        if ((gci "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SyncRootManager").name -match 'OneDrive!') {
            #...because onedrive hasn't been set up
            writeAlert "ERROR: OneDrive has not been set up on this system." 0
        } else {
            #...because onedrive isn't installed
            writeAlert "ERROR: OneDrive is not installed on this system." 0 #no alert, no diagnostic
        }
    }

    #...because no user is logged on and there is no stored data
    if ((gp "HKLM:\Software\CentraStage\ODSyncSGL" | get-member | ? {$_.name -match '^S-1'}).count -eq 0) {
        write-host "! ERROR: It appears there is neither any live data from ODSyncUtil nor stored data from the Registry."
        write-host "  This suggests that the script has never been able to successfully pull information."
        write-host "  This could just be because the first script run was performed when no users were logged on,"
        write-host "  or it could point to a larger issue which hopefully this diagnostic text will shed light on."
        write-host "  Please scrutinise the above and contact Support if nothing is obvious."
        write-host "  Reminder: Naturally, OneDrive needs to be signed-into on the device being monitored."
        writeAlert "ERROR: No data gathered from Monitor." 1
    }
}

#no string assembled...................................................................................................
if (!$varString) {
    write-host "! ERROR: Output string is blank."
    write-host "  Every user whose OneDrive profile is enumerated adds to a string (variable varString), the"
    write-host "  contents of which is regurgitated at script conclusion for the alert and UDF output."
    write-host "  It's a concentrated list of usernames, quotae, and sync status."
    write-host "  For whatever reason, the varString variable is empty, so there is nothing to write."
    write-host "  Please contact Support to resolve this issue."
    writeAlert "ERROR: No output string to report." 1
}

#region Write UDF & Close Out -----------------------------------------------------------------------------------------

if ($env:usrUDF -ge 1) {
    New-ItemProperty -Path "HKLM:\Software\CentraStage" -Name "Custom$env:usrUDF" -PropertyType String -Value "$varString" -force | out-null
} else {
    write-host "- Not writing to UDF"
}

writeAlert $varString $varExit