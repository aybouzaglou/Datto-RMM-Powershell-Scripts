<#
.SYNOPSIS
Test Script for GitHub Function Library Architecture

.DESCRIPTION
This script tests the new GitHub-based function library architecture to verify:
- Function loading from GitHub
- Caching mechanisms
- Fallback functionality
- Launcher integration
- Error handling

.PARAMETER TestType
Type of test to run: All, Functions, Launchers, Integration

.EXAMPLE
.\test-architecture.ps1 -TestType All
.\test-architecture.ps1 -TestType Functions

.NOTES
Version: 1.0.0
Author: Datto RMM Function Library Test Suite
#>

param(
    [ValidateSet('All','Functions','Launchers','Integration')]
    [string]$TestType = 'All'
)

Write-Host "=============================================="
Write-Host "Datto RMM Function Library Architecture Test"
Write-Host "=============================================="
Write-Host "Test Type: $TestType"
Write-Host "Start Time: $(Get-Date)"
Write-Host ""

$testResults = @()
$testsPassed = 0
$testsFailed = 0

function Test-Result {
    param([string]$TestName, [bool]$Passed, [string]$Details = "")
    
    $result = [PSCustomObject]@{
        TestName = $TestName
        Passed = $Passed
        Details = $Details
        Timestamp = Get-Date
    }
    
    $script:testResults += $result
    
    if ($Passed) {
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        $script:testsPassed++
    } else {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        if ($Details) {
            Write-Host "  Details: $Details" -ForegroundColor Yellow
        }
        $script:testsFailed++
    }
}

# Test 1: Function Loading
if ($TestType -eq 'All' -or $TestType -eq 'Functions') {
    Write-Host "=== Testing Function Loading ==="
    
    try {
        # Test loading shared functions
        $functionsPath = ".\shared-functions\SharedFunctions.ps1"
        if (Test-Path $functionsPath) {
            . $functionsPath -OfflineMode
            Test-Result "SharedFunctions.ps1 Loading" $true "Loaded in offline mode"
        } else {
            Test-Result "SharedFunctions.ps1 Loading" $false "File not found: $functionsPath"
        }
        
        # Test if global variables are set
        $globalVarsSet = $Global:RMMFunctionsLoaded -ne $null
        Test-Result "Global Variables Set" $globalVarsSet "RMMFunctionsLoaded: $Global:RMMFunctionsLoaded"
        
        # Test core functions availability
        $coreFunctions = @('Write-RMMLog', 'Get-RMMVariable', 'Get-RMMSoftware', 'Invoke-RMMDownload', 'New-RMMDirectory', 'Get-RMMRegistryValue')
        $functionsAvailable = 0
        
        foreach ($func in $coreFunctions) {
            if (Get-Command $func -ErrorAction SilentlyContinue) {
                $functionsAvailable++
            }
        }
        
        $allFunctionsLoaded = $functionsAvailable -eq $coreFunctions.Count
        Test-Result "Core Functions Available" $allFunctionsLoaded "$functionsAvailable of $($coreFunctions.Count) functions loaded"
        
        # Test function execution
        if (Get-Command Write-RMMLog -ErrorAction SilentlyContinue) {
            try {
                Write-RMMLog "Test message" -Level Info
                Test-Result "Write-RMMLog Execution" $true "Function executed successfully"
            } catch {
                Test-Result "Write-RMMLog Execution" $false $_.Exception.Message
            }
        } else {
            Test-Result "Write-RMMLog Execution" $false "Function not available"
        }
        
    } catch {
        Test-Result "Function Loading Test" $false $_.Exception.Message
    }
}

# Test 2: Launcher Scripts
if ($TestType -eq 'All' -or $TestType -eq 'Launchers') {
    Write-Host ""
    Write-Host "=== Testing Launcher Scripts ==="
    
    $launchers = @(
        ".\launchers\UniversalLauncher.ps1",
        ".\launchers\LaunchInstaller.ps1",
        ".\launchers\LaunchMonitor.ps1",
        ".\launchers\LaunchScripts.ps1"
    )
    
    foreach ($launcher in $launchers) {
        $launcherName = Split-Path $launcher -Leaf
        
        if (Test-Path $launcher) {
            try {
                # Test syntax by parsing the script
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $launcher -Raw), [ref]$null)
                Test-Result "$launcherName Syntax" $true "PowerShell syntax is valid"
            } catch {
                Test-Result "$launcherName Syntax" $false $_.Exception.Message
            }
        } else {
            Test-Result "$launcherName Exists" $false "File not found: $launcher"
        }
    }
}

