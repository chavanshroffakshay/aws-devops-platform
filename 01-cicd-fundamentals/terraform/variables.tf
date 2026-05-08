variable "region" {
  description = "AWS region for the platform"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "devops-platform"
}

variable "container_port" {
  description = "Port the sample app listens on"
  type        = number
  default     = 3000
}

variable "desired_count" {
  description = "Number of Fargate tasks to run"
  type        = number
  default     = 1
}
