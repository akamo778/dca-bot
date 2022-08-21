provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  services = toset([
    "run.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com"
  ])
}

resource "google_project_service" "service" {
  for_each           = local.services
  service            = each.value
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

  # Use an explicit depends_on clause to wait until API is enabled
  depends_on = [
    google_project_service.run_api
  ]
}