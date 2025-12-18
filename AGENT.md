# AGENT.md

This file provides valid guidance to AI agents (including rules for .cursorrules, .windsurf/rules, etc.) when working with code in this repository.

## 🤖 AI Agent Responsibilities

You are responsible for maintaining the high quality and reliability of the Datto RMM PowerShell Scripts repository. Valid scripts can be either self-contained (embedded functions) or modular (importing dependencies), depending on the specific needs of the task.

### 🌟 Core Principles

1.  **Strict Linting**: All scripts must pass `PSScriptAnalyzer` checks defined in `PSScriptAnalyzerSettings.psd1`.
2.  **Standardized Output**: Logs must be parseable. Use the `Write-RMMLog` standard.
3.  **Safety First**: Always validate system state, handling timeouts and errors gracefully.
4.  **Dependencies**: While self-contained scripts are preferred for reliability, you **MAY** use `Import-Module` or external dependencies if the task requires it or if it significantly simplifies maintainability.

---

## 📁 Repository Architecture

-   **`components/`**: The source of truth for all scripts.
    -   `Applications/`: Long-running software deployments (up to 30 mins).
    -   `Scripts/`: General automation tasks.
    -   `Monitors/`: Fast diagnostic checks (<200ms target).
-   **`shared-functions/`**: The library of approved functions.
    -   **Rule**: Do not write custom logic if a shared function exists. Copy the function from here into the script.
-   **`templates/`**: References for new scripts.
    -   *Always* check these templates before starting a new file.

---

## 📝 Coding Standards

### 1. Metadata Headers (Required)
Every script MUST start with a standard comment block containing the following metadata.

```powershell
<#
.SYNOPSIS
    Short description of the script's purpose.

.DESCRIPTION
    Detailed explanation of what the script does, including requirements and edge cases.

.COMPONENT
    Category=Scripts ; Level=Medium(3) ; Timeout=300s ; Build=1.0.0

.INPUTS
    Variable1(Type) ; Variable2(Type)

.REQUIRES
    LocalSystem ; PSVersion >=5.0
#>
```

### 2. Embedded Functions vs Modules
You should generally prefer embedding functions for simple tasks to ensure the script runs identically on all endpoints. However, if a standard PowerShell module is available or if the script logic is complex and better managed via a module, **you may use `Import-Module`**.

If you choose to embed, read the content of the required function from `shared-functions/` and embed it into the script region marked:

```powershell
############################################################################################################
#                                    EMBEDDED FUNCTION LIBRARY                                            #
############################################################################################################

# [Paste content of shared-functions/Core/RMMLogging.ps1 here]
# [Paste content of shared-functions/Core/RMMValidation.ps1 here]
```

### 3. Variable Handling (`Get-RMMVariable`)
Always use the standard `Get-RMMVariable` function (copied from `RMMValidation.ps1`) to safely retrieve environment variables.

```powershell
# ✅ Correct
$TargetFile = Get-RMMVariable -Name "TargetFile" -Required

# ❌ Incorrect
$TargetFile = $env:TargetFile
```

### 4. Logging Standards (`Write-RMMLog`)
Use `Write-RMMLog` for all output (except Monitors). This ensures RMM can parse the logs.

-   **Patterns**:
    -   `Write-RMMLog "Starting backup..." -Level Status`
    -   `Write-RMMLog "File not found" -Level Failed`
    -   `Write-RMMLog "Disk space: 50GB" -Level Metric`

### 5. Monitor Specifics
Monitors have a strict contract and CANNOT use `Write-RMMLog`.
-   **Must use**: `Write-Host` exactly.
-   **Structure**:
    ```powershell
    Write-Host "<-Start Diagnostic->"
    Write-Host "Checking service status..."
    Write-Host "<-End Diagnostic->"
    
    Write-Host "<-Start Result->"
    Write-Host "Status=OK: Service is running"
    Write-Host "<-End Result->"
    exit 0
    ```

---

## 🔍 Validation & Linting

### PSScriptAnalyzer
Run analysis on every script change.
```powershell
Invoke-ScriptAnalyzer -Path "components/Scripts/MyScript.ps1" -Settings "PSScriptAnalyzerSettings.psd1"
```

**Common Fixes**:
-   **Global Variables**: Allowed only for standard counters (`$Global:RMMSuccessCount`). use `$script:` scope otherwise.
-   **Empty Catch Blocks**: Forbidden. Always comment why an error is ignored:
    ```powershell
    catch {
        # Ignored because file might strict not exist yet
        $null = $_
    }
    ```
-   **Cmdlet Aliases**: Do not use `gwmi`, `gc`, etc. Use full names `Get-WmiObject`, `Get-Content`.

### PowerShell Versions
Scripts must support **PowerShell 5.0+**. Avoid syntax introduced in PowerShell 7 (like ternary operators `? :` or `||`) unless you explicitly check the version first.

---

## 🛠 Workflow for Agents

1.  **Read**: Analyze the user request.
2.  **Plan**: Check `templates/` and `shared-functions/`. Decide which functions to embed.
3.  **Draft**: Write the script in `components/Category/Name.ps1`.
4.  **Embed**: Copy function definitions from `shared-functions/` into the script.
    -   *Agent Tip*: You can assume `RMMLogging.ps1` and `RMMValidation.ps1` are always needed.
5.  **Validate**: Run `Invoke-ScriptAnalyzer`. Fix all Warnings/Errors.
6.  **Verify**: Ensure no absolute paths to the user's machine are hardcoded (use system variables).

## 🚫 "Do Not" List

-   **DO NOT** use `Write-Host` in non-Monitor scripts (use `Write-RMMLog` or `Write-Output`).
-   **DO NOT** use `+=` for arrays (use `[System.Collections.Generic.List[Object]]::new()`).
-   **DO NOT** create "launcher" scripts that download code from GitHub.
-   **DO NOT** use `Read-Host` (scripts run headless).
