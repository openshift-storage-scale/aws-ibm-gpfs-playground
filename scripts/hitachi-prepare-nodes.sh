#!/bin/bash
set -e

# Hitachi Node Preparation Script
# Generates Ansible inventory from Terraform output

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INVENTORY_FILE="$PROJECT_ROOT/config/hitachi/inventory/hitachi-hosts.yml"

echo "Preparing Hitachi SDS nodes..."
echo "==============================="

# Get Terraform outputs
cd "$PROJECT_ROOT/terraform"
NODE_IPS=$(terraform output -raw hitachi_node_ips 2>/dev/null | tr ',' '\n' | tr -d '[]" ')
NODE_PUBLIC_IPS=$(terraform output -raw hitachi_node_public_ips 2>/dev/null | tr ',' '\n' | tr -d '[]" ')
NODE_IDS=$(terraform output -raw hitachi_node_ids 2>/dev/null | tr ',' '\n' | tr -d '[]" ')

# Create inventory file
mkdir -p "$(dirname "$INVENTORY_FILE")"
cat > "$INVENTORY_FILE" << 'EOF'
---
all:
  hosts:
EOF

# Add nodes to inventory
NODE_INDEX=0
while IFS= read -r ip; do
  [ -z "$ip" ] && continue
  cat >> "$INVENTORY_FILE" << EOF
    hitachi-node-$NODE_INDEX:
      ansible_host: $ip
      ansible_user: ubuntu
      ansible_become: true
      node_id: $NODE_INDEX
EOF
  NODE_INDEX=$((NODE_INDEX + 1))
done <<< "$NODE_IPS"

cat >> "$INVENTORY_FILE" << 'EOF'
  
  children:
    hitachi_nodes:
      hosts:
EOF

# Add all nodes to hitachi_nodes group
NODE_INDEX=0
while IFS= read -r ip; do
  [ -z "$ip" ] && continue
  echo "        hitachi-node-$NODE_INDEX:" >> "$INVENTORY_FILE"
  NODE_INDEX=$((NODE_INDEX + 1))
done <<< "$NODE_IPS"

echo "✅ Inventory file created: $INVENTORY_FILE"
echo ""
echo "Nodes configured:"
NODE_INDEX=0
while IFS= read -r ip; do
  [ -z "$ip" ] && continue
  echo "  - hitachi-node-$NODE_INDEX: $ip"
  NODE_INDEX=$((NODE_INDEX + 1))
done <<< "$NODE_IPS"

# Test SSH connectivity
echo ""
echo "Testing SSH connectivity..."
NODE_INDEX=0
while IFS= read -r ip; do
  [ -z "$ip" ] && continue
  if timeout 5 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "ubuntu@$ip" "echo" 2>/dev/null; then
    echo "  ✅ hitachi-node-$NODE_INDEX: SSH OK"
  else
    echo "  ⚠️  hitachi-node-$NODE_INDEX: SSH failed (instance may still be booting)"
  fi
  NODE_INDEX=$((NODE_INDEX + 1))
done <<< "$NODE_IPS"

echo ""
echo "✅ Node preparation complete!"
