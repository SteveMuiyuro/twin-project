terraform {
  backend "gcs" {
    bucket  = "twin-terraform-state-51053-001"
    prefix  = "terraform/state"
  }
}


############################################
# Enable required APIs
############################################

resource "google_project_service" "services" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "apigateway.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "aiplatform.googleapis.com",
    "compute.googleapis.com" # ✅ REQUIRED FOR CDN
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
    not_found_page   = "index.html"
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
# Cloud Function (Backend)
############################################

resource "google_cloudfunctions2_function" "backend" {
  name        = "${var.project_name}-backend-v2"
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
    timeout_seconds    = 120

    environment_variables = {
      MEMORY_BUCKET  = google_storage_bucket.memory.name
      GCP_PROJECT    = var.project_id
      GCP_REGION     = var.region
      GEMINI_API_KEY = var.gemini_api_key
    }

    service_account_email = google_service_account.function_sa.email
  }

  depends_on = [google_project_service.services]
}

############################################
# Make function public
############################################

resource "google_cloudfunctions2_function_iam_member" "invoker" {
  project        = var.project_id
  location       = var.region
  cloud_function = google_cloudfunctions2_function.backend.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

############################################
# API Gateway
############################################

resource "google_api_gateway_api" "api" {
  provider = google-beta
  api_id   = "${var.project_name}-api"
}

resource "google_api_gateway_api_config" "api_config" {
  provider      = google-beta
  api           = google_api_gateway_api.api.api_id
  api_config_id = "v2"

  lifecycle {
    create_before_destroy = true
  }

  openapi_documents {
    document {
      path = "openapi.yaml"

      contents = base64encode(
        replace(
          file("${path.module}/openapi.yaml"),
          "REPLACE_WITH_FUNCTION_URL",
          google_cloudfunctions2_function.backend.service_config[0].uri
        )
      )
    }
  }

  depends_on = [google_cloudfunctions2_function.backend]
}

resource "google_api_gateway_gateway" "gateway" {
  provider   = google-beta
  api_config = google_api_gateway_api_config.api_config.id
  gateway_id = "${var.project_name}-gateway"
  region     = var.region
}

############################################
# 🔥 CDN SETUP (NEW)
############################################

resource "google_compute_backend_bucket" "frontend_backend" {
  name        = "${var.project_name}-backend-bucket"
  bucket_name = google_storage_bucket.frontend.name
  enable_cdn  = true
}

resource "google_compute_url_map" "frontend_url_map" {
  name            = "${var.project_name}-url-map"
  default_service = google_compute_backend_bucket.frontend_backend.id
}

resource "google_compute_target_http_proxy" "frontend_proxy" {
  name    = "${var.project_name}-http-proxy"
  url_map = google_compute_url_map.frontend_url_map.id
}

resource "google_compute_global_address" "frontend_ip" {
  name = "${var.project_name}-ip"
}

resource "google_compute_global_forwarding_rule" "frontend_rule" {
  name       = "${var.project_name}-forwarding-rule"
  target     = google_compute_target_http_proxy.frontend_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.frontend_ip.address
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

output "cdn_ip" {
  value = google_compute_global_address.frontend_ip.address
}