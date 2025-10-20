#!/usr/bin/env bash
set -euo pipefail

: "${STACK_NAME:=gha-ec2}"
: "${KEY_NAME:?missing KEY_NAME}"
: "${INSTANCE_TYPE:=t3.micro}"
: "${APP_PORT:=5000}"
: "${YOUR_IP_CIDR:=0.0.0.0/0}"
: "${AWS_REGION:=eu-west-1}"

# Resolve latest Amazon Linux 2023 x86_64 AMI (official owner 137112412989)
AMI_ID=$(aws ec2 describe-images \
  --region "$AWS_REGION" \
  --owners 137112412989 \
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
  --query "Images | sort_by(@, &CreationDate)[-1].ImageId" \
  --output text)

echo "[cfn] Using AMI $AMI_ID"

aws cloudformation deploy \
  --region "$AWS_REGION" \
  --stack-name "$STACK_NAME" \
  --template-file infra/ec2-min.yml \
  --parameter-overrides \
    StackName="$STACK_NAME" \
    KeyName="$KEY_NAME" \
    InstanceType="$INSTANCE_TYPE" \
    AppPort="$APP_PORT" \
    YourIpCidr="$YOUR_IP_CIDR" \
    AmiId="$AMI_ID" \
  --capabilities CAPABILITY_IAM

PUBLIC_IP=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='PublicIp'].OutputValue" --output text)

echo "PUBLIC_IP=${PUBLIC_IP}"
echo "PUBLIC_IP=${PUBLIC_IP}" >> "$GITHUB_OUTPUT"
