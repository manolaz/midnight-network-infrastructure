output "instance_public_ip" {
  description = "The public IP address of the Midnight Archive Node"
  value       = google_compute_instance.midnight_node.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "gcloud compute ssh ${google_compute_instance.midnight_node.name} --zone=${var.zone} --project=${var.project_id}"
}
