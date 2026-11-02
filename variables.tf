variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Target AWS Region"
}

variable "environment" {
  type        = string
  default     = "wiz-exercise"
  description = "Environment prefix for resource naming"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block"
}

variable "db_username" {
  type        = string
  default     = "wizadmin"
  description = "MongoDB Admin Username"
}

variable "db_password" {
  type        = string
  default     = "WizSecurePass2026!"
  description = "MongoDB Admin Password"
}