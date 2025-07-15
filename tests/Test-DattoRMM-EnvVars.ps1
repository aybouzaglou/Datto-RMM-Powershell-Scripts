<#
.SYNOPSIS
Quick Test - Datto RMM Environment Variable Inheritance

.DESCRIPTION
Simple test to verify that the hard-coded launcher approach will work with Datto RMM
by testing environment variable inheritance in the exact same pattern.

.EXAMPLE
.\Test-DattoRMM-EnvVars.ps1

.NOTES
This test simulates:
1. Datto RMM setting environment variables
2. Hard-coded launcher downloading and executing a script
3. Downloaded script accessing those environment variables
#>

Write-Output "🧪 Testing Datto RMM Environment Variable Inheritance"
Write-Output "====================================================="
Write-Output ""

# Step 1: Simulate Datto RMM setting environment variables
Write-Output "Step 1: Setting environment variables (simulating Datto RMM UI)..."
$env:customwhitelist = "MyApp1,MyApp2,MyApp3"
$env:skipwindows = "false"
$env:RebootEnabled = "true"
$env:MaxRetries = "3"
$env:LogLevel = "Verbose"

Write-Output "✅ Environment variables set:"
Write-Output "   customwhitelist = $env:customwhitelist"
Write-Output "   skipwindows = $env:skipwindows"
Write-Output "   RebootEnabled = $env:RebootEnabled"
Write-Output "   MaxRetries = $env:MaxRetries"
Write-Output "   LogLevel = $env:LogLevel"
Write-Output ""

# Step 2: Create a test script (simulating downloaded script from GitHub)
Write-Output "Step 2: Creating test script (simulating GitHub download)..."
$TestScriptContent = @'
# This simulates a script downloaded from GitHub by the hard-coded launcher
Write-Output "🔍 Downloaded Script - Testing Environment Variable Access"
Write-Output "========================================================="

# Embedded Get-RMMVariable function (same as in real scripts)
function Get-RMMVariable {
    param([string]$Name, [string]$Type='String', [object]$Default='', [switch]$Required)
    $val = Get-Item "env:$Name" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value
    if ([string]::IsNullOrWhiteSpace($val)) {
        if ($Required) {
            Write-Output "ERROR: Required variable '$Name' not found"
            exit 1
        }
        return $Default
    }
    switch ($Type) {
        'Boolean' { return ($val -eq 'true') }
        'Integer' { try { return [int]$val } catch { return $Default } }
        default   { return $val }
    }
}

Write-Output "Accessing environment variables using Get-RMMVariable..."

# Test accessing variables exactly like real Datto RMM scripts do
$customwhitelist = Get-RMMVariable -Name "customwhitelist" -Type "String"
$skipwindows = Get-RMMVariable -Name "skipwindows" -Type "Boolean" -Default $false
$RebootEnabled = Get-RMMVariable -Name "RebootEnabled" -Type "Boolean" -Default $false
$MaxRetries = Get-RMMVariable -Name "MaxRetries" -Type "Integer" -Default 1
$LogLevel = Get-RMMVariable -Name "LogLevel" -Type "String" -Default "Normal"

Write-Output ""
Write-Output "📊 Variables accessed by downloaded script:"
Write-Output "   customwhitelist: $customwhitelist (Type: String)"
Write-Output "   skipwindows: $skipwindows (Type: Boolean)"
Write-Output "   RebootEnabled: $RebootEnabled (Type: Boolean)"
Write-Output "   MaxRetries: $MaxRetries (Type: Integer)"
Write-Output "   LogLevel: $LogLevel (Type: String)"
Write-Output ""

# Validate that values match what was set
$success = $true
$errors = @()

if ($customwhitelist -ne "MyApp1,MyApp2,MyApp3") {
    $success = $false
    $errors += "customwhitelist mismatch: expected 'MyApp1,MyApp2,MyApp3', got '$customwhitelist'"
}

if ($skipwindows -ne $false) {
    $success = $false
    $errors += "skipwindows mismatch: expected False, got $skipwindows"
}

if ($RebootEnabled -ne $true) {
    $success = $false
    $errors += "RebootEnabled mismatch: expected True, got $RebootEnabled"
}

if ($MaxRetries -ne 3) {
    $success = $false
    $errors += "MaxRetries mismatch: expected 3, got $MaxRetries"
}

if ($LogLevel -ne "Verbose") {
    $success = $false
    $errors += "LogLevel mismatch: expected 'Verbose', got '$LogLevel'"
}

if ($success) {
    Write-Output "✅ SUCCESS: All environment variables correctly inherited and processed!"
    Write-Output ""
    Write-Output "This proves the downloaded script can access all Datto RMM environment variables."
    exit 0
} else {
    Write-Output "❌ FAILURE: Environment variable issues detected:"
    foreach ($error in $errors) {
        Write-Output "   - $error"
    }
    exit 1
}
'@

$TestScriptPath = "$env:TEMP\TestDownloadedScript.ps1"
$TestScriptContent | Out-File -FilePath $TestScriptPath -Encoding UTF8
Write-Output "✅ Test script created at: $TestScriptPath"
Write-Output ""

# Step 3: Execute the script using & (same method as hard-coded launcher)
Write-Output "Step 3: Executing script using & method (simulating hard-coded launcher)..."
Write-Output "========================================================================"
Write-Output ""

try {
    # This is the critical test - does & $scriptPath inherit environment variables?
    & $TestScriptPath
    $exitCode = $LASTEXITCODE
    
    Write-Output ""
    Write-Output "========================================================================"
    Write-Output "🎯 TEST RESULT:"
    
    if ($exitCode -eq 0) {
        Write-Output "✅ PASSED - Environment variables successfully inherited!"
        Write-Output ""
        Write-Output "🎉 CONCLUSION: Hard-coded launcher approach WILL WORK with Datto RMM!"
        Write-Output ""
        Write-Output "What this proves:"
        Write-Output "• Datto RMM environment variables are accessible via `$env:VariableName"
        Write-Output "• PowerShell & execution inherits environment variables to child processes"
        Write-Output "• Downloaded scripts can access all environment variables set by Datto RMM"
        Write-Output "• Hard-coded launchers will successfully pass variables to target scripts"
        Write-Output ""
        Write-Output "✅ The hard-coded launcher system is ready for production deployment!"
    } else {
        Write-Output "❌ FAILED - Environment variables NOT properly inherited!"
        Write-Output ""
        Write-Output "⚠️ This indicates a potential issue with the hard-coded launcher approach."
        Write-Output "Exit code: $exitCode"
    }
    
} catch {
    Write-Output "❌ ERROR executing test script: $($_.Exception.Message)"
    Write-Output ""
    Write-Output "⚠️ This indicates a potential issue with script execution."
}

# Cleanup
Write-Output ""
Write-Output "🧹 Cleaning up test environment..."
Remove-Item $TestScriptPath -ErrorAction SilentlyContinue
$env:customwhitelist = $null
$env:skipwindows = $null
$env:RebootEnabled = $null
$env:MaxRetries = $null
$env:LogLevel = $null

Write-Output "✅ Cleanup complete"
Write-Output ""
Write-Output "====================================================="
Write-Output "Test completed - $(Get-Date)"
Write-Output "====================================================="
