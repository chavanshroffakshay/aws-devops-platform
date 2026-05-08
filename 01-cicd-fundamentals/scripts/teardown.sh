#!/usr/bin/env bash
# Destroy the platform and any pipeline stacks under samples/*/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for dir in "$ROOT/samples/codepipeline" "$ROOT/samples/github-actions"; do
  if [ -f "$dir/terraform.tfstate" ] || [ -d "$dir/.terraform" ]; then
    echo "Destroying $dir"
    (cd "$dir" && terraform destroy -auto-approve)
  fi
done

echo "Destroying platform"
cd "$ROOT/terraform"
terraform destroy -auto-approve
