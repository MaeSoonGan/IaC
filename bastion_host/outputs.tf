output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_private_key" {
  value     = tls_private_key.bastion.private_key_pem
  sensitive = true
}