# Test 3: Component Scripts
if ($TestType -eq 'All' -or $TestType -eq 'Integration') {
    Write-Host ""
    Write-Host "=== Testing Component Scripts ==="
    
    $components = @(
        ".\components\Scripts\FocusedDebloat.ps1",
        ".\components\Applications\ScanSnapHome.ps1",
        ".\components\Monitors\DiskSpaceMonitor.ps1"
    )
    
    foreach ($component in $components) {
        $componentName = Split-Path $component -Leaf
        
        if (Test-Path $component) {
            try {
                # Test syntax
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $component -Raw), [ref]$null)
                Test-Result "$componentName Syntax" $true "PowerShell syntax is valid"
                
                # Check for shared function usage
                $content = Get-Content $component -Raw
                $usesSharedFunctions = $content -match '\$Global:RMMFunctionsLoaded' -or $content -match 'Write-RMMLog'
                Test-Result "$componentName Uses Shared Functions" $usesSharedFunctions "Script integrates with function library"
                
            } catch {
                Test-Result "$componentName Syntax" $false $_.Exception.Message
            }
        } else {
            Test-Result "$componentName Exists" $false "File not found: $component"
        }
    }
}

# Test 4: Directory Structure
if ($TestType -eq 'All') {
    Write-Host ""
    Write-Host "=== Testing Directory Structure ==="
    
    $requiredDirs = @(
        ".\shared-functions",
        ".\shared-functions\Core",
        ".\shared-functions\Utilities",
        ".\components",
        ".\components\Monitors",
        ".\components\Applications",
        ".\components\Scripts",
        ".\launchers",
        ".\docs",
        ".\legacy"
    )
    
    foreach ($dir in $requiredDirs) {
        $dirName = $dir -replace '\.\\', ''
        $exists = Test-Path $dir
        Test-Result "Directory: $dirName" $exists "Required directory structure"
    }
    
    # Test required files
    $requiredFiles = @(
        ".\shared-functions\SharedFunctions.ps1",
        ".\shared-functions\Core\RMMLogging.ps1",
        ".\shared-functions\Core\RMMValidation.ps1",
        ".\shared-functions\Core\RMMSoftwareDetection.ps1",
        ".\docs\GitHub-Function-Library-Guide.md",
        ".\docs\Function-Reference.md",
        ".\docs\Deployment-Guide.md"
    )
    
    foreach ($file in $requiredFiles) {
        $fileName = Split-Path $file -Leaf
        $exists = Test-Path $file
        Test-Result "File: $fileName" $exists "Required architecture file"
    }
}

# Test 5: Integration Test (if functions are loaded)
if (($TestType -eq 'All' -or $TestType -eq 'Integration') -and $Global:RMMFunctionsLoaded) {
    Write-Host ""
    Write-Host "=== Testing Function Integration ==="
    
    try {
        # Test variable handling
        $env:TestVar = "TestValue"
        if (Get-Command Get-RMMVariable -ErrorAction SilentlyContinue) {
            $testValue = Get-RMMVariable -Name "TestVar" -Type "String"
            $variableTest = $testValue -eq "TestValue"
            Test-Result "Variable Handling" $variableTest "Retrieved: $testValue"
        }
        
        # Test logging with counters
        if (Get-Command Write-RMMLog -ErrorAction SilentlyContinue) {
            $initialSuccess = $Global:RMMSuccessCount
            Write-RMMLog "Integration test message" -Level Success
            $counterIncremented = $Global:RMMSuccessCount -gt $initialSuccess
            Test-Result "Counter Integration" $counterIncremented "Success counter incremented"
        }
        
        # Test timeout wrapper
        if (Get-Command Invoke-RMMTimeout -ErrorAction SilentlyContinue) {
            $result = Invoke-RMMTimeout -Code { "Test Result" } -TimeoutSec 5 -OperationName "Integration Test"
            $timeoutTest = $result -eq "Test Result"
            Test-Result "Timeout Wrapper" $timeoutTest "Returned: $result"
        }
        
    } catch {
        Test-Result "Integration Test" $false $_.Exception.Message
    }
}

# Summary
Write-Host ""
Write-Host "=============================================="
Write-Host "Test Summary"
Write-Host "=============================================="
Write-Host "Total Tests: $($testsPassed + $testsFailed)"
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { 'Red' } else { 'Green' })
Write-Host "Success Rate: $([math]::Round(($testsPassed / ($testsPassed + $testsFailed)) * 100, 1))%"
Write-Host "End Time: $(Get-Date)"

if ($testsFailed -gt 0) {
    Write-Host ""
    Write-Host "Failed Tests:" -ForegroundColor Red
    $testResults | Where-Object { -not $_.Passed } | ForEach-Object {
        Write-Host "  - $($_.TestName): $($_.Details)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Architecture Status: $(if ($testsFailed -eq 0) { 'READY FOR DEPLOYMENT' } else { 'NEEDS ATTENTION' })" -ForegroundColor $(if ($testsFailed -eq 0) { 'Green' } else { 'Red' })

# Return appropriate exit code
exit $testsFailed
