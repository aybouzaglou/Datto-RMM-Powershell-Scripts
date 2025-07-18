# 🎯 Quick Reference & Decision Matrix - Datto RMM Scripts

## 📋 Overview

This guide provides a comprehensive decision matrix and quick reference for choosing the right approach for different Datto RMM automation tasks. Use this guide to quickly determine component types, deployment strategies, and operation compatibility.

## 🎯 Component Type Decision Matrix

### **📊 Monitors (Performance Critical)**
**Purpose**: Checking system status, monitoring services, detecting issues

- **Execution Pattern**: Frequent/continuous (every few minutes)
- **Component Category**: Monitors (Custom Monitor)
- **Performance**: CRITICAL - Must complete in under 3 seconds
- **Deployment**: **Direct deployment only** (no launchers)
- **Functions**: Embedded only (copy/paste from shared-functions)
- **Focus**: Speed and proper output format

**✅ Use Monitors For:**
- System health checks (disk space, services, processes)
- Performance monitoring (CPU, memory, network)
- Security monitoring (failed logins, security events)
- Configuration drift detection
- Real-time alerting requirements

### **📦 Applications (Installation & Configuration)**
**Purpose**: Installing software, deploying applications, initial system configuration

- **Execution Pattern**: One-time or occasional deployment
- **Component Category**: Applications
- **Performance**: More flexible - can run longer processes (up to 30 minutes)
- **Deployment**: **Launcher-based** (GitHub integration)
- **Functions**: Copy/paste patterns from shared-functions
- **Focus**: Reliability and error handling

**✅ Use Applications For:**
- Software installation and deployment
- System configuration and setup
- Service installation and configuration
- Initial system provisioning
- Complex deployment scenarios

### **🔧 Scripts (General Automation)**
**Purpose**: General automation, maintenance, and administrative tasks

- **Execution Pattern**: As-needed or scheduled tasks
- **Component Category**: Scripts
- **Performance**: Balanced approach - timeouts recommended
- **Deployment**: **Launcher-based** (GitHub integration)
- **Functions**: Copy/paste patterns from shared-functions
- **Focus**: Flexibility and maintainability

**✅ Use Scripts For:**
- System maintenance and cleanup
- Administrative automation
- Reporting and data collection
- Configuration management
- General purpose automation

## 🚀 Deployment Strategy Decision Matrix

| Component Type | Deployment Method | Performance | Flexibility | Use Case |
|----------------|------------------|-------------|-------------|----------|
| **Monitor** | **Direct** | **Fastest** (25-50ms) | Limited | High-frequency monitoring |
| **Application** | **Launcher** | Moderate | High | Software deployment |
| **Script** | **Launcher** | Moderate | High | General automation |

### **Direct Deployment (Monitors Only)**
- **Performance**: 98.2% faster than launcher-based
- **Reliability**: 100% (no network dependencies)
- **Maintenance**: Manual updates required
- **Best For**: Critical, high-frequency monitoring

### **Launcher-Based Deployment (Applications & Scripts)**
- **Performance**: Moderate (1-2 second overhead)
- **Reliability**: Network dependent
- **Maintenance**: Automatic updates from GitHub
- **Best For**: Complex scripts requiring frequent updates

## ⚡ Operation Compatibility Matrix

| Operation | Monitor | Application | Script | Notes |
|-----------|---------|-------------|--------|-------|
| `Get-WmiObject Win32_Product` | ❌ NEVER | ❌ NEVER | ❌ NEVER | Triggers MSI repair |
| `Get-CimInstance Win32_Product` | ❌ NEVER | ❌ NEVER | ❌ NEVER | Triggers MSI repair |
| `Get-CimInstance` (other classes) | ⚠️ Add timeout | ✅ OK | ✅ OK | Safe for non-Product classes |
| `Start-Process -Wait` (known) | ❌ Too slow | ✅ OK | ✅ OK | Use for known processes |
| `Start-Process -Wait` (unknown) | ❌ Too slow | ⚠️ Add timeout | ⚠️ Add timeout | Always add timeouts |
| Registry detection | ✅ PREFERRED | ✅ PREFERRED | ✅ PREFERRED | Fastest method |
| Network operations | ⚠️ Add timeout | ✅ OK | ✅ OK | Handle failures gracefully |
| File downloads | ❌ Avoid | ✅ OK | ✅ OK | Use timeouts and verification |
| Service management | ✅ OK | ✅ OK | ✅ OK | Fast operations |
| Process monitoring | ✅ OK | ✅ OK | ✅ OK | Use efficient queries |

