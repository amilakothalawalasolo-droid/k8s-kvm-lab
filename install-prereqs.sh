#!/bin/bash

#  IP 
HAPROXY="192.168.122.10"
MASTERS=("192.168.122.11" "192.168.122.12" "192.168.122.13")
WORKERS=("192.168.122.21" "192.168.122.22" "192.168.122.23")
ALL_K8S_NODES=("${MASTERS[@]}" "${WORKERS[@]}")

echo "=========================================="
echo " 1. Configuring HAProxy Load Balancer..."
echo "=========================================="
ssh -o StrictHostKeyChecking=no amila@$HAPROXY << 'SSHEOF'
sudo apt-get update && sudo apt-get install -y haproxy

# HAProxy Configuration 
cat << HAPROXY_CONF | sudo tee -a /etc/haproxy/haproxy.cfg

frontend kubernetes-frontend
    bind *:6443
    mode tcp
    option tcplog
    default_backend kubernetes-backend

backend kubernetes-backend
    mode tcp
    option tcp-check
    balance roundrobin
    server k8s-master-1 192.168.122.11:6443 check fall 3 rise 2
    server k8s-master-2 192.168.122.12:6443 check fall 3 rise 2
    server k8s-master-3 192.168.122.13:6443 check fall 3 rise 2
HAPROXY_CONF

sudo systemctl restart haproxy
sudo systemctl enable haproxy
SSHEOF
echo "HAProxy Configuration Completed."

echo ""
echo "=========================================================="
echo " 2. Installing Kubernetes Prerequisites on all Nodes..."
echo "=========================================================="

for NODE in "${ALL_K8S_NODES[@]}"; do
    echo ">>> Configuring Node: $NODE"
    ssh -o StrictHostKeyChecking=no amila@$NODE << 'SSHEOF'
    
    # 2.1 - Network & Kernel Modules 
    cat << K8S_MODULES | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
K8S_MODULES
    sudo modprobe overlay
    sudo modprobe br_netfilter

    cat << K8S_SYSCTL | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
K8S_SYSCTL
    sudo sysctl --system >/dev/null

    # 2.2 - Containerd (Container Runtime) 
    sudo apt-get update >/dev/null
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update >/dev/null
    sudo apt-get install -y containerd.io

    # Systemd Cgroup Containerd 
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    sudo systemctl restart containerd
    sudo systemctl enable containerd

    # 2.3 - Kubeadm, Kubelet Kubectl (v1.30)
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
    sudo apt-get update >/dev/null
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
SSHEOF
done

echo "=========================================="
echo " Prerequisites Installation Complete!"
echo "=========================================="
