provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "run_api" {
  service                    = "run.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "iam_api" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "resource_manager_api" {
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "scheduler_api" {
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild_api" {
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloud_run_service" "default" {
  project  = var.project_id
  name     = "mydcabot-service"
  location = var.region

  template {
    spec {
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.run_api
  ]

  lifecycle {
    ignore_changes = all
  }
}

resource "google_service_account" "default" {
  account_id   = "mydcabot-scheduler-sa"
  description  = "Cloud Scheduler service account; used to trigger scheduled Cloud Run jobs."
  display_name = "mydcabot-scheduler-sa"

  depends_on = [
    google_project_service.iam_api
  ]
}

resource "google_cloud_scheduler_job" "default" {
  name             = "mydcabot-scheduled-cloud-run-job"
  description      = "Invoke a mydcabot Cloud Run container on a schedule."
  schedule         = "0 */6 * * *"
  time_zone        = "Asia/Tokyo"
  attempt_deadline = "320s"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = google_cloud_run_service.default.status[0].url

    oidc_token {
      service_account_email = google_service_account.default.email
    }
  }

  depends_on = [
    google_project_service.scheduler_api
  ]
}

resource "google_cloud_run_service_iam_member" "default" {
  location = google_cloud_run_service.default.location
  service  = google_cloud_run_service.default.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.default.email}"

  depends_on = [
    google_cloud_run_service.default
  ]
}

resource "google_cloudbuild_trigger" "mydcabot-build-trigger" {
  name     = "mydcabot-build-trigger"
  filename = "cloudbuild.yaml"

  # TODO: service account の指定

  github {
    owner = "akamo778"
    name  = "dca-bot"
    push {
      branch = "^main$"
    }
  }

  substitutions = {
    _REGION = var.region
  }

  depends_on = [
    google_project_service.cloudbuild_api
  ]
}
