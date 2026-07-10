variable "aws_region" {
  description = "The AWS Region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "target_network" {
  description = "Midnight network to target: preview, preprod, mainnet"
  type        = string
  default     = "preprod"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.xlarge"
}

variable "key_name" {
  description = "Name of an existing AWS Key Pair to allow SSH access"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy into. Leave blank to use Default VPC."
  type        = string
  default     = ""
}
