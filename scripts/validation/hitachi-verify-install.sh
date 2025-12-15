#!/bin/bash
set -e

# Hitachi Installation Verification Script

echo "Verifying Hitachi SDS Installation"
echo "===================================="

# Check Kubernetes connectivity
echo "1. Checking Kubernetes connectivity..."
if kubectl cluster-info &> /dev/null; then
  echo "   ✅ Kubernetes cluster accessible"
else
  echo "   ❌ Kubernetes cluster not accessible"
  exit 1
fi

# Check CSI driver status
echo ""
echo "2. Checking CSI driver status..."
if kubectl get csidriver 2>/dev/null | grep -q "hitachi"; then
  echo "   ✅ Hitachi CSI driver installed"
else
  echo "   ⚠️  Hitachi CSI driver not yet deployed"
fi

# Check storage classes
echo ""
echo "3. Checking storage classes..."
if kubectl get storageclass 2>/dev/null | grep -q "hitachi"; then
  echo "   ✅ Hitachi storage class available"
  kubectl get storageclass -o wide | grep hitachi
else
  echo "   ⚠️  Hitachi storage class not found"
fi

# Check namespaces
echo ""
echo "4. Checking namespaces..."
if kubectl get namespace hitachi-system 2>/dev/null; then
  echo "   ✅ Hitachi namespace exists"
  echo ""
  echo "   Hitachi pods:"
  kubectl get pods -n hitachi-system 2>/dev/null || echo "     (no pods yet)"
else
  echo "   ⚠️  Hitachi namespace not found"
fi

echo ""
echo "✅ Verification complete!"
