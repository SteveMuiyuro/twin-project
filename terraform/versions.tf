terraform {
  required_version = ">= 1.0"

  backend "gcs" {
    bucket  = "twin-terraform-state-51053"
    prefix  = "terraform/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "twin-project-51053"
  region  = "us-central1"
}