## 🔧 CIM/WMI Usage Guidelines

### **✅ ALLOWED Classes:**
```powershell
Get-CimInstance -ClassName Win32_ComputerSystem    # System info
Get-CimInstance -ClassName Win32_OperatingSystem   # OS details
Get-CimInstance -ClassName Win32_Service           # Service info
Get-CimInstance -ClassName Win32_LogicalDisk       # Disk info
Get-CimInstance -ClassName Win32_Process           # Process info
Get-CimInstance -ClassName Win32_NetworkAdapter    # Network info
```

### **❌ BANNED Classes:**
```powershell
Get-CimInstance -ClassName Win32_Product           # Triggers MSI repair
Get-WmiObject -Class Win32_Product                 # Triggers MSI repair
```

> **⚠️ Why Win32_Product is banned:** Both `Get-WmiObject` and `Get-CimInstance` accessing the `Win32_Product` WMI class can trigger MSI repair operations, causing system instability, performance issues, and script failures. Always use registry-based detection for software detection instead.

## 📊 Performance Guidelines by Component Type

### **Monitors (< 3 seconds)**
- **Target**: <200ms for high-frequency monitors
- **Critical**: Must complete within Datto's 3-second timeout
- **Optimization**: Embed all functions, minimize system calls
- **Testing**: Use `Measure-Command` to verify performance

### **Applications (< 30 minutes)**
- **Target**: Complete within reasonable time for user experience
- **Flexibility**: Can use longer-running operations
- **Reliability**: Focus on error handling and rollback
- **Testing**: Test with various installer types and scenarios

### **Scripts (Flexible)**
- **Target**: Balance performance with functionality
- **Maintenance**: Design for easy updates and modifications
- **Flexibility**: Can adapt to different requirements
- **Testing**: Test with various input scenarios

## 🎯 Quick Selection Guide

### **Choose Monitors When:**
- ✅ Need real-time system health monitoring
- ✅ Checking service status or process existence
- ✅ Monitoring performance metrics (CPU, memory, disk)
- ✅ Detecting configuration drift
- ✅ Require fast execution (< 3 seconds)
- ✅ Need specific output format (OK:/WARNING:/CRITICAL:)

### **Choose Applications When:**
- ✅ Deploying new software or applications
- ✅ Configuring systems for the first time
- ✅ Setting up services or system components
- ✅ Need longer execution times (up to 30 minutes)
- ✅ Performing complex installation procedures

### **Choose Scripts When:**
- ✅ General system maintenance and cleanup
- ✅ Administrative automation tasks
- ✅ Data collection and reporting
- ✅ Configuration management
- ✅ Need balanced performance with flexibility

## 🚨 Critical Rules Summary

### **Universal Rules (All Components)**
- ❌ **NEVER** use `Win32_Product` with any cmdlet
- ✅ **ALWAYS** handle LocalSystem context limitations
- ✅ **ALWAYS** parse environment variables safely
- ✅ **ALWAYS** implement proper error handling
- ✅ **ALWAYS** use appropriate exit codes

### **Monitor-Specific Rules**
- ❌ **NEVER** use launchers (direct deployment only)
- ❌ **NEVER** use external dependencies
- ✅ **ALWAYS** embed required functions
- ✅ **ALWAYS** include result markers (`<-Start Result->` and `<-End Result->`)
- ✅ **ALWAYS** optimize for performance (<200ms target)

### **Application/Script Rules**
- ✅ **ALWAYS** use launcher-based deployment
- ✅ **ALWAYS** copy functions from shared-functions (no runtime dependencies)
- ✅ **ALWAYS** implement timeouts for unknown operations
- ✅ **ALWAYS** handle partial failures gracefully

## 📋 Development Workflow

### **1. Determine Component Type**
Use the decision matrix above to choose Monitor, Application, or Script

### **2. Select Deployment Strategy**
- **Monitors**: Direct deployment (paste script directly)
- **Applications/Scripts**: Launcher-based deployment

### **3. Choose Function Patterns**
- Copy relevant functions from `shared-functions/` directory
- Embed functions directly in monitors
- Use copy/paste approach (no runtime dependencies)

### **4. Implement Universal Requirements**
- Follow LocalSystem context guidelines
- Implement proper environment variable parsing
- Use appropriate exit codes
- Add event logging with error handling

### **5. Test Thoroughly**
- Test in LocalSystem context
- Verify performance requirements
- Test error scenarios
- Validate with various inputs

---

**Remember**: This decision matrix helps ensure you choose the right approach for each automation task. When in doubt, refer to the specific component guides for detailed implementation guidance.
