# ICPC University Contest Lab Automation

[![ICPC Ready](https://img.shields.io/badge/ICPC-Standard%20Ready-blue.svg)](#)
[![OS](https://img.shields.io/badge/OS-Windows%2010%20%7C%2011-0078D6.svg)](#)
[![Languages](https://img.shields.io/badge/Languages-C%20%7C%20C%2B%2B%20%7C%20Java%20%7C%20Python-orange.svg)](#)
[![Editor](https://img.shields.io/badge/Editor-VS%20Code%20%2B%20Code%20Runner-007ACC.svg)](#)

A production-ready automation toolkit and operational runbook for configuring 60+ Windows workstations for internet-free programming competitions (ICPC, IEEEXtreme, National Olympiad, and University Contests).

---

## 📋 Features

* **One-Click Deployment:** Fast, self-elevating setup script runnable directly from a USB stick or network share.
* **Auto-Install Toolchains (for every account):** Installs missing compilers (WinLibs GCC/G++, Temurin JDK 21, Python 3.12, VS Code System 64-bit) **machine-wide** via `winget`. Copies that only exist inside an admin's profile are ignored (the contestant cannot read them) and System PATH is fixed accordingly.
* **VS Code Language Extensions:** Downloads Code Runner, C/C++, Python and Java extensions once into a shared cache (`C:\ProgramData\ICPC\vscode-extensions`, also saved to `installers\vscode-extensions` on the USB stick) and installs them **into the contestant's own profile**. List: [`configs/vscode/extensions.txt`](configs/vscode/extensions.txt).
* **Team & Account Provisioning:** Provisions team accounts (`ICPCLK26_G...`) or a generic `contestant` account as Standard User, and creates the Windows profile immediately so the workspace, settings and extensions are in place before first login.
* **Strict Network Isolation:** Default outbound **BLOCK** plus explicit **block rules** (which override every other allow rule on the PC) for all addresses except the DOMjudge server. Applies to every account, including the contestant. Warns if Group Policy overrides the local firewall.
* **Auto Wi-Fi Disabling:** Scans for and automatically disables all wireless (Wi-Fi/WLAN) adapters on the PC, forcing all network traffic through the isolated wired Ethernet switch.
* **Windows Update Freezing:** Update policies (no auto-update, no auto-restart, dead update server), updates paused, update services and scheduled tasks disabled as SYSTEM, and a warning if a restart is already pending. Everything is backed up and restored by cleanup.
* **Verification inside the contestant account:** After setup, the full test (compilers, 120 test cases, extensions, internet leak test over TCP/HTTPS/DNS/proxy) is run **as the contestant**, not just as Administrator.
* **120 Comprehensive Tests (30 per Language):** Runs 30 automated algorithmic test cases for C, C++, Java, and Python covering 64-bit overflow, negative numbers, stress tests ($N=1000$), strings, and edge cases.
* **Clean Post-Contest Teardown:** One-click rollback script (`RUN_CLEANUP.bat`) restores the computer lab to factory university settings and re-enables Windows Updates.

---

## 📁 Repository Structure

```text
.
├── RUN_SETUP.bat             # 1-Click Master Setup Launcher (Self-elevates as Admin)
├── RUN_CLEANUP.bat           # 1-Click Post-Contest Teardown Launcher
├── configs/
│   ├── test_programs/        # Test source files & 30-case validation programs
│   │   ├── suite_c.c         # C 30-test suite program
│   │   ├── suite_cpp.cpp     # C++ 30-test suite program
│   │   ├── SuiteJava.java    # Java 30-test suite program
│   │   ├── suite_py.py       # Python 30-test suite program
│   │   ├── test.c            # Basic smoke test C
│   │   ├── test.cpp          # Basic smoke test C++
│   │   ├── Test.java         # Basic smoke test Java
│   │   └── test.py           # Basic smoke test Python
│   └── vscode/
│       ├── settings.json     # Offline-tuned VS Code settings & Code Runner config
│       └── extensions.txt    # VS Code extensions installed for the contestant
├── docs/
│   ├── checklist.md          # Complete organizer timeline checklist (T-7 to T-0)
│   ├── network-topology.md   # Subnets, IP plans, and physical air-gap diagrams
│   ├── simple_guide.md       # 1-page quickstart setup guide for volunteers
│   └── troubleshooting.md    # Solutions for compiler PATHs, WindowsApps stubs, etc.
├── installers/               # (optional) offline files: winlibs*.zip, vscode-extensions\ (auto-filled)
└── scripts/
    ├── common.ps1                   # Shared helpers (machine-wide PATH, profiles, run-as-SYSTEM)
    ├── 00_install_prerequisites.ps1 # Machine-wide compilers, VS Code + extension cache
    ├── 01_create_user.ps1           # User + profile creation & official team credential mapping
    ├── 02_lockdown_network.ps1      # Blocks Internet/peers, whitelists DOMserver
    ├── 02b_block_updates.ps1        # Freezes Windows Update (policies, pause, services, tasks)
    ├── 03_configure_vscode.ps1      # Settings, extensions & workspace in the contestant profile
    ├── 04_verify_env.bat            # Compiler/extension/network checks (run as admin AND contestant)
    ├── 05_verify_as_contestant.ps1  # Runs 04_verify_env.bat inside the contestant account
    ├── net_probe.ps1                # Real internet-leak test (TCP, HTTPS, DNS, proxy)
    ├── 99_cleanup_lab.ps1           # Complete lab restoration & cleanup
    ├── generate_credentials.py      # Re-generates strong team passwords from teams.txt
    └── run_30_tests.py              # Executes 30 algorithmic test cases per language (120 total)
```

---

## 🚀 Quick Start Guide (Contest Setup)

### Step 1: Configure Your DOMjudge Server IP
Open **[RUN_SETUP.bat](file:///d:/UoP/ICPC2026/icpc_onsite_setup/RUN_SETUP.bat)** and set your DOMjudge server's exact IP at line 6:
```bat
:: Set your DOMjudge / Contest Server IP below:
set "DOMSERVER_IP=192.168.1.100"
```

---

### Step 2: Deploy to the 60 Workstations

1. Copy this repository to **3–4 fast USB flash drives**.
2. Assign 2 volunteers per row in the computer lab.
3. Plug in the USB drive, right-click **`RUN_SETUP.bat`** and select **Run as administrator**.
4. Confirm with `Y`.
5. When prompted:
   ```text
   Enter Lab PC Number (1-60) for assigned team, or press ENTER for standard 'contestant': 
   ```
   * Type the PC number (e.g., `5`) to automatically assign the official team username (e.g. `ICPCLK26_G022`), team name, and password.
   * Or press **ENTER** to create the standard `contestant` account.
6. The setup runs through 7 automated phases (the first PC needs internet to download tools and extensions; it takes longer):
   * **[1/7]** Installs missing toolchains machine-wide and prepares the VS Code extension cache.
   * **[2/7]** Provisions the team's Standard User account and creates its profile.
   * **[3/7]** Locks down the firewall exclusively to `%DOMSERVER_IP%`.
   * **[4/7]** Freezes Windows Update.
   * **[5/7]** Installs settings, language extensions and the desktop workspace into the contestant account.
   * **[6/7]** Runs the 120-test suite and network checks as Administrator.
   * **[7/7]** Runs the same checks **inside the contestant account**.
7. The last screen says either `ALL STEPS OK` or lists the failed steps. Only move on when it says `ALL STEPS OK`.
8. If step 4 warns that a restart is pending, restart the PC and run setup again.

---

## 🧪 Automated 120-Test Validation Output

During Step 5, the automated suite tests 30 test cases per language:
```text
============================================================
      COMPREHENSIVE 30-TEST-CASE COMPILER & RUNTIME SUITE
============================================================
Testing 30 automated test cases per language:
  - Small values, Negative numbers, 64-bit integer overflow
  - Strings, Palindromes, Stress tests (N=1 to N=1000)
------------------------------------------------------------
  [C++   ] .............................. [30/30 PASSED] (100% OK)
  [C     ] .............................. [30/30 PASSED] (100% OK)
  [Java  ] .............................. [30/30 PASSED] (100% OK)
  [Python] .............................. [30/30 PASSED] (100% OK)
------------------------------------------------------------
 RESULT: [ALL 120 TEST CASES PASSED] Toolchains 100% operational!
============================================================
```

---

## 🧹 Post-Contest Teardown & Reset

Once the competition concludes:
1. Log in to each machine with university Administrator credentials.
2. Insert the USB drive, right-click **`RUN_CLEANUP.bat`**, and select **Run as administrator**.
3. Type `Y` and press Enter.
4. The cleanup script will:
   * Remove the contestant accounts together with their profiles.
   * Restore the firewall exactly as it was before setup (factory reset only if no backup exists).
   * Restore Windows Update services, scheduled tasks and policies from the backup.
   * Re-enable Wi-Fi and disable automatic login.
5. Reconnect the physical WAN/Internet uplink cable to the lab's main switch.

---

## 📖 Operational Documentation

* ⚡ [Simple 3-Step Volunteer Guide](docs/simple_guide.md) – Quick, 1-page instructions for setting up and testing each PC.
* 📝 [Organizer Timeline Checklist](docs/checklist.md) – Step-by-step checklist from T-7 days to contest morning.
* 🌐 [Network Topology & Isolation Plan](docs/network-topology.md) – Physical air-gap diagram, client-to-client blocking, and IP addressing.
* 🛠️ [Troubleshooting Guide](docs/troubleshooting.md) – Solutions for WindowsApps Python stubs, firewall ping precedence, and Defender false-positives.
