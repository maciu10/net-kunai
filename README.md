# 🥷 Net-Kunai

![Platform](https://img.shields.io/badge/platform-linux%2Famd64-blue)
![Base Image](https://img.shields.io/badge/base-AlmaLinux%209-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

**The Network Ninja's Multi-Tool for Kubernetes & OpenShift**

**Net-Kunai** is a specialized, lightweight container image designed to be a "Swiss Army Knife" for network engineers, SREs, and developers debugging complex networking issues in Kubernetes, OpenShift, and Linux environments.

It combines low-level kernel diagnostic tools (like `dropwatch` and `retis`) with standard performance testers (`iperf3`, `netperf`) and utility clients (`oc`, `kubectl`, `sshuttle`).

---

## 📦 Tool Inventory & Sources

This image mixes tools compiled from the latest source (for bleeding-edge features) with stable enterprise packages.

| Tool | Source | Version Notes | Check Command |
| :--- | :--- | :--- | :--- |
| **Dropwatch** | 🏗 Compiled | Latest Git `HEAD` | `dropwatch -v` |
| **Retis** | 🐳 Official | Extracted from `quay.io/retis/retis` | `retis --version` |
| **Iperf3** | 🏗 Compiled | Latest Git `HEAD` (Static Build) | `iperf3 -v` |
| **Netperf** | 🏗 Compiled | Latest Git `HEAD` | `netperf -V` |
| **Uperf** | 🏗 Compiled | Latest Git `HEAD` | `uperf -V` |
| **k8s-netperf** | 🏗 Compiled | Latest Git `HEAD` (Go) | `k8s-netperf --help` |
| **OC Client** | 📥 Download | OpenShift v4 Stable | `oc version` |
| **Kubectl** | 📥 Download | Kubernetes Stable | `kubectl version --client` |
| **Tcpdump** | 📦 RPM | AlmaLinux 9 / AppStream | `tcpdump --version` |
| **Hping3** | 📦 RPM | EPEL 9 | `hping3 -v` |
| **WireGuard** | 📦 RPM | EPEL 9 | `wg --version` |
| **Sshuttle** | 📦 RPM | EPEL 9 | `sshuttle --version` |
| **Bmon** | 📦 RPM | EPEL 9 | `bmon -v` |
| **Iftop** | 📦 RPM | EPEL 9 | `iftop -h` |

---

## 🚀 Quick Start

> [!WARNING]
> **Privileged Access Required**
> Net-Kunai requires privileged access to the host kernel (for Dropwatch, Retis, and WireGuard) and access to the host network namespace. Do not deploy this on untrusted multi-tenant nodes.

### Step 1: Create Identity & Permissions

First, create a `ServiceAccount` and grant it the necessary privileges.

**For OpenShift (OCP)**
```bash
oc create sa net-kunai
oc adm policy add-scc-to-user privileged -z net-kunai