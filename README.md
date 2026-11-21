# ICPC University Contest Lab Automation

[![ICPC Ready](https://img.shields.io/badge/ICPC-Standard%20Ready-blue.svg)](#)
[![OS](https://img.shields.io/badge/OS-Windows%2010%20%7C%2011-0078D6.svg)](#)
[![Languages](https://img.shields.io/badge/Languages-C%20%7C%20C%2B%2B%20%7C%20Java%20%7C%20Python-orange.svg)](#)
[![Editor](https://img.shields.io/badge/Editor-VS%20Code%20%2B%20Code%20Runner-007ACC.svg)](#)

A production-ready automation toolkit and operational runbook for configuring 60+ Windows workstations for internet-free programming competitions (ICPC, IEEEXtreme, National Olympiad, and University Contests).

---

## 📋 Features

* **One-Click Deployment:** Fast, self-elevating setup script runnable directly from a USB stick or network share.
* **Auto-Install Toolchains:** Automatically detects and installs missing compilers (MinGW GCC/G++, OpenJDK 21, Python 3.12, VS Code System 64-bit) machine-wide via `winget`.
* **VS Code & Code Runner:** Pre-configures VS Code in offline mode, installs the `formulahendry.code-runner` extension, and maps interactive terminal execution (`runInTerminal: true`) for instant code running.
* **Team & Account Provisioning:** Automatically provisions individual team accounts (`ICPCLK26_G...`) or generic `contestant` accounts with locked Standard User privileges.
* **Strict Network Isolation:** Locks Windows Firewall outbound policy to **BLOCK**—completely cutting off internet, blocking peer-to-peer communication between contestants, and permitting traffic **strictly** to the DOMjudge server.
* **Windows Update Freezing:** Stops and disables Windows Update background services and telemetry policies to ensure zero popups or unexpected reboots during contest hours.
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
│       └── settings.json     # Offline-tuned VS Code settings & Code Runner config
├── docs/
│   ├── checklist.md          # Complete organizer timeline checklist (T-7 to T-0)
│   ├── network-topology.md   # Subnets, IP plans, and physical air-gap diagrams
│   └── troubleshooting.md    # Solutions for compiler PATHs, WindowsApps stubs, etc.
└── scripts/
    ├── 00_install_prerequisites.ps1 # Auto-installs missing compilers, VS Code & Code Runner
    ├── 01_create_user.ps1           # User creation & official team credential mapping
    ├── 02_lockdown_network.ps1      # Blocks Internet/peers, whitelists DOMserver & stops WU
    ├── 03_configure_vscode.ps1      # VS Code profile injection, extensions sync & workspace
    ├── 04_verify_env.bat            # Automated compiler smoke test & ping verification
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
6. The setup runs in ~20 seconds through all 5 automated phases:
   * **[Step 1/5]** Installs any missing toolchains & Code Runner via `winget`.
   * **[Step 2/5]** Provisions the team's local standard user account.
   * **[Step 3/5]** Disables Windows Update and locks down the firewall exclusively to `%DOMSERVER_IP%`.
   * **[Step 4/5]** Injects offline VS Code settings, syncs Code Runner, and configures the desktop workspace.
   * **[Step 5/5]** Runs the full 120-test validation suite and pings the DOMserver.
7. Unplug the USB drive and move to the next PC. (All 60 machines can be prepped in ~25 minutes).

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
   * Remove the contestant user profile and desktop workspace.
   * Reset Windows Firewall to factory defaults (restores normal campus internet).
   * Re-enable Windows Update services and clear registry policies.
   * Disable automatic login.
5. Reconnect the physical WAN/Internet uplink cable to the lab's main switch.

---

## 📖 Operational Documentation

* 📝 [Organizer Timeline Checklist](docs/checklist.md) – Step-by-step checklist from T-7 days to contest morning.
* 🌐 [Network Topology & Isolation Plan](docs/network-topology.md) – Physical air-gap diagram, client-to-client blocking, and IP addressing.
* 🛠️ [Troubleshooting Guide](docs/troubleshooting.md) – Solutions for WindowsApps Python stubs, firewall ping precedence, and Defender false-positives.
