# ICPC Workstation & Lab Organizer Checklist

This checklist is designed for the technical committee organizing ICPC programming competitions. Follow these time-stamped checkpoints to guarantee zero downtime and smooth operations.

---

## Phase 1: Preparation (T-7 Days to T-3 Days)

- [ ] **Base Image Inspection:**
  - Verify OS on all 60 machines (Windows 10 / 11 Pro or Enterprise recommended).
  - Verify hardware: Ensure all monitors, keyboards, and mice function properly.
- [ ] **Toolchain Verification on Admin Account:**
  - `gcc` / `g++` (MinGW-w64, version 11+ or latest available, supporting C++17/C++20).
  - `java` & `javac` (OpenJDK 17 or 21 LTS).
  - `python` (Python 3.10+).
  - Visual Studio Code (latest stable).
- [ ] **System PATH Check:**
  - **Crucial:** Ensure compiler bin directories are added to **System Environment Variables**, NOT User Variables.
    - Example: `C:\msys64\ucrt64\bin` or `C:\MinGW\bin`
    - Example: `C:\Program Files\Java\jdk-21\bin`
    - Example: `C:\Python312` or `C:\Program Files\Python312`
- [ ] **Contest Server Preparation:**
  - DOMjudge / PC^2 / Kattis server tested on local server hardware.
  - Static IP assigned to server (e.g., `192.168.1.100`).
  - Web interface tested and operational on local port 80/443/8080.
- [ ] **Deployment Media:**
  - Copy this repository onto 3–5 fast USB flash drives (or host as read-only LAN share).

---

## Phase 2: Workstation Deployment (T-2 Days)

- [ ] **Physical Network Isolation:**
  - **Gold Standard:** Physically disconnect the WAN / Internet uplink cable from the lab's main network switch.
  - The switch should now only interconnect the 60 PCs and the contest server(s).
- [ ] **Execute Setup Script on all 60 PCs:**
  - Log in with university Administrator account.
  - Insert USB drive and run `RUN_SETUP.bat` (Run as Administrator).
  - Observe `04_verify_env.bat` output:
    - [x] GCC / G++ passes
    - [x] Java passes
    - [x] Python passes
    - [x] External internet ping (8.8.8.8) fails (isolated)
    - [x] Contest server ping succeeds
- [ ] **Contestant Account Check:**
  - Log into the newly created `contestant` account.
  - Open VS Code via the desktop shortcut.
  - Open terminal (`Ctrl + ~`) and verify `g++ --version`, `javac --version`, and `python --version`.
  - Open browser and verify access to `http://<SERVER_IP>`.

---

## Phase 3: Mock Contest / Practice Session (T-1 Day)

- [ ] Run the official practice session with participants.
- [ ] Have contestants submit at least one problem in each supported language (C, C++, Java, Python) to the judging system.
- [ ] Test local printing functionality (if paper printing of code is supported).
- [ ] Collect any reports of keyboard/mouse defects or unusual software behavior.
- [ ] Resolve any reported bugs immediately.

---

## Phase 4: Contest Day Morning (T - 2 Hours)

- [ ] Power on all 60 workstations.
- [ ] Ensure all machines are sitting at the `contestant` desktop or login prompt.
- [ ] Place contestant credentials (team username/password for DOMjudge) and scratch paper at each desk.
- [ ] Verify judge server and scoreboard monitors are active.
- [ ] Confirm no stray WiFi adapters or unauthorized USB devices are connected.

---

## Phase 5: Post-Contest Teardown

- [ ] Log in with university Admin credentials on each machine.
- [ ] Insert USB drive and run `RUN_CLEANUP.bat`.
- [ ] Confirm:
  - `contestant` account removed.
  - Windows Firewall reset to defaults.
  - Internet access restored.
- [ ] Reconnect the WAN uplink cable to the lab's network switch.
- [ ] Hand the computer lab back to university lab administrators.

