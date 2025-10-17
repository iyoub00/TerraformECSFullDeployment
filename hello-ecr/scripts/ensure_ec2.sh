#!/usr/bin/env bash
# ==========================================================
# ensure_ec2.sh — Prepare an EC2 target for deployment
# What it does:
#   1) Ensure Security Group exists with required rules
#   2) Create an ephemeral SSH keypair for this run
#   3) Ensure an EC2 instance exists (or recreate if key mismatches)
#   4) Optionally associate an Elastic IP
#   5) Output PUBLIC_IP and EPH_KEY_NAME to GitHub Actions
# ==========================================================

set -euo pipefail

# ---------- Config (provided by the workflow env) ----------
: "${SG_NAME:?missing}"
: "${APP_PORT:?missing}"
: "${EC2_AMI_FILTER:?missing}"
: "${EC2_INSTANCE_TYPE:?missing}"
: "${EC2_INSTANCE_NAME:?missing}"
: "${ASSOCIATE_EIP:?missing}"
YOUR_IP_CIDR="${YOUR_IP_CIDR:-}"  # optional

log() { echo "[ensure_ec2] $*"; }

# ---------- 1) Default VPC ----------
log "Finding default VPC"
VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)

# ---------- 2) Security Group ----------
log "Ensuring security group '${SG_NAME}'"
SG_ID=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values="${SG_NAME}" Name=vpc-id,Values="${VPC_ID}" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)

if [[ -z "$SG_ID" || "$SG_ID" == "None" ]]; then
  SG_ID=$(aws ec2 create-security-group \
    --vpc-id "$VPC_ID" \
    --group-name "$SG_NAME" \
    --description "GA EC2 SG" \
    --query GroupId --output text)

  # SSH ingress
  if [[ -n "$YOUR_IP_CIDR" ]]; then
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$YOUR_IP_CIDR"
  else
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0
  fi
  # HTTP/HTTPS + App port
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80  --cidr 0.0.0.0/0
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port "${APP_PORT}" --cidr 0.0.0.0/0
fi

# ---------- 3) Latest Ubuntu AMI ----------
log "Finding latest Ubuntu AMI"
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=${EC2_AMI_FILTER}" "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate)[-1].ImageId' --output text)

# ---------- 4) Ephemeral SSH key ----------
log "Creating ephemeral SSH key"
KEY_NAME="gha-ephemeral-$(date +%s)"
ssh-keygen -t ed25519 -N "" -f /tmp/gha_ephemeral_key >/dev/null
aws ec2 import-key-pair --key-name "$KEY_NAME" --public-key-material fileb:///tmp/gha_ephemeral_key.pub >/dev/null
cp /tmp/gha_ephemeral_key /tmp/key.pem && chmod 600 /tmp/key.pem

# ---------- 5) Instance ensure (replace if key mismatch) ----------
log "Ensuring EC2 instance '${EC2_INSTANCE_NAME}'"
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${EC2_INSTANCE_NAME}" "Name=instance-state-name,Values=running,pending" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || true)

if [[ -n "$INSTANCE_ID" && "$INSTANCE_ID" != "None" ]]; then
  CUR_KEY=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].KeyName' --output text)
  if [[ "$CUR_KEY" != "$KEY_NAME" ]]; then
    log "Existing instance uses different key; terminating"
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" >/dev/null
    aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
    INSTANCE_ID=""
  fi
fi

if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
  log "Launching a new instance"
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$EC2_INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${EC2_INSTANCE_NAME}}]" \
    --query 'Instances[0].InstanceId' --output text)
fi

log "Waiting for instance to be ready"
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"

# ---------- 6) Elastic IP (optional) ----------
if [[ "$ASSOCIATE_EIP" == "true" ]]; then
  log "Associating an Elastic IP (reusing or creating as needed)"
  ALLOC_ID=$(aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].AllocationId' --output text | awk '{print $1}')
  [[ -z "$ALLOC_ID" || "$ALLOC_ID" == "None" ]] && ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query AllocationId --output text)
  aws ec2 associate-address --instance-id "$INSTANCE_ID" --allocation-id "$ALLOC_ID" --allow-reassociation || true
fi

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

log "Ready. Public IP: $PUBLIC_IP"

# ---------- 7) Emit outputs to GitHub Actions ----------
echo "PUBLIC_IP=${PUBLIC_IP}" >> "$GITHUB_OUTPUT"
echo "EPH_KEY_NAME=${KEY_NAME}" >> "$GITHUB_OUTPUT"
