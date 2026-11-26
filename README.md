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
├── config.bat                # Central 3-lab DOMjudge server IP configuration
├── RUN_SETUP.bat             # Phase 1: Accounts, offline installers, VS Code & compiler tests
├── RUN_LOCKDOWN.bat          # Phase 2: Turn OFF firewalls, disable Wi-Fi & Windows Updates
├── RUN_CLEANUP.bat           # Post-Contest Teardown Launcher
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
├── installers/               # (optional) offline files: VSCodeSetup*.exe, winlibs*.zip, *jdk*.msi, python*.exe, vscode-extensions\
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

### Step 1: Phase 1 — Setup PCs (`RUN_SETUP.bat`)
Run this days in advance while the lab still has internet access (you do **not** need the final DOMserver IPs yet—leave the placeholders in `config.bat` for now):
1. Copy this repository (including `installers\` and `contestant_credentials.csv`) to **3–4 fast USB flash drives**.
2. Plug in the USB drive, right-click **`RUN_SETUP.bat`** and select **Run as administrator**.
3. Confirm with `Y`, select which Lab (`1`, `2`, or `3`) the PC is in, and enter the Lab PC Number (`1-60`) for the assigned team (or press **ENTER** for `contestant`).
4. The script installs missing toolchains/Code Runner, creates the user account, configures VS Code, and verifies compilers & the 120-test suite (without locking down the network yet).

---

### Step 2: Phase 2 — Network Lockdown (`RUN_LOCKDOWN.bat`)
Run this on contest/mock day once the DOMservers are up and the lab WAN uplink is unplugged:
1. Open **[config.bat](file:///d:/UoP/ICPC2026/icpc_onsite_setup/config.bat)** on the USB drive(s) and set the **real DOMserver IP** for each of the 3 labs (`LAB1_DOMSERVER_IP`, `LAB2_DOMSERVER_IP`, `LAB3_DOMSERVER_IP`).
2. Plug in the USB drive and run **`RUN_LOCKDOWN.bat`** as Administrator.
3. Press **ENTER** to confirm the Lab remembered from Phase 1 (or choose `1`, `2`, or `3`).
4. The script turns **OFF** Windows Firewall across all profiles, disables any Wi-Fi adapters, disables Windows Updates, and verifies DOMserver reachability and offline isolation.

---

### Step 3: Phase 3 — Contestant Verification (`RUN_VERIFY.bat`)
Run **`RUN_VERIFY.bat`** as Administrator to verify from **inside the contestant account** that Code Runner and all extensions are present, all 120 test cases pass, the DOMserver is reachable, and outbound internet is completely off.

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
