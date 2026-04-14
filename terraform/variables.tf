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

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
}