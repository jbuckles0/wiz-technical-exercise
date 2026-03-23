variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "wiz-demo"
}

variable "mongo_admin_password" {
  description = "MongoDB admin user password"
  type        = string
  sensitive   = true
}

variable "mongo_app_password" {
  description = "MongoDB application user password"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default = {
    Project     = "wiz-demo"
    Environment = "demo"
    ManagedBy   = "terraform"
    Owner       = "jacob-buckles"
  }
}
