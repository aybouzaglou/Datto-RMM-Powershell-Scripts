# 📊 Monitor Development Guidelines

## 🎯 Core Principles

### **Diagnostic-First Design**
- Show your work before showing results
- Extensive diagnostic output helps troubleshooting
- Use `Write-Host` consistently for all output

### **Single Output Stream**
- Use `Write-Host` for ALL output (diagnostic and results)
- Avoid `Write-Output`, `Write-Verbose`, or mixed output methods
- Prevents "no data" issues in Datto RMM

### **Custom Alert Functions**
- Create centralized alert functions for proper marker handling
- Example pattern:
```powershell
function writeAlert ($message, $code) {
    Write-Host '<-End Diagnostic->'
    Write-Host '<-Start Result->'
    Write-Host "Status=$message"
    Write-Host '<-End Result->'
    exit $code
}
```

## 🏗️ Architecture Patterns

### **Defensive Programming**
- Handle scenarios where expected data isn't available
- Graceful degradation (e.g., no user logged in)
- Fallback to stored/cached data when possible

### **Multi-State Support**
- Support both "active" and "idle" states
- Store historical data for comparison
- Handle transitions between states gracefully

### **Complex Output Normalization**
- Aggregate data from multiple sources
- Normalize different data formats into consistent output
- Provide meaningful status summaries

## 📋 Required Elements

### **Diagnostic Markers (Critical)**
```powershell
Write-Host '<-Start Diagnostic->'
# Your diagnostic output here
Write-Host '<-End Diagnostic->'
```

### **Result Markers + Single Status Line (Critical)**
RMM expects exactly one result block containing exactly one line that begins with `Status=`.

```powershell
Write-Host '<-Start Result->'
Write-Host 'Status=OK: All checks passed'    # or 'Status=CRITICAL: <reason>'
Write-Host '<-End Result->'
```

- Do not write multiple result lines
- Do not mix Write-Output/Write-Verbose (use Write-Host only)
- Exit code 0 for OK, non-zero for alerts

### **Centralized Helpers (Recommended)**
```powershell
function Write-MonitorAlert {
  param([string]$Message)
  Write-Host '<-End Diagnostic->'
  Write-Host '<-Start Result->'
  Write-Host "Status=$Message"
  Write-Host '<-End Result->'
  exit 1
}

function Write-MonitorSuccess {
  param([string]$Message)
  Write-Host '<-End Diagnostic->'
  Write-Host '<-Start Result->'
  Write-Host "Status=$Message"
  Write-Host '<-End Result->'
  exit 0
}
```

## ⚡ Performance Guidelines

- **Target**: <200ms execution time
- **Maximum**: 3 seconds (hard limit)
- **Direct deployment only** - no launchers for monitors
- Embed all functions - no external dependencies

## 🔍 Expert Patterns from OneDrive Monitor

### **Registry-Based State Management**
- Store user data in registry for persistence
- Compare live vs stored data
- Handle user login/logout scenarios

### **Sophisticated Error Handling**
- Multiple validation layers
- Specific error messages for different failure modes
- Graceful handling of edge cases

### **User Context Awareness**
- Detect logged-in vs logged-out users
- Handle multi-user scenarios
- Provide context-appropriate alerts

## 🚫 Common Mistakes to Avoid

- ❌ Using mixed output methods (Write-Output + Write-Host)
- ❌ Missing result markers
- ❌ Assuming users are always logged in
- ❌ Not handling edge cases gracefully
- ❌ Using launchers for monitors (performance impact)

## ✅ Validation Checklist

- [ ] Uses `Write-Host` for all output
- [ ] Has proper `<-Start Result->` and `<-End Result->` markers
- [ ] Executes in <200ms
- [ ] Handles "no user logged in" scenario
- [ ] Provides meaningful diagnostic output
- [ ] Uses defensive programming patterns
- [ ] Self-contained (no external dependencies)
