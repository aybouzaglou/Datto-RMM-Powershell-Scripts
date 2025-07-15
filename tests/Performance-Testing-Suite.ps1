<#
.SYNOPSIS
Comprehensive Performance Testing Suite for Direct Deployment Monitors

.DESCRIPTION
Automated performance testing suite that validates direct deployment monitors
meet the <200ms execution time requirement and performance standards.

.PARAMETER TestIterations
Number of test iterations per monitor (default: 10)

.PARAMETER PerformanceThreshold
Maximum acceptable execution time in milliseconds (default: 200)

.PARAMETER GenerateReport
Generate detailed performance report

.EXAMPLE
.\Performance-Testing-Suite.ps1 -TestIterations 20 -GenerateReport

.NOTES
Version: 1.0.0
Author: Datto RMM Performance Optimization Team
Purpose: Validate direct deployment monitor performance
#>

param(
    [int]$TestIterations = 10,
    [int]$PerformanceThreshold = 200,
    [switch]$GenerateReport = $false
)

# Performance testing results
$global:TestResults = @{
    DirectDeploymentMonitors = @()
    LauncherBasedMonitors = @()
    PerformanceMetrics = @{
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        AverageExecutionTime = 0
        PerformanceImprovement = 0
    }
}

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""
}

function Write-TestSection {
    param([string]$Section)
    Write-Host ""
    Write-Host "🔍 $Section" -ForegroundColor Yellow
    Write-Host "-" * 60 -ForegroundColor Yellow
}

function Test-MonitorPerformance {
    param(
        [string]$ScriptPath,
        [string]$MonitorName,
        [int]$Iterations,
        [int]$Threshold,
        [string]$DeploymentType
    )
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "❌ Script not found: $ScriptPath" -ForegroundColor Red
        return $null
    }
    
    Write-Host "📊 Testing: $MonitorName ($DeploymentType)" -ForegroundColor White
    
    $executionTimes = @()
    $successCount = 0
    $errorCount = 0
    
    for ($i = 1; $i -le $Iterations; $i++) {
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Execute the monitor
            $result = & $ScriptPath 2>&1
            
            $stopwatch.Stop()
            $executionTime = $stopwatch.ElapsedMilliseconds
            $executionTimes += $executionTime
            
            # Check if execution was successful (basic validation)
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
                $successCount++
            } else {
                $errorCount++
            }
            
            Write-Host "  Run $i`: ${executionTime}ms" -ForegroundColor Gray
            
        } catch {
            $errorCount++
            Write-Host "  Run $i`: ERROR - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    if ($executionTimes.Count -gt 0) {
        $stats = @{
            MonitorName = $MonitorName
            DeploymentType = $DeploymentType
            ScriptPath = $ScriptPath
            Iterations = $Iterations
            SuccessCount = $successCount
            ErrorCount = $errorCount
            ExecutionTimes = $executionTimes
            Average = [math]::Round(($executionTimes | Measure-Object -Average).Average, 2)
            Min = ($executionTimes | Measure-Object -Minimum).Minimum
            Max = ($executionTimes | Measure-Object -Maximum).Maximum
            Median = $executionTimes | Sort-Object | Select-Object -Index ([math]::Floor($executionTimes.Count / 2))
            PassedThreshold = $null
            PerformanceGrade = $null
        }
        
        # Evaluate performance
        $stats.PassedThreshold = $stats.Average -le $Threshold
        
        if ($stats.Average -le 50) {
            $stats.PerformanceGrade = "Excellent"
            $gradeColor = "Green"
        } elseif ($stats.Average -le 100) {
            $stats.PerformanceGrade = "Good"
            $gradeColor = "Green"
        } elseif ($stats.Average -le $Threshold) {
            $stats.PerformanceGrade = "Acceptable"
            $gradeColor = "Yellow"
        } else {
            $stats.PerformanceGrade = "Needs Optimization"
            $gradeColor = "Red"
        }
        
        # Display results
        Write-Host "  📈 Results:" -ForegroundColor White
        Write-Host "    Average: $($stats.Average)ms" -ForegroundColor White
        Write-Host "    Range: $($stats.Min)ms - $($stats.Max)ms" -ForegroundColor White
        Write-Host "    Success Rate: $successCount/$Iterations ($([math]::Round(($successCount/$Iterations)*100,1))%)" -ForegroundColor White
        Write-Host "    Performance: $($stats.PerformanceGrade)" -ForegroundColor $gradeColor
        
        if ($stats.PassedThreshold) {
            Write-Host "    ✅ PASSED: Under ${Threshold}ms threshold" -ForegroundColor Green
        } else {
            Write-Host "    ❌ FAILED: Exceeds ${Threshold}ms threshold" -ForegroundColor Red
        }
        
        return $stats
    }
    
    return $null
}

