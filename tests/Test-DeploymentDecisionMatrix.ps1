#!/usr/bin/env pwsh
<#
.SYNOPSIS
    🎯 Deployment Decision Matrix Testing Suite

.DESCRIPTION
    Comprehensive testing suite that validates the deployment decision matrix logic
    for determining when to use direct deployment vs launcher-based deployment.
    
    Tests all decision criteria:
    - Component type (Monitors, Applications, Scripts)
    - Execution frequency (high-frequency vs standard)
    - Performance requirements (<200ms vs standard)
    - Reliability requirements (critical vs standard)
    - Complexity (simple vs multi-step)
    - Update frequency (frequent vs stable)

.PARAMETER TestLevel
    Level of testing to perform
    - Quick: Basic decision matrix validation
    - Full: Complete testing with edge cases
    - Comprehensive: Extended testing with performance validation

.EXAMPLE
    .\Test-DeploymentDecisionMatrix.ps1 -TestLevel Full
    
.EXAMPLE
    .\Test-DeploymentDecisionMatrix.ps1 -TestLevel Quick
#>

param(
    [ValidateSet("Quick", "Full", "Comprehensive")]
    [string]$TestLevel = "Full"
)

# Test framework functions
function Write-TestResult {
    param([string]$TestName, [bool]$Passed, [string]$Details = "")
    $status = if ($Passed) { "✅ PASS" } else { "❌ FAIL" }
    Write-Host "$status - $TestName" -ForegroundColor $(if ($Passed) { "Green" } else { "Red" })
    if ($Details) { Write-Host "    $Details" -ForegroundColor Gray }
}

function Test-DeploymentDecision {
    param(
        [string]$ComponentType,
        [string]$ExecutionFrequency,
        [int]$PerformanceRequirement,
        [string]$ReliabilityLevel,
        [string]$ComplexityLevel,
        [string]$UpdateFrequency
    )
    
    # Decision matrix logic
    $useDirectDeployment = $false
    $reason = ""
    
    # Primary decision: Component type
    if ($ComponentType -eq "Monitor") {
        $useDirectDeployment = $true
        $reason = "All monitors use direct deployment for performance"
    }
    elseif ($ComponentType -in @("Application", "Script")) {
        # Secondary criteria for Applications and Scripts
        if ($ExecutionFrequency -eq "High" -and $PerformanceRequirement -lt 200) {
            $useDirectDeployment = $true
            $reason = "High-frequency execution with performance requirements"
        }
        elseif ($ReliabilityLevel -eq "Critical" -and $PerformanceRequirement -lt 500) {
            $useDirectDeployment = $true
            $reason = "Critical reliability requirements"
        }
        elseif ($ComplexityLevel -eq "Simple" -and $UpdateFrequency -eq "Stable") {
            $useDirectDeployment = $true
            $reason = "Simple, stable operations benefit from direct deployment"
        }
        else {
            $useDirectDeployment = $false
            $reason = "Complex operations or frequent updates benefit from launcher flexibility"
        }
    }
    
    return @{
        UseDirectDeployment = $useDirectDeployment
        Reason = $reason
        ComponentType = $ComponentType
        Criteria = @{
            ExecutionFrequency = $ExecutionFrequency
            PerformanceRequirement = $PerformanceRequirement
            ReliabilityLevel = $ReliabilityLevel
            ComplexityLevel = $ComplexityLevel
            UpdateFrequency = $UpdateFrequency
        }
    }
}

Write-Host "🎯 === DEPLOYMENT DECISION MATRIX TESTING SUITE ===" -ForegroundColor Magenta
Write-Host ""
Write-Host "Test Level: $TestLevel" -ForegroundColor Cyan
Write-Host ""

$totalTests = 0
$passedTests = 0

# Test 1: Monitor Component Type (Always Direct Deployment)
Write-Host "📊 TESTING: Monitor Component Type" -ForegroundColor Yellow
Write-Host "Rule: All monitors should use direct deployment regardless of other factors" -ForegroundColor Gray
Write-Host ""

$monitorTests = @(
    @{ Name = "High-frequency monitor"; Freq = "High"; Perf = 50; Rel = "Critical"; Complex = "Simple"; Update = "Stable" }
    @{ Name = "Low-frequency monitor"; Freq = "Low"; Perf = 1000; Rel = "Standard"; Complex = "Complex"; Update = "Frequent" }
    @{ Name = "Complex monitor"; Freq = "Standard"; Perf = 100; Rel = "Critical"; Complex = "Complex"; Update = "Frequent" }
)

