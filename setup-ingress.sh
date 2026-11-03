#!/bin/bash

MASTER1="192.168.122.11"

echo "=========================================="
echo " 1. Installing MetalLB Load Balancer..."
echo "=========================================="
ssh -o StrictHostKeyChecking=no amila@$MASTER1 << 'SSHEOF'
# MetalLB Native Manifest 
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml

# MetalLB Pods Ready 
echo "Waiting for MetalLB to start..."
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=120s

# IPAddressPool and L2Advertisement CRDs IP Range 
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.122.200-192.168.122.240
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
EOF
SSHEOF

echo "=========================================="
echo " 2. Installing NGINX Ingress Controller..."
echo "=========================================="
ssh -o StrictHostKeyChecking=no amila@$MASTER1 << 'SSHEOF'
# NGINX Ingress (Cloud Provider version for LoadBalancer Support) save
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml

echo "Waiting for NGINX Ingress pods..."
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
SSHEOF

echo "=========================================="
echo " MetalLB and Ingress Installation Complete!"
echo "=========================================="
