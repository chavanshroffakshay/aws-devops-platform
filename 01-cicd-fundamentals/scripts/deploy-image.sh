#!/usr/bin/env bash
# Build the sample app and push :latest to ECR, then force a rollout.
# Useful for the very first deploy; pipelines take over after that.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/terraform"

ECR=$(terraform output -raw ecr_repository_url)
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)
REGION=$(aws configure get region)

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${ECR%/*}"

docker build -t "$ECR:latest" "$ROOT/samples/app"
docker push "$ECR:latest"

aws ecs update-service \
  --cluster "$CLUSTER" --service "$SERVICE" \
  --force-new-deployment >/dev/null

echo "Pushed $ECR:latest and triggered ECS rollout."
