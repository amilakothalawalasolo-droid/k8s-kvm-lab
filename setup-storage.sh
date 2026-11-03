#!/bin/bash

WORKERS=("192.168.122.21" "192.168.122.22" "192.168.122.23")

echo "=========================================="
echo " Preparing Worker Nodes for Longhorn..."
echo "=========================================="

for WORKER in "${WORKERS[@]}"; do
    echo ">>> Configuring Storage on $WORKER"
    ssh -o StrictHostKeyChecking=no amila@$WORKER << 'SSHEOF'
    
    sudo apt-get update >/dev/null
    sudo apt-get install -y open-iscsi nfs-common
    sudo systemctl enable --now iscsid

    if ! grep -q "/var/lib/longhorn" /etc/fstab; then
        echo "Formatting and mounting /dev/vdb..."
        sudo mkfs.ext4 /dev/vdb
        sudo mkdir -p /var/lib/longhorn
        echo "/dev/vdb /var/lib/longhorn ext4 defaults 0 0" | sudo tee -a /etc/fstab
        sudo mount -a
    else
        echo "Disk already mounted."
    fi
SSHEOF
done

echo "=========================================="
echo " Storage Preparation Complete!"
echo "=========================================="
