# Network Topology & Air-Gap Guidelines

This document outlines the network topology and isolation plan for running an internet-free ICPC contest across **3 labs** totaling **60 contestant PCs** and **9 server machines** (1 DOMserver + 2 Judgehost servers per lab).

---

## 1. Multi-Lab Network Architecture

```
                [ Physical WAN / Outside Campus Internet ]
                                    |
                         [ X ] DISCONNECTED!
                                    |
     ┌──────────────────────────────┼──────────────────────────────┐
     ▼                              ▼                              ▼
┌──────────────────────┐       ┌──────────────────────┐       ┌──────────────────────┐
│    LAB 1 SWITCH      │       │    LAB 2 SWITCH      │       │    LAB 3 SWITCH      │
└──────────────────────┘       └──────────────────────┘       └──────────────────────┘
  │         │                    │         │                    │         │
  │ (~20 Contestant PCs)         │ (~20 Contestant PCs)         │ (~20 Contestant PCs)
  │         │                    │         │                    │         │
  ▼         ▼                    ▼         ▼                    ▼         ▼
┌──────────────────────┐       ┌──────────────────────┐       ┌──────────────────────┐
│ Lab 1 DOMserver      │       │ Lab 2 DOMserver      │       │ Lab 3 DOMserver      │
│ (192.168.1.100)      │       │ (192.168.2.100)      │       │ (192.168.3.100)      │
└──────────────────────┘       └──────────────────────┘       └──────────────────────┘
     │          │                   │          │                   │          │
     ▼          ▼                   ▼          ▼                   ▼          ▼
┌─────────┐ ┌─────────┐        ┌─────────┐ ┌─────────┐        ┌─────────┐ ┌─────────┐
│Judgehost│ │Judgehost│        │Judgehost│ │Judgehost│        │Judgehost│ │Judgehost│
│ 1A      │ │ 1B      │        │ 2A      │ │ 2B      │        │ 3A      │ │ 3B      │
└─────────┘ └─────────┘        └─────────┘ └─────────┘        └─────────┘ └─────────┘
```

### Summary of Infrastructure
* **Contestant Workstations:** 60 PCs total (~20 PCs per lab).
* **Server Infrastructure (9 machines total):**
  * **3 DOMservers** (1 per lab) — receives submissions from that lab's ~20 contestant PCs.
  * **6 Judgehost Servers** (2 per lab) — each DOMserver connects to its 2 dedicated Judgehosts for parallel judging.

---

## 2. Recommended IP Addressing Plan (Per Lab)

On lockdown day (once the 3 DOMservers are up and their IPs are known), update `config.bat` on your USB drives before running `RUN_LOCKDOWN.bat`:

| Lab | Role | Machine Count | Example IP / Range | Subnet Mask | Default Gateway |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Lab 1** | DOMserver (`LAB1_DOMSERVER_IP`) | 1 | `192.168.1.100` | `255.255.255.0` | None (Blank) |
| **Lab 1** | Judgehosts (`1A`, `1B`) | 2 | `192.168.1.101` – `192.168.1.102` | `255.255.255.0` | None (Blank) |
| **Lab 1** | Contestant PCs | 26 | `192.168.1.11` – `192.168.1.30` | `255.255.255.0` | None (Blank) |
| **Lab 2** | DOMserver (`LAB2_DOMSERVER_IP`) | 1 | `192.168.2.100` | `255.255.255.0` | None (Blank) |
| **Lab 2** | Judgehosts (`2A`, `2B`) | 2 | `192.168.2.101` – `192.168.2.102` | `255.255.255.0` | None (Blank) |
| **Lab 2** | Contestant PCs | 14 | `192.168.2.11` – `192.168.2.30` | `255.255.255.0` | None (Blank) |
| **Lab 3** | DOMserver (`LAB3_DOMSERVER_IP`) | 1 | `192.168.3.100` | `255.255.255.0` | None (Blank) |
| **Lab 3** | Judgehosts (`3A`, `3B`) | 2 | `192.168.3.101` – `192.168.3.102` | `255.255.255.0` | None (Blank) |
| **Lab 3** | Contestant PCs | 20 | `192.168.3.11` – `192.168.3.30` | `255.255.255.0` | None (Blank) |

---

## 3. The Two Layers of Isolation

### Layer 1: Physical / Switch Isolation (Primary Defense)
* Unplug the WAN / internet uplink cables from the **3 lab switches** (or the campus backbone uplink feeding them).
* Without a physical uplink, no packet can leave the labs under any circumstances.
* Each lab's ~20 contestant PCs communicate only with their respective DOMserver, and each DOMserver communicates with its 2 Judgehosts at full LAN speed.

### Layer 2: Host-based Network & Update Lockdown (`RUN_LOCKDOWN.bat` / `02_lockdown_network.ps1`)
Because each lab switch is physically air-gapped from the internet:
1. **Windows Firewall Turned OFF:**
   * `02_lockdown_network.ps1` turns **OFF** Windows Firewall across all profiles (`Domain`, `Private`, `Public`) so local DOMjudge HTTP/HTTPS traffic and ping diagnostics are never blocked by Windows Firewall rules.
2. **Wi-Fi Adapter Disabling:**
   * Automatically scans for and disables any Wireless / Wi-Fi / 802.11 adapters so contestants cannot bypass the wired air-gap via campus Wi-Fi or mobile hotspots.
3. **Windows Update Freezing:**
   * Disables `wuauserv`, `DoSvc`, `UsoSvc`, `WaaSMedicSvc` and sets `NoAutoUpdate=1` / `AUOptions=2` in the registry so background updates or forced restarts never interrupt the contest.

---

## 4. DHCP & Server Connection

1. **Option A: Local DHCP (Recommended per Lab)**
   * Run a local DHCP server on each lab's DOMserver or unmanaged router (with WAN unplugged).
   * **Do not configure a default gateway** in DHCP options so Windows never attempts to route outside the lab.
   * Contestants access their lab's DOMjudge instance directly via its IP (e.g. `http://192.168.1.100`).
2. **Option B: Static IPs**
   * Leave the local IP and subnet mask intact and set the **Default Gateway** and **DNS Server** fields completely blank on contestant PCs.
