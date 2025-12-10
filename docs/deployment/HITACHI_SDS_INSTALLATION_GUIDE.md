# Hitachi VSP One SDS Installation Guide

**Reference Document:** MK-SL-304-01 (September 2024)  
**Architecture:** Red Hat OpenShift with Hitachi VSP One SDS Block on AWS

---

## 📋 Executive Summary

This guide provides:
1. **Installation Overview** - Complete Hitachi SDS deployment procedure
2. **Helm Repository Details** - Where to get Hitachi operator charts
3. **Authentication Requirements** - Pull secrets and credentials needed
4. **Automation Status** - What can be automated vs. manual steps
5. **Prerequisites** - IAM, VPC, S3, and networking requirements

---

## 🏗️ Architecture Components

### Software Stack (Validated Versions)
| Component | Version | Notes |
|-----------|---------|-------|
| Hitachi VSP One SDS Block Cloud on AWS | 1.14 | Core storage engine |
| Hitachi Storage Plug-in for Containers (HSPC) | 3.14.0 | Kubernetes CSI driver |
| Red Hat OpenShift Container Platform (OCP) | 4.15 | Container orchestration |
| Helm | 3.x | Package manager for deployment |

### Deployment Path
```
OCP Cluster (4.15)
    ↓
Hitachi Storage Plug-in for Containers (3.14.0)
    ↓
SDS Block Cloud (1.14) on AWS
    ↓
Persistent Volumes for CI/CD workloads
```

---

## 🚀 Installation Procedure

### Phase 1: Prerequisites & IAM Setup

