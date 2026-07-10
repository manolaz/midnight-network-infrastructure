variable "project_id" {
  description = "The GCP Project ID where resources will be created"
  type        = string
}

variable "region" {
  description = "The GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "target_network" {
  description = "Midnight network to target: preview, preprod, mainnet"
  type        = string
  default     = "preprod"
}

variable "machine_type" {
  description = "Compute instance machine type"
  type        = string
  default     = "e2-standard-4"
}
