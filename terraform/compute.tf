resource "google_compute_instance" "midnight_node" {
  name         = "midnight-archive-node"
  machine_type = var.machine_type
  zone         = var.zone
  project      = var.project_id

  tags = ["midnight-node"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 500
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.midnight_vpc.id
    subnetwork = google_compute_subnetwork.midnight_subnet.id
    
    access_config {
      # Ephemeral public IP
    }
  }

  service_account {
    email  = google_service_account.midnight_node_sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    cd /root
    git clone https://github.com/tristan-midnight-network/midnight-network-infrastructure.git
    cd midnight-network-infrastructure
    bash scripts/install_midnight_archive_node.sh $${var.target_network}
  EOT
}
