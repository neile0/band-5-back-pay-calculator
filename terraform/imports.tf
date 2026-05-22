# Run `terraform apply` once to import existing resources, then delete this file.

import {
  to = google_project.back_pay_calc
  id = "back-pay-calc"
}

import {
  to = google_project_service.apis["run.googleapis.com"]
  id = "back-pay-calc/run.googleapis.com"
}

import {
  to = google_project_service.apis["artifactregistry.googleapis.com"]
  id = "back-pay-calc/artifactregistry.googleapis.com"
}

import {
  to = google_project_service.apis["iam.googleapis.com"]
  id = "back-pay-calc/iam.googleapis.com"
}

import {
  to = google_project_service.apis["cloudresourcemanager.googleapis.com"]
  id = "back-pay-calc/cloudresourcemanager.googleapis.com"
}

import {
  to = google_project_service.apis["iamcredentials.googleapis.com"]
  id = "back-pay-calc/iamcredentials.googleapis.com"
}

import {
  to = google_artifact_registry_repository.docker
  id = "projects/back-pay-calc/locations/europe-west1/repositories/back-pay-calc"
}

import {
  to = google_service_account.github_actions
  id = "projects/back-pay-calc/serviceAccounts/github-actions@back-pay-calc.iam.gserviceaccount.com"
}

import {
  to = google_project_iam_member.github_actions_roles["roles/run.admin"]
  id = "back-pay-calc roles/run.admin serviceAccount:github-actions@back-pay-calc.iam.gserviceaccount.com"
}

import {
  to = google_project_iam_member.github_actions_roles["roles/artifactregistry.writer"]
  id = "back-pay-calc roles/artifactregistry.writer serviceAccount:github-actions@back-pay-calc.iam.gserviceaccount.com"
}

import {
  to = google_project_iam_member.github_actions_roles["roles/iam.serviceAccountUser"]
  id = "back-pay-calc roles/iam.serviceAccountUser serviceAccount:github-actions@back-pay-calc.iam.gserviceaccount.com"
}

import {
  to = google_iam_workload_identity_pool.github
  id = "projects/back-pay-calc/locations/global/workloadIdentityPools/github-actions"
}

import {
  to = google_iam_workload_identity_pool_provider.github
  id = "projects/back-pay-calc/locations/global/workloadIdentityPools/github-actions/providers/github-oidc"
}

import {
  to = google_service_account_iam_member.wif_binding
  id = "projects/back-pay-calc/serviceAccounts/github-actions@back-pay-calc.iam.gserviceaccount.com roles/iam.workloadIdentityUser principalSet://iam.googleapis.com/projects/196799348587/locations/global/workloadIdentityPools/github-actions/attribute.repository/Neile0/band-5-back-pay-calculator"
}
