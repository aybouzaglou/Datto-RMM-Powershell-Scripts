#!/usr/bin/env pwsh
<#
.SYNOPSIS
    🪝 Install Git Pre-Push Hook for Automatic Validation

.DESCRIPTION
    This script installs a git pre-push hook that automatically runs validation
    before every push, preventing broken code from reaching GitHub.

.PARAMETER Install
    Install the pre-push hook

.PARAMETER Uninstall
    Remove the pre-push hook

.EXAMPLE
    .\install-git-hooks.ps1 -Install
    
.EXAMPLE
    .\install-git-hooks.ps1 -Uninstall
#>

param(
    [switch]$Install,
    [switch]$Uninstall
)

if (-not $Install -and -not $Uninstall) {
    Write-Host "Usage: .\install-git-hooks.ps1 -Install | -Uninstall"
    exit 1
}

$hookPath = ".git/hooks/pre-push"

if ($Uninstall) {
    if (Test-Path $hookPath) {
        Remove-Item $hookPath -Force
        Write-Host "✅ Pre-push hook removed" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  No pre-push hook found" -ForegroundColor Cyan
    }
    exit 0
}

if ($Install) {
    # Create the pre-push hook
    $hookContent = @'
#!/bin/sh
# Git pre-push hook for PowerShell script validation

echo "🔍 Running pre-push validation..."

# Run PowerShell validation script
pwsh -File "scripts/validate-before-push.ps1" -Quick

# Check exit code
if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Pre-push validation failed!"
    echo "💡 Fix the issues above or run: pwsh scripts/validate-before-push.ps1 -Full"
    echo "🚫 Push blocked to prevent broken code from reaching GitHub"
    exit 1
fi

echo "✅ Pre-push validation passed - proceeding with push"
exit 0
'@

    # Ensure hooks directory exists
    $hooksDir = ".git/hooks"
    if (-not (Test-Path $hooksDir)) {
        New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
    }

    # Write the hook
    $hookContent | Out-File -FilePath $hookPath -Encoding ASCII -NoNewline

    # Make it executable (on Unix-like systems)
    if ($IsLinux -or $IsMacOS) {
        chmod +x $hookPath
    }

    Write-Host "✅ Pre-push hook installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎯 What this does:" -ForegroundColor Yellow
    Write-Host "  • Automatically runs validation before every push"
    Write-Host "  • Blocks push if validation fails"
    Write-Host "  • Prevents broken code from reaching GitHub"
    Write-Host ""
    Write-Host "💡 To disable temporarily: git push --no-verify"
    Write-Host "🗑️  To remove completely: .\install-git-hooks.ps1 -Uninstall"
}
