# Kubernetes HA Production Lab on KVM

This repository contains the Infrastructure as Code (IaC) scripts to provision a 7-Node High Availability Kubernetes Cluster (1 HAProxy, 3 Masters, 3 Workers) on a KVM host using Ubuntu Cloud Images and cloud-init.

## Architecture
* **HAProxy Load Balancer:** 1 Node
* **Control Plane:** 3 Nodes
* **Worker Nodes:** 3 Nodes (with extra disks for Longhorn storage)

## Deployment
Run the `deploy.sh` script to automatically provision the VMs with static IPs and MAC addresses.
