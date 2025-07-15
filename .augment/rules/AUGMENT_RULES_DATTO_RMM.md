---
type: "agent_requested"
description: "Augment Agent Rules for Datto RMM PowerShell Scripts Repository"
---
# 🎯 Augment Agent Rules for Datto RMM PowerShell Scripts Repository

## 🔍 Context Gathering Rules

### Always Start With Repository Context
1. **Use `codebase-retrieval`** to understand current repository structure, architecture, and existing scripts before making any suggestions
2. **Search for specific patterns** like "launcher", "shared-functions", "component categories", "GitHub Actions" to understand the current implementation
3. **Check documentation files** in `docs/` directory for current deployment strategies and technician guides
4. **Understand the two-tier deployment strategy**: Dedicated components vs Universal launcher approach

### Key Repository Architecture to Remember
- **GitHub-based function library** with automatic downloads and caching
- **Three Datto RMM component categories**: Applications, Monitors, Scripts
- **Two-tier deployment**: Dedicated components (frequent use) + Universal launcher (occasional use)
- **GitHub Actions validation pipeline** for script quality assurance
- **Manual deployment approach** (not API-based) for simplicity and control

## 🚫 Process Management Rules (Critical)

### Git Operations
- **ALWAYS use `wait=false`** for git operations to avoid blocking waiting processes
- **Use `read-process`** to check results when needed instead of waiting processes
- **Never launch multiple waiting processes** - this causes "Cannot launch another waiting process" errors

### Example Pattern
```bash
# ✅ Correct approach
launch-process: git add . && git commit -m "message" (wait=false)
read-process: terminal_id, wait=true, max_wait_seconds=15

# ❌ Wrong approach  
launch-process: git add . (wait=true)
launch-process: git commit -m "message" (wait=true) # This will fail!
```

## 🏗️ Repository Structure Rules

### Component Organization
- **`components/Applications/`** - Software deployment (changeable category, up to 30min timeout)
- **`components/Monitors/`** - System monitoring (immutable category, <3 seconds timeout, requires result markers)
- **`components/Scripts/`** - General automation (changeable category, flexible timeout)
- **`shared-functions/`** - Reusable function library with automatic GitHub downloading
- **`launchers/`** - Universal launchers for different component types
- **`docs/`** - Comprehensive documentation including technician guides

### File Naming Conventions
- **Components**: Descriptive names like `Setup-TestDevice.ps1`, `FocusedDebloat.ps1`
- **Monitors**: Must include `<-Start Result->` and `<-End Result->` markers
- **Documentation**: Clear, tech-friendly guides with quick reference cards

## 🚀 Deployment Strategy Rules

### Two-Tier Approach
1. **Dedicated Components** (for weekly+ use):
   - Create specific RMM components for frequently used scripts
   - Pre-configure environment variables
   - One-click deployment for technicians

2. **Universal Launcher** (for monthly- use):
   - Use `GitHub-Universal-Launcher` component
   - Change `ScriptPath` environment variable for different scripts
   - Perfect for testing, one-offs, and rare scripts

### Environment Variables Pattern
```
GitHubRepo = aybouzaglou/Datto-RMM-Powershell-Scripts
ScriptPath = components/Scripts/YourScript.ps1
CacheTimeout = 3600
```

## 📋 Documentation Rules

### Always Provide Tech-Friendly Documentation
- **Create clear decision matrices** for when to use which approach
- **Provide copy/paste examples** for technicians
- **Include troubleshooting sections** with common mistakes
- **Make quick reference cards** that can be printed
- **Use clear visual formatting** with emojis and tables for readability

## 🔧 GitHub Actions Rules

### Validation Pipeline
- **Automatic triggers** on push to main/develop branches
- **Manual triggers** with test level options (basic/full/comprehensive)
- **Validates**: PowerShell syntax, shared functions, component categories, monitor result markers
- **Creates artifacts** with validated scripts for manual deployment
- **Never use API deployment** - stick to manual deployment approach for simplicity

### Workflow Update Strategy
- **Push workflow changes to main branch FIRST** before testing on feature branches
- **Avoid circular PR creation** by not running workflows on themselves
- **Test workflow changes** on feature branches after main is updated

## 🎯 Script Development Rules

### Component Category Guidelines
- **Applications**: Software installation/deployment, can change category later, up to 30min timeout
- **Monitors**: System health checks, **immutable category** (cannot change), <3 seconds timeout, requires result markers
- **Scripts**: General automation, can change category later, flexible timeout

### Shared Functions Usage
- **Always leverage shared functions** for consistency
- **Use GitHub auto-download pattern** for zero-maintenance updates
- **Implement caching** for offline scenarios
- **Include fallback mechanisms** for standalone operation
