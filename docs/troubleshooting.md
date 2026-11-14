# ICPC Lab Troubleshooting Guide

This guide addresses common technical issues encountered when setting up 60 Windows machines for competitive programming.

---

## 1. Issue: "Compiler not recognized" in Contestant Account

### Symptom:
`gcc`, `g++`, `javac`, or `python` runs fine when logged in as Administrator, but fails with `"command not recognized"` when logged in as `contestant`.

### Root Cause:
The environment variable `PATH` was added under **User Variables for Administrator**, not **System Variables**.

### Fix:
Open PowerShell as Administrator and run the following command to append the toolchain to the machine-wide `PATH`:

```powershell
# Example for MinGW and Python:
$oldPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$newPath = "$oldPath;C:\MinGW\bin;C:\Python312;C:\Python312\Scripts"
[Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
```
*Note: Restart the PC or sign out and sign back in for the changes to take effect.*

---

## 2. Issue: Windows Defender Quarantining Student Executables

### Symptom:
A contestant compiles their C/C++ solution (`g++ solution.cpp -o solution.exe`), but running `solution.exe` gives an "Access Denied" error or Windows Defender notifies that a threat was blocked.

### Root Cause:
Windows Defender heuristics frequently flag freshly compiled small binaries with no digital signature as potential malware.

### Fix:
Add an exclusion path in Windows Defender for the contest workspace folder:

```powershell
Add-MpPreference -ExclusionPath "C:\Users\contestant\Desktop\ICPC_Workspace"
```
*(Run this as Administrator).*

---

## 3. Issue: Cannot Access Contest Server (DOMjudge / PC^2)

### Symptom:
Browser shows `ERR_CONNECTION_REFUSED` or `ERR_CONNECTION_TIMED_OUT` when loading `http://192.168.1.100`.

### Diagnostic Steps:
1. **Verify Local IP Address:**
   Run `ipconfig` in Command Prompt. Ensure the workstation's IP is in the same subnet (e.g. `192.168.1.xxx`).
2. **Ping the Server:**
   Run `ping 192.168.1.100`.
   - If ping responds: Web server service (e.g. Nginx/Apache on the judge server) is stopped or bound only to `127.0.0.1`. Check judge server configs.
   - If ping times out: Physical cable issue or workstation firewall rule was configured with the wrong subnet.
3. **Check Firewall Rules:**
   Run `Get-NetFirewallRule -DisplayName "ICPC-*"` in PowerShell to confirm the `ICPC-Allow-Subnet` rule is present and enabled.

---

## 4. Issue: VS Code Extensions Missing for Contestant

### Symptom:
C/C++ or Python extensions installed under the Administrator account do not show up when `contestant` opens VS Code.

### Fix:
By default, VS Code installs extensions to `%USERPROFILE%\.vscode\extensions`. To make extensions available to all users on the PC:

1. Copy the extensions folder to a shared directory:
   ```cmd
   robocopy "%USERPROFILE%\.vscode\extensions" "C:\ProgramData\VSCodeExtensions" /E
   ```
2. Modify the contestant's VS Code shortcut to include the shared extensions directory:
   ```cmd
   code --extensions-dir "C:\ProgramData\VSCodeExtensions" "C:\Users\contestant\Desktop\ICPC_Workspace"
   ```

---

## 5. Issue: Contestant Accidental Internet Re-connection (WiFi)

### Symptom:
Lab machines with built-in WiFi cards automatically connect to university campus Wi-Fi, bypassing the physical Ethernet air-gap.

### Fix:
Disable the wireless network adapter on all contest machines:

```powershell
# Disable all wireless network interfaces
Get-NetAdapter | Where-Object { $_.InterfaceDescription -match "Wireless|Wi-Fi|802.11" } | Disable-NetAdapter -Confirm:$false
```
To re-enable after contest:
```powershell
Get-NetAdapter | Where-Object { $_.InterfaceDescription -match "Wireless|Wi-Fi|802.11" } | Enable-NetAdapter -Confirm:$false
```

