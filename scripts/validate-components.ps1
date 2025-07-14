# Component Validation Script
# This script validates PowerShell components before deployment

param(
    [Parameter(Mandatory = $true)]
    [string]$ComponentPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

<#
.SYNOPSIS
    Validates the structure and content of PowerShell components
.DESCRIPTION
    Performs comprehensive validation of PowerShell components to ensure they meet deployment standards
.PARAMETER ComponentPath
    Path to the components directory
.PARAMETER Detailed
    Show detailed validation results
#>

# Configuration
$ValidationRules = @{
    RequiredComments = @('#SYNOPSIS', '#DESCRIPTION', '#EXAMPLE')
    ForbiddenCommands = @('Remove-Item', 'Format-Volume', 'Clear-Host', 'Remove-Computer', 'Stop-Computer', 'Restart-Computer')
    RequiredStructure = @{
        HasParamBlock = $true
        HasTryBlock = $true
        HasErrorHandling = $true
    }
    MaxFileSize = 50KB
    RequiredEncoding = 'UTF8'
}

function Test-PowerShellSyntax {
    param([string]$FilePath)
    
    try {
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$errors)
        
        return @{
            Valid = $errors.Count -eq 0
            Errors = $errors
            AST = $ast
        }
    }
    catch {
        return @{
            Valid = $false
            Errors = @("Failed to parse file: $($_.Exception.Message)")
            AST = $null
        }
    }
}

function Test-ComponentStructure {
    param([string]$Content, [object]$AST)
    
    $issues = @()
    
    # Check for param block
    if ($ValidationRules.RequiredStructure.HasParamBlock) {
        $paramBlocks = $AST.FindAll({ $args[0] -is [System.Management.Automation.Language.ParamBlockAst] }, $true)
        if ($paramBlocks.Count -eq 0) {
            $issues += "Missing param block"
        }
    }
    
    # Check for try-catch blocks
    if ($ValidationRules.RequiredStructure.HasTryBlock) {
        $tryBlocks = $AST.FindAll({ $args[0] -is [System.Management.Automation.Language.TryStatementAst] }, $true)
        if ($tryBlocks.Count -eq 0) {
            $issues += "Missing try-catch block for error handling"
        }
    }
    
    # Check for Write-Error or throw statements
    if ($ValidationRules.RequiredStructure.HasErrorHandling) {
        $hasErrorHandling = $Content -match "Write-Error|throw|catch"
        if (-not $hasErrorHandling) {
            $issues += "Missing error handling (Write-Error, throw, or catch)"
        }
    }
    
    return $issues
}

function Test-ComponentContent {
    param([string]$Content)
    
    $issues = @()
    
    # Check for required comments
    foreach ($comment in $ValidationRules.RequiredComments) {
        if ($Content -notmatch [regex]::Escape($comment)) {
            $issues += "Missing required comment: $comment"
        }
    }
    
    # Check for forbidden commands
    foreach ($command in $ValidationRules.ForbiddenCommands) {
        if ($Content -match "\b$([regex]::Escape($command))\b") {
            $issues += "Contains forbidden command: $command"
        }
    }
    
    # Check for hardcoded paths
    if ($Content -match "C:\\|D:\\|E:\\") {
        $issues += "Contains hardcoded drive paths - use environment variables or relative paths"
    }
    
    # Check for sensitive information
    if ($Content -match "password|secret|key" -and $Content -notmatch "#.*password|#.*secret|#.*key") {
        $issues += "May contain sensitive information - ensure proper handling"
    }
    
    return $issues
}

function Test-ComponentMetadata {
    param([string]$Content, [string]$FileName)
    
    $issues = @()
    
    # Extract metadata from comments
    $synopsis = if ($Content -match "(?s)#\s*SYNOPSIS\s*\n\s*#\s*(.+?)(?=\n\s*#|\n\s*param|\n\s*function|\n\s*$)") { $matches[1].Trim() } else { $null }
    $description = if ($Content -match "(?s)#\s*DESCRIPTION\s*\n\s*#\s*(.+?)(?=\n\s*#|\n\s*param|\n\s*function|\n\s*$)") { $matches[1].Trim() } else { $null }
    
    if (-not $synopsis -or $synopsis.Length -lt 10) {
        $issues += "Synopsis is missing or too short (minimum 10 characters)"
    }
    
    if (-not $description -or $description.Length -lt 20) {
        $issues += "Description is missing or too short (minimum 20 characters)"
    }
    
    # Check if filename matches function name (if applicable)
    if ($Content -match "function\s+([a-zA-Z][a-zA-Z0-9-_]*)" -and $FileName -notmatch $matches[1]) {
        $issues += "Filename should match the main function name"
    }
    
    return $issues
}

