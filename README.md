# ICPC University Contest Lab Automation

[![ICPC Ready](https://img.shields.io/badge/ICPC-Standard%20Ready-blue.svg)](#)
[![OS](https://img.shields.io/badge/OS-Windows%2010%20%7C%2011-0078D6.svg)](#)
[![Languages](https://img.shields.io/badge/Languages-C%20%7C%20C%2B%2B%20%7C%20Java%20%7C%20Python-orange.svg)](#)
[![Editor](https://img.shields.io/badge/Editor-VS%20Code-007ACC.svg)](#)

A production-ready automation toolkit and operational runbook for configuring 60+ Windows workstations for internet-free programming competitions (ICPC, IEEEXtreme, National Olympiad, and University Contests).

---

## 📋 Features

* **One-Click Deployment:** Fast, self-elevating setup script runnable directly from a USB stick or network share.
* **Account Provisioning:** Creates a locked-down, standard `contestant` user profile (prevents system tampering and unauthorized installations).
* **Strict Network Isolation:** Turns Windows Firewall into a whitelist barrier—completely blocking the internet while permitting local LAN traffic to DOMjudge / PC^2 contest servers.
* **VS Code Pre-configuration:** Pre-configures VS Code with offline optimizations (disables update popups, background telemetry, online syncing) and pre-loads C/C++ compilation build tasks.
* **Automated Smoke Test (`04_verify_env.bat`):** Compiles and executes real C, C++, Java, and Python test programs in seconds and tests network reachability.
* **Clean Post-Contest Teardown:** One-click rollback script (`RUN_CLEANUP.bat`) restores the computer lab to factory university settings.

---

## 📁 Repository Structure

```text
.
├── RUN_SETUP.bat             # 1-Click Master Setup Launcher (Run as Admin)
├── RUN_CLEANUP.bat           # 1-Click Post-Contest Teardown Launcher
├── configs/
│   ├── test_programs/        # Smoke test source files for verification
│   │   ├── test.c
│   │   ├── test.cpp
│   │   ├── Test.java
│   │   └── test.py
│   └── vscode/
│       └── settings.json     # Offline-tuned VS Code settings
├── docs/
│   ├── checklist.md          # Complete organizer timeline checklist (T-7 to T-0)
│   ├── network-topology.md   # Subnets, IP plans, and physical air-gap diagrams
│   └── troubleshooting.md    # Solutions for compiler PATHs, Defender flags, etc.
└── scripts/
    ├── 01_create_user.ps1       # User creation & Auto-login management
    ├── 02_lockdown_network.ps1  # Subnet firewall rules & Internet blocking
    ├── 03_configure_vscode.ps1  # VS Code profile injection & workspace creation
    ├── 04_verify_env.bat        # Automated compiler & isolation smoke test
    └── 99_cleanup_lab.ps1       # Complete lab restoration & cleanup
```

---

## 🚀 Quick Start Guide (Contest Setup)

### Prerequisites
Before running setup on the 60 PCs, ensure the following are installed under the machine's Administrator account:
1. **Compilers / Runtimes:**
   * GCC / G++ (MinGW-w64 or MSYS2)
   * Java Development Kit (OpenJDK 17 or 21 LTS)
   * Python (Python 3.10+)
   * *Ensure their binary paths are included in the machine's **System PATH**.*
2. **Visual Studio Code:** Installed machine-wide.

---

### Step 1: Customize Your Lab Settings
Open `scripts/02_lockdown_network.ps1` and verify your contest server IP and subnet:
```powershell
[string]$ContestSubnet = "192.168.1.0/24"  # Your lab subnet
[string]$ServerIP      = "192.168.1.100"   # DOMjudge / PC^2 server IP
```
*(Optional: Change default password in `scripts/01_create_user.ps1` if desired).*

---

### Step 2: Deploy to the 60 Workstations

#### Option A: USB Flash Drive Sneakernet (Recommended)
1. Copy this repository to **3–4 fast USB flash drives**.
2. Have 2–3 volunteers divide the lab rows.
3. Plug in the USB drive, right-click `RUN_SETUP.bat` and select **Run as administrator**.
4. Confirm with `Y`. The script runs in ~15 seconds and displays the verification report:
   ```text
   [1] Checking Installed Toolchains:
     [PASS] GCC (C Compiler)
     [PASS] G++ (C++ Compiler)
     [PASS] Java Compiler (javac)
     [PASS] Python Interpreter
   [2] Compiling and Executing Test Programs:
     [PASS] C compilation and execution succeeded.
     [PASS] C++ (STL) compilation succeeded.
     [PASS] Java compilation succeeded.
     [PASS] Python execution succeeded.
   [3] Checking Network Security & Isolation:
     [PASS] Contest server is REACHABLE.
     [PASS] External Internet is BLOCKED.
   ```
5. Remove USB drive and move to the next PC. (60 machines take ~25 minutes).

#### Option B: Over Local Network Share (SMB)
1. Share this folder on your contest server as a read-only share: `\\192.168.1.100\icpc-setup`.
2. On each workstation, press `Win + R`, paste the path, and run `RUN_SETUP.bat`.

---

## 🧹 Post-Contest Teardown & Reset

Once the competition finishes and awards are distributed:
1. Insert the USB drive with this repository.
2. Right-click `RUN_CLEANUP.bat` and choose **Run as administrator**.
3. The cleanup script will:
   * Delete the `contestant` user and its desktop profile.
   * Reset Windows Firewall to factory settings (restores university internet access).
   * Disable automatic login.
4. Reconnect the physical WAN uplink cable to the lab switch.

---

## 📖 Operational Documentation

* 📝 [Organizer Timeline Checklist](docs/checklist.md) – Step-by-step instructions from 7 days before the contest to contest morning.
* 🌐 [Network Topology & Isolation Plan](docs/network-topology.md) – Air-gap design, DHCP configurations, and IP schemes.
* 🛠️ [Troubleshooting Guide](docs/troubleshooting.md) – Fixes for Windows Defender false positives, compiler PATH bugs, and missing extensions.

---

## 👥 Notes for Future Organizing Committees

1. **Physical Air-Gap First:** Never rely exclusively on software firewalls. Always pull the physical WAN uplink cable from the lab switch before contest start.
2. **Practice Session (Mock Contest):** Always host a 1-hour practice session on the day before the main contest. Let contestants test compiling and submitting with all four languages to catch hardware or environment quirks early.
3. **Keep this Repository Updated:** When updating compiler versions (e.g., upgrading from C++17 to C++20 or newer JDKs), verify `04_verify_env.bat` and update this repository for next year's batch!

