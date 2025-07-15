<#
.SYNOPSIS
Test Environment Variable Inheritance for Hard-Coded Launcher System

.DESCRIPTION
This test verifies that environment variables are properly inherited when PowerShell
executes a script using & $scriptPath, which is critical for the hard-coded launcher
system to work correctly with Datto RMM.

.PARAMETER TestScenario
Which test scenario to run: Basic, DattoRMM, or All

.EXAMPLE
.\Test-EnvironmentVariableInheritance.ps1 -TestScenario All

.NOTES
Version: 1.0.0
Author: Datto RMM Function Library
Purpose: Validate hard-coded launcher environment variable inheritance
#>

param(
    [ValidateSet('Basic', 'DattoRMM', 'All')]
    [string]$TestScenario = 'All'
)

# Test configuration
$TestDir = "$env:TEMP\RMM-EnvVar-Test"
$TestResults = @()

# Ensure test directory exists
if (-not (Test-Path $TestDir)) {
    New-Item -Path $TestDir -ItemType Directory -Force | Out-Null
}

Write-Output "=============================================="
Write-Output "Environment Variable Inheritance Test"
Write-Output "=============================================="
Write-Output "Test Directory: $TestDir"
Write-Output "Test Scenario: $TestScenario"
Write-Output "Timestamp: $(Get-Date)"
Write-Output ""

# Function to add test results
function Add-TestResult {
    param(
        [string]$TestName,
        [string]$Status,
        [string]$Details,
        [string]$Expected = "",
        [string]$Actual = ""
    )
    
    $result = [PSCustomObject]@{
        TestName = $TestName
        Status = $Status
        Details = $Details
        Expected = $Expected
        Actual = $Actual
        Timestamp = Get-Date
    }
    
    $script:TestResults += $result
    
    $statusIcon = switch ($Status) {
        "PASS" { "✅" }
        "FAIL" { "❌" }
        "INFO" { "ℹ️" }
        default { "⚠️" }
    }
    
    Write-Output "$statusIcon $TestName - $Status"
    if ($Details) { Write-Output "   $Details" }
    if ($Expected -and $Actual) {
        Write-Output "   Expected: $Expected"
        Write-Output "   Actual: $Actual"
    }
    Write-Output ""
}

# Test 1: Basic Environment Variable Inheritance
if ($TestScenario -eq 'Basic' -or $TestScenario -eq 'All') {
    Write-Output "=== Test 1: Basic Environment Variable Inheritance ==="
    
    # Create a simple test script
    $TestScript1 = @'
# Test script to verify environment variable inheritance
Write-Output "=== Child Script Environment Variables ==="
Write-Output "TEST_VAR1: $env:TEST_VAR1"
Write-Output "TEST_VAR2: $env:TEST_VAR2"
Write-Output "TEST_BOOLEAN: $env:TEST_BOOLEAN"
Write-Output "TEST_NUMBER: $env:TEST_NUMBER"

# Test if variables are accessible
if ($env:TEST_VAR1) {
    Write-Output "SUCCESS: TEST_VAR1 inherited correctly"
    exit 0
} else {
    Write-Output "FAILURE: TEST_VAR1 not inherited"
    exit 1
}
'@
    
    $TestScript1Path = Join-Path $TestDir "BasicTest.ps1"
    $TestScript1 | Out-File -FilePath $TestScript1Path -Encoding UTF8
    
    # Set test environment variables
    $env:TEST_VAR1 = "Hello from parent"
    $env:TEST_VAR2 = "Another test value"
    $env:TEST_BOOLEAN = "true"
    $env:TEST_NUMBER = "42"
    
    Add-TestResult "Environment Setup" "INFO" "Set test environment variables in parent process"
    
    try {
        # Execute the test script using & (same method as hard-coded launcher)
        $output = & $TestScript1Path 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Add-TestResult "Basic Inheritance Test" "PASS" "Environment variables successfully inherited by child script"
        } else {
            Add-TestResult "Basic Inheritance Test" "FAIL" "Environment variables NOT inherited by child script" "Exit code 0" "Exit code $exitCode"
        }
        
        # Display child script output
        Write-Output "Child Script Output:"
        $output | ForEach-Object { Write-Output "  $_" }
        Write-Output ""
        
    } catch {
        Add-TestResult "Basic Inheritance Test" "FAIL" "Error executing child script: $($_.Exception.Message)"
    }
}

