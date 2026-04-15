############################################
# Enable required APIs
############################################

resource "google_project_service" "services" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "apigateway.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "aiplatform.googleapis.com"
  ])

  project = var.project_id
  service = each.key
}

############################################
# Random suffix
############################################

resource "random_id" "suffix" {
  byte_length = 2
}

############################################
# Storage bucket (frontend)
############################################

resource "google_storage_bucket" "frontend" {
  name     = "${var.project_name}-frontend-${random_id.suffix.hex}"
  location = var.region

  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
  }
}

resource "google_storage_bucket_iam_member" "frontend_public" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

############################################
# Storage bucket (memory)
############################################

resource "google_storage_bucket" "memory" {
  name     = "${var.project_name}-memory-${random_id.suffix.hex}"
  location = var.region

  uniform_bucket_level_access = true
}

############################################
# Service Account
############################################

resource "google_service_account" "function_sa" {
  account_id   = "${var.project_name}-function-sa"
  display_name = "Cloud Function Service Account"
}

resource "google_project_iam_member" "storage_access" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

resource "google_project_iam_member" "vertex_access" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

############################################
# Zip backend code
############################################

data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "../backend"
  output_path = "../backend/function.zip"
}

############################################
# Upload function code
############################################

resource "google_storage_bucket_object" "function_archive" {
  name   = "function.zip"
  bucket = google_storage_bucket.memory.name
  source = data.archive_file.function_zip.output_path
}

############################################
# Cloud Function (Lambda equivalent)
############################################

resource "google_cloudfunctions2_function" "backend" {
  name        = "${var.project_name}-backend"
  location    = var.region
  description = "Digital Twin API"

  build_config {
    runtime     = "python311"
    entry_point = "chat"

    source {
      storage_source {
        bucket = google_storage_bucket.memory.name
        object = google_storage_bucket_object.function_archive.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "512M"

    environment_variables = {
      MEMORY_BUCKET = google_storage_bucket.memory.name
      GCP_PROJECT   = var.project_id
      GCP_REGION    = var.region
    }

    service_account_email = google_service_account.function_sa.email
  }

  depends_on = [google_project_service.services]
}

############################################
# Make function public (VERY IMPORTANT)
############################################

resource "google_cloudfunctions2_function_iam_member" "invoker" {
  project        = var.project_id
  location       = var.region
  cloud_function = google_cloudfunctions2_function.backend.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

############################################
# API Gateway (USES google-beta)
############################################

resource "google_api_gateway_api" "api" {
  provider = google-beta
  api_id   = "${var.project_name}-api"
}

resource "google_api_gateway_api_config" "api_config" {
  provider      = google-beta
  api           = google_api_gateway_api.api.api_id
  api_config_id = "v1"

  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = base64encode(file("${path.module}/openapi.yaml"))
    }
  }
}

resource "google_api_gateway_gateway" "gateway" {
  provider   = google-beta
  api_config = google_api_gateway_api_config.api_config.id
  gateway_id = "${var.project_name}-gateway"
  region     = var.region
}

############################################
# Outputs
############################################

output "api_url" {
  value = google_api_gateway_gateway.gateway.default_hostname
}

output "frontend_bucket" {
  value = google_storage_bucket.frontend.name
}