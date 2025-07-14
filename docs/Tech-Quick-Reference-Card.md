# 🎯 GitHub Launcher - Tech Quick Reference

## Two Ways to Run Scripts

### **🚀 Method 1: One-Click (Frequent Scripts)**
**Use dedicated components for scripts you run often**

| Component Name | Purpose | When to Use |
|----------------|---------|-------------|
| `Focused-Debloat` | Remove bloatware | New device setup |
| `ScanSnap-Home-Setup` | Install ScanSnap | Software deployment |
| `Disk-Space-Monitor` | Check disk space | Daily monitoring |

**Steps:**
1. Select device → Run Component
2. Choose component from list above
3. Click Run ✅

---

### **🔧 Method 2: Variable-Based (Occasional Scripts)**
**Use universal launcher for scripts you run rarely**

**Component:** `GitHub-Universal-Launcher`

**Steps:**
1. Select device → Run Component → `GitHub-Universal-Launcher`
2. Override Environment Variables → Change `ScriptPath` to:

#### **Copy/Paste Script Paths:**

**System Maintenance:**
```
components/Scripts/Setup-TestDevice.ps1
components/Scripts/Validate-TestEnvironment.ps1
components/Scripts/FocusedDebloat.ps1
```

**Software Deployment:**
```
components/Applications/ScanSnapHome.ps1
```

**Monitoring:**
```
components/Monitors/DiskSpaceMonitor.ps1
```

3. Click Run ✅

---

## 🎯 **When to Use Which Method**

| How Often? | Method | Why? |
|------------|--------|------|
| **Daily/Weekly** | One-Click | Faster, no mistakes |
| **Monthly** | One-Click | Still worth it |
| **Rarely** | Variable-Based | No clutter |
| **Testing** | Variable-Based | Flexible |

---

## ✅ **What Happens When You Run**

1. **Downloads latest script** from GitHub
2. **Caches functions** locally for speed
3. **Runs your target script** with full error handling
4. **Shows results** in real-time logs

**Benefits:**
- ✅ Always latest version
- ✅ Automatic updates
- ✅ No manual maintenance
- ✅ Works offline after first download

---

## 🆘 **Troubleshooting**

**If script fails:**
1. Check device has internet connection
2. Verify ScriptPath is typed correctly
3. Check logs for specific error messages
4. Try running again (may be temporary network issue)

**Common ScriptPath mistakes:**
- ❌ `Scripts/Setup-TestDevice.ps1` (missing components/)
- ❌ `components\Scripts\Setup-TestDevice.ps1` (wrong slashes)
- ✅ `components/Scripts/Setup-TestDevice.ps1` (correct)

---

## 📞 **Need Help?**

1. **Check this card first** - Most common tasks covered
2. **Look at execution logs** - Usually shows the problem
3. **Ask senior tech** - They know the common issues
4. **Document new scripts** - Add to the path list when you find new ones

---

*Print this card and keep it handy! 📋*