**Manual Steps (Outside Ansible):**
1. Configure AWS IAM policies for SDS Block
   - Reference: [Hitachi Setup Guide](https://docs.hitachivantara.com/r/en-us/virtual-storage-platform-one-sds-block/1.14.x/mk-24vsp1sds008/setup-procedure/confirming-prerequisites-for-setup)
   - Required policies for EC2, S3, CloudFormation, VPC, KMS

2. Prepare AWS Infrastructure:
   - Create or identify existing VPC
   - Create 3 subnets (control network, internode network, compute network)
   - Create VPC endpoints:
     - CloudFormation
     - EC2
     - Amazon S3
     - EC2Message
     - SSM
     - SSMMessage
   - Create S3 bucket for dump logs (e.g., `sdsc-s3-bucket/sdsc-s3`)
   - Keep S3 URI ready (format: `s3://bucket-name/folder-name`)

3. Network ACL Configuration:
   - Allow all access between subnets
   - Can be more granular if needed

**✅ Automated (Our Playbook):**
- Security group creation for Hitachi ports (443, 3260, 5696, 5697)

---

### Phase 2: Deploy SDS Block Cloud

**Manual Steps (Hitachi Marketplace):**
1. Access AWS Marketplace
   - Navigate to [Hitachi VSP One SDS Block](https://aws.amazon.com/marketplace)
   - Subscribe to product
   - Accept Terms and Conditions
   - Select fulfillment option

2. Launch CloudFormation Stack with required parameters:
   ```
   Stack name: <any-name>
   ClusterName: <cluster-name>
   AvailabilityZone: <az>
   VpcId: <vpc-id>
   ControlSubnetId: <subnet-id>
   ControlSubnetCidrBlock: <cidr>
   InterNodeSubnetId: <subnet-id>
   ComputeSubnetId: <subnet-id>
   StorageNodeInstanceType: m5.2xlarge (recommended)
   ConfigurationPattern: <data-protection-method>
   DriveCount: <number>
   LogicalCapacity: <capacity-in-GB>
   EbsVolumeEncryption: true|false
   EbsVolumeKmsKeyId: <kms-key-id>
   TimeZone: <timezone>
   BillingCode: <billing-code>
   S3URI: s3://bucket-name/folder
   IamRoleNameForStorageCluster: <role-name>
   ```

3. Wait for CloudFormation stack creation (~30-45 minutes)

4. Retrieve SDS Block connection details:
   - Management interface IP
   - Credentials from CloudFormation outputs

**⏳ Currently Not Automated:**
- Marketplace subscription and CloudFormation deployment
- Requires AWS console access

---

### Phase 3: Install Hitachi Storage Plug-in for Containers (HSPC)

**Method 1: OpenShift OperatorHub (Simpler)**
- HSPC is available in OpenShift's OperatorHub
- Can be installed via OCP Console GUI
- Automatic subscription and updates

**Method 2: Helm Chart (Recommended for Automation)**

#### Helm Repository Details
```yaml
Repository Name: hitachi
Repository URL: https://cdn.hitachivantara.com/charts/hitachi/hitachi-storage-container-plugin
Chart Name: vsp-one-sds-hspc
Namespace: hitachi-system
Version: Latest (check Helm repository)
```

#### Installation Command (Helm)
```bash
# Add Hitachi Helm repository
helm repo add hitachi https://cdn.hitachivantara.com/charts/hitachi

# Update repositories
helm repo update

# Install HSPC operator
helm install hitachi-sds-hspc hitachi/vsp-one-sds-hspc \
  --namespace hitachi-system \
  --create-namespace \
  --values hitachi-hspc-values.yaml
```

**✅ Automated (Our Playbook):**
- Helm repository addition
- Helm chart deployment with custom values
- Namespace creation
- Operator readiness validation

---

### Phase 4: Configure Secrets for SDS Block Access

**Required Secret Configuration:**

1. **Create Secret with SDS Block Credentials:**
```bash
kubectl create secret generic sds-block-secret \
  --from-literal=username=<sds-user> \
  --from-literal=password=<sds-password> \
  --namespace=hitachi-system
```

2. **Configure HSPC to Access SDS Block:**
   - SDS Block management IP
   - Username and password (from step 1)
   - Port (typically 8443 for HTTPS)

**Key Information Needed:**
- SDS Block management IP (from CloudFormation)
- Administrative credentials (from CloudFormation)

**✅ Automated (Our Playbook):**
- Secret creation
- HSPC configuration with secret reference

**⏳ Manual Steps:**
- Obtain SDS Block credentials from AWS Marketplace deployment
- Create secure secret store entry

---

### Phase 5: Configure StorageClass

**Create StorageClass for SDS Block:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hitachi-sds
provisioner: storage.hitachivantara.com/vsp-one-sds
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
parameters:
  sds_array_id: SDS-0001
  pool_name: replication-pool  # Must exist in SDS Block
```

**Multipath Configuration (iSCSI):**
- Configure multipath.conf for iSCSI access
- Enable resource partitioning in HSPC settings

---

## 🔐 Authentication & Pull Secrets

### Red Hat OpenShift Pull Secret

**What it is:**
- JSON credential file for accessing Red Hat's container image registry
- Required for downloading OCP images
- Downloaded from https://console.redhat.com

**How to Get It:**
1. Visit: https://console.redhat.com
2. Select "Red Hat OpenShift"
3. Click "Create Cluster"
4. Scroll to "Run it yourself"
5. Select "AWS (x86_64)" → "Automated"
6. Download:
   - Pull Secret (JSON file)
   - CLI tools (oc, kubectl)

**Usage:**
- Place in OCP installation directory
- Used by openshift-install during cluster creation
- Already handled in our `_ocp-install-common.yml`

### Hitachi Helm Repository Authentication

**Status:** ✅ **Public Helm Repository (No Auth Required)**

The Hitachi Helm repository at `https://cdn.hitachivantara.com/charts/hitachi/` is publicly accessible.

**No additional authentication needed** for basic HSPC installation.

**Optional:** If using private/custom Hitachi charts:
```bash
helm repo add hitachi https://cdn.hitachivantara.com/charts/hitachi \
  --username <username> \
  --password <password>
```

### Image Registry Authentication (For Custom Images)

If deploying custom Hitachi images:

1. **Create Docker Pull Secret:**
```bash
kubectl create secret docker-registry hitachi-registry-secret \
  --docker-server=docker.io \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email> \
  --namespace=hitachi-system
```

2. **Reference in Helm values:**
```yaml
image:
  registry: docker.io
  pullSecrets:
    - name: hitachi-registry-secret
```

---

## 📦 What We Can Automate

### ✅ Fully Automated (Already in Playbook)
- ✅ OCP cluster provisioning (common layer)
- ✅ AWS security group configuration for Hitachi ports
- ✅ Namespace creation (hitachi-system)
- ✅ Helm repository addition
- ✅ HSPC operator installation via Helm
- ✅ Helm values templating
- ✅ Operator readiness validation
- ✅ kubeconfig configuration

### ⏳ Partially Automated (Can Be Enhanced)
- ⏳ Secret creation (requires credentials as input)
- ⏳ StorageClass creation (requires SDS Block pool names)
- ⏳ Multipath configuration (requires iSCSI setup)

### 🔒 Manual Steps (Outside Automation)
- 🔒 AWS IAM policy setup
- 🔒 VPC and subnet creation
- 🔒 CloudFormation stack deployment (Hitachi Marketplace)
- 🔒 Obtain SDS Block credentials
- 🔒 Download Red Hat pull secret (console.redhat.com)
- 🔒 Configure SDS Block storage pools (done in SDS GUI)

---

## 🔧 Helm Configuration Values

### Recommended HSPC Helm Values
```yaml
image:
  registry: docker.io
  repository: hitachi/vsp-one-sds-hspc
  tag: 3.14.0
  pullPolicy: IfNotPresent

rbac:
  create: true

serviceAccount:
  create: true
  name: hitachi-sds-hspc

resources:
  limits:
    cpu: 1000m
    memory: 1024Mi
  requests:
    cpu: 500m
    memory: 512Mi

nodeSelector: {}

tolerations: []

affinity: {}

# SDS Block Connection
sds:
  arrays:
    - id: SDS-0001
      name: Playground-SDS
      managementIP: <sds-management-ip>
      port: 8443
      secretName: sds-block-secret

# Multipath
multipath:
  enabled: true
  backend: iscsi

# Features
features:
  dynamicProvisioning: true
  expandVolumes: true
  snapshotting: true
```

---

## 🎯 Prerequisites Checklist

Before running `make install-hitachi`:

### AWS Prerequisites
- [ ] AWS account with appropriate IAM permissions
- [ ] VPC and subnets created
- [ ] VPC endpoints configured
- [ ] S3 bucket created for logs
- [ ] IAM role created for SDS Block

### Hitachi Prerequisites
- [ ] Hitachi SDS Block deployed on AWS Marketplace
- [ ] SDS Block management IP known
- [ ] SDS Block admin credentials available
- [ ] SDS Block storage pools created

### OCP Prerequisites
- [ ] OpenShift pull secret downloaded (console.redhat.com)
- [ ] OCP cluster deployed (handled by playbook)
- [ ] kubeconfig accessible

### Local Prerequisites
- [ ] Ansible 2.9+
- [ ] Helm 3.x
- [ ] kubectl/oc CLI tools
- [ ] AWS credentials configured locally

---

## 📝 Configuration Variables

### In `hitachi.overrides.yml`
```yaml
# Hitachi SDS Configuration
hitachi_sds_version: "5.3.0"
hitachi_array_id: "SDS-0001"
hitachi_array_name: "Playground-SDS"
hitachi_management_ip: "10.1.0.50"  # ADD THIS

# Helm Configuration
hitachi_helm_repo: "https://cdn.hitachivantara.com/charts/hitachi"
hitachi_helm_chart: "vsp-one-sds-hspc"
hitachi_helm_namespace: "hitachi-system"

# SDS Block Access
hitachi_sds_username: "admin"       # ADD THIS (or from vars_prompt)
hitachi_sds_password: "{{ vault }}" # ADD THIS (from Vault)

# Storage Configuration
hitachi_storage_pool_name: "replication-pool"
hitachi_storage_class_name: "hitachi-sds"
```

---

## 🔍 Troubleshooting

### Helm Repository Not Found
**Error:** `Error: repo hitachi not found`

**Solution:**
```bash
# Verify Helm repo URL is accessible
curl -I https://cdn.hitachivantara.com/charts/hitachi/

# Add/update repository
helm repo add hitachi https://cdn.hitachivantara.com/charts/hitachi
helm repo update

# List available charts
helm search repo hitachi/
```

### HSPC Operator Not Starting
1. Check operator deployment:
```bash
kubectl get deployment -n hitachi-system
kubectl describe pod <pod-name> -n hitachi-system
kubectl logs <pod-name> -n hitachi-system
```

2. Verify secret credentials:
```bash
kubectl get secret sds-block-secret -n hitachi-system -o yaml
```

### SDS Block Connectivity Issues
1. Verify security groups allow required ports:
   - 443 (HTTPS management)
   - 3260 (iSCSI)
   - 5696, 5697 (Hitachi proprietary)

2. Test connectivity:
```bash
telnet <sds-management-ip> 8443
```

---

## 📚 Additional Resources

| Resource | Link |
|----------|------|
| SDS Block Setup Guide | https://docs.hitachivantara.com/r/en-us/virtual-storage-platform-one-sds-block/1.14.x/mk-24vsp1sds008 |
| HSPC Reference Guide | https://docs.hitachivantara.com/r/en-us/hitachi-storage-plugin-containers |
| OpenShift Installation | https://docs.openshift.com/container-platform/4.15/ |
| Helm Documentation | https://helm.sh/docs/ |
| GitOps Workflow | https://docs.openshift.com/gitops/1.13/ |
| Support Contact | https://support.hitachivantara.com |

---

## 🎬 Next Steps

1. **Prepare Prerequisites:**
   - [ ] Configure AWS IAM and VPC
   - [ ] Deploy SDS Block via AWS Marketplace
   - [ ] Collect credentials and connection details

2. **Update Configuration:**
   - [ ] Update `hitachi.overrides.yml` with SDS Block details
   - [ ] Store credentials securely (Vault or secure env vars)

3. **Run Deployment:**
   ```bash
   make install-hitachi
   ```

4. **Validate Deployment:**
   ```bash
   kubectl get all -n hitachi-system
   kubectl get storageclasses
   kubectl get pv
   ```

5. **Configure Storage Pools:**
   - Create storage pools in SDS Block GUI
   - Create StorageClass resources in OCP

---

**Last Updated:** December 9, 2025  
**Document Version:** 1.0  
**Architecture Reference:** MK-SL-304-01 (September 2024)
