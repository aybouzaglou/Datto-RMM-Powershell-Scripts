#!/bin/bash
# Mac Development Helper Script
# Helps Mac developers work with Windows PowerShell components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPONENTS_DIR="$REPO_ROOT/components"
TEST_RESULTS_DIR="$REPO_ROOT/test-results"

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Datto RMM Mac Dev Helper${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to validate PowerShell syntax (requires PowerShell Core on Mac)
validate_powershell_syntax() {
    local file="$1"
    print_info "Validating PowerShell syntax for: $(basename "$file")"
    
    if command -v pwsh >/dev/null 2>&1; then
        if pwsh -Command "try { \$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content '$file' -Raw), [ref]\$null); Write-Host 'Syntax OK' } catch { Write-Error \$_.Exception.Message; exit 1 }" >/dev/null 2>&1; then
            print_success "PowerShell syntax valid"
            return 0
        else
            print_error "PowerShell syntax error detected"
            return 1
        fi
    else
        print_warning "PowerShell Core not installed - skipping syntax validation"
        print_info "Install with: brew install --cask powershell"
        return 0
    fi
}

# Function to check component structure
validate_component_structure() {
    local file="$1"
    local filename=$(basename "$file")
    
    print_info "Validating component structure for: $filename"
    
    # Check for required comment blocks
    if grep -q "\.SYNOPSIS" "$file" && grep -q "\.DESCRIPTION" "$file"; then
        print_success "Documentation blocks found"
    else
        print_warning "Missing .SYNOPSIS or .DESCRIPTION comment blocks"
    fi
    
    # Check for param block
    if grep -q "param(" "$file"; then
        print_success "Parameter block found"
    else
        print_warning "No parameter block found"
    fi
    
    # Check for try/catch blocks
    if grep -q "try\s*{" "$file" && grep -q "catch\s*{" "$file"; then
        print_success "Error handling (try/catch) found"
    else
        print_warning "No try/catch error handling found"
    fi
    
    # Check component category
    local category=""
    if [[ "$file" == *"/Applications/"* ]]; then
        category="Applications"
    elif [[ "$file" == *"/Monitors/"* ]]; then
        category="Monitors"
    elif [[ "$file" == *"/Scripts/"* ]]; then
        category="Scripts"
    else
        print_warning "Component not in recognized category directory"
        return 1
    fi
    
    print_success "Component categorized as: $category"
    
    # Category-specific validation
    if [[ "$category" == "Monitors" ]]; then
        if grep -q "<-Start Result->" "$file" && grep -q "<-End Result->" "$file"; then
            print_success "Monitor result markers found"
        else
            print_error "Monitor components require <-Start Result-> and <-End Result-> markers"
            return 1
        fi
    fi
    
    return 0
}

# Function to prepare component for testing
prepare_test_component() {
    local file="$1"
    local filename=$(basename "$file" .ps1)
    local test_filename="TEST-$filename.ps1"
    local test_file="$TEST_RESULTS_DIR/$test_filename"
    
    print_info "Preparing test version: $test_filename"
    
    # Create test results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Copy component and add test mode wrapper
    cat > "$test_file" << 'EOF'
# TEST MODE WRAPPER - Auto-generated
param(
    [string]$TestMode = "true",
    [string]$LogPath = "C:\TestResults"
)

# Enhanced logging for test mode
if ($TestMode -eq "true") {
    $startTime = Get-Date
    Start-Transcript -Path "$LogPath\TEST-$(Get-Date -Format 'yyyyMMdd-HHmmss').log" -Append
    Write-Output "TEST-START: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

# Original component code below:
# ============================================

EOF
    
    # Append original component (skip first line if it has shebang-like comment)
    tail -n +2 "$file" >> "$test_file"
    
    # Add test mode footer
    cat >> "$test_file" << 'EOF'

# ============================================
# Test mode footer

if ($TestMode -eq "true") {
    $endTime = Get-Date
    $duration = $endTime - $startTime
    Write-Output "TEST-END: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output "TEST-DURATION: $($duration.TotalSeconds) seconds"
    Write-Output "TEST-RESULT: Component preparation completed"
    Stop-Transcript
}
EOF
    
    print_success "Test component created: $test_file"
    return 0
}

# Function to run local validation
run_local_validation() {
    print_header
    print_info "Running local validation on Mac..."
    
    local error_count=0
    local component_count=0
    
    # Find all PowerShell components
    while IFS= read -r -d '' file; do
        ((component_count++))
        print_info "Processing: $(basename "$file")"
        
        # Validate syntax
        if ! validate_powershell_syntax "$file"; then
            ((error_count++))
        fi
        
        # Validate structure
        if ! validate_component_structure "$file"; then
            ((error_count++))
        fi
        
        # Prepare test version
        if ! prepare_test_component "$file"; then
            ((error_count++))
        fi
        
        echo ""
    done < <(find "$COMPONENTS_DIR" -name "*.ps1" -type f -print0)
    
    # Summary
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Validation Summary${NC}"
    echo -e "${BLUE}================================${NC}"
    print_info "Components processed: $component_count"
    
    if [[ $error_count -eq 0 ]]; then
        print_success "All validations passed!"
        print_info "Test components created in: $TEST_RESULTS_DIR"
        print_info "Ready to commit and push for CI/CD pipeline"
    else
        print_error "Found $error_count validation issues"
        print_info "Please fix issues before committing"
        exit 1
    fi
}

# Function to show help
show_help() {
    print_header
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  validate    Run local validation on all components"
    echo "  syntax      Check PowerShell syntax only"
    echo "  structure   Check component structure only"
    echo "  prepare     Prepare test components only"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 validate                    # Run full validation"
    echo "  $0 syntax                      # Check syntax only"
    echo "  $0 structure                   # Check structure only"
    echo ""
    echo "Prerequisites:"
    echo "  - PowerShell Core (brew install --cask powershell)"
    echo "  - Git repository with components/ directory"
    echo ""
}

# Main script logic
case "${1:-validate}" in
    "validate")
        run_local_validation
        ;;
    "syntax")
        print_header
        find "$COMPONENTS_DIR" -name "*.ps1" -type f | while read -r file; do
            validate_powershell_syntax "$file"
        done
        ;;
    "structure")
        print_header
        find "$COMPONENTS_DIR" -name "*.ps1" -type f | while read -r file; do
            validate_component_structure "$file"
        done
        ;;
    "prepare")
        print_header
        mkdir -p "$TEST_RESULTS_DIR"
        find "$COMPONENTS_DIR" -name "*.ps1" -type f | while read -r file; do
            prepare_test_component "$file"
        done
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
