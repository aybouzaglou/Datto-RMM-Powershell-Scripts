# Phase 1 Deployment Guide: Test Device Setup

## ✅ **Completed Steps**

### **Mac Development Environment**
- ✅ PowerShell Core installed and working
- ✅ Mac development helper script tested and functional
- ✅ Component validation working (syntax, structure, categories)
- ✅ Test component generation working
- ✅ All 4 components validated successfully

### **Test Components Created**
- ✅ `TEST-DiskSpaceMonitor.ps1` (Monitors category)
- ✅ `TEST-FocusedDebloat.ps1` (Scripts category)
- ✅ `TEST-ScanSnapHome.ps1` (Applications category)
- ✅ `TEST-Setup-TestDevice.ps1` (Scripts category)

## 🚀 **Next Steps: API-Based Automated Deployment**

### **Step 1: Set Up Datto RMM API Access**

#### **1.1 Generate API Credentials**
1. **Log into Datto RMM Console**
2. **Navigate to**: `Settings` → `API` → `API Keys`
3. **Create New API Key**:
   - **Name**: `GitHub-CI-CD-Pipeline`
   - **Permissions**: Component management, Device management, Job execution
   - **Note the API Key and Secret** (you'll need these for GitHub secrets)

#### **1.2 Identify Your Test Device**
1. **Find your Windows VM** in Datto RMM
2. **Note the Device ID** (visible in URL or device details)
3. **Tag the device** for identification:
   - Add **Custom Field**: `DeviceRole` = `TEST-DEVICE`
   - Or use device name pattern for API filtering

#### **1.3 Set Up GitHub Secrets**
1. **Navigate to your GitHub repository**
2. **Go to**: `Settings` → `Secrets and variables` → `Actions`
3. **Add Repository Secrets**:
   ```
   DATTO_API_KEY = your-api-key
   DATTO_API_SECRET = your-api-secret
   DATTO_API_URL = https://concord-api.centrastage.net/api
   TEST_DEVICE_ID = your-windows-vm-device-id
   ```

### **Step 2: API-Based Component Deployment**

Instead of manual deployment, we'll use the Datto RMM API to:
- **Create components** programmatically
- **Deploy to test device** automatically
- **Execute and monitor** results
- **Collect logs** and results

### **Step 2: Verify Test Environment**

#### **2.1 Check Setup Results**
After running the setup script, verify on your Windows VM:

1. **Directory Structure Created**:
   ```
   C:\TestResults\
   ├── Logs\
   ├── Components\
   ├── Reports\
   └── Archive\
   ```

2. **Configuration Files**:
   - `C:\TestResults\test-config.json`
   - `C:\TestResults\TestHelpers.psm1`
   - `C:\TestResults\setup-summary.json`

3. **PowerShell Environment**:
   - Execution policy set to RemoteSigned
   - Test helper functions available

#### **2.2 Test the Environment**
Run this PowerShell command on your Windows VM to test:

```powershell
# Test the setup
Import-Module "C:\TestResults\TestHelpers.psm1"
$envInfo = Get-TestEnvironmentInfo
$envInfo | ConvertTo-Json
```

Expected output should show computer name, OS version, PowerShell version, etc.

### **Step 3: Deploy First Test Component**

#### **3.1 Create Test Monitor Component**
1. **Create New Component** in Datto RMM:
   - **Type**: Monitors Component
   - **Name**: `TEST-DiskSpaceMonitor`
   - **Description**: `Test version of disk space monitor`

2. **Copy Test Script Content**:
   - Copy content from `test-results/TEST-DiskSpaceMonitor.ps1`
   - Paste into Datto RMM component

3. **Configure Environment Variables**:
   ```
   TestMode = true
   LogPath = C:\TestResults
   WarningThreshold = 15
   CriticalThreshold = 5
   ```

4. **Deploy and Test**:
   - **Target**: Your Windows test VM only
   - **Schedule**: Run once for initial test
   - **Monitor**: Check both RMM results and test logs

#### **3.2 Verify Test Execution**
After the test component runs:

1. **Check RMM Results**:
   - Component should show success/failure in RMM console
   - Monitor should display disk space status

2. **Check Test Logs**:
   - Look for log files in `C:\TestResults\Logs\`
   - Check for `TEST-yyyyMMdd-HHmmss.log` files
   - Verify test timing and results

3. **Check Test Reports**:
   - Look for JSON reports in `C:\TestResults\Reports\`
   - Verify test metadata and execution details

### **Step 4: Validate Mac → Windows Workflow**

#### **4.1 Test Development Workflow**
1. **On Mac**: Make a small change to a component
2. **Run Validation**: `./scripts/mac-dev-helper.sh validate`
3. **Commit Changes**: `git add . && git commit -m "Test change"`
4. **Deploy to RMM**: Manually copy updated test component
5. **Verify Results**: Check execution on Windows VM

#### **4.2 Test Component Categories**
Deploy and test one component from each category:

- **✅ Monitors**: `TEST-DiskSpaceMonitor.ps1` (must complete <3 seconds)
- **🔄 Scripts**: `TEST-FocusedDebloat.ps1` (flexible timing)
- **🔄 Applications**: `TEST-ScanSnapHome.ps1` (up to 30 minutes)

### **Step 5: Document Test Device Configuration**

#### **5.1 Create Device Documentation**
Document your test device setup:

```json
{
  "TestDevice": {
    "ComputerName": "YOUR-VM-NAME",
    "DeviceId": "YOUR-DEVICE-ID",
    "Role": "TEST-DEVICE",
    "TestResultsPath": "C:\\TestResults",
    "SetupDate": "2025-07-14",
    "Components": [
      "Setup-TestDevice",
      "TEST-DiskSpaceMonitor"
    ]
  }
}
```

#### **5.2 Test Device Checklist**
- ✅ Windows VM tagged as TEST-DEVICE
- ✅ Setup-TestDevice script deployed and executed
- ✅ Test directory structure created
- ✅ PowerShell environment configured
- ✅ Test helper functions available
- ✅ First test component deployed and working
- ✅ Log collection functioning
- ✅ Mac development workflow tested

## 🎯 **Success Criteria for Phase 1**

### **Mac Development Environment**
- ✅ PowerShell Core installed and working
- ✅ Component validation script functional
- ✅ Test component generation working
- ✅ All existing components pass validation

### **Windows Test Device**
- ⏳ VM tagged and identified in RMM
- ⏳ Test environment setup completed
- ⏳ Directory structure and helpers installed
- ⏳ First test component deployed and working
- ⏳ Log collection and reporting functional

### **Integration Testing**
- ⏳ Mac → Windows development workflow tested
- ⏳ Component deployment process validated
- ⏳ Test result collection working
- ⏳ All component categories tested

## 📋 **Next Steps After Phase 1**

Once Phase 1 is complete, you'll be ready for:

### **Phase 2: GitHub Actions Integration**
- Set up GitHub secrets for Datto RMM API
- Create automated deployment workflows
- Implement test result collection automation

### **Phase 3: Full CI/CD Pipeline**
- Automated testing on every commit
- Automated deployment to test device
- Production deployment with approval gates

## 🆘 **Troubleshooting**

### **Common Issues**
1. **PowerShell Execution Policy**: Ensure RemoteSigned or Bypass
2. **Directory Permissions**: Ensure RMM agent can write to C:\TestResults
3. **Component Timeout**: Monitors must complete in <3 seconds
4. **Log Collection**: Verify transcript logging is working

### **Getting Help**
- Check setup logs in `C:\TestResults\Logs\`
- Review component execution logs in RMM console
- Validate test helper functions are loaded correctly
- Ensure test device is properly tagged and accessible

Ready to proceed with Windows VM setup? Let me know when you've completed the Datto RMM component deployment!