foreach ($test in $monitorTests) {
    $totalTests++
    $result = Test-DeploymentDecision -ComponentType "Monitor" -ExecutionFrequency $test.Freq -PerformanceRequirement $test.Perf -ReliabilityLevel $test.Rel -ComplexityLevel $test.Complex -UpdateFrequency $test.Update
    
    $passed = $result.UseDirectDeployment -eq $true
    if ($passed) { $passedTests++ }
    
    Write-TestResult -TestName $test.Name -Passed $passed -Details $result.Reason
}

Write-Host ""

# Test 2: Application Component Type (Conditional Logic)
Write-Host "🔧 TESTING: Application Component Type" -ForegroundColor Yellow
Write-Host "Rule: Applications use launcher-based deployment unless specific criteria met" -ForegroundColor Gray
Write-Host ""

$applicationTests = @(
    @{ Name = "High-freq, high-perf app"; Freq = "High"; Perf = 150; Rel = "Standard"; Complex = "Simple"; Update = "Stable"; Expected = $true }
    @{ Name = "Critical, fast app"; Freq = "Standard"; Perf = 300; Rel = "Critical"; Complex = "Simple"; Update = "Stable"; Expected = $true }
    @{ Name = "Simple, stable app"; Freq = "Standard"; Perf = 1000; Rel = "Standard"; Complex = "Simple"; Update = "Stable"; Expected = $true }
    @{ Name = "Complex app"; Freq = "Standard"; Perf = 500; Rel = "Standard"; Complex = "Complex"; Update = "Stable"; Expected = $false }
    @{ Name = "Frequently updated app"; Freq = "Standard"; Perf = 500; Rel = "Standard"; Complex = "Simple"; Update = "Frequent"; Expected = $false }
    @{ Name = "Standard app"; Freq = "Standard"; Perf = 1000; Rel = "Standard"; Complex = "Complex"; Update = "Frequent"; Expected = $false }
)

foreach ($test in $applicationTests) {
    $totalTests++
    $result = Test-DeploymentDecision -ComponentType "Application" -ExecutionFrequency $test.Freq -PerformanceRequirement $test.Perf -ReliabilityLevel $test.Rel -ComplexityLevel $test.Complex -UpdateFrequency $test.Update
    
    $passed = $result.UseDirectDeployment -eq $test.Expected
    if ($passed) { $passedTests++ }
    
    $deployment = if ($result.UseDirectDeployment) { "Direct" } else { "Launcher" }
    Write-TestResult -TestName "$($test.Name) → $deployment" -Passed $passed -Details $result.Reason
}

Write-Host ""

# Test 3: Script Component Type (Similar to Applications)
Write-Host "📝 TESTING: Script Component Type" -ForegroundColor Yellow
Write-Host "Rule: Scripts use launcher-based deployment unless specific criteria met" -ForegroundColor Gray
Write-Host ""

$scriptTests = @(
    @{ Name = "High-freq maintenance script"; Freq = "High"; Perf = 100; Rel = "Standard"; Complex = "Simple"; Update = "Stable"; Expected = $true }
    @{ Name = "Critical system script"; Freq = "Standard"; Perf = 400; Rel = "Critical"; Complex = "Simple"; Update = "Stable"; Expected = $true }
    @{ Name = "Complex automation script"; Freq = "Standard"; Perf = 1000; Rel = "Standard"; Complex = "Complex"; Update = "Frequent"; Expected = $false }
    @{ Name = "Development script"; Freq = "Low"; Perf = 2000; Rel = "Standard"; Complex = "Complex"; Update = "Frequent"; Expected = $false }
)

foreach ($test in $scriptTests) {
    $totalTests++
    $result = Test-DeploymentDecision -ComponentType "Script" -ExecutionFrequency $test.Freq -PerformanceRequirement $test.Perf -ReliabilityLevel $test.Rel -ComplexityLevel $test.Complex -UpdateFrequency $test.Update
    
    $passed = $result.UseDirectDeployment -eq $test.Expected
    if ($passed) { $passedTests++ }
    
    $deployment = if ($result.UseDirectDeployment) { "Direct" } else { "Launcher" }
    Write-TestResult -TestName "$($test.Name) → $deployment" -Passed $passed -Details $result.Reason
}

Write-Host ""

