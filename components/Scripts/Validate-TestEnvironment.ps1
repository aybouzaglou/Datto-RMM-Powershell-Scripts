# Validate Test Environment
# This script validates that the test environment is properly configured

<#
.SYNOPSIS
    Validates the test environment setup on a Windows device
.DESCRIPTION
    Checks that all required directories, files, and configurations are in place
    for automated component testing within a Datto RMM environment.
.PARAMETER TestResultsPath
    Path where test results and logs should be stored
.EXAMPLE
    .\Validate-TestEnvironment.ps1 -TestResultsPath "C:\TestResults"
.NOTES
    Author: Datto RMM Automation Team
    Version: 1.0
    Created: 2025-07-14
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$TestResultsPath = "C:\TestResults"
)

# Initialize validation results
$validationResults = @{
    Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    ComputerName = $env:COMPUTERNAME
    TestResultsPath = $TestResultsPath
    Checks = @()
    OverallStatus = "UNKNOWN"
    ErrorCount = 0
    WarningCount = 0
    SuccessCount = 0
}

function Add-ValidationCheck {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Message,
        [string]$Details = ""
    )
    
    $check = @{
        Name = $Name
        Status = $Status
        Message = $Message
        Details = $Details
        Timestamp = Get-Date -Format 'HH:mm:ss'
    }
    
    $validationResults.Checks += $check
    
    switch ($Status) {
        "SUCCESS" { 
            $validationResults.SuccessCount++
            Write-Output "✓ $Name - $Message"
        }
        "WARNING" { 
            $validationResults.WarningCount++
            Write-Warning "⚠ $Name - $Message"
        }
        "ERROR" { 
            $validationResults.ErrorCount++
            Write-Error "✗ $Name - $Message"
        }
    }
    
    if ($Details) {
        Write-Output "  Details: $Details"
    }
}

