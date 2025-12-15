#!/bin/bash
##############################################################################
# download-hitachi-charts.sh
# Purpose: Download Hitachi Helm charts from CDN for offline use
# Usage: ./download-hitachi-charts.sh [output-directory] [version]
# Example: ./download-hitachi-charts.sh /home/user/charts 3.14.0
##############################################################################

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../" && pwd)"
LOG_DIR="${PROJECT_ROOT}/Logs"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Setup logging
LOG_FILE="${LOG_DIR}/download-hitachi-charts-$(date +%Y%m%d_%H%M%S).log"

# Redirect all output to log file and console
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=========================================="
echo "Hitachi Helm Charts Download"
echo "Log file: $LOG_FILE"
echo "=========================================="
echo ""

# Configuration
OUTPUT_DIR="${1:-${PROJECT_ROOT}/charts}"
HELM_VERSION="${2:-3.14.0}"
HELM_CHART="vsp-one-sds-hspc"
HELM_REPO_URL="https://cdn.hitachivantara.com/charts/hitachi"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verify prerequisites
log_info "Verifying prerequisites..."

if ! command -v helm &> /dev/null; then
    log_error "helm not found. Please install helm."
    exit 1
fi

log_info "✓ helm is installed: $(helm version --short)"
echo ""

# Create output directory
log_info "Creating output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
log_info "✓ Directory ready"
echo ""

# Add Hitachi Helm repository
log_info "Adding Hitachi Helm repository..."
if helm repo add hitachi "$HELM_REPO_URL" 2>&1 | grep -v "already exists"; then
    log_info "✓ Repository added"
else
    log_warn "Repository already exists"
fi

log_info "Updating Helm repositories..."
helm repo update
log_info "✓ Repositories updated"
echo ""

# Download the chart
log_info "Downloading Hitachi chart..."
log_info "Chart: $HELM_CHART"
log_info "Version: $HELM_VERSION"
log_info "Output: $OUTPUT_DIR"
echo ""

cd "$OUTPUT_DIR"

if helm pull "hitachi/$HELM_CHART" \
    --version "$HELM_VERSION" \
    --untar \
    --untardir "$OUTPUT_DIR"; then
    
    log_info "✓ Chart downloaded and extracted"
    
    # Create a tarball for easy transfer
    TARBALL="${OUTPUT_DIR}/${HELM_CHART}-${HELM_VERSION}.tar.gz"
    log_info "Creating tarball for easy transfer..."
    tar -czf "$TARBALL" -C "$OUTPUT_DIR" "$HELM_CHART"
    
    echo ""
    log_info "=========================================="
    log_info "✓ Download complete!"
    log_info "=========================================="
    echo ""
    
    echo "Chart location: $OUTPUT_DIR/$HELM_CHART"
    echo "Tarball location: $TARBALL"
    echo ""
    
    echo "To transfer to your cluster:"
    echo "  1. Copy to cluster machine:"
    echo "     scp -r $OUTPUT_DIR/$HELM_CHART user@cluster:/tmp/"
    echo ""
    echo "  2. Set environment variable before deployment:"
    echo "     export LOCAL_CHART_PATH=/tmp/$HELM_CHART"
    echo "     ./scripts/deployment/deploy-hitachi-operator.sh"
    echo ""
    
    echo "Or deploy directly:"
    echo "  make hitachi-deploy-operator"
    echo ""
    
else
    log_error "Failed to download chart"
    exit 1
fi