if ($TestLevel -in @("Full", "Comprehensive")) {
    # Test 4: Edge Cases and Boundary Conditions
    Write-Host "⚠️  TESTING: Edge Cases and Boundary Conditions" -ForegroundColor Yellow
    Write-Host ""
    
    $edgeCases = @(
        @{ Name = "Exactly 200ms performance requirement"; Type = "Application"; Freq = "High"; Perf = 200; Rel = "Standard"; Complex = "Simple"; Update = "Stable"; Expected = $false }
        @{ Name = "Just under 200ms performance requirement"; Type = "Application"; Freq = "High"; Perf = 199; Rel = "Standard"; Complex = "Simple"; Update = "Stable"; Expected = $true }
        @{ Name = "Critical app with 500ms requirement"; Type = "Application"; Freq = "Standard"; Perf = 500; Rel = "Critical"; Complex = "Simple"; Update = "Stable"; Expected = $false }
        @{ Name = "Critical app with 499ms requirement"; Type = "Application"; Freq = "Standard"; Perf = 499; Rel = "Critical"; Complex = "Simple"; Update = "Stable"; Expected = $true }
    )
    
    foreach ($test in $edgeCases) {
        $totalTests++
        $result = Test-DeploymentDecision -ComponentType $test.Type -ExecutionFrequency $test.Freq -PerformanceRequirement $test.Perf -ReliabilityLevel $test.Rel -ComplexityLevel $test.Complex -UpdateFrequency $test.Update
        
        $passed = $result.UseDirectDeployment -eq $test.Expected
        if ($passed) { $passedTests++ }
        
        $deployment = if ($result.UseDirectDeployment) { "Direct" } else { "Launcher" }
        Write-TestResult -TestName "$($test.Name) → $deployment" -Passed $passed -Details $result.Reason
    }
    
    Write-Host ""
}

if ($TestLevel -eq "Comprehensive") {
    # Test 5: Real-World Scenarios
    Write-Host "🌍 TESTING: Real-World Scenarios" -ForegroundColor Yellow
    Write-Host ""
    
    $realWorldTests = @(
        @{ Name = "Disk Space Monitor"; Type = "Monitor"; Freq = "High"; Perf = 50; Rel = "Critical"; Complex = "Simple"; Update = "Stable"; Expected = $true }
        @{ Name = "Bluescreen Monitor"; Type = "Monitor"; Freq = "High"; Perf = 25; Rel = "Critical"; Complex = "Simple"; Update = "Stable"; Expected = $true }
        @{ Name = "Office Debloat Application"; Type = "Application"; Freq = "Low"; Perf = 30000; Rel = "Standard"; Complex = "Complex"; Update = "Frequent"; Expected = $false }
        @{ Name = "ScanSnap Installer"; Type = "Application"; Freq = "Low"; Perf = 60000; Rel = "Standard"; Complex = "Complex"; Update = "Stable"; Expected = $false }
        @{ Name = "System Maintenance Script"; Type = "Script"; Freq = "Standard"; Perf = 5000; Rel = "Standard"; Complex = "Complex"; Update = "Frequent"; Expected = $false }
        @{ Name = "Quick Registry Fix"; Type = "Script"; Freq = "High"; Perf = 100; Rel = "Standard"; Complex = "Simple"; Update = "Stable"; Expected = $true }
    )
    
    foreach ($test in $realWorldTests) {
        $totalTests++
        $result = Test-DeploymentDecision -ComponentType $test.Type -ExecutionFrequency $test.Freq -PerformanceRequirement $test.Perf -ReliabilityLevel $test.Rel -ComplexityLevel $test.Complex -UpdateFrequency $test.Update
        
        $passed = $result.UseDirectDeployment -eq $test.Expected
        if ($passed) { $passedTests++ }
        
        $deployment = if ($result.UseDirectDeployment) { "Direct" } else { "Launcher" }
        Write-TestResult -TestName "$($test.Name) → $deployment" -Passed $passed -Details $result.Reason
    }
    
    Write-Host ""
}

# Test Summary
Write-Host "📊 === TEST SUMMARY ===" -ForegroundColor Magenta
Write-Host ""
Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $($totalTests - $passedTests)" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($passedTests / $totalTests) * 100, 1))%" -ForegroundColor Cyan
Write-Host ""

# Test 6: Repository Component Validation
Write-Host "📁 TESTING: Actual Repository Components" -ForegroundColor Yellow
Write-Host "Validating that existing components follow the decision matrix" -ForegroundColor Gray
Write-Host ""

# Analyze actual components in the repository
$componentValidation = @()

