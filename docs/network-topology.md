# Network Topology & Air-Gap Guidelines

This document outlines the recommended network topology for running an internet-free ICPC contest across 60 client workstations and a local contest server.

---

## 1. Network Architecture Diagram

```
                 [ Physical WAN / Outside Campus Internet ]
                                     |
                          [ X ] DISCONNECTED!
                                     |
               +-------------------------------------------+
               |       Lab Core Switch (e.g., 24/48-port)  |
               +-------------------------------------------+
                     |                  |             |
      +--------------+                  |             +---------------+
      |                                 |                             |
+--------------------------+  +--------------------------+  +--------------------------+
| Contest Server           |  | Contest Workstations     |  | Backup / Print Server    |
| - IP: 192.168.1.100      |  | - IPs: 192.168.1.101-160 |  | - IP: 192.168.1.200      |
| - DOMjudge / PC^2 Server |  | - 60 Client Machines     |  | - Code Print Queue       |
| - DHCP Server (Optional) |  | - Locked Windows OS      |  +--------------------------+
+--------------------------+  +--------------------------+
```

---

## 2. Recommended IP Addressing Plan

| Device Type | Hostname / Description | IP Address Range | Subnet Mask | Default Gateway |
| :--- | :--- | :--- | :--- | :--- |
| **Contest Server** | `domjudge-primary` | `192.168.1.100` | `255.255.255.0` | None (Blank) |
| **Print Server** | `print-server` | `192.168.1.200` | `255.255.255.0` | None (Blank) |
| **Judge Workstations** | `judge-01` to `04` | `192.168.1.10` - `192.168.1.15` | `255.255.255.0` | None (Blank) |
| **Contestant PCs** | `pc-01` to `pc-60` | `192.168.1.101` - `192.168.1.160` | `255.255.255.0` | None (Blank) |

---

## 3. The Two Layers of Isolation

### Layer 1: Physical / Switch Isolation (Primary Defense)
* The most secure and fool-proof way to disable the internet is to **unplug the uplink cable** connecting the computer lab's main switch to the campus backbone.
* Without a physical uplink, packets cannot leave the room under any circumstances.
* All 60 client PCs can still communicate with the local server at gigabit speeds over the local switch.

### Layer 2: Host-based Windows Firewall (Defense-in-Depth)
* Even if an accidental uplink cable or rogue WiFi network is connected:
  * `02_lockdown_network.ps1` sets the default Windows outbound action to **BLOCK**.
  * Only packets destined for the `192.168.1.0/24` subnet are permitted.
  * Packets to `8.8.8.8`, external domain names, or other subnets are dropped at the kernel driver level.

---

## 4. DHCP and Name Resolution

1. **Option A: Router/Server DHCP (Recommended)**
   * Run a simple DHCP server on the contest server or a dedicated unmanaged router with WAN unplugged.
   * Configure DHCP pool: `192.168.1.101` - `192.168.1.160`.
   * **Do not configure a default gateway** in the DHCP options. This prevents Windows from even attempting to look for an internet route.
   * Set DNS to `192.168.1.100` (pointing to the DOMjudge server) or leave blank and access the server via its direct IP: `http://192.168.1.100`.

2. **Option B: Static IPs**
   * If the lab already has hardcoded static IP addresses, simply leave the IP and Subnet mask intact and set the **Default Gateway** and **DNS Server** fields completely blank.

