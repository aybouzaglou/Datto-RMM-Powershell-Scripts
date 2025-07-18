# 📥 Datto RMM Download Best Practices

## 🎯 Overview

Best practices for downloading files in Datto RMM scripts with security, reliability, and validation.

## ✅ Recommended Approach

### **1. Use Invoke-WebRequest**
```powershell
# Modern approach with progress bar and auto-resume
$uri = 'https://download.vendor.com/app.msi'
$outFile = "$env:TEMP\app.msi"

Invoke-WebRequest -Uri $uri -OutFile $outFile -UseBasicParsing
```

### **2. Enforce TLS 1.2**
```powershell
# Set once per session (required for older systems)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

### **3. Validate File Integrity**
```powershell
# Verify SHA-256 hash if available
$expectedHash = '6BA9EF6EB60103B1912B9E79F3EEF4C6F662C4F7'
$actualHash = (Get-FileHash $outFile -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) {
    Write-Error 'Hash mismatch – aborting installation'
    exit 1
}
```

### **4. Verify Digital Signature**
```powershell
# Check Authenticode signature
$signature = Get-AuthenticodeSignature $outFile
if ($signature.Status -ne 'Valid') {
    Write-Error "Signature check failed ($($signature.Status))"
    exit 2
}
```

## 🔧 Production Template

```powershell
function Invoke-SecureDownload {
    param(
        [string]$Url,
        [string]$OutputPath,
        [string]$ExpectedHash = "",
        [bool]$VerifySignature = $true
    )
    
    try {
        # Set TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Download with error handling
        Write-RMMLog "Downloading from: $Url" -Level Status
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -ErrorAction Stop
        
        # Verify file exists
        if (-not (Test-Path $OutputPath)) {
            throw "Download failed - file not found"
        }
        
        # Hash validation (if provided)
        if ($ExpectedHash) {
            $actualHash = (Get-FileHash $OutputPath -Algorithm SHA256).Hash
            if ($actualHash -ne $ExpectedHash) {
                throw "SHA-256 hash mismatch"
            }
            Write-RMMLog "Hash verification passed" -Level Success
        }
        
        # Signature validation (if enabled)
        if ($VerifySignature) {
            $sig = Get-AuthenticodeSignature $OutputPath
            if ($sig.Status -ne 'Valid') {
                throw "Digital signature invalid: $($sig.Status)"
            }
            Write-RMMLog "Signature verification passed" -Level Success
        }
        
        $fileInfo = Get-Item $OutputPath
        Write-RMMLog "Download completed: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -Level Success
        return $true
        
    } catch {
        Write-RMMLog "Download failed: $($_.Exception.Message)" -Level Error
        
        # Cleanup partial download
        if (Test-Path $OutputPath) {
            Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
}
```

## 📋 Usage Guidelines

### **When to Download vs File Attachment**
- **File Attachment**: Static installers, known versions, offline scenarios
- **Download**: Latest versions, dynamic content, API-based installers

### **Large Files (>1GB)**
```powershell
# Use BITS for fault-tolerant downloads
Start-BitsTransfer -Source $uri -Destination $outFile -Priority foreground
```

### **Environment Variables**
```powershell
# Use secure variables for URLs and hashes
$downloadUrl = Get-RMMVariable -Name "DownloadUrl" -Required
$expectedHash = Get-RMMVariable -Name "ExpectedHash" -Default ""
```

## ⚠️ Security Considerations

- **Always use HTTPS** for downloads
- **Validate file integrity** when hashes are available
- **Check digital signatures** for executable files
- **Use secure variables** for sensitive URLs
- **Clean up failed downloads** to prevent partial files

## 🔍 Troubleshooting

### **TLS Errors**
```powershell
# Force TLS 1.2 before any web requests
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

### **Proxy Issues**
```powershell
# Use system proxy settings
Invoke-WebRequest -Uri $uri -OutFile $outFile -UseBasicParsing -UseDefaultCredentials
```

### **Timeout Issues**
```powershell
# Increase timeout for large files
Invoke-WebRequest -Uri $uri -OutFile $outFile -TimeoutSec 1800  # 30 minutes
```
