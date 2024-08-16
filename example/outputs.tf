output "vpc_id" {
  value = module.ec2_instance.vpc_id
}

output "subnet_id" {
  value = module.ec2_instance.subnet_id
}

output "public_ip" {
  value = module.ec2_instance.public_ip
}

output "id" {
  value = module.ec2_instance.id
}

output "public_key_openssh" {
  value = module.ec2_instance.public_key_openssh
}

output "public_key" {
  value = module.ec2_instance.public_key
}

output "private_key" {
  value = module.ec2_instance.private_key
  sensitive = true
}
