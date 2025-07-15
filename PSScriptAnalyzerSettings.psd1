# PSScriptAnalyzer Settings for Datto RMM PowerShell Scripts Repository
# Optimized for copy/paste architecture and Datto RMM requirements

@{
    # Include default rules but exclude context-inappropriate ones
    IncludeDefaultRules = $true
    
    # Rules to exclude globally (formatting noise and context-inappropriate)
    ExcludeRules = @(
        # Formatting rules that create noise
        'PSAvoidTrailingWhitespace',
        
        # Rules that don't align with Datto RMM architecture
        'PSUseBOMForUnicodeEncodedFile',  # Not relevant for Datto RMM
        'PSAvoidUsingPositionalParameters',  # Sometimes necessary for conciseness
        'PSUseSingularNouns',  # Not critical for functionality
        
        # Rules that conflict with reference patterns
        'PSReviewUnusedParameter',  # Reference patterns may have unused params
        'PSUseShouldProcessForStateChangingFunctions'  # Not applicable to RMM scripts
    )
    
    # Severity levels to include
    Severity = @('Error', 'Warning')
    
    # Custom rules for specific contexts
    Rules = @{
        # Allow Write-Host in specific contexts where it's required/appropriate
        PSAvoidUsingWriteHost = @{
            # Exclude paths where Write-Host is legitimate
            ExcludePath = @(
                '*Monitors*',      # Required for Datto RMM result markers
                '*shared-functions*',  # Reference patterns
                '*templates*',     # Template files
                '*scripts*',       # Development tools
                '*tests*',         # Testing scripts
                '*benchmark*',     # Performance tools
                '*performance*'    # Performance tools
            )
        }
        
        # Be more lenient with global variables in reference patterns
        PSAvoidGlobalVars = @{
            ExcludePath = @(
                '*shared-functions*',
                '*templates*'
            )
        }
    }
}
