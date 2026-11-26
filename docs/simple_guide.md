# ICPC Lab Setup: Simple 3-Step Guide

This guide is designed for organizers and student volunteers setting up the 60 competition PCs.

---

## ⚡ Quick Summary

| Action | Script to Run | Time Needed |
| :--- | :--- | :--- |
| **Phase 1: Setup Accounts & Tools** | Double-click `RUN_SETUP.bat` | ~3-5 minutes per PC (first PC longer: downloads) |
| **Phase 2: Lockdown Network** | Double-click `RUN_LOCKDOWN.bat` | ~5 seconds per PC |
| **Restore PC After Contest** | Double-click `RUN_CLEANUP.bat` | ~10 seconds per PC |

---

## 🚀 Part 1: How to Setup Each PC (Before the Contest)

### Step 1: Plug in the USB Drive
* Insert the USB drive containing the `icpc_onsite_setup` folder into the PC.
* Ensure you are logged into the PC with the university **Administrator** account.

### Step 2: Run the Setup Script
1. Open the USB drive in File Explorer.
2. Double-click **`RUN_SETUP.bat`** (or right-click $\rightarrow$ **Run as administrator**).
3. If Windows asks for permission (UAC prompt), click **Yes**.

### Step 3: Answer Three Prompts
* When asked: `Proceed with setup on this workstation? (Y/N):`  
  👉 Type **`Y`** and press **Enter**.
* When asked: `Which Lab is this PC in? (1, 2, or 3):`  
  👉 Type **`1`**, **`2`**, or **`3`** (configured in `config.bat`) and press **Enter**.
* When asked: `Enter Lab PC Number (1-60) for assigned team...:`  
  👉 Type the PC number (e.g., **`5`** for Lab PC #5) and press **Enter**.  
  *(Or just press **Enter** without a number if you want the generic `contestant` account).*

### That's it for Phase 1!
The script will automatically:
- [x] Install VS Code, WinLibs GCC/G++, JDK 21, and Python 3.12 from `installers\` (completely offline!).
- [x] Create the team's account (and its profile) with their password.
- [x] Install VS Code settings, extensions (Code Runner, C/C++, Python, Java) and the desktop workspace into the team's account.
- [x] Run 120 automated test cases (30 per language) to verify all compilers.

---

## 🔒 Part 2: Lockdown Network Before Contest (`RUN_LOCKDOWN.bat`)

Run this on contest day after the lab's internet cable is unplugged and the coordinator has updated `config.bat` with the 3 real DOMserver IPs:
1. Double-click **`RUN_LOCKDOWN.bat`** as Administrator.
2. Press **Enter** to confirm the Lab remembered from Phase 1 (or type `1`, `2`, or `3`).
3. Type **`Y`** and press **Enter**.
   * Turns **OFF** Windows Firewall across all profiles.
   * Disables any Wi-Fi adapters.
   * Disables Windows Update services.
   * Reads the latest DOMserver IP from `config.bat` and verifies DOMserver reachability and offline isolation.

When it prints **`SETUP FINISHED - ALL STEPS OK`**, press any key, remove the USB drive, and move to the next PC.
If it prints **`SETUP FINISHED WITH PROBLEMS IN: ...`**, scroll up to the red lines (see `docs/troubleshooting.md`) and run it again.
If it says **a restart is pending**, restart the PC and run `RUN_SETUP.bat` again.

> The **first** PC must have internet: it downloads the tools and saves the VS Code extensions to `installers\vscode-extensions` on the USB stick. Later PCs reuse that copy.

---

## 🔍 Part 2: Quick 1-Minute Verification (Test the PC)

1. **Log in as Contestant:**
   * Sign out of the Administrator account.
   * Log into the newly created account:
     * **Username:** e.g., `ICPCLK26_G022` (or check `contestant_credentials.txt`).
     * **Password:** Check the slip or `contestant_credentials.txt`.
2. **Test Code Runner in VS Code:**
   * Double-click the **"Open ICPC Workspace"** shortcut on the Desktop.
   * Open `sample.cpp`.
   * Press **`Ctrl + Alt + N`** (or click the **▶ Run** button at the top right).
   * Verify it compiles and prints `ICPC 2026 Ready!` in the terminal.
3. **Test Network Isolation:**
   * Open Chrome / Edge.
   * Go to your DOMjudge server (e.g. `http://192.168.1.100`) $\rightarrow$ **Should open!**
   * Go to `https://google.com` $\rightarrow$ **Should fail / time out!**

---

## 🧹 Part 3: How to Clean Up (After the Contest)

1. Log into the PC using the **Administrator** account.
2. Plug in the USB drive.
3. Double-click **`RUN_CLEANUP.bat`**.
4. Type **`Y`** and press **Enter**.

The script will automatically:
- Delete the contestant user account and files.
- Reset the firewall and restore normal internet access.
- Re-enable any Wi-Fi adapters.
- Re-enable Windows Updates.

