output "jenkins_public_ip" {
  description = "Public IP of Jenkins EC2"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins web interface"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH connection to Ubuntu"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.jenkins.public_ip}"
}
