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

```

**For Vanilla Kubernetes**
*(Ensure your namespace allows privileged pods)*

```bash
kubectl create sa net-kunai

```

### Step 2: Deploy the Pod

Copy the following YAML to a file named `net-kunai.yaml` and apply it. This configures the necessary host mounts (`/sys`, `/boot`, `/lib/modules`) for eBPF tools.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: net-kunai
  labels:
    app: net-kunai
spec:
  serviceAccountName: net-kunai
  hostNetwork: true
  hostPID: true
  nodeSelector:
    kubernetes.io/os: linux
  containers:
  - name: net-kunai
    image: quay.io/YOUR_USER/net-kunai:latest
    imagePullPolicy: Always
    command: ["/bin/bash", "-c", "sleep infinity"]
    securityContext:
      privileged: true
      capabilities:
        add: ["NET_ADMIN", "SYS_ADMIN", "SYS_PTRACE"]
    volumeMounts:
    - name: modules
      mountPath: /lib/modules
      readOnly: true
    - name: sys
      mountPath: /sys
      readOnly: true
    - name: boot
      mountPath: /boot
      readOnly: true
  volumes:
  - name: modules
    hostPath:
      path: /lib/modules
      type: Directory
  - name: sys
    hostPath:
      path: /sys
      type: Directory
  - name: boot
    hostPath:
      path: /boot
      type: Directory

```

**Apply it:**

```bash
kubectl apply -f net-kunai.yaml

```

### Step 3: Enter the Dojo

Attach to the shell to start troubleshooting.

```bash
kubectl exec -it net-kunai -- /bin/bash

```

> [!TIP]
> You are now inside the node's network namespace with full root privileges. Be careful!

### Step 4: Cleanup

When you are finished, delete the pod and the service account.

```bash
kubectl delete pod net-kunai
kubectl delete sa net-kunai

```

---

## 🧭 Troubleshooting Decision Map

Not sure which tool to use? Follow this flow.

```mermaid
graph TD
    A[Start: What is the symptom?] -->|Connection Refused| B(Check TCP Handshake)
    A -->|Random Timeouts| C(Check Packet Loss)
    A -->|Silent Drops| D(Check Kernel Drops)
    A -->|Slow Throughput| E(Check Bandwidth)
    A -->|Slow Latency| F(Check Transaction Speed)
    A -->|Unknown Traffic Hog| G(Check Top Talkers)
    A -->|Routing/CNI Issues| H(Trace Packet Path)
    
    B --> I[Tool: <b>nc / hping3</b>]
    C --> J[Tool: <b>mtr</b>]
    D --> K[Tool: <b>dropwatch</b>]
    E --> L[Tool: <b>iperf3</b>]
    F --> M[Tool: <b>netperf</b>]
    G --> N[Tool: <b>iftop</b>]
    H --> O[Tool: <b>retis</b>]

```

| Symptom | Primary Suspect | **Use This Tool** |
| --- | --- | --- |
| **"Connection Refused"** | Firewall / App Down | `nc` or `hping3` |
| **Random Timeouts** | Packet Loss | `mtr` |
| **"Silent" Drops** | Kernel/Driver Drops | `dropwatch` |
| **Slow Throughput** | Bandwidth Limit | `iperf3` |
| **Slow Request/Response** | Latency / Jitter | `netperf` |
| **Unknown Traffic Hog** | Noise / DDoS | `iftop` |
| **CNI / Routing Weirdness** | Routing Table / BPF | `retis` |
| **DNS Failures** | CoreDNS / Upstream | `dig` |
| **Restricted Network** | Private Subnet | `sshuttle` |

---

## 🛠 Building the Image

### Standard Build (Linux/Intel)

```bash
docker build -t quay.io/YOUR_USER/net-kunai:latest .

```

### Cross-Compile (Apple Silicon M1/M4 -> AMD64)

> [!NOTE]
> If you are on a Mac building for an Intel/AMD cluster, you **must** use the platform flag.

```bash
podman build --platform linux/amd64 -t quay.io/YOUR_USER/net-kunai:latest .

```

---

## 🧰 Detailed Tool Usage

### 1. Kernel & Packet Forensics

<details>
<summary><b>Dropwatch</b> (Click to expand)</summary>

**Best For:** Finding "silent" packet drops that tcpdump can't explain.

```bash
# 1. Initialize with Kernel Address Space lookup
dropwatch -l kas

# 2. Start monitoring
> start

# Output Example:
# 1 drops at tcp_v4_rcv+80 (0xffffffff81789a00)

```

</details>

<details>
<summary><b>Retis</b> (Click to expand)</summary>

**Best For:** Visualizing the full path of a packet through OVS, iptables, and the kernel.

```bash
# Trace all dropped packets
retis collect -e drops

# Trace traffic to a specific pod IP
retis collect -f "ip.daddr == 10.128.2.50"

```

</details>

<details>
<summary><b>Tcpdump</b> (Click to expand)</summary>

**Best For:** Verifying packet arrival on an interface.

```bash
# Capture port 80 traffic, no DNS resolution (-n), verbose (-v)
tcpdump -i any port 80 -nn -v

```

</details>

### 2. Performance & Stress Testing

<details>
<summary><b>Iperf3</b> (Click to expand)</summary>

**Best For:** Testing raw bandwidth (Gbps).

```bash
# Server Mode (Run this on Node A)
iperf3 -s

# Client Mode (Run this on Node B)
iperf3 -c <node_a_ip>

```

</details>

<details>
<summary><b>Netperf</b> (Click to expand)</summary>

**Best For:** Testing latency and transaction speed (Requests Per Second).

```bash
# Test Transaction Rate (Request/Response)
netperf -H <target_ip> -t TCP_RR

```

</details>

<details>
<summary><b>Hping3</b> (Click to expand)</summary>

**Best For:** Testing firewall rules by manually crafting packets (e.g., SYN injection).

```bash
# Send SYN packets to port 80 (Simulate TCP Connect)
hping3 -S -p 80 <target_ip>

```

</details>

### 3. Utilities & Connectivity

* **`sshuttle`**: VPN into a private subnet via a jump host.
```bash
sshuttle -r user@bastion.example.com 10.0.0.0/24

```


* **`wg`**: Debug WireGuard tunnels.
```bash
wg show

```


* **`socat`**: Port forwarding or connecting data streams.
```bash
socat TCP-LISTEN:8080,fork TCP:google.com:80

```


* **`mtr`**: Diagnosing packet loss at specific network hops.
```bash
mtr 8.8.8.8

```



```

