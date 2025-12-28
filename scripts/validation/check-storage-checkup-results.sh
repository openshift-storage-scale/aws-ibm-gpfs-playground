#!/bin/bash
# check-storage-checkup-results.sh
# Validates and displays KubeVirt Storage Checkup results
# Reference: https://github.com/nadavleva/kubevirt-storage-checkup/blob/csireplicpg/docs/csi-tests.md

set -e

NAMESPACE="${CHECKUP_NAMESPACE:-storage-checkup}"
KUBECONFIG="${KUBECONFIG:-~/aws-gpfs-playground/ocp_install_files/auth/kubeconfig}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  KubeVirt Storage Checkup Results     ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if the configmap exists
if ! oc get configmap storage-checkup-config -n "${NAMESPACE}" &>/dev/null; then
    echo -e "${RED}ERROR: ConfigMap 'storage-checkup-config' not found in namespace '${NAMESPACE}'${NC}"
    echo "Run 'make storage-checkup' first to execute the checkup."
    exit 1
fi

# Get all results
RESULTS=$(oc get configmap storage-checkup-config -n "${NAMESPACE}" -o json)

echo -e "${BLUE}=== Cluster Information ===${NC}"
OCP_VERSION=$(echo "$RESULTS" | jq -r '.data["status.result.ocpVersion"] // "N/A"')
CNV_VERSION=$(echo "$RESULTS" | jq -r '.data["status.result.cnvVersion"] // "N/A"')
echo "OpenShift Version: $OCP_VERSION"
echo "CNV Version: $CNV_VERSION"
echo ""

echo -e "${BLUE}=== Storage Configuration ===${NC}"
DEFAULT_SC=$(echo "$RESULTS" | jq -r '.data["status.result.defaultStorageClass"] // "N/A"')
echo "Default Storage Class: $DEFAULT_SC"
echo ""

echo -e "${BLUE}=== Test Results ===${NC}"

# Function to check and display result
check_result() {
    local key="$1"
    local name="$2"
    local pass_value="${3:-true}"
    local value=$(echo "$RESULTS" | jq -r ".data[\"status.result.$key\"] // \"N/A\"")
    
    if [[ "$value" == "N/A" || "$value" == "null" ]]; then
        echo -e "  ${YELLOW}⚠ $name: Not run or N/A${NC}"
    elif [[ "$value" == "$pass_value" ]]; then
        echo -e "  ${GREEN}✓ $name: PASS${NC} ($value)"
    elif [[ "$value" == "true" && "$pass_value" == "true" ]]; then
        echo -e "  ${GREEN}✓ $name: PASS${NC}"
    elif [[ "$value" == "" || "$value" == "0" ]]; then
        echo -e "  ${GREEN}✓ $name: PASS${NC} (no issues found)"
    else
        echo -e "  ${RED}✗ $name: FAIL${NC} ($value)"
    fi
}

echo "Core Tests:"
check_result "pvcBound" "PVC Creation & Binding"
echo ""

echo "Storage Profiles:"
EMPTY_CLAIMS=$(echo "$RESULTS" | jq -r '.data["status.result.storageProfilesWithEmptyClaimPropertySets"] // "N/A"')
if [[ "$EMPTY_CLAIMS" == "N/A" || "$EMPTY_CLAIMS" == "null" || "$EMPTY_CLAIMS" == "" ]]; then
    echo -e "  ${GREEN}✓ ClaimPropertySets: PASS${NC} (no empty profiles)"
else
    echo -e "  ${YELLOW}⚠ ClaimPropertySets: Empty profiles found${NC}: $EMPTY_CLAIMS"
fi

SMART_CLONE=$(echo "$RESULTS" | jq -r '.data["status.result.storageProfilesWithSmartClone"] // "N/A"')
if [[ "$SMART_CLONE" != "N/A" && "$SMART_CLONE" != "null" && "$SMART_CLONE" != "" ]]; then
    echo -e "  ${GREEN}✓ Smart Clone Support: PASS${NC} ($SMART_CLONE)"
else
    echo -e "  ${YELLOW}⚠ Smart Clone Support: Not detected${NC}"
fi

RWX=$(echo "$RESULTS" | jq -r '.data["status.result.storageProfilesWithRWX"] // "N/A"')
if [[ "$RWX" != "N/A" && "$RWX" != "null" && "$RWX" != "" ]]; then
    echo -e "  ${GREEN}✓ RWX Support: Available${NC} ($RWX)"
else
    echo -e "  ${YELLOW}⚠ RWX Support: Not detected${NC}"
fi
echo ""

