# Variables

variable "vpc_cidr" {
  description = "Cidr block for VPC"
}

variable "default_tags" {
  description = "Default tags to add to all resources that support tagging"
  type        = "map"
}

variable "aws_region" {
  description = "Region to provision resources in"
}

variable "azs" {
  description = "Availability zone key to provision in (default: [a,b,c])"
  type        = "list"
  default     = ["a", "b", "c"]
}

variable "pub_subnet_cidrs" {
  description = "cidr for public subnet. Subset of vpc cidr"
  type        = "list"
}

variable "priv_subnet_cidrs" {
  description = "cidr for private subnet. Subset of vpc cidr"
  type        = "list"
}
