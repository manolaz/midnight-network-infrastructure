resource "google_compute_network" "midnight_vpc" {
  name                    = "midnight-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "midnight_subnet" {
  name          = "midnight-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.midnight_vpc.id
}

resource "google_compute_firewall" "midnight_node_fw" {
  name    = "midnight-node-fw"
  network = google_compute_network.midnight_vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22", "3000", "3001", "5432", "9090", "9944", "30333"]
  }

  description = "Allow Midnight P2P, RPC, Cardano P2P, PostgreSQL, Prometheus, Grafana, SSH"
  
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["midnight-node"]
}
