variable "project_id" {
  description = "GCP project ID (must be globally unique)"
  type        = string
  default     = "back-pay-calc"
}

variable "region" {
  description = "GCP region for Cloud Run and Artifact Registry"
  type        = string
  default     = "europe-west1"
}

variable "org_id" {
  description = "GCP organization ID"
  type        = string
  default     = "843451588951"
}

variable "billing_account" {
  description = "GCP billing account ID"
  type        = string
  default     = "0110A8-CCA9D4-CB26D9"
}

variable "github_repo" {
  description = "GitHub repository (owner/repo) allowed to authenticate via WIF"
  type        = string
  default     = "Neile0/band-5-back-pay-calculator"
}
