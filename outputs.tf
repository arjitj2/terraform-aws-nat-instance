output "sg_id" {
  description = "ID of the security group of the NAT instance"
  value       = aws_security_group.this.id
}

output "iam_role_name" {
  description = "Name of the IAM role for the NAT instance"
  value       = aws_iam_role.this.name
}
