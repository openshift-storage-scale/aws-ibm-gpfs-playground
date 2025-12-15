# Automatic AWS Resource Creation for Hitachi SDS Block

## Overview

The `make install-hitachi-with-sds` command now **automatically discovers or creates** the required AWS resources (`aws_ec2_key_name` and `aws_vpc_id`). You don't need to manually create them!

## What Gets Automated

### 1. EC2 Key Pair (`aws_ec2_key_name`)

The playbook automatically handles EC2 key pair provisioning:

**If you DON'T provide `aws_ec2_key_name` in `overrides.yml`:**
- ✅ Checks for existing EC2 key pairs in your region
- ✅ Uses the first available key pair, OR
- ✅ Creates a new one automatically: `<cluster-name>-sds-key`
- ✅ Saves the private key to: `~/.ssh/<cluster-name>-sds-key.pem`

**If you DO provide `aws_ec2_key_name` in `overrides.yml`:**
- ✅ Uses your specified key pair (must exist in AWS)

### 2. VPC ID (`aws_vpc_id`)

The playbook automatically discovers your VPC:

**If you DON'T provide `aws_vpc_id` in `overrides.yml`:**
- ✅ Automatically detects your default VPC, OR
- ✅ Fails with helpful instructions if no default VPC exists

**If you DO provide `aws_vpc_id` in `overrides.yml`:**
- ✅ Uses your specified VPC (must exist in AWS)

## Quick Start

### Option 1: Full Automation (Recommended)

Let the playbook create/discover everything:

```bash
# No configuration needed!
make install-hitachi-with-sds
```

The playbook will:
- 🤖 Auto-create EC2 key pair if needed
- 🤖 Auto-detect default VPC
- 📋 Print the resources it's using
- 🚀 Proceed with deployment

### Option 2: Partial Configuration

Provide some values in `overrides.yml` to override defaults:

```yaml
# Optional: Use a specific EC2 key pair (must already exist)
aws_ec2_key_name: "my-existing-key"

# Optional: Use a specific VPC (must already exist)
aws_vpc_id: "vpc-0123456789abcdef0"
```

Then run:
```bash
make install-hitachi-with-sds
```

## Output Example

When you run the deployment, you'll see something like:

```
✅ AWS configuration is properly set up
✅ Created EC2 key pair: gpfs-levanon-sds-key
📁 Private key saved to: ~/.ssh/gpfs-levanon-sds-key.pem
✅ AWS Resources Ready:
  EC2 Key Pair: gpfs-levanon-sds-key
  VPC ID: vpc-0123456789abcdef0
  Region: eu-north-1
  Profile: default
```

## Manual Override Reference

If you need to override the automatic detection:

### Get your VPC ID manually

```bash
# Find your default VPC
aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' \
  --profile default \
  --output text

# Or list all VPCs
aws ec2 describe-vpcs \
  --profile default \
  --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

### Get or create your EC2 key pair manually

```bash
# List existing key pairs
aws ec2 describe-key-pairs \
  --profile default \
  --region eu-north-1 \
  --query 'KeyPairs[*].KeyName' \
  --output table

# Or create a new one
aws ec2 create-key-pair \
  --key-name my-sds-key \
  --profile default \
  --region eu-north-1 \
  --query 'KeyMaterial' \
  --output text > ~/my-sds-key.pem

chmod 600 ~/my-sds-key.pem
```

## Troubleshooting

### "No default VPC found"

If the automation fails with this error:
1. Either create a default VPC in AWS Console
2. Or manually specify a VPC in `overrides.yml`:
   ```yaml
   aws_vpc_id: "vpc-0123456789abcdef0"
   ```

### "EC2 key pair not found"

If you specified `aws_ec2_key_name` but it doesn't exist:
1. Create the key pair in AWS Console, OR
2. Let the automation create it by removing `aws_ec2_key_name` from `overrides.yml`

## Behind the Scenes

The automation logic is implemented in:
- **File:** `playbooks/sds-block-deploy.yml`
- **Tasks:** Lines 1-120 (AWS resource validation and auto-creation)

The logic follows this decision tree:

```
EC2 Key Pair:
├─ Is aws_ec2_key_name provided? (not "your-*" placeholder)
│  ├─ YES: Use it (must exist)
│  └─ NO: Check for existing key pairs
│     ├─ Found: Use first one
│     └─ Not found: Auto-create "<cluster>-sds-key"
│
VPC ID:
├─ Is aws_vpc_id provided? (not "vpc-*" placeholder)
│  ├─ YES: Use it (must exist)
│  └─ NO: Check for default VPC
│     ├─ Found: Use it
│     └─ Not found: Fail with instructions
```
