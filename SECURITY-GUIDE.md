# 🔒 Security Guide: Protecting API Credentials

## ⚠️ **CRITICAL: Never Commit API Credentials to Git!**

Your repository is **public**, so API credentials must **NEVER** be committed to Git. Here's how to handle them securely.

## 🚫 **What NOT to Do (Dangerous)**

```powershell
# ❌ NEVER DO THIS - Credentials in code
$apiKey = "datto-api-key-12345"  # EXPOSED TO EVERYONE!
$apiSecret = "secret-abc123"     # VISIBLE IN PUBLIC REPO!
```

```json
// ❌ NEVER DO THIS - Credentials in committed files
{
  "apiKey": "real-api-key-here",    // EXPOSED TO EVERYONE!
  "apiSecret": "real-secret-here"   // VISIBLE IN PUBLIC REPO!
}
```

## ✅ **Secure Methods (Use These)**

### **Method 1: Local Configuration File (Recommended for Development)**

#### **Step 1: Create Your Local Config**
```bash
# Copy the example file
cp config/api-config.example.json config/api-config.json

# Edit with your real credentials (this file is git-ignored)
code config/api-config.json
```

#### **Step 2: Add Your Real Credentials**
```json
{
  "datto": {
    "apiKey": "your-real-api-key-here",
    "apiSecret": "your-real-api-secret-here",
    "apiUrl": "https://concord-api.centrastage.net/api",
    "testDeviceId": "your-real-device-id-here"
  }
}
```

#### **Step 3: Use Secure Script**
```bash
# This reads from your local config file (never committed)
pwsh -File scripts/secure-api-deploy.ps1
```

### **Method 2: Environment Variables (Recommended for Mac)**

#### **Step 1: Add to Your Shell Profile**
```bash
# Edit your shell profile
code ~/.zshrc  # or ~/.bash_profile

# Add these lines (with your real credentials)
export DATTO_API_KEY="your-real-api-key-here"
export DATTO_API_SECRET="your-real-api-secret-here"
export DATTO_TEST_DEVICE_ID="your-real-device-id-here"
```

#### **Step 2: Reload Your Shell**
```bash
source ~/.zshrc
```

#### **Step 3: Use Environment Variables**
```bash
# This reads from environment variables
pwsh -File scripts/secure-api-deploy.ps1 -UseEnvironment
```

### **Method 3: GitHub Secrets (For CI/CD)**

#### **Step 1: Add Repository Secrets**
1. Go to your GitHub repository
2. Navigate to: `Settings` → `Secrets and variables` → `Actions`
3. Click `New repository secret`
4. Add these secrets:
   ```
   Name: DATTO_API_KEY
   Value: your-real-api-key-here
   
   Name: DATTO_API_SECRET
   Value: your-real-api-secret-here
   
   Name: DATTO_TEST_DEVICE_ID
   Value: your-real-device-id-here
   ```

#### **Step 2: Use in GitHub Actions**
```yaml
# In .github/workflows/deploy.yml
env:
  DATTO_API_KEY: ${{ secrets.DATTO_API_KEY }}
  DATTO_API_SECRET: ${{ secrets.DATTO_API_SECRET }}
  DATTO_TEST_DEVICE_ID: ${{ secrets.DATTO_TEST_DEVICE_ID }}
```

## 🛡️ **Security Features Built-In**

### **Git Ignore Protection**
The `.gitignore` file prevents accidental commits:
```gitignore
# API configuration files (contain sensitive credentials)
config/api-config.json
config/api-config.local.json
config/*.secret.json
config/*.key

# Environment files with credentials
.env
.env.api
.env.datto
.env.secrets
```

### **Credential Masking**
The secure script masks credentials in output:
```
✅ Configuration validated:
  API Key: datt...5678
  API Secret: secr...xyz9
  API URL: https://concord-api.centrastage.net/api
  Test Device: 12345
```

### **Validation Checks**
The script validates that you've replaced example values:
```powershell
if ($config.datto.apiKey -eq "YOUR-DATTO-API-KEY-HERE") {
    Write-Error "❌ API Key not configured properly"
}
```

## 📋 **Quick Setup Checklist**

### **For Local Development:**
- [ ] Copy `config/api-config.example.json` to `config/api-config.json`
- [ ] Edit `config/api-config.json` with your real credentials
- [ ] Verify the file is git-ignored (should not appear in `git status`)
- [ ] Test with: `pwsh -File scripts/secure-api-deploy.ps1`

### **For Environment Variables:**
- [ ] Add credentials to `~/.zshrc` or `~/.bash_profile`
- [ ] Reload shell: `source ~/.zshrc`
- [ ] Test with: `pwsh -File scripts/secure-api-deploy.ps1 -UseEnvironment`

### **For GitHub Actions:**
- [ ] Add secrets to GitHub repository settings
- [ ] Test in a GitHub Actions workflow
- [ ] Verify secrets are not visible in logs

## 🔍 **How to Verify Security**

### **Check Git Status**
```bash
git status
# Should NOT show config/api-config.json
```

### **Check Git History**
```bash
git log --oneline -p | grep -i "api"
# Should NOT show any real API credentials
```

### **Test Script Output**
```bash
pwsh -File scripts/secure-api-deploy.ps1
# Should show masked credentials: "datt...5678"
```

## 🆘 **If You Accidentally Commit Credentials**

### **Immediate Actions:**
1. **Revoke the API key** in Datto RMM console immediately
2. **Generate new API credentials**
3. **Remove from Git history** (complex, ask for help)
4. **Update your local configuration** with new credentials

### **Prevention:**
- Always use the secure scripts provided
- Double-check `git status` before committing
- Use `git diff` to review changes before committing

## ✅ **Recommended Workflow**

```bash
# 1. Set up credentials once (local config or environment)
cp config/api-config.example.json config/api-config.json
# Edit config/api-config.json with real credentials

# 2. Use secure deployment
pwsh -File scripts/secure-api-deploy.ps1

# 3. Develop and commit code (never credentials)
git add scripts/
git commit -m "Add new deployment feature"
git push origin main

# 4. Credentials stay local, code goes to GitHub
```

## 🎯 **Summary**

- ✅ **Use local config files** (git-ignored)
- ✅ **Use environment variables** (not committed)
- ✅ **Use GitHub secrets** (for CI/CD)
- ✅ **Use provided secure scripts**
- ❌ **Never commit credentials** to Git
- ❌ **Never put credentials** in code files
- ❌ **Never share credentials** in public

Your API credentials are now completely secure and will never be exposed in your public repository! 🔒
