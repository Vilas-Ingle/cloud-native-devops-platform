variable "aws_region" {
  description = "AWS region where infrastructure will be deployed"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "project_name" {
  description = "Name used for AWS resources"
  type        = string
  default     = "cloud-native-devops"
}

variable "eks_public_access_cidrs" {
  description = "IPv4 CIDR blocks allowed to access the public EKS kubernetes API endpoint"
  type        = list(string)
}