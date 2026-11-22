# ICPC Lab Setup: Simple 3-Step Guide

This guide is designed for organizers and student volunteers setting up the 60 competition PCs.

---

## ⚡ Quick Summary

| Action | Script to Run | Time Needed |
| :--- | :--- | :--- |
| **Setup PC for Contest** | Double-click `RUN_SETUP.bat` | ~20 seconds per PC |
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

### Step 3: Answer Two Prompts
* When asked: `Proceed with setup on this workstation? (Y/N):`  
  👉 Type **`Y`** and press **Enter**.
* When asked: `Enter Lab PC Number (1-60) for assigned team...:`  
  👉 Type the PC number (e.g., **`5`** for Lab PC #5) and press **Enter**.  
  *(Or just press **Enter** without a number if you want the generic `contestant` account).*

### That's it!
The script will automatically:
- [x] Check/install missing compilers and Code Runner extension.
- [x] Create the team's account with their password.
- [x] Disable Wi-Fi and block internet (locking network strictly to DOMjudge).
- [x] Freeze Windows Updates.
- [x] Configure VS Code and desktop workspace.
- [x] Run 120 automated test cases (30 per language).

When it prints **`SETUP WORKFLOW FINISHED`**, press any key to close the window, remove the USB drive, and move to the next PC.

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

