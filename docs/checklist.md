# ICPC Workstation & Lab Organizer Checklist

This checklist is designed for the technical committee organizing ICPC programming competitions. Follow these time-stamped checkpoints to guarantee zero downtime and smooth operations.

---

## Phase 1: Preparation (T-7 Days to T-3 Days)

- [ ] **Base Image & Hardware Inspection:**
  - Verify OS on all 60 machines (Windows 10 / 11 64-bit).
  - Verify hardware: Ensure all monitors, keyboards, mice, and LAN cables function properly.
- [ ] **Configure Master Repository & Settings:**
  - Open `RUN_SETUP.bat` and configure `DOMSERVER_IP` (e.g. `192.168.1.100`).
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
- [ ] **Execute Setup Script on all 60 PCs:**
  - Log in with university Administrator account.
  - Insert USB drive and run `RUN_SETUP.bat` (Run as Administrator).
  - Enter the assigned PC number (`1` to `60`) when prompted.
  - Verify output across all 5 automated phases:
    - [x] Step 1: Toolchains installed machine-wide via `winget`; VS Code extensions cached.
    - [x] Step 2: Official team user account created with Standard User restrictions.
    - [x] Step 3/4: Firewall locked down to `%DOMSERVER_IP%`; Windows Update frozen.
    - [x] Step 7: Verification passed **inside the contestant account**.
    - [x] Step 4: VS Code settings injected, Code Runner synced, desktop workspace created.
    - [x] Step 5: Smoke test passed & **30/30 test cases passed for C, C++, Java, and Python** (120/120 total).
    - [x] External internet ping (8.8.8.8) is BLOCKED.
    - [x] Contest server ping SUCCEEDS.
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
