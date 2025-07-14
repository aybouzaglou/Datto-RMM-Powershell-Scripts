# Deployment Script for Datto RMM Components
# This script handles the deployment of PowerShell components to Datto RMM

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("staging", "production")]
    [string]$Environment,
    
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,
    
    [Parameter(Mandatory = $false)]
    [string]$ComponentPath = "components",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Import the Datto RMM API module
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
Import-Module "$scriptPath\DattoRMMAPI.psm1" -Force

# Configuration
$DeploymentConfig = @{
    staging = @{
        SiteId = "staging-site-id"
        ComponentPrefix = "STAGING_"
        ApprovalRequired = $false
    }
    production = @{
        SiteId = "production-site-id"
        ComponentPrefix = "PROD_"
        ApprovalRequired = $true
    }
}

<#
.SYNOPSIS
    Validates component files before deployment
.DESCRIPTION
    Ensures all component files meet requirements before deployment
.PARAMETER ComponentFiles
    Array of component files to validate
#>
function Test-ComponentFiles {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$ComponentFiles
    )
    
    $validationResults = @()
    
    foreach ($file in $ComponentFiles) {
        $result = @{
            File = $file.Name
            Valid = $true
            Issues = @()
        }
        
        try {
            # Check if file is valid PowerShell
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            if (-not $ast) {
                $result.Valid = $false
                $result.Issues += "Invalid PowerShell syntax"
            }
            
            # Check for required metadata
            $content = Get-Content -Path $file.FullName -Raw
            if (-not $content.Contains("#SYNOPSIS")) {
                $result.Issues += "Missing synopsis comment"
            }
            
            if (-not $content.Contains("#DESCRIPTION")) {
                $result.Issues += "Missing description comment"
            }
            
            # Check for dangerous commands
            $dangerousCommands = @('Remove-Item', 'Format-Volume', 'Clear-Host', 'Remove-Computer')
            foreach ($cmd in $dangerousCommands) {
                if ($content.Contains($cmd)) {
                    $result.Issues += "Contains potentially dangerous command: $cmd"
                }
            }
            
            if ($result.Issues.Count -gt 0 -and $result.Valid) {
                $result.Valid = $false
            }
            
        }
        catch {
            $result.Valid = $false
            $result.Issues += "Error parsing file: $($_.Exception.Message)"
        }
        
        $validationResults += $result
    }
    
    return $validationResults
}

<#
.SYNOPSIS
    Deploys components to Datto RMM
.DESCRIPTION
    Handles the deployment process for components
.PARAMETER ComponentFiles
    Array of component files to deploy
.PARAMETER Environment
    Target environment (staging/production)
#>
function Deploy-Components {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$ComponentFiles,
        
        [Parameter(Mandatory = $true)]
        [string]$Environment
    )
    
    $config = $DeploymentConfig[$Environment]
    $deploymentResults = @()
    
    foreach ($file in $ComponentFiles) {
        $result = @{
            File = $file.Name
            Success = $false
            ComponentId = $null
            Message = ""
        }
        
        try {
            # Read component content
            $content = Get-Content -Path $file.FullName -Raw
            
            # Extract metadata from comments
            $name = $config.ComponentPrefix + $file.BaseName
            $description = "Deployed from $($file.Name) to $Environment environment"
            
            # Check if component already exists
            Write-Host "Checking if component '$name' already exists..." -ForegroundColor Yellow
            $existingComponents = Get-DattoComponents
            $existingComponent = $existingComponents | Where-Object { $_.name -eq $name }
            
            if ($existingComponent) {
                Write-Host "Updating existing component '$name'..." -ForegroundColor Blue
                $response = Update-DattoComponent -ComponentId $existingComponent.id -Name $name -Description $description -ScriptContent $content
                $result.ComponentId = $existingComponent.id
                $result.Message = "Component updated successfully"
            }
            else {
                Write-Host "Creating new component '$name'..." -ForegroundColor Green
                $response = New-DattoComponent -Name $name -Description $description -ScriptContent $content -Category "Automated Deployment"
                $result.ComponentId = $response.id
                $result.Message = "Component created successfully"
            }
            
            $result.Success = $true
            Write-Host "✅ $($result.Message): $name (ID: $($result.ComponentId))" -ForegroundColor Green
            
        }
        catch {
            $result.Message = "Deployment failed: $($_.Exception.Message)"
            Write-Error "❌ Failed to deploy $($file.Name): $($_.Exception.Message)"
        }
        
        $deploymentResults += $result
    }
    
    return $deploymentResults
}

<#
.SYNOPSIS
    Generates deployment report
.DESCRIPTION
    Creates a summary report of the deployment
.PARAMETER ValidationResults
    Results from component validation
.PARAMETER DeploymentResults
    Results from component deployment
