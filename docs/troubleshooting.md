# ICPC Lab Troubleshooting Guide

This guide addresses common technical issues encountered when setting up 60 Windows machines for competitive programming.

---

## 1. Issue: "Python was not found; run without arguments to install from the Microsoft Store"

### Symptom:
When running `python`, Windows displays:
```text
Python was not found; run without arguments to install from the Microsoft Store, or disable this shortcut from Settings > Apps > Advanced app settings > App execution aliases.
```

### Root Cause:
Windows 10/11 includes a dummy "App Execution Alias" stub located at `%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe`. When real Python is not installed, Windows intercepts the `python` command and tries to open the Microsoft Store.

### Fix:
1. `00_install_prerequisites.ps1` automatically detects real Python vs the Microsoft Store stub and installs Python 3.12 machine-wide via `winget`.
2. To install manually as Administrator:
   ```cmd
   winget install --id Python.Python.3.12 --scope machine --override "/quiet InstallAllUsers=1 PrependPath=1"
   ```
3. Ensure `C:\Program Files\Python312` appears in the **System PATH** ahead of `%USERPROFILE%\AppData\Local\Microsoft\WindowsApps`.

---

## 2. Issue: Cannot Type Input into Code Runner Terminal

### Symptom:
When running a C++ or Python program using the Code Runner Play ▶ button, the program hangs waiting for input, but the terminal does not allow typing.

### Root Cause:
By default, Code Runner executes code in the VS Code **Output** tab, which is read-only and does not accept stdin (`cin`, `scanf`, `input()`).

### Fix:
Ensure `configs/vscode/settings.json` has:
```json
"code-runner.runInTerminal": true
```
This forces Code Runner to use the interactive integrated terminal, allowing contestants to type keyboard input or paste test cases.

---

## 3. Issue: External Ping (8.8.8.8) Succeeds Despite Firewall Lockdown

### Symptom:
`04_verify_env.bat` warns that external internet is accessible because `ping 8.8.8.8` received a reply.

### Root Cause:
Windows 11 has a pre-existing built-in rule: `File and Printer Sharing (Echo Request - ICMPv4-Out)` set to **Allow**. In Windows Firewall, an explicit `Allow` rule takes precedence over `DefaultOutboundAction Block`.

### Fix:
`02_lockdown_network.ps1` now adds explicit `ICPC-Block-*` rules (TCP, UDP, ICMPv4, ICMPv6). Block rules take precedence over every allow rule, so built-in rules like this one can no longer leak. The verification also tests real TCP/HTTPS/DNS/proxy connections (`net_probe.ps1`), not just ping.

---

## 4. Issue: Windows Defender Quarantining Student Executables

### Symptom:
A contestant compiles their C/C++ solution (`g++ solution.cpp -o solution.exe`), but running `solution.exe` gives an "Access Denied" error or Windows Defender notifies that a threat was blocked.

### Root Cause:
Windows Defender heuristics frequently flag freshly compiled small binaries with no digital signature as potential malware.

### Fix:
Add an exclusion path in Windows Defender for the contest workspace folder:
```powershell
Add-MpPreference -ExclusionPath "C:\Users\contestant\Desktop\ICPC_Workspace"
```
*(Run this in an elevated Administrator PowerShell prompt).*

---

## 5. Issue: "Compiler not recognized" in Contestant Account

### Symptom:
`gcc`, `g++`, `javac`, or `python` works in Administrator, but fails with `"command not recognized"` in the contestant account.

### Root Cause:
The `PATH` environment variable was added under **User Variables for Administrator**, not **System Variables**.

### Fix:
Append the toolchains to the machine-wide `PATH`:
```powershell
$oldPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$newPath = "$oldPath;C:\MinGW\bin;C:\Program Files\Python312;C:\Program Files\Java\jdk-21\bin"
[Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
```
Sign out and sign back in for the changes to apply to all user profiles.

---

## 6. Issue: Contestant Accidental Internet Re-connection (WiFi)

### Symptom:
Workstations with built-in WiFi cards automatically connect to university campus Wi-Fi, bypassing the physical Ethernet air-gap.

### Fix:
Disable the wireless network adapter on all contest machines:
```powershell
Get-NetAdapter | Where-Object { $_.InterfaceDescription -match "Wireless|Wi-Fi|802.11" } | Disable-NetAdapter -Confirm:$false
```
To re-enable after the contest:
```powershell
Get-NetAdapter | Where-Object { $_.InterfaceDescription -match "Wireless|Wi-Fi|802.11" } | Enable-NetAdapter -Confirm:$false
```

---

## 7. Issue: Compilers / Python work as Administrator but not in the contestant account

### Root Cause:
The tool was installed **for the Administrator only** (winget's default per-user WinLibs install, or a "Just for me" Python). It lives under `C:\Users\<admin>\...`, which other accounts cannot read.

### Fix:
`00_install_prerequisites.ps1` ignores such copies, installs machine-wide (`--scope machine`), copies a per-user WinLibs to `C:\mingw64` if needed, and removes `C:\Users\...` entries from the System PATH. Step 7 of `RUN_SETUP.bat` confirms it from inside the contestant account.

---

## 8. Issue: VS Code extensions missing in the contestant account

### Root Cause:
VS Code records installed extensions in `.vscode\extensions\extensions.json` with absolute paths. Copying the Administrator's folder leaves paths the contestant cannot read, and the contestant profile did not exist yet at setup time.

### Fix:
Setup now creates the profile immediately, copies the extensions from `C:\ProgramData\ICPC\vscode-extensions` and rewrites `extensions.json` for the contestant. If step 1 reports **MISSING** extensions, run setup once on a PC with internet: the cache is saved to `installers\vscode-extensions` on the USB stick for all other PCs. Edit `configs/vscode/extensions.txt` to change the list.

---

## 9. Issue: Step 3 reports "Group Policy ignores local firewall rules"

### Root Cause:
The PC is domain-joined and a GPO sets "Apply local firewall rules = No" (or turns the firewall off). Local rules then have no effect.

### Fix:
Ask campus IT to move the lab PCs to an OU without that GPO for the contest, or physically disconnect the lab switch from the campus uplink.

---

## 10. Issue: Windows still wants to install updates / restart

### Fix:
* Step 4 warns when an update is **already downloaded and waiting for a restart**. Restart the PC, let it finish, then run `RUN_SETUP.bat` again; do this the day before the contest.
* `WaaSMedicSvc` is protected by Windows and may stay enabled; that is expected. Policies + firewall leave it nothing to download.
* `RUN_CLEANUP.bat` restores all update settings; restart afterwards.
