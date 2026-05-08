output "alb_dns_name" {
  description = "Public URL of the ALB"
  value       = aws_lb.this.dns_name
}

output "ecr_repository_url" {
  description = "URL of the app ECR repo"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name (used by pipelines)"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name (used by pipelines)"
  value       = aws_ecs_service.app.name
}

output "task_family" {
  description = "ECS task family for new revisions"
  value       = aws_ecs_task_definition.app.family
}
