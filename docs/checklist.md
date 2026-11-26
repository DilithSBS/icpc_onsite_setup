# ICPC Workstation & Lab Organizer Checklist

This checklist is designed for the technical committee organizing ICPC programming competitions. Follow these time-stamped checkpoints to guarantee zero downtime and smooth operations.

---

## Phase 1: Preparation (T-7 Days to T-3 Days)

- [ ] **Base Image & Hardware Inspection:**
  - Verify OS on all 60 machines (Windows 10 / 11 64-bit).
  - Verify hardware: Ensure all monitors, keyboards, mice, and LAN cables function properly.
- [ ] **Configure Master Repository & Settings:**
  - Open `config.bat` and configure the DOMserver IP for all 3 labs (`LAB1_DOMSERVER_IP`, `LAB2_DOMSERVER_IP`, `LAB3_DOMSERVER_IP`).
  - Verify `installers\` contains the 4 offline installers (VS Code, WinLibs GCC zip, JDK 21 MSI, Python 3.12 EXE).
  - Verify `teams.txt` contains the finalized list of 60 official participating teams.
  - Run `python scripts/generate_credentials.py` to generate the matching `contestant_credentials.txt` and `contestant_credentials.csv`.
- [ ] **Print Contestant Desk Slips:**
  - Print `contestant_credentials.txt` and cut it into 60 slips containing Team Name, PC Number, official Username, and Password.
- [ ] **Contest Server Preparation:**
  - DOMjudge / PC^2 / Kattis server tested on local server hardware.
  - Static IP assigned to server (e.g., `192.168.1.100`).
  - Import `contestant_credentials.csv` into DOMjudge.
  - Web interface tested and operational on local port 80/443/8080.
- [ ] **Prepare Deployment Media:**
  - Copy the `icpc_onsite_setup` repository onto 3–5 fast USB flash drives.

---

## Phase 2: Workstation Deployment (T-2 Days)

- [ ] **Physical Network Isolation:**
  - **Gold Standard:** Physically disconnect the WAN / Internet uplink cable from the lab's main network switch.
  - The switch should now only interconnect the 60 PCs and the contest server(s).
- [ ] **Disable WiFi Interfaces:**
  - If machines have wireless network cards, disable them to prevent automatic connection to campus Wi-Fi.
- [ ] **Execute Phase 1 (`RUN_SETUP.bat`) on all 60 PCs:**
  - Log in with university Administrator account.
  - Insert USB drive and run `RUN_SETUP.bat` (Run as Administrator).
  - Select the Lab (`1`, `2`, or `3`) and enter the assigned PC number (`1` to `60`).
  - Verify:
    - [x] Offline installers & VS Code extensions installed machine-wide.
    - [x] Official team user account created with Standard User restrictions.
    - [x] VS Code settings, Code Runner, and desktop workspace configured.
    - [x] **30/30 test cases passed for C, C++, Java, and Python** (120/120 total).
- [ ] **Execute Phase 2 (`RUN_LOCKDOWN.bat`) before Contest:**
  - Run `RUN_LOCKDOWN.bat` as Administrator (press Enter to confirm the saved Lab).
  - Verify:
    - [x] Windows Firewall turned OFF on all profiles.
    - [x] Wi-Fi adapters disabled.
    - [x] Windows Updates disabled.
    - [x] Contest server ping SUCCEEDS & external internet ping (`8.8.8.8`) is BLOCKED.
- [ ] **Contestant Account Check:**
  - Log into the newly created team account (or switch user).
  - Open VS Code via the desktop shortcut.
  - Test compiling and running code using Code Runner (`Ctrl + Alt + N` or ▶ button) and `Ctrl + Shift + B`.
  - Open browser and verify access to `http://<DOMSERVER_IP>`.

---

## Phase 3: Mock Contest / Practice Session (T-1 Day)

- [ ] Run the official practice session with participants.
- [ ] Have contestants submit at least one problem in each supported language (C, C++, Java, Python) to DOMjudge.
- [ ] Test local printing functionality (if code printouts are supported).
- [ ] Collect any reports of keyboard/mouse defects or unusual software behavior.
- [ ] Resolve any reported issues immediately.

---

## Phase 4: Contest Day Morning (T - 2 Hours)

- [ ] Power on all 60 workstations.
- [ ] Ensure all machines are sitting at the contestant desktop or login prompt.
- [ ] Place contestant credentials slips and scratch paper at each desk.
- [ ] Verify judge server and scoreboard monitors are active.
- [ ] Confirm no unauthorized USB devices or cables are connected.

---

## Phase 5: Post-Contest Teardown

- [ ] Log in with university Admin credentials on each machine.
- [ ] Insert USB drive and run `RUN_CLEANUP.bat`.
- [ ] Confirm:
  - Team user account and desktop profile removed.
  - Windows Firewall reset to defaults (internet restored).
  - Windows Update services re-enabled.
  - Auto-logon disabled.
- [ ] Reconnect the WAN uplink cable to the lab's network switch.
- [ ] Hand the computer lab back to university lab administrators.
