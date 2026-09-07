output "instance_id" {
  description = "The instance id, e.g. i-0abc123. Use it with the aws ec2 CLI."
  value       = aws_instance.vm.id
}

output "public_ip" {
  description = "Public IPv4 address. Changes every stop/start unless you attach an Elastic IP."
  value       = aws_instance.vm.public_ip
}

output "ssh_command" {
  description = "Copy-paste this to log in."
  value       = "ssh -i ~/.ssh/cloud-project ec2-user@${aws_instance.vm.public_ip}"
}

output "web_url" {
  description = "The page served by scripts/user-data.sh."
  value       = "http://${aws_instance.vm.public_ip}/"
}

output "monthly_cost_note" {
  description = "Rough monthly on-demand cost of this instance at 730 hours, before storage and data transfer."
  value       = "t4g.micro at $0.0084/hr = about $6.13/month if left running (us-east-1 list price, 7 Sept 2026). The 20 GiB gp3 root volume is billed separately, per GB-month, for as long as it exists. Run 'terraform destroy' when finished."
}
