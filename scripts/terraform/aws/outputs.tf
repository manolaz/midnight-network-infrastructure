output "instance_public_ip" {
  description = "The public IP address of the Midnight Archive Node on AWS"
  value       = aws_instance.midnight_node.public_ip
}

output "ssh_command" {
  description = "Command to SSH into the EC2 instance"
  value       = "ssh -i /path/to/${var.key_name}.pem ubuntu@${aws_instance.midnight_node.public_ip}"
}
