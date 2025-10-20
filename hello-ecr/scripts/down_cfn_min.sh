#!/usr/bin/env bash
set -euo pipefail
: "${STACK_NAME:=gha-ec2}"
: "${AWS_REGION:=eu-west-1}"
aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION"