function Test-ComponentFile {
    param([System.IO.FileInfo]$File)
    
    $result = @{
        File = $File.Name
        FullPath = $File.FullName
        Valid = $true
        Issues = @()
        Warnings = @()
        Size = $File.Length
    }
    
    # Check file size
    if ($File.Length -gt $ValidationRules.MaxFileSize) {
        $result.Issues += "File size exceeds maximum allowed size ($($ValidationRules.MaxFileSize / 1KB)KB)"
    }
    
    # Check file encoding
    try {
        $encoding = [System.Text.Encoding]::GetEncoding((Get-Content -Path $File.FullName -Encoding Byte -ReadCount 4 -TotalCount 4))
        if ($encoding.WebName -ne 'utf-8') {
            $result.Warnings += "File encoding is not UTF-8"
        }
    }
    catch {
        $result.Warnings += "Could not determine file encoding"
    }
    
    # Read file content
    try {
        $content = Get-Content -Path $File.FullName -Raw -Encoding UTF8
    }
    catch {
        $result.Issues += "Failed to read file content: $($_.Exception.Message)"
        $result.Valid = $false
        return $result
    }
    
    # Test PowerShell syntax
    $syntaxTest = Test-PowerShellSyntax -FilePath $File.FullName
    if (-not $syntaxTest.Valid) {
        $result.Issues += "PowerShell syntax errors:"
        $result.Issues += $syntaxTest.Errors | ForEach-Object { "  - $($_.Message)" }
    }
    
    # Test component structure
    if ($syntaxTest.AST) {
        $structureIssues = Test-ComponentStructure -Content $content -AST $syntaxTest.AST
        $result.Issues += $structureIssues
    }
    
    # Test component content
    $contentIssues = Test-ComponentContent -Content $content
    $result.Issues += $contentIssues
    
    # Test component metadata
    $metadataIssues = Test-ComponentMetadata -Content $content -FileName $File.BaseName
    $result.Issues += $metadataIssues
    
    # Set overall validity
    $result.Valid = $result.Issues.Count -eq 0
    
    return $result
}

# Main validation logic
Write-Host "🔍 Starting Component Validation" -ForegroundColor Cyan
Write-Host "Component Path: $ComponentPath" -ForegroundColor Yellow

try {
    # Check if path exists
    if (-not (Test-Path $ComponentPath)) {
        throw "Component path '$ComponentPath' does not exist"
    }
    
    # Get all PowerShell files
    $componentFiles = Get-ChildItem -Path $ComponentPath -Filter "*.ps1" -Recurse
    
    if ($componentFiles.Count -eq 0) {
        throw "No PowerShell files found in '$ComponentPath'"
    }
    
    Write-Host "Found $($componentFiles.Count) PowerShell file(s)" -ForegroundColor Green
    
    # Validate each file
    $validationResults = @()
    $validCount = 0
    $invalidCount = 0
    
    foreach ($file in $componentFiles) {
        Write-Host "Validating: $($file.Name)" -ForegroundColor Yellow
        
        $result = Test-ComponentFile -File $file
        $validationResults += $result
        
        if ($result.Valid) {
            $validCount++
            Write-Host "  ✅ Valid" -ForegroundColor Green
        }
        else {
            $invalidCount++
            Write-Host "  ❌ Invalid" -ForegroundColor Red
        }
        
        # Show warnings if any
        if ($result.Warnings.Count -gt 0) {
            foreach ($warning in $result.Warnings) {
                Write-Host "  ⚠️  $warning" -ForegroundColor Yellow
            }
        }
        
        # Show issues if detailed mode or if invalid
        if ($Detailed -or -not $result.Valid) {
            foreach ($issue in $result.Issues) {
                Write-Host "  ❌ $issue" -ForegroundColor Red
            }
        }
    }
    
    # Summary
    Write-Host "`n📊 Validation Summary:" -ForegroundColor Cyan
    Write-Host "  Total files: $($componentFiles.Count)" -ForegroundColor White
    Write-Host "  Valid: $validCount" -ForegroundColor Green
    Write-Host "  Invalid: $invalidCount" -ForegroundColor Red
    Write-Host "  Success rate: $([math]::Round(($validCount / $componentFiles.Count) * 100, 2))%" -ForegroundColor White
    
    # Generate detailed report
    $reportPath = "validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $validationResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "📄 Detailed report saved to: $reportPath" -ForegroundColor Blue
    
    # Exit with appropriate code
    if ($invalidCount -gt 0) {
        Write-Host "❌ Validation failed - $invalidCount file(s) have issues" -ForegroundColor Red
        exit 1
    }
    else {
        Write-Host "✅ All files passed validation!" -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Error "❌ Validation failed: $($_.Exception.Message)"
    exit 1
}