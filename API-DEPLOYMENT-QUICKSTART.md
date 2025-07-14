# API Deployment Quickstart Guide

## 🚀 **Get Started with Datto RMM API Deployment in 15 Minutes**

You're absolutely right - we should use the Datto RMM API for automated deployment! This guide gets you up and running with API-based deployment quickly.

## **Step 1: Get Your Datto RMM API Credentials**

### **1.1 Generate API Key**
1. **Log into Datto RMM Console**
2. **Navigate to**: `Settings` → `API` → `API Keys`
3. **Create New API Key**:
   - **Name**: `GitHub-CI-CD-Pipeline`
   - **Permissions**: Select all (or at minimum: Components, Devices, Jobs)
   - **Copy the API Key and Secret** - you'll need these!

### **1.2 Find Your Test Device ID**
1. **Go to Devices** in Datto RMM
2. **Find your Windows VM** for testing
3. **Click on the device** - note the **Device ID** in the URL
   - Example: `https://rmm.datto.com/devices/12345` → Device ID is `12345`

## **Step 2: Test API Deployment**

### **2.1 Run the Quick Deployment Script**
From your Mac, in the repository directory:

```bash
# Make sure you're in the repository root
cd /path/to/Datto-RMM-Powershell-Scripts

# Run the quick API deployment
pwsh -File scripts/quick-api-deploy.ps1 -ApiKey "YOUR-API-KEY" -ApiSecret "YOUR-API-SECRET" -TestDeviceId "YOUR-DEVICE-ID"
```

### **2.2 Expected Output**
You should see:
```
=== Quick Datto RMM API Deployment ===
✓ Authentication configured
✓ API connection successful
✓ Test device found: YOUR-VM-NAME
✓ Component script loaded
✓ Component ready: Setup-TestDevice-API
✓ Deployment job started: 67890
🎉 API-based deployment is working!
```

### **2.3 Verify in Datto RMM Console**
1. **Go to Jobs** section in RMM
2. **Look for**: "API Test Device Setup"
3. **Check execution status** and logs
4. **Verify success** (exit code 0)

## **Step 3: Verify Test Environment**

### **3.1 Check Test Device Setup**
After the job completes successfully:

1. **Remote into your Windows VM** (or check via RMM)
2. **Verify directory structure**:
   ```
   C:\TestResults\
   ├── Logs\
   ├── Components\
   ├── Reports\
   ├── Archive\
   ├── test-config.json
   ├── TestHelpers.psm1
   └── setup-summary.json
   ```

### **3.2 Test the Environment**
Run this PowerShell command on your Windows VM:
```powershell
# Test the setup
Import-Module "C:\TestResults\TestHelpers.psm1"
Get-TestEnvironmentInfo | ConvertTo-Json
```

## **Step 4: Deploy Your First Test Component**

### **4.1 Deploy Test Monitor via API**
```bash
# Deploy the disk space monitor test component
pwsh -File scripts/deploy-component-api.ps1 -ApiKey "YOUR-API-KEY" -ApiSecret "YOUR-API-SECRET" -TestDeviceId "YOUR-DEVICE-ID" -ComponentPath "test-results/TEST-DiskSpaceMonitor.ps1" -ComponentName "TEST-DiskSpaceMonitor" -ComponentType "Monitors"
```

### **4.2 Verify Test Component**
1. **Check RMM console** for the new Monitor component
2. **Verify execution** (should complete in <3 seconds)
3. **Check test logs** in `C:\TestResults\Logs\`
4. **Review monitor status** (OK/Warning/Critical)

## **Step 5: Set Up GitHub Actions (Optional)**

### **5.1 Add GitHub Secrets**
In your GitHub repository:
1. **Go to**: `Settings` → `Secrets and variables` → `Actions`
2. **Add these secrets**:
   ```
   DATTO_API_KEY = your-api-key
   DATTO_API_SECRET = your-api-secret
   DATTO_API_URL = https://concord-api.centrastage.net/api
   TEST_DEVICE_ID = your-device-id
   ```

### **5.2 Create Basic Workflow**
Create `.github/workflows/test-deploy.yml`:
```yaml
name: Test Device Deployment

on:
  push:
    branches: [ main ]
    paths: [ 'components/**' ]

jobs:
  deploy-to-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install PowerShell
        run: |
          sudo apt-get update
          sudo apt-get install -y powershell
          
      - name: Deploy to Test Device
        run: |
          pwsh -File scripts/quick-api-deploy.ps1 -ApiKey "${{ secrets.DATTO_API_KEY }}" -ApiSecret "${{ secrets.DATTO_API_SECRET }}" -TestDeviceId "${{ secrets.TEST_DEVICE_ID }}"
```

## **🎯 Benefits of API Approach**

### **✅ Immediate Benefits**
- **Automated deployment** - no manual component creation
- **Version control** - all changes tracked in Git
- **Consistent deployment** - same process every time
- **Remote deployment** - deploy from your Mac to Windows VM
- **Job monitoring** - automated status checking

### **🚀 Advanced Capabilities**
- **GitHub Actions integration** - deploy on every commit
- **Multi-environment support** - test → staging → production
- **Rollback capabilities** - quick revert to previous versions
- **Automated testing** - deploy, test, validate automatically

## **🔧 Troubleshooting**

### **Common Issues**

#### **API Authentication Fails**
- Verify API key and secret are correct
- Check API permissions include Components, Devices, Jobs
- Ensure API key is active and not expired

#### **Device Not Found**
- Verify device ID is correct (check RMM console URL)
- Ensure device is online and accessible
- Check device has Datto RMM agent installed

#### **Component Creation Fails**
- Verify script content is valid PowerShell
- Check component name doesn't conflict with existing
- Ensure API permissions include component management

#### **Job Execution Fails**
- Check device is online during execution
- Verify PowerShell execution policy on target device
- Review job logs in RMM console for specific errors

### **Getting Help**
- Check the `scripts/quick-api-deploy.ps1` output for specific error messages
- Review job execution logs in Datto RMM console
- Verify API credentials and permissions
- Test with a simple component first

## **📋 Next Steps**

### **Phase 1 Complete ✅**
- [x] API credentials configured
- [x] Test device setup deployed via API
- [x] Test environment verified
- [x] First test component deployed

### **Phase 2: Full Automation**
- [ ] GitHub Actions workflow configured
- [ ] Automated testing on every commit
- [ ] Multiple component deployment
- [ ] Result collection and reporting

### **Phase 3: Enterprise Features**
- [ ] Multi-environment deployment
- [ ] Automated rollback capabilities
- [ ] Performance monitoring
- [ ] Compliance validation

## **🎉 Success!**

You now have:
- ✅ **API-based deployment** working from your Mac
- ✅ **Test device** properly configured
- ✅ **Automated component creation** and deployment
- ✅ **Foundation for CI/CD pipeline**

This is a huge step forward from manual deployment! You can now deploy and test components automatically using the Datto RMM API.

Ready to move to Phase 2 with GitHub Actions automation?
