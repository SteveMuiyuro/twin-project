variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "twin-project-51053"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "twin"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}
variable "gemini_api_key" {
  description = "Gemini API key for Vertex AI"
  type        = string
  sensitive   = true
}
