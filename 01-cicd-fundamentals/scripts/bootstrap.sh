#!/usr/bin/env bash
# Provision the shared platform (VPC, ECS, ECR, ALB)
set -euo pipefail

cd "$(dirname "$0")/../terraform"

terraform init
terraform apply -auto-approve

echo
echo "Platform up."
echo "  ALB: $(terraform output -raw alb_dns_name)"
echo "  ECR: $(terraform output -raw ecr_repository_url)"
