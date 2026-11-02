#!/bin/bash

HAPROXY="192.168.122.10"
MASTER1="192.168.122.11"
MASTER2="192.168.122.12"
MASTER3="192.168.122.13"
WORKERS=("192.168.122.21" "192.168.122.22" "192.168.122.23")

echo "=========================================="
echo " 1. Initializing Cluster on Master-1"
echo "=========================================="
ssh -o StrictHostKeyChecking=no amila@$MASTER1 << 'SSHEOF'
sudo kubeadm init --control-plane-endpoint "192.168.122.10:6443" --upload-certs --pod-network-cidr "10.244.0.0/16"

# Configuring Kubectl for local user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
SSHEOF

echo "=========================================="
echo " 2. Generating Join Commands"
echo "=========================================="
CERT_KEY=$(ssh amila@$MASTER1 "sudo kubeadm init phase upload-certs --upload-certs | tail -1")
JOIN_CMD=$(ssh amila@$MASTER1 "sudo kubeadm token create --print-join-command")

MASTER_JOIN="sudo $JOIN_CMD --control-plane --certificate-key $CERT_KEY"
WORKER_JOIN="sudo $JOIN_CMD"

echo "=========================================="
echo " 3. Joining Master-2 and Master-3"
echo "=========================================="
for MASTER in $MASTER2 $MASTER3; do
    echo "Joining $MASTER..."
    ssh -o StrictHostKeyChecking=no amila@$MASTER << SSHEOF
$MASTER_JOIN
mkdir -p \$HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config
SSHEOF
done

echo "=========================================="
echo " 4. Joining Worker Nodes"
echo "=========================================="
for WORKER in "${WORKERS[@]}"; do
    echo "Joining $WORKER..."
    ssh -o StrictHostKeyChecking=no amila@$WORKER "$WORKER_JOIN"
done

echo "=========================================="
echo " 5. Installing Cilium CNI (on Master-1)"
echo "=========================================="
ssh -o StrictHostKeyChecking=no amila@$MASTER1 << 'SSHEOF'
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz
cilium install
cilium status --wait
SSHEOF

echo "=========================================="
echo " Bootstrap and CNI Installation Complete!"
echo "=========================================="
