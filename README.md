🥷 Net-KunaiThe Network Ninja's Multi-Tool for Kubernetes & OpenShiftNet-Kunai is a specialized, lightweight container image built on AlmaLinux 9 Minimal. It is designed to be a "Swiss Army Knife" for network engineers, SREs, and developers debugging complex networking issues in Kubernetes, OpenShift, and Linux environments.It combines low-level kernel diagnostic tools (like dropwatch and retis) with standard performance testers (iperf3, netperf) and utility clients (oc, kubectl, sshuttle).📦 Tool Inventory & SourcesThis image mixes tools compiled from source (for the latest features), official binaries, and stable enterprise packages.ToolSource TypeVersion NotesCheck Version CommandDropwatch🏗 CompiledLatest Git HEADdropwatch -vRetis🐳 ExtractedFrom Official quay.io/retis/retisretis --versionIperf3🏗 CompiledLatest Git HEAD (Static Build)iperf3 -vNetperf🏗 CompiledLatest Git HEADnetperf -VUperf🏗 CompiledLatest Git HEADuperf -Vk8s-netperf🏗 CompiledLatest Git HEAD (Go)k8s-netperf --helpOC Client📥 DownloadedOpenShift v4 Stable Channeloc versionKubectl📥 DownloadedKubernetes Stable Releasekubectl version --clientTcpdump📦 RPMAlmaLinux 9 / AppStreamtcpdump --versionHping3📦 RPMEPEL 9hping3 -vWireGuard📦 RPMEPEL 9wg --versionSshuttle📦 RPMEPEL 9sshuttle --versionBmon📦 RPMEPEL 9bmon -vIftop📦 RPMEPEL 9iftop -hNote on Compilation: This image builds several tools from their master/main branches. If you require a pinned version (e.g., Iperf 3.16), you must modify the Dockerfile git clone command to include --branch 3.16.🚀 Quick Start (Manifest Method)Net-Kunai requires privileged access to the host kernel (for Dropwatch, Retis, and WireGuard) and access to the host network namespace.Step 1: Create Identity & PermissionsFirst, create a ServiceAccount and grant it the necessary privileges.For OpenShift (OCP)Run these commands to create the account and grant it the privileged Security Context Constraint (SCC).Bashoc create sa net-kunai
oc adm policy add-scc-to-user privileged -z net-kunai
For Vanilla Kubernetes(If your cluster enforces Pod Security Standards, ensure the net-kunai namespace allows privileged pods).Bashkubectl create sa net-kunai
Step 2: Deploy the PodSave the following YAML as net-kunai.yaml and apply it, or copy-paste it directly into your terminal.This manifest mounts the necessary kernel directories (/sys, /boot, /lib/modules) required for eBPF tools like retis and dropwatch to function.YAMLapiVersion: v1
kind: Pod
metadata:
  name: net-kunai
  labels:
    app: net-kunai
spec:
  # Use the ServiceAccount we created
  serviceAccountName: net-kunai
  
  # Essential for network debugging
  hostNetwork: true
  hostPID: true
  
  # Ensure it lands on a Linux node
  nodeSelector:
    kubernetes.io/os: linux

  containers:
  - name: net-kunai
    image: quay.io/YOUR_USER/net-kunai:latest
    imagePullPolicy: Always
    
    # Keep the pod running indefinitely
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
Apply it:Bashkubectl apply -f net-kunai.yaml
Step 3: Enter the DojoOnce the pod is running, attach to the shell to start troubleshooting.Bashkubectl exec -it net-kunai -- /bin/bash
You are now inside the node's network namespace with full root privileges.Step 4: CleanupWhen you are finished, delete the pod and the service account.Bashkubectl delete pod net-kunai
kubectl delete sa net-kunai
🛠 Building the ImagePrerequisitesDocker or Podman~4GB of RAM allocated to Docker/PodmanStandard Build (Linux/Intel)Bashdocker build -t quay.io/YOUR_USER/net-kunai:latest .
Cross-Compile (Apple Silicon M1/M4 -> AMD64)If you are on a Mac building for an Intel/AMD cluster, you must use the platform flag to ensure the binaries work on your servers.Bashpodman build --platform linux/amd64 -t quay.io/YOUR_USER/net-kunai:latest .
🧭 Troubleshooting Decision MapUse this map to select the right tool for your problem.SymptomSuspectUse This ToolAction"Connection Refused"Firewall / App Downnc or hping3Test TCP handshake on specific ports.Random TimeoutsPacket LossmtrRun trace to find which hop is dropping packets."Silent" DropsKernel/Driver DropsdropwatchListen to kernel kfree_skb events.Slow ThroughputBandwidth Limitiperf3Saturate link to test max capacity.Slow Request/ResponseLatency / JitternetperfRun TCP_RR test to check transaction speed.Unknown Traffic HogNoise / DDoSiftopSee "Top Talkers" in real-time.CNI / Routing IssuesRouting Table / BPFretisTrace packet path through the kernel stack.DNS FailuresCoreDNS / UpstreamdigQuery internal K8s DNS and upstream resolvers.Restricted NetworkPrivate SubnetsshuttleVPN into the subnet via a jump host.🧰 Detailed Tool Usage1. Kernel & Packet ForensicsDropwatchBest For: Finding "silent" packet drops that tcpdump can't explain.Usage:Bash# 1. Initialize with Kernel Address Space lookup
dropwatch -l kas

# 2. Start monitoring
> start

# 3. Output Example:
# 1 drops at tcp_v4_rcv+80 (0xffffffff81789a00)
RetisBest For: Visualizing the full path of a packet through OVS, iptables, and the kernel.Usage:Bash# Trace all dropped packets
retis collect -e drops

# Trace traffic to a specific pod IP
retis collect -f "ip.daddr == 10.128.2.50"
TcpdumpBest For: Verifying packet arrival on an interface.Usage:Bash# Capture port 80 traffic, no DNS resolution (-n), verbose (-v)
tcpdump -i any port 80 -nn -v
2. Performance & Stress TestingIperf3Best For: Testing raw bandwidth (Gbps).Usage:Bash# Server Mode (Run this on Node A)
iperf3 -s

# Client Mode (Run this on Node B)
iperf3 -c <node_a_ip>
NetperfBest For: Testing latency and transaction speed (Requests Per Second).Usage:Bash# Test Transaction Rate (Request/Response)
netperf -H <target_ip> -t TCP_RR
Hping3Best For: Testing firewall rules by manually crafting packets (e.g., SYN injection).Usage:Bash# Send SYN packets to port 80 (Simulate TCP Connect)
hping3 -S -p 80 <target_ip>
3. Utilities & ConnectivitySshuttleBest For: Accessing a private network/subnet from your laptop via the container.Usage:Bash# Proxy all traffic for 10.0.0.0/24 through a bastion host
sshuttle -r user@bastion.example.com 10.0.0.0/24
WireGuard Tools (wg)Best For: Debugging CNI plugins that use WireGuard (e.g., OVN-Kubernetes IPsec).Usage:Bash# Show active tunnels
wg show
SocatBest For: Port forwarding or connecting data streams.Usage:Bash# Forward local port 8080 to remote google port 80
socat TCP-LISTEN:8080,fork TCP:google.com:80
MTR (My Traceroute)Best For: Diagnosing packet loss at specific network hops.Usage:Bashmtr 8.8.8.8
