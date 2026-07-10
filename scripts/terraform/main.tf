terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.39"
    }
  }

  # Note: Users must define their own bucket or use local state by uncommenting this and adding a bucket name
  # backend "gcs" {
  #   bucket  = "YOUR_STATE_BUCKET_NAME"
  #   prefix  = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
