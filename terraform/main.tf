############################################
# Random suffix for globally unique buckets
############################################

resource "random_id" "suffix" {
  byte_length = 2
}

############################################
# Enable required GCP APIs
############################################

resource "google_project_service" "run_api" {
  project = var.project_id
  service = "run.googleapis.com"
}

resource "google_project_service" "artifact_registry_api" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "storage_api" {
  project = var.project_id
  service = "storage.googleapis.com"
}

############################################
# Artifact Registry (Docker images)
############################################

resource "google_artifact_registry_repository" "backend_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.project_name}-${var.environment}-repo"
  description   = "Docker repository for backend"
  format        = "DOCKER"

  depends_on = [
    google_project_service.artifact_registry_api
  ]
}

############################################
# Cloud Storage bucket for frontend
############################################

resource "google_storage_bucket" "frontend_bucket" {
  name     = "${var.project_name}-${var.environment}-frontend-${random_id.suffix.hex}"
  location = var.region

  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  depends_on = [
    google_project_service.storage_api
  ]
}

resource "google_storage_bucket_iam_member" "frontend_public" {
  bucket = google_storage_bucket.frontend_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

############################################
# Cloud Storage bucket for memory
############################################

resource "google_storage_bucket" "memory_bucket" {
  name     = "${var.project_name}-${var.environment}-memory-${random_id.suffix.hex}"
  location = var.region

  uniform_bucket_level_access = true

  depends_on = [
    google_project_service.storage_api
  ]
}

############################################
# Service account for Cloud Run
############################################

resource "google_service_account" "cloud_run_sa" {
  project      = var.project_id
  account_id   = "${var.project_name}-${var.environment}-run-sa"
  display_name = "Cloud Run Service Account"
}

############################################
# IAM permissions for Cloud Run
############################################

resource "google_project_iam_member" "run_storage_access" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

############################################
# Cloud Run service (backend API)
############################################

resource "google_cloud_run_service" "backend" {
  name     = "${var.project_name}-${var.environment}-backend"
  location = var.region

  template {

    metadata {
      annotations = {
        "run.googleapis.com/client-name" = "terraform"
      }
    }

    spec {
      service_account_name = google_service_account.cloud_run_sa.email

      containers {

        image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.backend_repo.repository_id}/twin-backend:latest"

        ports {
          container_port = 8000
        }

        env {
          name  = "OPENAI_API_KEY"
          value = var.openai_api_key
        }

        env {
          name  = "CORS_ORIGINS"
          value = "*"
        }

        env {
          name  = "MEMORY_BUCKET"
          value = google_storage_bucket.memory_bucket.name
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.run_api,
    google_artifact_registry_repository.backend_repo
  ]
}

############################################
# Make Cloud Run public
############################################

resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.backend.name
  location = google_cloud_run_service.backend.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

############################################
# Outputs
############################################

output "backend_url" {
  value = google_cloud_run_service.backend.status[0].url
}

output "frontend_bucket" {
  value = google_storage_bucket.frontend_bucket.name
}

output "memory_bucket" {
  value = google_storage_bucket.memory_bucket.name
}

output "artifact_registry_repo" {
  value = google_artifact_registry_repository.backend_repo.repository_id
}