# aws-devops-platform

End-to-end DevOps platform on AWS — Infrastructure as Code, CI/CD pipelines, GitOps deployments to EKS, and multi-environment provisioning patterns.

This repo demonstrates the core DevOps competencies I use day-to-day at Nuvepro Technologies: standing up reproducible environments with Terraform, automating builds and deployments through AWS-native pipelines, and progressing toward GitOps with ArgoCD.

---

## Architecture

![Architecture](docs/architecture.png)

Source code lives on GitHub and is connected to AWS via CodeConnections. Pushes trigger CodeBuild for compile/test/package, which hands artifacts to CodePipeline. CodePipeline orchestrates promotion across dev → staging → prod with manual approval gates. CodeDeploy rolls updates onto EC2 instances; for containerized workloads, ArgoCD pulls manifests from a separate config repo and reconciles state in EKS.

Terraform provisions the underlying infrastructure (VPC, ECS, S3, DynamoDB) using a single codebase parameterized per environment, with remote state in S3 + DynamoDB locking.

---

## What's inside

| Folder | Description |
|---|---|
| [`01-cicd-fundamentals`](./01-cicd-fundamentals) | AWS-native CI/CD with CodeBuild, CodeDeploy, CodePipeline, and CodeConnections. Multi-environment pipeline with approval gates. |
| [`02-iac-cloudformation-vs-terraform`](./02-iac-cloudformation-vs-terraform) | Same multi-tier web stack provisioned two ways — CloudFormation and Terraform. Side-by-side comparison of workflow, syntax, and state management. |
| [`03-containerization-fundamentals`](./03-containerization-fundamentals) | Docker image builds, ECR push pipelines, and base container patterns for downstream services. |
| [`04-terraform-multi-env`](./04-terraform-multi-env) | Single Terraform codebase parameterized for dev/staging/prod. Remote backend with S3 + DynamoDB locking. Python helper scripts to bootstrap the backend and drive plan/apply workflows. |
| [`05-gitops-eks-argocd`](./05-gitops-eks-argocd) | EKS cluster provisioned via eksctl + Terraform, ArgoCD installed and configured for declarative app sync. GitHub Actions builds and pushes to ECR; ArgoCD reconciles the cluster from a config repo. |

---

## Tech stack

- **AWS:** CodePipeline, CodeBuild, CodeDeploy, CodeConnections, EC2, ECR, EKS, ECS, S3, DynamoDB, IAM, CloudWatch, VPC
- **IaC:** Terraform (modules, remote state, workspaces), AWS CloudFormation
- **GitOps:** ArgoCD, GitHub Actions
- **Languages:** Python (Boto3 helpers), Bash, HCL

---

## Key concepts demonstrated

- Multi-environment promotion with manual approval gates
- Drift detection and idempotent re-applies via Terraform
- Remote state with locking to support team workflows
- Pull-based deployments with ArgoCD vs push-based with CodePipeline
- Environment parameterization without code duplication

---

## How to run

Each subfolder has its own README with prerequisites and step-by-step instructions. Recommended order:

```bash
# 1. Stand up shared infrastructure
cd 04-terraform-multi-env
./scripts/bootstrap-backend.sh
terraform init && terraform workspace new dev && terraform apply

# 2. Build & deploy a sample app
cd ../01-cicd-fundamentals
# Follow README.md to wire up CodeConnections + GitHub repo

# 3. Try GitOps for containerized workloads
cd ../05-gitops-eks-argocd
./scripts/create-cluster.sh
kubectl apply -f argocd/install.yaml
```

> **Cost note:** EKS clusters and NAT gateways are not free. The `cleanup` script in each folder tears everything down. Run it after each session.

---

## Lessons learned / production considerations

These are things I'd do differently — or pay closer attention to — running this in a real production environment, beyond the lab scope.

- **CodeConnections vs OIDC for GitHub Actions:** CodeConnections is fine for CodePipeline, but for GitHub Actions itself I'd use OIDC federation rather than long-lived IAM access keys. Static access keys in GitHub secrets are a real audit finding waiting to happen.
- **Approval gates aren't enough for prod:** A manual approval click doesn't replace canary deployments. For real prod traffic, I'd add CodeDeploy's traffic-shifting (linear or canary configs) plus CloudWatch alarm-based rollbacks.
- **Terraform workspaces have limits:** Workspaces are fine for 2–3 environments but get fragile as you add accounts and regions. For real multi-account setups I'd move to per-environment directories with shared modules — workspaces hide the actual state file path and that bites you during incidents.
- **ArgoCD app-of-apps pattern:** The lab uses a single Application resource. In production I'd use the app-of-apps pattern so platform teams own the bootstrap and product teams own their app definitions, with RBAC enforced at the AppProject level.
- **Secrets:** Nothing in this repo handles secrets properly. Real deployments need External Secrets Operator + AWS Secrets Manager (or Parameter Store) — never bake secrets into manifests or env vars in plaintext.
- **State file blast radius:** A single Terraform state for "everything" is a liability. Splitting state by lifecycle (network rarely changes, apps change daily) reduces blast radius when something goes wrong.

---

## Cleanup

Every subfolder has a `cleanup.sh` or `terraform destroy` workflow. Run them in **reverse order** of creation. EKS clusters specifically need their workloads removed before the cluster itself, or the LoadBalancer Services will leave orphaned ELBs racking up charges.

---

## Related

- [aws-microservices-eks](https://github.com/akshaychavan/aws-microservices-eks) — the EKS workloads this platform deploys
- [aws-genai-engineering](https://github.com/akshaychavan/aws-genai-engineering) — GenAI tooling integrated into this CI/CD flow