# Test 2: Datto RMM Simulation Test
if ($TestScenario -eq 'DattoRMM' -or $TestScenario -eq 'All') {
    Write-Output "=== Test 2: Datto RMM Environment Variable Simulation ==="
    
    # Create a script that mimics how Datto RMM scripts access environment variables
    $TestScript2 = @'
# Simulate Datto RMM script environment variable access
function Get-RMMVariable {
    param([string]$Name, [string]$Type='String', [object]$Default='', [switch]$Required)
    $val = Get-Item "env:$Name" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value
    if ([string]::IsNullOrWhiteSpace($val)) {
        if ($Required) {
            Write-Output "ERROR: Input variable '$Name' required but not supplied"
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

Write-Output "=== Datto RMM Variable Access Test ==="

# Test typical Datto RMM variables
$customwhitelist = Get-RMMVariable -Name "customwhitelist" -Type "String" -Default "DefaultApp1,DefaultApp2"
$skipwindows = Get-RMMVariable -Name "skipwindows" -Type "Boolean" -Default $false
$RebootEnabled = Get-RMMVariable -Name "RebootEnabled" -Type "Boolean" -Default $false
$MaxRetries = Get-RMMVariable -Name "MaxRetries" -Type "Integer" -Default 3

Write-Output "customwhitelist: $customwhitelist"
Write-Output "skipwindows: $skipwindows"
Write-Output "RebootEnabled: $RebootEnabled"
Write-Output "MaxRetries: $MaxRetries"

# Verify values
$success = $true
if ($customwhitelist -ne "App1,App2,App3") { $success = $false }
if ($skipwindows -ne $false) { $success = $false }
if ($RebootEnabled -ne $true) { $success = $false }
if ($MaxRetries -ne 5) { $success = $false }

if ($success) {
    Write-Output "SUCCESS: All Datto RMM variables accessed correctly"
    exit 0
} else {
    Write-Output "FAILURE: Some Datto RMM variables not accessed correctly"
    exit 1
}
'@
    
    $TestScript2Path = Join-Path $TestDir "DattoRMMTest.ps1"
    $TestScript2 | Out-File -FilePath $TestScript2Path -Encoding UTF8
    
    # Set Datto RMM-style environment variables
    $env:customwhitelist = "App1,App2,App3"
    $env:skipwindows = "false"
    $env:RebootEnabled = "true"
    $env:MaxRetries = "5"
    
    Add-TestResult "Datto RMM Env Setup" "INFO" "Set Datto RMM-style environment variables"
    
    try {
        # Execute the Datto RMM simulation script
        $output = & $TestScript2Path 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Add-TestResult "Datto RMM Simulation Test" "PASS" "Datto RMM-style variables successfully inherited and processed"
        } else {
            Add-TestResult "Datto RMM Simulation Test" "FAIL" "Datto RMM-style variables NOT properly inherited" "Exit code 0" "Exit code $exitCode"
        }
        
        # Display child script output
        Write-Output "Datto RMM Simulation Output:"
        $output | ForEach-Object { Write-Output "  $_" }
        Write-Output ""
        
    } catch {
        Add-TestResult "Datto RMM Simulation Test" "FAIL" "Error executing Datto RMM simulation: $($_.Exception.Message)"
    }
}

# Test 3: Hard-Coded Launcher Simulation
if ($TestScenario -eq 'All') {
    Write-Output "=== Test 3: Hard-Coded Launcher Simulation ==="
    
    # Create a mini hard-coded launcher
    $MiniLauncher = @'
# Mini Hard-Coded Launcher Simulation
param([string]$TargetScript)

Write-Output "=== Mini Hard-Coded Launcher ==="
Write-Output "Target Script: $TargetScript"
Write-Output "Environment Variables Available:"

# Display environment variables (like our hard-coded launcher does)
$rmmVars = Get-ChildItem env: | Where-Object { 
    $_.Name -like "TEST_*" -or 
    $_.Name -like "customwhitelist*" -or 
    $_.Name -like "skip*" -or 
    $_.Name -like "Reboot*" -or 
    $_.Name -like "Max*"
} | Sort-Object Name

foreach ($var in $rmmVars) {
    Write-Output "  $($var.Name) = $($var.Value)"
}

Write-Output ""
Write-Output "Executing target script..."
Write-Output "=========================="

# Execute the target script (same as hard-coded launcher)
& $TargetScript
$exitCode = $LASTEXITCODE

Write-Output "=========================="
Write-Output "Target script completed with exit code: $exitCode"
exit $exitCode
'@
    
    $MiniLauncherPath = Join-Path $TestDir "MiniLauncher.ps1"
    $MiniLauncher | Out-File -FilePath $MiniLauncherPath -Encoding UTF8
    
    # Create target script for launcher to execute
    $TargetScript = @'
Write-Output "=== Target Script Executed by Launcher ==="
Write-Output "Checking environment variable inheritance..."

$allGood = $true
$testVars = @("TEST_VAR1", "customwhitelist", "skipwindows", "RebootEnabled", "MaxRetries")

foreach ($varName in $testVars) {
    $value = [Environment]::GetEnvironmentVariable($varName)
    if ($value) {
        Write-Output "✅ $varName = $value"
    } else {
        Write-Output "❌ $varName = (not found)"
        $allGood = $false
    }
}

if ($allGood) {
    Write-Output "SUCCESS: All environment variables inherited through launcher"
    exit 0
} else {
    Write-Output "FAILURE: Some environment variables missing"
    exit 1
}
'@
    
    $TargetScriptPath = Join-Path $TestDir "TargetScript.ps1"
    $TargetScript | Out-File -FilePath $TargetScriptPath -Encoding UTF8
    
    try {
        # Execute mini launcher (simulates hard-coded launcher behavior)
        $output = & $MiniLauncherPath -TargetScript $TargetScriptPath 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Add-TestResult "Hard-Coded Launcher Simulation" "PASS" "Environment variables successfully passed through launcher to target script"
        } else {
            Add-TestResult "Hard-Coded Launcher Simulation" "FAIL" "Environment variables NOT properly passed through launcher" "Exit code 0" "Exit code $exitCode"
        }
        
        # Display launcher output
        Write-Output "Launcher Simulation Output:"
        $output | ForEach-Object { Write-Output "  $_" }
        Write-Output ""
        
    } catch {
        Add-TestResult "Hard-Coded Launcher Simulation" "FAIL" "Error executing launcher simulation: $($_.Exception.Message)"
    }
}

# Test Summary
Write-Output "=============================================="
Write-Output "TEST SUMMARY"
Write-Output "=============================================="

$passCount = ($TestResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($TestResults | Where-Object { $_.Status -eq "FAIL" }).Count
$totalTests = ($TestResults | Where-Object { $_.Status -in @("PASS", "FAIL") }).Count

Write-Output "Total Tests: $totalTests"
Write-Output "Passed: $passCount"
Write-Output "Failed: $failCount"
Write-Output ""

if ($failCount -eq 0 -and $passCount -gt 0) {
    Write-Output "🎉 ALL TESTS PASSED - Hard-coded launcher approach WILL WORK!"
    Write-Output ""
    Write-Output "✅ Environment variables ARE inherited by child PowerShell processes"
    Write-Output "✅ Datto RMM-style variable access works correctly"
    Write-Output "✅ Hard-coded launcher pattern successfully passes variables to target scripts"
    Write-Output ""
    Write-Output "The hard-coded launcher system is ready for production use!"
} else {
    Write-Output "⚠️ SOME TESTS FAILED - Review results above"
    Write-Output ""
    Write-Output "This indicates potential issues with the hard-coded launcher approach."
    Write-Output "Please review the failed tests and address any issues before deployment."
}

# Cleanup test environment variables
$env:TEST_VAR1 = $null
$env:TEST_VAR2 = $null
$env:TEST_BOOLEAN = $null
$env:TEST_NUMBER = $null
$env:customwhitelist = $null
$env:skipwindows = $null
$env:RebootEnabled = $null
$env:MaxRetries = $null

Write-Output ""
Write-Output "Test completed. Test files remain in: $TestDir"
Write-Output "=============================================="
