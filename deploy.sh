#!/bin/bash

PUB_KEY=$(cat ~/.ssh/k8s_key.pub)

create_vm() {
    NAME=$1
    RAM=$2
    VCPU=$3
    OS_DISK=$4
    IS_WORKER=$5
    MAC=$6

    echo "Creating VM: $NAME with Static MAC $MAC..."
    
    cat <<EOF > user-data-${NAME}.yaml
#cloud-config
hostname: $NAME
manage_etc_hosts: true
users:
  - name: amila
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $PUB_KEY
runcmd:
  - swapoff -a
  - sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
EOF

    cp images/ubuntu-base.qcow2 images/${NAME}.qcow2
    qemu-img resize images/${NAME}.qcow2 ${OS_DISK}G
    
    cloud-localds images/${NAME}-seed.img user-data-${NAME}.yaml
    
    EXTRA_DISK_ARG=""
    if [ "$IS_WORKER" == "yes" ]; then
        qemu-img create -f qcow2 images/${NAME}-data.qcow2 20G
        EXTRA_DISK_ARG="--disk path=images/${NAME}-data.qcow2,device=disk,bus=virtio"
    fi

    virt-install \
        --name $NAME \
        --memory $RAM \
        --vcpus $VCPU \
        --disk path=images/${NAME}.qcow2,device=disk,bus=virtio \
        $EXTRA_DISK_ARG \
        --disk path=images/${NAME}-seed.img,device=cdrom \
        --os-variant ubuntu24.04 \
        --network network=default,model=virtio,mac=$MAC \
        --import \
        --noautoconsole
}

create_vm "k8s-haproxy" 512 1 10 "no" "52:54:00:00:00:10"
create_vm "k8s-master-1" 2048 2 20 "no" "52:54:00:00:00:11"
create_vm "k8s-master-2" 2048 2 20 "no" "52:54:00:00:00:12"
create_vm "k8s-master-3" 2048 2 20 "no" "52:54:00:00:00:13"
create_vm "k8s-worker-1" 4096 2 40 "yes" "52:54:00:00:00:21"
create_vm "k8s-worker-2" 4096 2 40 "yes" "52:54:00:00:00:22"
create_vm "k8s-worker-3" 4096 2 40 "yes" "52:54:00:00:00:23"

echo "All VMs are provisioned with Static IPs!"
