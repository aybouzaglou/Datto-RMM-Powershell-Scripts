<#
.SYNOPSIS
    🎯 Deployment Decision Matrix Function Library

.DESCRIPTION
    Provides functions to determine the optimal deployment strategy (direct vs launcher-based)
    based on component characteristics and requirements.

.NOTES
    Version: 1.0.0
    Compatible: PowerShell 3.0+
    Purpose: Deployment strategy decision automation
#>

function Get-DeploymentStrategy {
    <#
    .SYNOPSIS
        Determines the optimal deployment strategy based on component characteristics
        
    .DESCRIPTION
        Analyzes component type, performance requirements, complexity, and other factors
        to recommend either direct deployment or launcher-based deployment.
        
    .PARAMETER ComponentType
        Type of component: Monitor, Application, or Script
        
    .PARAMETER ExecutionFrequency
        How often the component runs: High (every 1-2 minutes), Standard (hourly/daily), Low (weekly/monthly)
        
    .PARAMETER PerformanceRequirement
        Maximum acceptable execution time in milliseconds
        
    .PARAMETER ReliabilityLevel
        Required reliability level: Critical, Standard, Low
        
    .PARAMETER ComplexityLevel
        Component complexity: Simple, Standard, Complex
        
    .PARAMETER UpdateFrequency
        How often the component logic changes: Frequent, Standard, Stable
        
    .EXAMPLE
        Get-DeploymentStrategy -ComponentType "Monitor" -ExecutionFrequency "High" -PerformanceRequirement 100
        
    .EXAMPLE
        Get-DeploymentStrategy -ComponentType "Application" -ComplexityLevel "Complex" -UpdateFrequency "Frequent"
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Monitor", "Application", "Script")]
        [string]$ComponentType,
        
        [ValidateSet("High", "Standard", "Low")]
        [string]$ExecutionFrequency = "Standard",
        
        [int]$PerformanceRequirement = 1000,
        
        [ValidateSet("Critical", "Standard", "Low")]
        [string]$ReliabilityLevel = "Standard",
        
        [ValidateSet("Simple", "Standard", "Complex")]
        [string]$ComplexityLevel = "Standard",
        
        [ValidateSet("Frequent", "Standard", "Stable")]
        [string]$UpdateFrequency = "Standard"
    )
    
    $decision = @{
        UseDirectDeployment = $false
        DeploymentType = "Launcher-Based"
        Reason = ""
        Confidence = "Medium"
        Recommendations = @()
        Criteria = @{
            ComponentType = $ComponentType
            ExecutionFrequency = $ExecutionFrequency
            PerformanceRequirement = $PerformanceRequirement
            ReliabilityLevel = $ReliabilityLevel
            ComplexityLevel = $ComplexityLevel
            UpdateFrequency = $UpdateFrequency
        }
    }
    
    # Primary decision: Component type
    if ($ComponentType -eq "Monitor") {
        $decision.UseDirectDeployment = $true
        $decision.DeploymentType = "Direct"
        $decision.Reason = "All monitors use direct deployment for maximum performance (98.2% improvement)"
        $decision.Confidence = "High"
        $decision.Recommendations += "Embed all required functions for zero dependencies"
        $decision.Recommendations += "Target <200ms execution time"
        $decision.Recommendations += "Implement diagnostic-first architecture"
    }
    elseif ($ComponentType -in @("Application", "Script")) {
        # Secondary criteria evaluation for Applications and Scripts
        $directDeploymentScore = 0
        $reasons = @()
        
        # High-frequency execution favors direct deployment
        if ($ExecutionFrequency -eq "High") {
            $directDeploymentScore += 3
            $reasons += "High-frequency execution benefits from direct deployment"
        }
        
        # Performance requirements
        if ($PerformanceRequirement -lt 200) {
            $directDeploymentScore += 4
            $reasons += "Sub-200ms performance requirement strongly favors direct deployment"
        }
        elseif ($PerformanceRequirement -lt 500) {
            $directDeploymentScore += 2
            $reasons += "Performance requirement <500ms favors direct deployment"
        }
        
        # Reliability requirements
        if ($ReliabilityLevel -eq "Critical") {
            $directDeploymentScore += 3
            $reasons += "Critical reliability requirements favor direct deployment (zero network dependencies)"
        }
        
        # Complexity assessment
        if ($ComplexityLevel -eq "Simple") {
            $directDeploymentScore += 2
            $reasons += "Simple operations are well-suited for direct deployment"
        }
        elseif ($ComplexityLevel -eq "Complex") {
            $directDeploymentScore -= 2
            $reasons += "Complex operations benefit from launcher flexibility"
        }
        
        # Update frequency
        if ($UpdateFrequency -eq "Stable") {
            $directDeploymentScore += 1
            $reasons += "Stable components benefit from direct deployment efficiency"
        }
        elseif ($UpdateFrequency -eq "Frequent") {
            $directDeploymentScore -= 3
            $reasons += "Frequently updated components benefit from launcher-based deployment"
        }
        
        # Make decision based on score
        if ($directDeploymentScore >= 5) {
            $decision.UseDirectDeployment = $true
            $decision.DeploymentType = "Direct"
            $decision.Confidence = "High"
            $decision.Reason = "Multiple factors strongly favor direct deployment: " + ($reasons -join "; ")
            $decision.Recommendations += "Embed required functions for performance"
            $decision.Recommendations += "Minimize external dependencies"
        }
        elseif ($directDeploymentScore >= 3) {
            $decision.UseDirectDeployment = $true
            $decision.DeploymentType = "Direct"
            $decision.Confidence = "Medium"
            $decision.Reason = "Factors moderately favor direct deployment: " + ($reasons -join "; ")
            $decision.Recommendations += "Consider direct deployment for performance benefits"
            $decision.Recommendations += "Evaluate complexity vs performance trade-offs"
        }
        else {
            $decision.UseDirectDeployment = $false
            $decision.DeploymentType = "Launcher-Based"
            $decision.Confidence = "High"
            $decision.Reason = "Factors favor launcher-based deployment: " + ($reasons -join "; ")
            $decision.Recommendations += "Use GitHub function library for flexibility"
            $decision.Recommendations += "Leverage shared functions for maintainability"
        }
    }
    
    return $decision
}

