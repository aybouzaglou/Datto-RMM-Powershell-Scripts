#!/usr/bin/env pwsh
<#
.SYNOPSIS
    🔍 Pre-Push Validation Script - Catch Issues Before They Reach GitHub

.DESCRIPTION
    This script runs the same validation checks as the GitHub Actions pipeline
    but locally, so you can catch and fix issues before pushing to GitHub.

.PARAMETER Quick
    Run only syntax and critical PSScriptAnalyzer checks (faster)

.PARAMETER Full
    Run comprehensive validation including semantic and performance checks

.EXAMPLE
    .\validate-before-push.ps1 -Quick
    
.EXAMPLE
    .\validate-before-push.ps1 -Full
#>

param(
    [switch]$Quick,
    [switch]$Full
)

# If no parameter specified, default to Quick
if (-not $Quick -and -not $Full) {
    $Quick = $true
}

# Color functions for better output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

Write-Host "🔍 === PRE-PUSH VALIDATION ===" -ForegroundColor Magenta
Write-Host ""

if ($Quick) {
    Write-Info "Running QUICK validation (syntax + critical issues)"
} else {
    Write-Info "Running FULL validation (comprehensive checks)"
}
Write-Host ""

# Get scripts to validate (excluding archive/legacy files)
$scripts = Get-ChildItem -Path . -Filter "*.ps1" -Recurse | Where-Object {
    $_.FullName -notlike "*\.git\*" -and
    $_.FullName -notlike "*\legacy\*" -and
    $_.FullName -notlike "*archive*" -and
    $_.FullName -notlike "*api-experiments*"
}

Write-Info "Found $($scripts.Count) PowerShell scripts to validate"
Write-Host ""

# 1. SYNTAX VALIDATION
Write-Host "🔍 === SYNTAX VALIDATION ===" -ForegroundColor Yellow
$syntaxErrors = 0

foreach ($script in $scripts) {
    Write-Host "Checking: $($script.Name)" -NoNewline
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script.FullName -Raw), [ref]$null)
        Write-Host " ✅" -ForegroundColor Green
    } catch {
        Write-Host " ❌" -ForegroundColor Red
        Write-Error "  Syntax Error: $($_.Exception.Message)"
        $syntaxErrors++
    }
}

if ($syntaxErrors -gt 0) {
    Write-Host ""
    Write-Error "Found $syntaxErrors syntax errors. Fix these before pushing!"
    exit 1
}

Write-Success "All scripts have valid syntax"
Write-Host ""

# 2. PSSCRIPTANALYZER VALIDATION
Write-Host "🔍 === PSSCRIPTANALYZER VALIDATION ===" -ForegroundColor Yellow

# Check if PSScriptAnalyzer is installed
try {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
} catch {
    Write-Info "Installing PSScriptAnalyzer..."
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -Repository PSGallery
    Import-Module PSScriptAnalyzer
}

$criticalIssues = 0
$totalIssues = 0

foreach ($script in $scripts) {
    Write-Host "Analyzing: $($script.Name)" -NoNewline
    
    $issues = Invoke-ScriptAnalyzer -Path $script.FullName -Severity @('Error','Warning','Information')
    $criticalCount = ($issues | Where-Object { $_.Severity -eq 'Error' }).Count
    
    if ($criticalCount -gt 0) {
        Write-Host " ❌ ($criticalCount critical)" -ForegroundColor Red
        $issues | Where-Object { $_.Severity -eq 'Error' } | ForEach-Object {
            Write-Error "  Line $($_.Line): [$($_.RuleName)] $($_.Message)"
        }
        $criticalIssues += $criticalCount
    } elseif ($issues.Count -gt 0) {
        Write-Host " ⚠️  ($($issues.Count) warnings)" -ForegroundColor Yellow
    } else {
        Write-Host " ✅" -ForegroundColor Green
    }
    
    $totalIssues += $issues.Count
}

if ($criticalIssues -gt 0) {
    Write-Host ""
    Write-Error "Found $criticalIssues critical PSScriptAnalyzer errors. Fix these before pushing!"
    exit 1
}

Write-Success "No critical PSScriptAnalyzer issues found"
if ($totalIssues -gt 0) {
    Write-Warning "Found $totalIssues total issues (warnings/info)"
}
Write-Host ""

# 3. FULL VALIDATION (if requested)
if ($Full) {
    Write-Host "🧠 === SEMANTIC VALIDATION ===" -ForegroundColor Yellow
    
    $semanticIssues = 0
    foreach ($script in $scripts) {
        $content = Get-Content $script.FullName -Raw
        $relativePath = $script.FullName.Replace((Get-Location).Path, "").TrimStart('\')
        
        Write-Host "Checking: $($script.Name)" -NoNewline
        
        $issues = @()
        
        # Check for banned operations
        if ($content -match 'Get-WmiObject.*Win32_Product' -or $content -match 'Get-CimInstance.*Win32_Product') {
            $issues += "Uses Win32_Product (banned in Datto RMM)"
        }
        
        if ($content -match 'Read-Host|Get-Credential|\[System\.Windows\.Forms\]|\[System\.Windows\.MessageBox\]') {
            $issues += "Contains interactive elements (incompatible with Datto RMM)"
        }
        
        if ($relativePath -like "*Monitors*" -and $content -notmatch 'exit \d+') {
            $issues += "Monitor missing explicit exit codes"
        }
        
        if ($issues.Count -gt 0) {
            Write-Host " ❌" -ForegroundColor Red
            $issues | ForEach-Object { Write-Error "  $_" }
            $semanticIssues += $issues.Count
        } else {
            Write-Host " ✅" -ForegroundColor Green
        }
    }
    
    if ($semanticIssues -gt 0) {
        Write-Host ""
        Write-Error "Found $semanticIssues semantic issues. Fix these before pushing!"
        exit 1
    }
    
    Write-Success "No semantic issues found"
    Write-Host ""
}

# SUMMARY
Write-Host "🎉 === VALIDATION COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Success "✅ Syntax validation: PASSED"
Write-Success "✅ PSScriptAnalyzer: PASSED"
if ($Full) {
    Write-Success "✅ Semantic validation: PASSED"
}
Write-Host ""
Write-Success "🚀 Your code is ready to push!"
Write-Host ""
Write-Info "💡 Pro tip: Run this script before every push to catch issues early"
