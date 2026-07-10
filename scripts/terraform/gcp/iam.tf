resource "google_service_account" "midnight_node_sa" {
  account_id   = "midnight-node-sa"
  display_name = "Midnight Node Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.midnight_node_sa.email}"
}

resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.midnight_node_sa.email}"
}