function Test-ComponentDeploymentCompliance {
    <#
    .SYNOPSIS
        Tests if a component follows the recommended deployment strategy
        
    .DESCRIPTION
        Analyzes a PowerShell script file to determine its current deployment method
        and compares it against the recommended strategy based on component characteristics.
        
    .PARAMETER FilePath
        Path to the PowerShell script file to analyze
        
    .PARAMETER ComponentType
        Type of component: Monitor, Application, or Script
        
    .EXAMPLE
        Test-ComponentDeploymentCompliance -FilePath "components/Monitors/DiskSpaceMonitor.ps1" -ComponentType "Monitor"
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Monitor", "Application", "Script")]
        [string]$ComponentType
    )
    
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $content = Get-Content $FilePath -Raw
    
    # Detect current deployment method
    $hasEmbeddedFunctions = ($content -match 'function Get-RMMVariable' -and $content -match 'function Write-MonitorAlert')
    $hasLauncherPattern = ($content -match 'Launch(Monitor|Installer|Scripts)|GitHub.*download')
    $hasExternalDependencies = ($content -match 'Invoke-WebRequest|Invoke-RestMethod')
    
    $currentDeployment = if ($hasEmbeddedFunctions -and -not $hasLauncherPattern) {
        "Direct"
    } elseif ($hasLauncherPattern) {
        "Launcher-Based"
    } else {
        "Unknown"
    }
    
    # Get recommended deployment strategy
    $recommendation = Get-DeploymentStrategy -ComponentType $ComponentType
    
    # Determine compliance
    $isCompliant = ($currentDeployment -eq $recommendation.DeploymentType) -or 
                   ($currentDeployment -eq "Direct" -and $recommendation.UseDirectDeployment) -or
                   ($currentDeployment -eq "Launcher-Based" -and -not $recommendation.UseDirectDeployment)
    
    return @{
        FilePath = $FilePath
        ComponentType = $ComponentType
        CurrentDeployment = $currentDeployment
        RecommendedDeployment = $recommendation.DeploymentType
        IsCompliant = $isCompliant
        Recommendation = $recommendation
        Analysis = @{
            HasEmbeddedFunctions = $hasEmbeddedFunctions
            HasLauncherPattern = $hasLauncherPattern
            HasExternalDependencies = $hasExternalDependencies
        }
    }
}

function Get-DeploymentDecisionMatrix {
    <#
    .SYNOPSIS
        Returns the complete deployment decision matrix as a structured object
        
    .DESCRIPTION
        Provides the decision matrix rules and criteria in a structured format
        for documentation, testing, and validation purposes.
    #>
    
    return @{
        Version = "1.0.0"
        LastUpdated = "2024-01-15"
        Rules = @{
            Monitors = @{
                Strategy = "Direct"
                Reason = "All monitors use direct deployment for maximum performance"
                Benefits = @(
                    "98.2% performance improvement",
                    "Sub-200ms execution times",
                    "Zero network dependencies",
                    "100% reliability"
                )
                Requirements = @(
                    "Embed all required functions",
                    "No external dependencies",
                    "Diagnostic-first architecture",
                    "Proper result markers"
                )
            }
            Applications = @{
                Strategy = "Conditional"
                DefaultStrategy = "Launcher-Based"
                DirectDeploymentCriteria = @(
                    "High-frequency execution (every 1-2 minutes)",
                    "Performance requirement <200ms",
                    "Critical reliability requirements",
                    "Simple operations with stable logic"
                )
                LauncherBasedCriteria = @(
                    "Complex multi-step operations",
                    "Frequently updated logic",
                    "Standard performance requirements",
                    "Software deployment and installation"
                )
            }
            Scripts = @{
                Strategy = "Conditional"
                DefaultStrategy = "Launcher-Based"
                DirectDeploymentCriteria = @(
                    "High-frequency execution",
                    "Performance requirement <500ms",
                    "Simple maintenance operations",
                    "Stable, rarely updated logic"
                )
                LauncherBasedCriteria = @(
                    "General automation and maintenance",
                    "Complex operations",
                    "Frequently updated logic",
                    "Multi-step processes"
                )
            }
        }
        DecisionFactors = @{
            ComponentType = @{
                Weight = "Primary"
                Values = @("Monitor", "Application", "Script")
            }
            ExecutionFrequency = @{
                Weight = "High"
                Values = @("High", "Standard", "Low")
                Thresholds = @{
                    High = "Every 1-2 minutes"
                    Standard = "Hourly to daily"
                    Low = "Weekly or less"
                }
            }
            PerformanceRequirement = @{
                Weight = "High"
                Unit = "milliseconds"
                Thresholds = @{
                    Critical = 200
                    High = 500
                    Standard = 1000
                }
            }
            ReliabilityLevel = @{
                Weight = "Medium"
                Values = @("Critical", "Standard", "Low")
            }
            ComplexityLevel = @{
                Weight = "Medium"
                Values = @("Simple", "Standard", "Complex")
            }
            UpdateFrequency = @{
                Weight = "Medium"
                Values = @("Frequent", "Standard", "Stable")
            }
        }
    }
}
