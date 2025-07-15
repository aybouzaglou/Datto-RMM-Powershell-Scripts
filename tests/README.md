# 🧪 Environment Variable Inheritance Tests

## 📋 Overview

These tests verify that the hard-coded launcher approach will work correctly with Datto RMM's environment variable system by testing the critical assumption: **environment variables are inherited by child PowerShell processes when using `& $scriptPath`**.

## 🎯 Why These Tests Matter

The hard-coded launcher system depends on this inheritance chain:
1. **Datto RMM** sets environment variables (customwhitelist, RebootEnabled, etc.)
2. **Hard-coded launcher** executes with those variables available
3. **Downloaded script** must inherit those same variables when executed via `& $scriptPath`

If step 3 fails, the entire hard-coded launcher approach won't work.

## 🧪 Available Tests

### 1. Quick Test: `Test-DattoRMM-EnvVars.ps1`
**Recommended for quick validation**

```powershell
.\tests\Test-DattoRMM-EnvVars.ps1
```

**What it tests:**
- Sets environment variables (simulating Datto RMM UI)
- Creates a test script with `Get-RMMVariable` function
- Executes script using `& $scriptPath` (same as hard-coded launcher)
- Verifies all environment variables are accessible in the child script

**Expected output if working:**
```
✅ SUCCESS: All environment variables correctly inherited and processed!
🎉 CONCLUSION: Hard-coded launcher approach WILL WORK with Datto RMM!
```

### 2. Comprehensive Test: `Test-EnvironmentVariableInheritance.ps1`
**For thorough validation**

```powershell
# Run all tests
.\tests\Test-EnvironmentVariableInheritance.ps1 -TestScenario All

# Run specific test scenarios
.\tests\Test-EnvironmentVariableInheritance.ps1 -TestScenario Basic
.\tests\Test-EnvironmentVariableInheritance.ps1 -TestScenario DattoRMM
```

**What it tests:**
- **Basic Test**: Simple environment variable inheritance
- **Datto RMM Test**: Simulates real Datto RMM variable access patterns
- **Launcher Test**: Full simulation of hard-coded launcher → target script flow

## 🚀 Running the Tests

### Prerequisites
- PowerShell 2.0+ (same as Datto RMM requirements)
- Write access to `$env:TEMP` directory

### Quick Validation
```powershell
# Navigate to repository root
cd "C:\Path\To\Datto-RMM-Powershell-Scripts"

# Run the quick test
.\tests\Test-DattoRMM-EnvVars.ps1
```

### Comprehensive Validation
```powershell
# Run all tests
.\tests\Test-EnvironmentVariableInheritance.ps1 -TestScenario All
```

## 📊 Interpreting Results

### ✅ Success Indicators
- All tests show "PASS" status
- Environment variables are correctly inherited
- Child scripts can access all parent environment variables
- Exit codes are 0

### ❌ Failure Indicators
- Any test shows "FAIL" status
- Environment variables are missing in child scripts
- Exit codes are non-zero
- Error messages about variable access

## 🔧 What These Tests Prove

### If Tests Pass ✅
- **Environment variable inheritance works** in PowerShell
- **Hard-coded launcher approach is viable** for Datto RMM
- **All environment variables will be available** to downloaded scripts
- **No conflicts between launcher and script variables**

### If Tests Fail ❌
- **Environment variable inheritance may not work** as expected
- **Hard-coded launcher approach needs revision**
- **Alternative solutions may be required**

## 🎯 Real-World Simulation

The tests simulate this exact Datto RMM workflow:

1. **Datto RMM UI**: Admin sets environment variables
   ```
   customwhitelist = "App1,App2,App3"
   RebootEnabled = true
   MaxRetries = 3
   ```

2. **Datto RMM Component**: Executes hard-coded launcher
   ```powershell
   # Hard-coded launcher content pasted in component
   $SCRIPT_PATH = "components/Scripts/FocusedDebloat.ps1"
   # ... launcher downloads and executes script
   & $downloadedScriptPath
   ```

3. **Downloaded Script**: Accesses environment variables
   ```powershell
   $customwhitelist = Get-RMMVariable -Name "customwhitelist" -Type "String"
   $RebootEnabled = Get-RMMVariable -Name "RebootEnabled" -Type "Boolean"
   ```

## 🛠️ Troubleshooting

### Test Files Not Found
```powershell
# Ensure you're in the repository root
Get-Location
# Should show: ...\Datto-RMM-Powershell-Scripts
```

### Permission Errors
```powershell
# Check PowerShell execution policy
Get-ExecutionPolicy
# May need: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Environment Variable Issues
- Tests automatically clean up environment variables
- If issues persist, restart PowerShell session

## 📚 Related Documentation

- **Hard-Coded Launcher Guide**: `docs/Hard-Coded-Launcher-Guide.md`
- **Datto RMM Component Categories**: `docs/Datto-RMM-Component-Categories.md`
- **Function Reference**: `docs/Function-Reference.md`

## 🎯 Next Steps After Testing

### If Tests Pass ✅
1. **Deploy hard-coded launchers** to Datto RMM components
2. **Migrate from universal launcher** to hard-coded approach
3. **Configure environment variables** in Datto RMM UI
4. **Test with real components** in your Datto RMM environment

### If Tests Fail ❌
1. **Review test output** for specific failure points
2. **Check PowerShell version** and environment
3. **Consider alternative approaches** or modifications
4. **Report issues** for further investigation

---

**Note**: These tests run locally and do not require Datto RMM access. They simulate the exact environment variable inheritance behavior that Datto RMM relies on.
