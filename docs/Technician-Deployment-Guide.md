# 🚀 Technician Deployment Guide: GitHub Script Launcher

## Overview

This guide explains the **two-tier deployment strategy** for running GitHub-based PowerShell scripts in Datto RMM:

- **Dedicated Components** - For frequently used scripts (easy one-click deployment)
- **Universal Launcher** - For one-off or rare scripts (flexible variable-based deployment)

## 🎯 **Deployment Strategy**

### **Tier 1: Dedicated Components (Frequent Use)**
Create dedicated components for scripts you run **weekly or more often**:
- ✅ **One-click deployment** - No variables to change
- ✅ **Faster execution** - Pre-configured and ready
- ✅ **Less chance of errors** - No manual variable entry
- ✅ **Perfect for standard procedures** - Debloating, monitoring, etc.

### **Tier 2: Universal Launcher (Occasional Use)**
Use the universal launcher for scripts you run **monthly or less**:
- ✅ **Flexible deployment** - Change variables as needed
- ✅ **No component clutter** - One launcher handles many scripts
- ✅ **Perfect for testing** - Try new scripts without creating components
- ✅ **Ideal for one-offs** - Custom deployments, troubleshooting, etc.

## 📋 **Implementation Guide**

### **Step 1: Deploy Universal Launcher (One-Time Setup)**

#### **Create Universal Launcher Component:**
1. **Go to**: Datto RMM → Setup → Components → New Component
2. **Configure**:
   ```
   Name: GitHub-Universal-Launcher
   Category: Scripts
   Description: Universal launcher for GitHub-based scripts (variable-driven)
   ```
3. **Script**: Copy content from `UniversalLauncher.ps1`
4. **Environment Variables**:
   ```
   GitHubRepo = aybouzaglou/Datto-RMM-Powershell-Scripts
   ScriptPath = components/Scripts/Setup-TestDevice.ps1
   CacheTimeout = 3600
   ```
5. **Save Component**

### **Step 2: Create Dedicated Components (Frequent Use Scripts)**

#### **Example 1: Focused Debloat (Weekly Use)**
1. **Clone**: `GitHub-Universal-Launcher` → Name: `Focused-Debloat`
2. **Pre-configure Environment Variables**:
   ```
   GitHubRepo = aybouzaglou/Datto-RMM-Powershell-Scripts
   ScriptPath = components/Scripts/FocusedDebloat.ps1
   CacheTimeout = 3600
   ```
3. **Description**: `Removes bloatware based on manufacturer detection`

#### **Example 2: ScanSnap Setup (Monthly Use)**
1. **Clone**: `GitHub-Universal-Launcher` → Name: `ScanSnap-Home-Setup`
2. **Pre-configure Environment Variables**:
   ```
   GitHubRepo = aybouzaglou/Datto-RMM-Powershell-Scripts
   ScriptPath = components/Applications/ScanSnapHome.ps1
   CacheTimeout = 3600
   ```
3. **Description**: `Installs and configures ScanSnap Home software`

#### **Example 3: Disk Space Monitor (Daily Use)**
1. **Clone**: `GitHub-Universal-Launcher` → Name: `Disk-Space-Monitor`
2. **Pre-configure Environment Variables**:
   ```
   GitHubRepo = aybouzaglou/Datto-RMM-Powershell-Scripts
   ScriptPath = components/Monitors/DiskSpaceMonitor.ps1
   CacheTimeout = 3600
   ```
3. **Category**: `Monitors` (for this one)
4. **Description**: `Monitors disk space and alerts on low space`

## 🎯 **Usage Guide for Technicians**

### **For Frequent Scripts (Dedicated Components):**

#### **Simple One-Click Deployment:**
1. **Select device** in Datto RMM
2. **Run Component** → Choose dedicated component:
   - `Focused-Debloat`
   - `ScanSnap-Home-Setup`
   - `Disk-Space-Monitor`
3. **Click Run** - No variables to change!
4. **Monitor results** in real-time

### **For Occasional Scripts (Universal Launcher):**

#### **Variable-Based Deployment:**
1. **Select device** in Datto RMM
2. **Run Component** → `GitHub-Universal-Launcher`
3. **Override Environment Variables**:
   ```
   ScriptPath = [choose from menu below]
   ```
4. **Click Run**

