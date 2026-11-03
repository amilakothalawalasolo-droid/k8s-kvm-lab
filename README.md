# Production-Grade Kubernetes HA Cluster on KVM

This repository contains the Infrastructure as Code (IaC) and automation scripts to provision a highly available Kubernetes cluster on local KVM virtualization.

## Architecture
- **Virtualization:** KVM / libvirt
- **OS:** Ubuntu 24.04 Cloud Images
- **Load Balancer:** HAProxy (192.168.122.10)
- **Control Plane:** 3x Master Nodes (192.168.122.11, .12, .13)
- **Worker Nodes:** 3x Worker Nodes (192.168.122.21, .22, .23) with extra 20GB disks.
- **CNI:** Cilium (eBPF)
- **Storage:** Longhorn Distributed Block Storage
- **External LoadBalancer / Ingress:** MetalLB (192.168.122.200-240) + NGINX Ingress Controller

## Execution Order

Run the scripts in the following order from the KVM host machine:

1. **`./deploy.sh`**
   - Provisions 7 VMs via cloud-init.
   - Sets up static IPs, SSH keys (Zero-Trust), and 20GB extra disks for workers.

2. **`./install-prereqs.sh`**
   - Configures HAProxy.
   - Installs containerd, kubeadm, kubelet, and kubectl on all 6 K8s nodes.

3. **`./k8s-bootstrap.sh`**
   - Initializes the cluster on Master-1 via HAProxy endpoint.
   - Generates join commands and attaches Master-2, Master-3, and all Worker nodes.
   - Installs Cilium CNI.

4. **`./setup-storage.sh`**
   - Installs `open-iscsi` and mounts `/dev/vdb` on worker nodes.
   - Deploys Longhorn Distributed Storage to the cluster.

5. **`./setup-ingress.sh`**
   - Deploys MetalLB and configures the IP address pool.
   - Deploys the NGINX Ingress Controller.

## Verification
- Check Nodes: `kubectl get nodes`
- Check Storage: `kubectl get pods -n longhorn-system`
- Check Ingress: `kubectl get svc -n ingress-nginx`