echo "VolumeSnapshotClass:"
MISSING_VSC=$(echo "$RESULTS" | jq -r '.data["status.result.storageProfileMissingVolumeSnapshotClass"] // "N/A"')
if [[ "$MISSING_VSC" == "N/A" || "$MISSING_VSC" == "null" || "$MISSING_VSC" == "" ]]; then
    echo -e "  ${GREEN}✓ VolumeSnapshotClass: PASS${NC} (all profiles have matching VSC)"
else
    echo -e "  ${RED}✗ VolumeSnapshotClass: Missing for profiles${NC}: $MISSING_VSC"
fi
echo ""

echo "Golden Images:"
NOT_UP_TO_DATE=$(echo "$RESULTS" | jq -r '.data["status.result.goldenImagesNotUpToDate"] // "N/A"')
if [[ "$NOT_UP_TO_DATE" == "N/A" || "$NOT_UP_TO_DATE" == "null" || "$NOT_UP_TO_DATE" == "" ]]; then
    echo -e "  ${GREEN}✓ DataImportCron: PASS${NC} (all up to date)"
else
    echo -e "  ${YELLOW}⚠ DataImportCron: Not up to date${NC}: $NOT_UP_TO_DATE"
fi

NO_DATASOURCE=$(echo "$RESULTS" | jq -r '.data["status.result.goldenImagesNoDataSource"] // "N/A"')
if [[ "$NO_DATASOURCE" == "N/A" || "$NO_DATASOURCE" == "null" || "$NO_DATASOURCE" == "" ]]; then
    echo -e "  ${GREEN}✓ DataSource: PASS${NC} (all have valid source)"
else
    echo -e "  ${RED}✗ DataSource: Missing source${NC}: $NO_DATASOURCE"
fi
echo ""

echo "VM Tests:"
check_result "vmBootFromGoldenImage" "VM Boot from Golden Image"
check_result "vmVolumeClone" "Volume Clone Type" "snapshot"
check_result "vmLiveMigration" "VM Live Migration"
check_result "vmHotplugVolume" "Volume Hotplug"
check_result "concurrentVMBoot" "Concurrent VM Boot"
echo ""

echo "VM Storage Class Validation:"
NON_VIRT_RBD=$(echo "$RESULTS" | jq -r '.data["status.result.vmsWithNonVirtRbdStorageClass"] // "N/A"')
if [[ "$NON_VIRT_RBD" == "N/A" || "$NON_VIRT_RBD" == "null" || "$NON_VIRT_RBD" == "" || "$NON_VIRT_RBD" == "0" ]]; then
    echo -e "  ${GREEN}✓ RBD Storage Class: PASS${NC} (no VMs using non-virt RBD)"
else
    echo -e "  ${YELLOW}⚠ RBD Storage Class: VMs using non-optimized class${NC}: $NON_VIRT_RBD"
fi

UNSET_EFS=$(echo "$RESULTS" | jq -r '.data["status.result.vmsWithUnsetEfsStorageClass"] // "N/A"')
if [[ "$UNSET_EFS" == "N/A" || "$UNSET_EFS" == "null" || "$UNSET_EFS" == "" || "$UNSET_EFS" == "0" ]]; then
    echo -e "  ${GREEN}✓ EFS Storage Class: PASS${NC} (no VMs using unset EFS)"
else
    echo -e "  ${YELLOW}⚠ EFS Storage Class: VMs with unset uid/gid${NC}: $UNSET_EFS"
fi
echo ""

# Check for overall failures
SUCCEEDED=$(echo "$RESULTS" | jq -r '.data["status.succeeded"] // "N/A"')
FAILURE_REASON=$(echo "$RESULTS" | jq -r '.data["status.failureReason"] // ""')

echo -e "${BLUE}=== Overall Status ===${NC}"
if [[ "$SUCCEEDED" == "true" ]]; then
    echo -e "${GREEN}✓ CHECKUP PASSED${NC}"
elif [[ "$SUCCEEDED" == "false" ]]; then
    echo -e "${RED}✗ CHECKUP FAILED${NC}"
    if [[ -n "$FAILURE_REASON" ]]; then
        echo -e "Failure Reason: $FAILURE_REASON"
    fi
else
    echo -e "${YELLOW}⚠ Checkup status unknown${NC}"
fi

echo ""
echo -e "${BLUE}For full results, run:${NC}"
echo "  oc get configmap storage-checkup-config -n ${NAMESPACE} -o yaml"
echo ""
echo -e "${BLUE}For checkup logs:${NC}"
echo "  oc logs job/storage-checkup -n ${NAMESPACE}"