#### **Available Scripts Menu (Copy/Paste):**
```
┌─────────────────────────────────────────────────────────────┐
│                    SCRIPT PATH MENU                        │
├─────────────────────────────────────────────────────────────┤
│ SYSTEM MAINTENANCE:                                         │
│ components/Scripts/Setup-TestDevice.ps1                     │
│ components/Scripts/Validate-TestEnvironment.ps1             │
│                                                             │
│ APPLICATION DEPLOYMENT:                                     │
│ components/Applications/ScanSnapHome.ps1                    │
│                                                             │
│ MONITORING:                                                 │
│ components/Monitors/DiskSpaceMonitor.ps1                    │
│                                                             │
│ TROUBLESHOOTING:                                            │
│ components/Scripts/FocusedDebloat.ps1                       │
└─────────────────────────────────────────────────────────────┘
```

## 📊 **Decision Matrix: When to Use Which Approach**

| Script Usage Frequency | Approach | Benefits |
|------------------------|----------|----------|
| **Daily/Weekly** | Dedicated Component | One-click, no errors, fast |
| **Monthly** | Dedicated Component | Still worth the convenience |
| **Quarterly** | Universal Launcher | Flexible, no component clutter |
| **Rarely/Testing** | Universal Launcher | Perfect for experimentation |
| **One-off Tasks** | Universal Launcher | No permanent component needed |

## 🔧 **Recommended Dedicated Components**

Based on typical MSP workflows:

### **High Priority (Create Dedicated Components):**
- ✅ **Focused-Debloat** - Weekly new device setup
- ✅ **Disk-Space-Monitor** - Daily monitoring
- ✅ **System-Health-Check** - Weekly maintenance

### **Medium Priority (Consider Dedicated Components):**
- 🤔 **ScanSnap-Home-Setup** - Monthly software deployment
- 🤔 **Test-Environment-Setup** - Monthly testing

### **Low Priority (Use Universal Launcher):**
- 📋 **Validate-Test-Environment** - Quarterly validation
- 📋 **Custom-Troubleshooting** - As-needed basis

## 🎯 **Quick Reference Card for Techs**

```
┌─────────────────────────────────────────────────────────────┐
│                 GITHUB LAUNCHER QUICK GUIDE                │
├─────────────────────────────────────────────────────────────┤
│ FREQUENT SCRIPTS (One-Click):                              │
│ • Focused-Debloat          → Removes bloatware             │
│ • ScanSnap-Home-Setup      → Installs ScanSnap             │
│ • Disk-Space-Monitor       → Monitors disk space           │
│                                                             │
│ OCCASIONAL SCRIPTS (Variable-Based):                       │
│ • GitHub-Universal-Launcher → Change ScriptPath variable   │
│                                                             │
│ COMMON SCRIPT PATHS:                                        │
│ • components/Scripts/Setup-TestDevice.ps1                  │
│ • components/Scripts/Validate-TestEnvironment.ps1          │
│ • components/Applications/ScanSnapHome.ps1                 │
│ • components/Monitors/DiskSpaceMonitor.ps1                 │
│                                                             │
│ BENEFITS:                                                   │
│ ✅ Always latest version from GitHub                        │
│ ✅ Automatic error handling                                 │
│ ✅ Cached for offline use                                   │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 **Implementation Timeline**

### **Week 1: Foundation**
- [ ] Deploy Universal Launcher
- [ ] Test with 2-3 scripts
- [ ] Train primary technicians

### **Week 2: High-Priority Dedicated Components**
- [ ] Create Focused-Debloat component
- [ ] Create Disk-Space-Monitor component
- [ ] Deploy to test devices

### **Week 3: Medium-Priority Components**
- [ ] Evaluate usage patterns
- [ ] Create additional dedicated components as needed
- [ ] Document any custom configurations

### **Week 4: Full Deployment**
- [ ] Train all technicians
- [ ] Deploy to production environment
- [ ] Monitor usage and optimize

## 🎯 **Best Practices**

### **For Dedicated Components:**
- ✅ **Use descriptive names** - Clear purpose and function
- ✅ **Include descriptions** - What the script does
- ✅ **Test thoroughly** - Validate before production use
- ✅ **Monitor usage** - Track which components are used most

### **For Universal Launcher:**
- ✅ **Keep script menu updated** - Add new scripts as available
- ✅ **Train on variable syntax** - Ensure techs understand paths
- ✅ **Document common use cases** - Build institutional knowledge
- ✅ **Use for testing** - Perfect for trying new scripts

This two-tier approach gives you the **best of both worlds**: convenience for frequent tasks and flexibility for everything else! 🎯
