variable "region" {
  description = "AWS region. Everyone in the cohort uses the same one."
  type        = string
}

variable "group_name" {
  description = "Short group name, used as a prefix on every resource"
  type        = string
  # keep it short - some AWS names have a 32 character limit
}

variable "image_tag" {
  description = "Which image tag in ECR to deploy"
  type        = string
  default     = "v1"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "db_password" {
  description = "Database password. Comes from terraform.tfvars, never from here."
  type        = string
  sensitive   = true
}

# Week 5  - Desired count variable needed
variable "desired_count" {
  type        = number
  description = "The number of instance tasks to run in the ECS service"
  default     = 2
}