#>
function New-DeploymentReport {
    param(
        [Parameter(Mandatory = $true)]
        [array]$ValidationResults,
        
        [Parameter(Mandatory = $true)]
        [array]$DeploymentResults
    )
    
    $report = @"
# Datto RMM Deployment Report
**Environment:** $Environment
**Timestamp:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Validation Results
$(
    foreach ($result in $ValidationResults) {
        "- **$($result.File)**: $(if ($result.Valid) { "✅ Valid" } else { "❌ Invalid" })"
        if ($result.Issues.Count -gt 0) {
            foreach ($issue in $result.Issues) {
                "  - $issue"
            }
        }
    }
)

## Deployment Results
$(
    foreach ($result in $DeploymentResults) {
        "- **$($result.File)**: $(if ($result.Success) { "✅ Success" } else { "❌ Failed" })"
        "  - $($result.Message)"
        if ($result.ComponentId) {
            "  - Component ID: $($result.ComponentId)"
        }
    }
)

## Summary
- Total Components: $($ValidationResults.Count)
- Valid Components: $($ValidationResults | Where-Object { $_.Valid }).Count
- Successfully Deployed: $($DeploymentResults | Where-Object { $_.Success }).Count
- Failed Deployments: $($DeploymentResults | Where-Object { -not $_.Success }).Count
"@
    
    return $report
}

# Main deployment logic
Write-Host "🚀 Starting Datto RMM Component Deployment" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Component Path: $ComponentPath" -ForegroundColor Yellow

try {
    # Initialize Datto RMM API
    Write-Host "🔐 Initializing Datto RMM API..." -ForegroundColor Yellow
    Initialize-DattoRMMAPI -ApiKey $ApiKey
    
    # Get component files
    Write-Host "📁 Scanning for component files..." -ForegroundColor Yellow
    if (-not (Test-Path $ComponentPath)) {
        throw "Component path '$ComponentPath' does not exist"
    }
    
    $componentFiles = Get-ChildItem -Path $ComponentPath -Filter "*.ps1" -Recurse
    if ($componentFiles.Count -eq 0) {
        throw "No PowerShell component files found in '$ComponentPath'"
    }
    
    Write-Host "Found $($componentFiles.Count) component file(s)" -ForegroundColor Green
    
    # Validate components
    Write-Host "🔍 Validating component files..." -ForegroundColor Yellow
    $validationResults = Test-ComponentFiles -ComponentFiles $componentFiles
    
    $validComponents = $validationResults | Where-Object { $_.Valid }
    $invalidComponents = $validationResults | Where-Object { -not $_.Valid }
    
    Write-Host "Valid components: $($validComponents.Count)" -ForegroundColor Green
    Write-Host "Invalid components: $($invalidComponents.Count)" -ForegroundColor Red
    
    # Show validation issues
    foreach ($invalid in $invalidComponents) {
        Write-Warning "❌ $($invalid.File) has validation issues:"
        foreach ($issue in $invalid.Issues) {
            Write-Warning "  - $issue"
        }
    }
    
    # Deploy valid components
    if ($validComponents.Count -gt 0) {
        Write-Host "🚀 Deploying valid components to $Environment..." -ForegroundColor Yellow
        
        $validFiles = $componentFiles | Where-Object { $_.Name -in $validComponents.File }
        $deploymentResults = Deploy-Components -ComponentFiles $validFiles -Environment $Environment
        
        # Generate and save report
        Write-Host "📊 Generating deployment report..." -ForegroundColor Yellow
        $report = New-DeploymentReport -ValidationResults $validationResults -DeploymentResults $deploymentResults
        
        $reportPath = "deployment-report-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
        $report | Out-File -FilePath $reportPath -Encoding UTF8
        
        Write-Host "📄 Deployment report saved to: $reportPath" -ForegroundColor Green
        
        # Output summary
        $successCount = ($deploymentResults | Where-Object { $_.Success }).Count
        $failureCount = ($deploymentResults | Where-Object { -not $_.Success }).Count
        
        Write-Host "📈 Deployment Summary:" -ForegroundColor Cyan
        Write-Host "  ✅ Successful: $successCount" -ForegroundColor Green
        Write-Host "  ❌ Failed: $failureCount" -ForegroundColor Red
        
        if ($failureCount -gt 0) {
            Write-Host "Some deployments failed. Check the report for details." -ForegroundColor Yellow
            exit 1
        }
        else {
            Write-Host "🎉 All deployments completed successfully!" -ForegroundColor Green
        }
    }
    else {
        Write-Error "No valid components to deploy"
        exit 1
    }
}
catch {
    Write-Error "❌ Deployment failed: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "🏁 Deployment process completed" -ForegroundColor Cyan
}