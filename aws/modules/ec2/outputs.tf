# Bastion 정보 출력
output "bastion_instance_id" {
  value = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Bastion Host Elastic IP"
  # aws_instance 대신 aws_eip 리소스의 public_ip를 바라보게 변경
  value = aws_eip.bastion.public_ip
}

# Mgmt 정보 출력
output "mgmt_instance_id" {
  value = aws_instance.mgmt.id
}

output "mgmt_private_ip" {
  value = aws_instance.mgmt.private_ip
}

# Management Security Group ID
output "mgmt_security_group_id" {
  description = "Security Group ID of Management Instance"
  value       = aws_security_group.mgmt_sg.id
}

# Bastion Security Group ID
output "bastion_security_group_id" {
  description = "Security Group ID of Bastion Host"
  value       = aws_security_group.bastion_sg.id
}