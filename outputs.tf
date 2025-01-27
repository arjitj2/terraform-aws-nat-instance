output "iam_role_name" {
  description = "Name of the IAM role for the NAT instance"
  value       = aws_iam_role.this.name
}
