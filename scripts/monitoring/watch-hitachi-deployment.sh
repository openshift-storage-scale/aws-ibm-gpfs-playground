#!/bin/bash

# Continuous Hitachi Deployment Monitor
# Watches deployment progress and alerts on status changes

KUBECONFIG="${KUBECONFIG:-$HOME/aws-gpfs-playground/ocp_install_files/auth/kubeconfig}"
REGION="${1:-eu-north-1}"
STACK_NAME="${2:-hitachi-sds-block-gpfs-levanon-c4qpp}"
INTERVAL="${3:-30}"  # Check every 30 seconds by default

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="$SCRIPT_DIR/monitor-hitachi-deployment.sh"

echo "Starting continuous Hitachi deployment monitor..."
echo "Checking every $INTERVAL seconds"
echo "Press Ctrl+C to stop"
echo ""

LAST_STATUS=""

while true; do
    clear
    echo "=== Hitachi Deployment Monitor (Continuous) ==="
    echo "Updated: $(date)"
    echo "Stack: $STACK_NAME (Region: $REGION)"
    echo ""
    
    # Run the main monitoring script
    "$MONITOR_SCRIPT" "$REGION" "$STACK_NAME"
    
    # Get current status for comparison
    CURRENT_STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "UNKNOWN")
    
    # Alert on status change
    if [ "$LAST_STATUS" != "$CURRENT_STATUS" ] && [ -n "$LAST_STATUS" ]; then
        echo ""
        echo "⚠️  STATUS CHANGED: $LAST_STATUS → $CURRENT_STATUS"
        if command -v notify-send &> /dev/null; then
            notify-send "Hitachi Deployment" "Status changed to: $CURRENT_STATUS"
        fi
    fi
    
    LAST_STATUS="$CURRENT_STATUS"
    
    echo ""
    echo "Waiting $INTERVAL seconds before next check... (Ctrl+C to stop)"
    sleep "$INTERVAL"
done
