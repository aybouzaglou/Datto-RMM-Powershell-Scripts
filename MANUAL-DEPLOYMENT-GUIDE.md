# 🚀 Manual Deployment Guide - Performance Optimized

## Overview

This guide covers the **performance-optimized deployment approach** using GitHub Actions for validation and hybrid deployment strategies to Datto RMM:

- **📊 Monitors**: Direct deployment for 98.2% performance improvement
- **🔧 Applications & Scripts**: Traditional launcher-based deployment

## 🎯 Performance-Optimized Deployment Strategy

### **Direct Deployment (Monitors)**
- **Performance**: Sub-200ms execution times vs 1000-2000ms launcher overhead
- **Reliability**: Zero network dependencies during execution
- **Use Case**: High-frequency monitoring (every 1-2 minutes)
- **Method**: Paste entire script content directly into Datto RMM component

### **Launcher-Based Deployment (Applications/Scripts)**
- **Flexibility**: GitHub-based updates and shared functions
- **Maintenance**: Automatic function library updates
- **Use Case**: Complex operations with extended timeouts
- **Method**: Use launcher scripts with GitHub function library

## 🎯 **Why This Approach?**

- ✅ **Simple and reliable** - No complex authentication or API setup
- ✅ **GitHub validation** - Catch issues before deployment
- ✅ **Full control** - You decide when and what to deploy
- ✅ **Faster development** - Focus on script quality and functionality

## 🔄 **Development Workflow**

### **1. Development Phase**
```bash
# 1. Make changes to your scripts
code components/Scripts/MyScript.ps1

# 2. Test locally (optional)
pwsh -File components/Scripts/MyScript.ps1

# 3. Commit and push
git add .
git commit -m "Update MyScript functionality"
git push origin main
```

### **2. Automatic Validation**
GitHub Actions automatically:
- ✅ **Validates PowerShell syntax** on all scripts
- ✅ **Tests shared function imports**
- ✅ **Checks component categories** (Applications/Monitors/Scripts)
- ✅ **Validates Monitor result markers** (`<-Start Result->` / `<-End Result->`)
- ✅ **Tests launcher functionality**
- ✅ **Creates deployment package** with validated scripts

### **3. Manual Deployment**
After GitHub validation passes:
1. **Download validated scripts** from GitHub Actions artifacts
2. **Copy to Datto RMM** console manually
3. **Test on target device**
4. **Deploy to production**

## 📋 **Step-by-Step Manual Deployment**

### **Step 1: Get Validated Scripts**

#### **Option A: From GitHub Actions (Recommended)**
1. Go to your repository → **Actions** tab
2. Click on the latest successful workflow run
3. Download **"validated-scripts-[commit]"** artifact
4. Extract the ZIP file

#### **Option B: From Local Repository**
```bash
# Use scripts directly from your local repo
# (only if GitHub Actions validation passed)
```

### **Step 2: Deploy to Datto RMM Console**

#### **For Component Scripts:**
1. **Open Datto RMM** console
2. Go to **Setup** → **Components**
3. Click **"New Component"**
4. **Configure**:
   - **Name**: Descriptive name (e.g., "Enhanced Debloat Script")
   - **Category**: Choose appropriate category:
     - **Applications**: Software deployment/installation
     - **Monitors**: System monitoring (must complete in <3 seconds)
     - **Scripts**: General automation
   - **Script**: Copy/paste the validated PowerShell code
5. **Set Environment Variables** (if needed):
   ```
   TestResultsPath = C:\TestResults
   CleanupOldResults = 7
   ```
6. **Save Component**

#### **For Launcher Scripts:**
1. **Create Universal Launcher** component
2. **Copy launcher code** (e.g., `UniversalLauncher.ps1`)
3. **Set environment variables**:
   ```
   GitHubRepo = your-username/Datto-RMM-Powershell-Scripts
   ScriptPath = components/Scripts/YourScript.ps1
   ```

### **Step 3: Test Deployment**

