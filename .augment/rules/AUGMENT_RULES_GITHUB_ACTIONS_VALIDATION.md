---
type: "agent_requested"
description: "# 🔧 GitHub Actions PowerShell Validation Rules  ## 🎯 Critical Validation Patterns (Learned from Debugging)"
---
# 🔧 GitHub Actions PowerShell Validation Rules

## 🎯 Critical Validation Patterns (Learned from Debugging)

### PowerShell Variable Expansion in Workflows
```yaml
# ❌ WRONG - Causes parser errors with special characters
Write-Warning "  ⚠️  $scriptName: Issue detected"

# ✅ CORRECT - Proper variable expansion
Write-Warning "  ⚠️  $($scriptName): Issue detected"
```

**Rule**: Always use `$($variableName)` instead of `$variableName` when variables might contain special characters like colons.

### Context-Aware Development Script Detection
```powershell
# ❌ WRONG - Requires BOTH conditions (too restrictive)
if ($relativePath -like "*scripts*" -and ($script.Name -like "*workflow*" -or $script.Name -like "*helper*")) {

# ✅ CORRECT - Any development indicator works
if ($relativePath -like "*scripts*" -or $script.Name -like "*workflow*" -or $script.Name -like "*helper*" -or $script.Name -like "*install*" -or $script.Name -like "*validate*") {
```

**Rule**: Use `-or` instead of `-and` when checking if a script is a development tool.

### False Positive Prevention for Validation Scripts
```powershell
# ❌ WRONG - Flags validation scripts that check for banned patterns
if ($content -match 'Get-WmiObject.*Win32_Product') {
    Write-Error "Uses Win32_Product"
}

# ✅ CORRECT - Excludes validation logic patterns
if (($content -match 'Get-WmiObject\s+[^''"].*Win32_Product') -and $content -notmatch "content.*match.*Win32_Product") {
    Write-Error "Uses Win32_Product"
}
```

**Rule**: Exclude validation scripts that contain banned patterns as regex strings.

### Development vs Deployment Script Handling
```powershell
# ✅ CORRECT - Context-aware interactive element checking
if ($content -match 'Read-Host|Get-Credential') {
    if ($relativePath -like "*scripts*" -or $script.Name -like "*workflow*") {
        Write-Warning "Development script contains interactive elements (not for RMM deployment)"
        # Don't count as semantic issues - this is expected
    } else {
        Write-Error "Contains interactive elements (incompatible with Datto RMM deployment)"
        exit 1
    }
}
```

**Rule**: Development scripts can have interactive elements (warning), deployment scripts cannot (error).

### Error Message Quality
```powershell
# ❌ WRONG - Generic error messages
Write-Error "Contains interactive elements"

# ✅ CORRECT - Specific script identification
Write-Error "Script '$($script.Name)' contains interactive elements"
```

**Rule**: Always include script names in error/warning messages for easier debugging.

## 🛡️ Datto RMM Context-Aware Validation

### Write-Host Usage Validation
```powershell
# ✅ CORRECT - Context-aware Write-Host checking
if ($content -match 'Write-Host' -and $relativePath -like "*Monitors*") {
    if ($content -notmatch '<-Start Result->|<-End Result->') {
        Write-Warning "Monitor uses Write-Host but missing result markers"
    } else {
        Write-Output "Monitor correctly uses Write-Host with result markers"
    }
} elseif ($content -match 'Write-Host' -and $relativePath -notlike "*Monitors*") {
    if ($script.Name -like "*validate*" -or $script.Name -like "*workflow*") {
        Write-Output "Development script appropriately uses Write-Host for colored output"
    } else {
        Write-Warning "Non-monitor script uses Write-Host (consider Write-Output for RMM scripts)"
    }
}
```

### Monitor Exit Code Validation
```powershell
# ✅ CORRECT - Validate monitor exit codes
$hardcodedExitCodes = [regex]::Matches($content, 'exit\s+(\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
$invalidExitCodes = $hardcodedExitCodes | Where-Object { $_ -notin @(0, 30, 31) }

if ($invalidExitCodes.Count -gt 0) {
    Write-Warning "Monitor uses non-standard exit codes: $($invalidExitCodes -join ', ') (should be 0, 30, or 31)"
}
```

## 🚀 Workflow Architecture Best Practices

### Workflow File Update Strategy
1. **Always push workflow changes to main branch FIRST**
2. **Then test on feature branches** - they will use the updated workflow from main
3. **Never test workflow changes on feature branches first** - they run the old version from main

### Validation Pipeline Structure
```yaml
# ✅ CORRECT - Comprehensive validation pipeline
- Syntax Validation (PowerShell parsing)
- PSScriptAnalyzer (advanced linting)
- Semantic Validation (Datto RMM context-aware)
- Performance Validation (monitor compliance)
- Architecture Validation (shared functions, launchers)
- Auto-PR Creation (if all validation passes)
```

### Error Handling in Workflows
```yaml
# ✅ CORRECT - Fail fast on critical errors, warn on minor issues
if ($criticalIssues -gt 0) {
    Write-Error "Found $criticalIssues critical issues"
    exit 1
} elseif ($warnings -gt 10) {
    Write-Warning "High number of warnings: $warnings"
    # Continue execution
}
```

## 🎯 Common Mistakes to Avoid

1. **❌ Using `wait=true` for git operations** - causes blocking issues
2. **❌ Testing workflow changes on feature branches first** - runs old version
3. **❌ Generic error messages** - makes debugging impossible
4. **❌ Flagging development tools for having development patterns** - false positives
5. **❌ Not distinguishing between validation logic and actual usage** - false positives
6. **❌ Using `-and` when `-or` is needed for development script detection** - too restrictive
7. **❌ Improper variable expansion with special characters** - PowerShell parser errors