# Check monitors
$monitors = Get-ChildItem -Path "components/Monitors" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($monitor in $monitors) {
    $content = Get-Content $monitor.FullName -Raw
    $hasEmbeddedFunctions = ($content -match 'function Get-RMMVariable' -and $content -match 'function Write-MonitorAlert')
    $hasLauncherPattern = ($content -match 'LaunchMonitor|GitHub.*download')
    $isDirectDeployment = $hasEmbeddedFunctions -and -not $hasLauncherPattern

    $totalTests++
    $passed = $isDirectDeployment  # All monitors should use direct deployment
    if ($passed) { $passedTests++ }

    $deployment = if ($isDirectDeployment) { "Direct" } else { "Launcher" }
    Write-TestResult -TestName "Monitor: $($monitor.Name) → $deployment" -Passed $passed -Details $(if ($passed) { "Correctly uses direct deployment" } else { "Should use direct deployment" })

    $componentValidation += @{
        Name = $monitor.Name
        Type = "Monitor"
        ActualDeployment = $deployment
        ExpectedDeployment = "Direct"
        Compliant = $passed
    }
}

# Check applications
$applications = Get-ChildItem -Path "components/Applications" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($app in $applications) {
    $content = Get-Content $app.FullName -Raw
    $hasEmbeddedFunctions = ($content -match 'function Get-RMMVariable')
    $hasLauncherPattern = ($content -match 'LaunchInstaller|GitHub.*download')
    $isDirectDeployment = $hasEmbeddedFunctions -and -not $hasLauncherPattern

    $totalTests++
    # Most applications should use launcher-based deployment
    $passed = -not $isDirectDeployment
    if ($passed) { $passedTests++ }

    $deployment = if ($isDirectDeployment) { "Direct" } else { "Launcher" }
    Write-TestResult -TestName "Application: $($app.Name) → $deployment" -Passed $passed -Details $(if ($passed) { "Correctly uses launcher-based deployment" } else { "Complex applications should use launcher-based deployment" })

    $componentValidation += @{
        Name = $app.Name
        Type = "Application"
        ActualDeployment = $deployment
        ExpectedDeployment = "Launcher"
        Compliant = $passed
    }
}

# Check scripts
$scripts = Get-ChildItem -Path "components/Scripts" -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($script in $scripts) {
    $content = Get-Content $script.FullName -Raw
    $hasEmbeddedFunctions = ($content -match 'function Get-RMMVariable')
    $hasLauncherPattern = ($content -match 'LaunchScripts|GitHub.*download')
    $isDirectDeployment = $hasEmbeddedFunctions -and -not $hasLauncherPattern

    $totalTests++
    # Most scripts should use launcher-based deployment
    $passed = -not $isDirectDeployment
    if ($passed) { $passedTests++ }

    $deployment = if ($isDirectDeployment) { "Direct" } else { "Launcher" }
    Write-TestResult -TestName "Script: $($script.Name) → $deployment" -Passed $passed -Details $(if ($passed) { "Correctly uses launcher-based deployment" } else { "Complex scripts should use launcher-based deployment" })

    $componentValidation += @{
        Name = $script.Name
        Type = "Script"
        ActualDeployment = $deployment
        ExpectedDeployment = "Launcher"
        Compliant = $passed
    }
}

Write-Host ""

# Component compliance summary
Write-Host "📋 COMPONENT COMPLIANCE SUMMARY:" -ForegroundColor Cyan
$compliantComponents = $componentValidation | Where-Object { $_.Compliant }
$nonCompliantComponents = $componentValidation | Where-Object { -not $_.Compliant }

Write-Host "  Compliant Components: $($compliantComponents.Count)" -ForegroundColor Green
Write-Host "  Non-Compliant Components: $($nonCompliantComponents.Count)" -ForegroundColor Red

if ($nonCompliantComponents.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️  NON-COMPLIANT COMPONENTS:" -ForegroundColor Yellow
    foreach ($component in $nonCompliantComponents) {
        Write-Host "    $($component.Type): $($component.Name) (Expected: $($component.ExpectedDeployment), Actual: $($component.ActualDeployment))" -ForegroundColor Red
    }
}

Write-Host ""

if ($passedTests -eq $totalTests) {
    Write-Host "🎉 ALL TESTS PASSED! Decision matrix logic is working correctly." -ForegroundColor Green
    Write-Host "✅ All repository components follow the deployment decision matrix." -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ SOME TESTS FAILED! Review decision matrix logic." -ForegroundColor Red
    Write-Host "📊 Success Rate: $([math]::Round(($passedTests / $totalTests) * 100, 1))%" -ForegroundColor Yellow
    exit 1
}