#### **Create Test Job:**
1. Go to **Devices** → Select your test device
2. Click **"Run Component"**
3. Select your newly created component
4. **Monitor execution** in real-time
5. **Check results** in device logs

#### **Verify Results:**
- ✅ **Exit code 0** = Success
- ✅ **Expected output** in logs
- ✅ **Files created** (if applicable)
- ✅ **No errors** in execution

### **Step 4: Production Deployment**

After successful testing:
1. **Deploy to device groups** or individual devices
2. **Schedule recurring jobs** (if needed)
3. **Monitor execution** across fleet
4. **Review results** and adjust as needed

## 🛠️ **Component Categories Guide**

### **Applications Category**
- **Purpose**: Software deployment, installation, configuration
- **Timeout**: Up to 30 minutes
- **Changeable**: Yes (can switch to Scripts category)
- **Examples**: Software installers, system configuration

### **Monitors Category**  
- **Purpose**: System health monitoring, alerting
- **Timeout**: Must complete in under 3 seconds
- **Changeable**: No (immutable once created)
- **Requirements**: Must include result markers:
  ```powershell
  Write-Host "<-Start Result->"
  Write-Host "OK: System is healthy"
  Write-Host "<-End Result->"
  exit 0  # 0=OK, 30=WARNING, 31=CRITICAL
  ```

### **Scripts Category**
- **Purpose**: General automation, maintenance tasks
- **Timeout**: Flexible (typically 5-15 minutes)
- **Changeable**: Yes (can switch to Applications category)
- **Examples**: Cleanup scripts, system maintenance

## 🔍 **GitHub Actions Validation**

### **What Gets Validated:**
- ✅ **PowerShell syntax** - No parse errors
- ✅ **Shared function imports** - All functions load correctly
- ✅ **Component structure** - Proper category organization
- ✅ **Monitor requirements** - Result markers present
- ✅ **Launcher functionality** - Parameter blocks exist
- ✅ **Exit codes** - Proper error handling

### **Validation Triggers:**
- **Push to main/develop** - Automatic validation
- **Pull requests** - Pre-merge validation  
- **Manual trigger** - On-demand validation

### **Validation Results:**
- ✅ **Green check** = Ready for deployment
- ❌ **Red X** = Fix issues before deployment
- 📦 **Artifacts** = Download validated scripts

## 🎯 **Best Practices**

### **Development:**
- ✅ **Test locally** before committing
- ✅ **Use descriptive commit messages**
- ✅ **Follow PowerShell best practices**
- ✅ **Include error handling**

### **Deployment:**
- ✅ **Always test on single device first**
- ✅ **Use appropriate component categories**
- ✅ **Set realistic timeouts**
- ✅ **Monitor execution logs**

### **Maintenance:**
- ✅ **Regular GitHub Actions validation**
- ✅ **Update scripts based on feedback**
- ✅ **Version control all changes**
- ✅ **Document deployment notes**

## 🚨 **Troubleshooting**

### **GitHub Actions Fails:**
1. **Check syntax errors** in PowerShell scripts
2. **Fix validation issues** shown in logs
3. **Commit fixes** and re-run validation

### **Datto RMM Deployment Issues:**
1. **Check component category** is appropriate
2. **Verify timeout settings** for script complexity
3. **Review device logs** for execution errors
4. **Test on different device** to isolate issues

### **Script Execution Problems:**
1. **Check exit codes** in RMM console
2. **Review PowerShell execution policy** on target devices
3. **Verify required modules** are available
4. **Check network connectivity** for downloads

## 🎉 **Benefits of This Approach**

- 🚀 **Faster development** - Simple, straightforward workflow
- 🔍 **Better quality** - GitHub validation catches issues early
- 🎯 **Full control** - Deploy when and what you want
- 📊 **Clear feedback** - Validation results and deployment artifacts
- 🔄 **Iterative improvement** - Easy to test and refine scripts

This approach gives you enterprise-grade validation with simple, manual deployment control! 🎯