function Test-DirectDeploymentMonitors {
    Write-TestSection "Direct Deployment Monitor Performance Testing"
    
    $directMonitors = @(
        @{ Path = "components/monitors/BluescreenMonitor-Direct.ps1"; Name = "Bluescreen Monitor (Direct)" },
        @{ Path = "components/monitors/DiskSpaceMonitor-Direct.ps1"; Name = "Disk Space Monitor (Direct)" }
    )
    
    foreach ($monitor in $directMonitors) {
        $result = Test-MonitorPerformance -ScriptPath $monitor.Path -MonitorName $monitor.Name -Iterations $TestIterations -Threshold $PerformanceThreshold -DeploymentType "Direct"
        if ($result) {
            $global:TestResults.DirectDeploymentMonitors += $result
        }
    }
}

function Test-LauncherBasedMonitors {
    Write-TestSection "Launcher-Based Monitor Performance Testing"
    
    $launcherMonitors = @(
        @{ Path = "components/monitors/BluescreenMonitor.ps1"; Name = "Bluescreen Monitor (Launcher)" },
        @{ Path = "components/monitors/DiskSpaceMonitor.ps1"; Name = "Disk Space Monitor (Launcher)" }
    )
    
    foreach ($monitor in $launcherMonitors) {
        $result = Test-MonitorPerformance -ScriptPath $monitor.Path -MonitorName $monitor.Name -Iterations $TestIterations -Threshold $PerformanceThreshold -DeploymentType "Launcher"
        if ($result) {
            $global:TestResults.LauncherBasedMonitors += $result
        }
    }
}

