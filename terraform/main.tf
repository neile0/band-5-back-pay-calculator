terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  region = var.region
}

# ──────────────────────────────────────────────
# Project
# ──────────────────────────────────────────────
resource "google_project" "back_pay_calc" {
  name                = "back-pay-calc"
  project_id          = var.project_id
  org_id              = var.org_id
  billing_account     = var.billing_account
  auto_create_network = false
}

# ──────────────────────────────────────────────
# Enable APIs
# ──────────────────────────────────────────────
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iamcredentials.googleapis.com",
  ])

  project            = google_project.back_pay_calc.project_id
  service            = each.value
  disable_on_destroy = false
}

# ──────────────────────────────────────────────
# Artifact Registry — Docker repo
# ──────────────────────────────────────────────
resource "google_artifact_registry_repository" "docker" {
  project       = google_project.back_pay_calc.project_id
  location      = var.region
  repository_id = "back-pay-calc"
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"

    most_recent_versions {
      keep_count = 3
    }
  }

  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"

    condition {
      older_than = "604800s" # 7 days
    }
  }

  cleanup_policy_dry_run = false

  depends_on = [google_project_service.apis]
}

# ──────────────────────────────────────────────
# Service account for GitHub Actions CI/CD
# ──────────────────────────────────────────────
resource "google_service_account" "github_actions" {
  project      = google_project.back_pay_calc.project_id
  account_id   = "github-actions"
  display_name = "GitHub Actions CI/CD"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "github_actions_roles" {
  for_each = toset([
    "roles/run.admin",
    "roles/artifactregistry.writer",
    "roles/iam.serviceAccountUser",
  ])

  project = google_project.back_pay_calc.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# ──────────────────────────────────────────────
# Workload Identity Federation for GitHub Actions
# ──────────────────────────────────────────────
resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.back_pay_calc.project_id
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.back_pay_calc.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

# ──────────────────────────────────────────────
# Outputs — paste these into deploy.yml env vars
# ──────────────────────────────────────────────
output "project_id" {
  value = google_project.back_pay_calc.project_id
}

output "artifact_registry_url" {
  value = "${var.region}-docker.pkg.dev/${google_project.back_pay_calc.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "service_account_email" {
  value = google_service_account.github_actions.email
}

output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}