try {
    Write-Output "=== Test Environment Validation ==="
    Write-Output "Computer: $env:COMPUTERNAME"
    Write-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output "Test Path: $TestResultsPath"
    Write-Output ""
    
    # Check 1: Test Results Directory Structure
    Write-Output "--- Checking Directory Structure ---"
    
    $requiredDirs = @(
        $TestResultsPath,
        "$TestResultsPath\Logs",
        "$TestResultsPath\Components", 
        "$TestResultsPath\Reports",
        "$TestResultsPath\Archive"
    )
    
    foreach ($dir in $requiredDirs) {
        if (Test-Path $dir -PathType Container) {
            Add-ValidationCheck "Directory" "SUCCESS" "Found: $dir"
        } else {
            Add-ValidationCheck "Directory" "ERROR" "Missing: $dir"
        }
    }
    
    # Check 2: Configuration Files
    Write-Output "`n--- Checking Configuration Files ---"
    
    $configFile = "$TestResultsPath\test-config.json"
    if (Test-Path $configFile) {
        try {
            $config = Get-Content $configFile | ConvertFrom-Json
            Add-ValidationCheck "Config File" "SUCCESS" "Valid configuration found" "Setup Date: $($config.SetupDate)"
        } catch {
            Add-ValidationCheck "Config File" "ERROR" "Invalid configuration file" $_.Exception.Message
        }
    } else {
        Add-ValidationCheck "Config File" "ERROR" "Configuration file missing: $configFile"
    }
    
    $summaryFile = "$TestResultsPath\setup-summary.json"
    if (Test-Path $summaryFile) {
        Add-ValidationCheck "Summary File" "SUCCESS" "Setup summary found"
    } else {
        Add-ValidationCheck "Summary File" "WARNING" "Setup summary missing (not critical)"
    }
    
    # Check 3: Helper Module
    Write-Output "`n--- Checking Helper Module ---"
    
    $helperModule = "$TestResultsPath\TestHelpers.psm1"
    if (Test-Path $helperModule) {
        try {
            Import-Module $helperModule -Force
            $envInfo = Get-TestEnvironmentInfo
            Add-ValidationCheck "Helper Module" "SUCCESS" "Module loaded successfully" "Computer: $($envInfo.ComputerName)"
        } catch {
            Add-ValidationCheck "Helper Module" "ERROR" "Module failed to load" $_.Exception.Message
        }
    } else {
        Add-ValidationCheck "Helper Module" "ERROR" "Helper module missing: $helperModule"
    }
    
    # Check 4: PowerShell Environment
    Write-Output "`n--- Checking PowerShell Environment ---"
    
    $executionPolicy = Get-ExecutionPolicy
    if ($executionPolicy -in @("RemoteSigned", "Unrestricted", "Bypass")) {
        Add-ValidationCheck "Execution Policy" "SUCCESS" "Policy allows script execution: $executionPolicy"
    } else {
        Add-ValidationCheck "Execution Policy" "WARNING" "Restrictive policy: $executionPolicy"
    }
    
    Add-ValidationCheck "PowerShell Version" "SUCCESS" "Version: $($PSVersionTable.PSVersion)"
    Add-ValidationCheck "OS Version" "SUCCESS" "OS: $([System.Environment]::OSVersion.VersionString)"
    
    # Check 5: File Permissions
    Write-Output "`n--- Checking File Permissions ---"
    
    try {
        $testFile = "$TestResultsPath\permission-test.tmp"
        "Test content" | Out-File -FilePath $testFile -Encoding UTF8
        if (Test-Path $testFile) {
            Remove-Item $testFile -Force
            Add-ValidationCheck "File Permissions" "SUCCESS" "Can write to test directory"
        }
    } catch {
        Add-ValidationCheck "File Permissions" "ERROR" "Cannot write to test directory" $_.Exception.Message
    }
    
    # Check 6: Test Log Files
    Write-Output "`n--- Checking Existing Test Logs ---"
    
    $logFiles = Get-ChildItem -Path "$TestResultsPath\Logs" -Filter "*.log" -ErrorAction SilentlyContinue
    if ($logFiles) {
        Add-ValidationCheck "Test Logs" "SUCCESS" "Found $($logFiles.Count) log files" "Latest: $($logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Select-Object -ExpandProperty Name)"
    } else {
        Add-ValidationCheck "Test Logs" "WARNING" "No test logs found yet (normal for new setup)"
    }
    
    # Check 7: Test Reports
    Write-Output "`n--- Checking Test Reports ---"
    
    $reportFiles = Get-ChildItem -Path "$TestResultsPath\Reports" -Filter "*.json" -ErrorAction SilentlyContinue
    if ($reportFiles) {
        Add-ValidationCheck "Test Reports" "SUCCESS" "Found $($reportFiles.Count) report files"
    } else {
        Add-ValidationCheck "Test Reports" "WARNING" "No test reports found yet (normal for new setup)"
    }
    
    # Determine Overall Status
    Write-Output "`n--- Validation Summary ---"
    
    if ($validationResults.ErrorCount -eq 0) {
        if ($validationResults.WarningCount -eq 0) {
            $validationResults.OverallStatus = "EXCELLENT"
            Write-Output "🎉 Test environment is perfectly configured!"
        } else {
            $validationResults.OverallStatus = "GOOD"
            Write-Output "✅ Test environment is ready with minor warnings"
        }
    } else {
        $validationResults.OverallStatus = "NEEDS_ATTENTION"
        Write-Output "❌ Test environment has issues that need attention"
    }
    
    Write-Output ""
    Write-Output "Results Summary:"
    Write-Output "  ✓ Success: $($validationResults.SuccessCount)"
    Write-Output "  ⚠ Warning: $($validationResults.WarningCount)"
    Write-Output "  ✗ Error: $($validationResults.ErrorCount)"
    Write-Output "  Overall: $($validationResults.OverallStatus)"
    
    # Save validation results
    $resultFile = "$TestResultsPath\validation-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $validationResults | ConvertTo-Json -Depth 4 | Out-File -FilePath $resultFile -Encoding UTF8
    Write-Output ""
    Write-Output "Validation results saved to: $resultFile"
    
    # Exit with appropriate code
    if ($validationResults.ErrorCount -eq 0) {
        exit 0
    } else {
        exit 1
    }
    
} catch {
    Write-Error "Validation failed: $($_.Exception.Message)"
    exit 2
}