function Generate-PerformanceReport {
    Write-TestSection "Performance Analysis Report"
    
    $allResults = $global:TestResults.DirectDeploymentMonitors + $global:TestResults.LauncherBasedMonitors
    
    if ($allResults.Count -eq 0) {
        Write-Host "❌ No test results available for analysis" -ForegroundColor Red
        return
    }
    
    # Calculate overall metrics
    $totalTests = $allResults.Count
    $passedTests = ($allResults | Where-Object { $_.PassedThreshold }).Count
    $failedTests = $totalTests - $passedTests
    $overallAverage = [math]::Round(($allResults | Measure-Object -Property Average -Average).Average, 2)
    
    # Calculate performance improvement
    $directAverage = if ($global:TestResults.DirectDeploymentMonitors.Count -gt 0) {
        [math]::Round(($global:TestResults.DirectDeploymentMonitors | Measure-Object -Property Average -Average).Average, 2)
    } else { 0 }
    
    $launcherAverage = if ($global:TestResults.LauncherBasedMonitors.Count -gt 0) {
        [math]::Round(($global:TestResults.LauncherBasedMonitors | Measure-Object -Property Average -Average).Average, 2)
    } else { 0 }
    
    $performanceImprovement = if ($launcherAverage -gt 0) {
        [math]::Round((($launcherAverage - $directAverage) / $launcherAverage) * 100, 1)
    } else { 0 }
    
    # Update global metrics
    $global:TestResults.PerformanceMetrics.TotalTests = $totalTests
    $global:TestResults.PerformanceMetrics.PassedTests = $passedTests
    $global:TestResults.PerformanceMetrics.FailedTests = $failedTests
    $global:TestResults.PerformanceMetrics.AverageExecutionTime = $overallAverage
    $global:TestResults.PerformanceMetrics.PerformanceImprovement = $performanceImprovement
    
    # Display summary
    Write-Host "📊 PERFORMANCE SUMMARY" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host "Total Tests: $totalTests" -ForegroundColor White
    Write-Host "Passed (<${PerformanceThreshold}ms): $passedTests" -ForegroundColor Green
    Write-Host "Failed (>${PerformanceThreshold}ms): $failedTests" -ForegroundColor Red
    Write-Host "Overall Average: ${overallAverage}ms" -ForegroundColor White
    Write-Host ""
    
    if ($directAverage -gt 0 -and $launcherAverage -gt 0) {
        Write-Host "🚀 PERFORMANCE COMPARISON" -ForegroundColor Cyan
        Write-Host "=========================" -ForegroundColor Cyan
        Write-Host "Direct Deployment Average: ${directAverage}ms" -ForegroundColor Green
        Write-Host "Launcher-Based Average: ${launcherAverage}ms" -ForegroundColor Yellow
        Write-Host "Performance Improvement: ${performanceImprovement}%" -ForegroundColor Green
        Write-Host ""
    }
    
    # Individual monitor results
    Write-Host "📋 DETAILED RESULTS" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    
    foreach ($result in $allResults) {
        $status = if ($result.PassedThreshold) { "✅ PASS" } else { "❌ FAIL" }
        $statusColor = if ($result.PassedThreshold) { "Green" } else { "Red" }
        
        Write-Host "$status $($result.MonitorName)" -ForegroundColor $statusColor
        Write-Host "  Average: $($result.Average)ms | Grade: $($result.PerformanceGrade)" -ForegroundColor White
        Write-Host "  Success Rate: $($result.SuccessCount)/$($result.Iterations)" -ForegroundColor White
        Write-Host ""
    }
    
    # Recommendations
    Write-Host "💡 RECOMMENDATIONS" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    
    if ($failedTests -eq 0) {
        Write-Host "🎉 All monitors meet performance requirements!" -ForegroundColor Green
        Write-Host "✅ Direct deployment strategy is working optimally" -ForegroundColor Green
    } else {
        Write-Host "⚠️  $failedTests monitor(s) need optimization:" -ForegroundColor Yellow
        $failedMonitors = $allResults | Where-Object { -not $_.PassedThreshold }
        foreach ($failed in $failedMonitors) {
            Write-Host "  - $($failed.MonitorName): $($failed.Average)ms (target: <${PerformanceThreshold}ms)" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "📈 OPTIMIZATION TARGETS:" -ForegroundColor Cyan
    Write-Host "  - High-frequency monitors: <100ms" -ForegroundColor White
    Write-Host "  - Standard monitors: <200ms" -ForegroundColor White
    Write-Host "  - Complex monitors: <500ms" -ForegroundColor White
}

# Main execution
Write-TestHeader "🚀 DATTO RMM MONITOR PERFORMANCE TESTING SUITE"

Write-Host "Configuration:" -ForegroundColor White
Write-Host "  Test Iterations: $TestIterations" -ForegroundColor Gray
Write-Host "  Performance Threshold: ${PerformanceThreshold}ms" -ForegroundColor Gray
Write-Host "  Generate Report: $GenerateReport" -ForegroundColor Gray

# Run tests
Test-DirectDeploymentMonitors
Test-LauncherBasedMonitors

# Generate report
Generate-PerformanceReport

# Export results if requested
if ($GenerateReport) {
    $reportPath = "tests/Performance-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $global:TestResults | ConvertTo-Json -Depth 10 | Out-File $reportPath
    Write-Host "📄 Detailed report saved to: $reportPath" -ForegroundColor Green
}

Write-TestHeader "🏁 PERFORMANCE TESTING COMPLETE"

# Exit with appropriate code
$exitCode = if ($global:TestResults.PerformanceMetrics.FailedTests -eq 0) { 0 } else { 1 }
exit $exitCode
