# =============================================================================
# Stage 1: The Builder
# =============================================================================
FROM almalinux:9-minimal AS builder

# Install Build Dependencies
RUN microdnf install -y --enablerepo=crb \
    git gcc make automake autoconf libtool pkgconf \
    libnl3-devel readline-devel libpcap-devel binutils-devel kernel-headers \
    openssl-devel lksctp-tools-devel elfutils-libelf-devel zlib-devel \
    python3-devel \
    golang tar gzip wget \
    && microdnf clean all

WORKDIR /build

# --- 1. Dropwatch ---
RUN git clone https://github.com/nhorman/dropwatch.git
WORKDIR /build/dropwatch
RUN ./autogen.sh && ./configure && make

# --- 2. Iperf3 (Static) ---
WORKDIR /build
RUN git clone https://github.com/esnet/iperf.git
WORKDIR /build/iperf
RUN ./configure --disable-shared --enable-static && make

# --- 3. Netperf ---
WORKDIR /build
RUN git clone https://github.com/HewlettPackard/netperf.git
WORKDIR /build/netperf
RUN ./autogen.sh && ./configure --enable-demo=yes && make

# --- 4. Uperf ---
WORKDIR /build
RUN git clone https://github.com/uperf/uperf.git
WORKDIR /build/uperf
RUN autoreconf -i && ./configure && make

# --- 5. k8s-netperf ---
WORKDIR /build
RUN git clone https://github.com/cloud-bulldozer/k8s-netperf.git
WORKDIR /build/k8s-netperf
RUN go build -o k8s-netperf ./cmd/k8s-netperf

# --- 6. Clients ---
WORKDIR /build/clients

# FIX: Removed 'mv oc ...' because tar extracts it right where we want it
RUN curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz | tar -xz \
    && chmod +x oc

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl

# =============================================================================
# Stage 2: Net-Kunai Runtime
# =============================================================================
FROM almalinux:9-minimal

# 1. Install EPEL
RUN microdnf install -y epel-release

# 2. Install Tools via Package Manager
RUN microdnf install -y \
    binutils \
    libnl3 \
    readline \
    libpcap \
    openssl \
    lksctp-tools \
    tcpdump \
    nmap-ncat \
    hping3 \
    bmon \
    iftop \
    ethtool \
    socat \
    mtr \
    bind-utils \
    conntrack-tools \
    iproute \
    procps-ng \
    wireguard-tools \
    sshuttle \
    openssh-clients \
    clang \
    llvm \
    python3 \
    && microdnf clean all

# 3. Copy Compiled Binaries
COPY --from=builder /build/dropwatch/src/dropwatch /usr/local/bin/dropwatch
COPY --from=builder /build/iperf/src/iperf3 /usr/local/bin/iperf3
COPY --from=builder /build/netperf/src/netperf /usr/local/bin/netperf
COPY --from=builder /build/netperf/src/netserver /usr/local/bin/netserver
COPY --from=builder /build/uperf/src/uperf /usr/local/bin/uperf
COPY --from=builder /build/k8s-netperf/k8s-netperf /usr/local/bin/k8s-netperf
COPY --from=builder /build/clients/oc /usr/local/bin/oc
COPY --from=builder /build/clients/kubectl /usr/local/bin/kubectl

# --- 4. RETIS (From Official Image) ---
# We verify the path in the official image to be sure
COPY --from=quay.io/retis/retis:latest /usr/bin/retis /usr/local/bin/retis

# Alias for 'nc'
RUN ln -sf /usr/bin/ncat /usr/bin/nc

ENTRYPOINT ["/bin/bash"]