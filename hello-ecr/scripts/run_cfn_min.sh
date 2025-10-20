#!/usr/bin/env bash
set -euo pipefail

: "${STACK_NAME:=gha-ec2}"
: "${KEY_NAME:?missing KEY_NAME}"          # existing EC2 key pair (keep name in a secret)
: "${INSTANCE_TYPE:=t3.micro}"
: "${APP_PORT:=5000}"
: "${YOUR_IP_CIDR:=0.0.0.0/0}"
: "${AWS_REGION:=eu-west-1}"

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
  --capabilities CAPABILITY_IAM

PUBLIC_IP=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='PublicIp'].OutputValue" --output text)

echo "PUBLIC_IP=${PUBLIC_IP}"
# If used in GitHub Actions:
echo "PUBLIC_IP=${PUBLIC_IP}" >> "$GITHUB_OUTPUT"
