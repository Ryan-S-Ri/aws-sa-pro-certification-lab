# # Root level outputs
# 
# # Networking outputs
# output "vpc_id" {
#   description = "ID of the VPC"
#   value       = var.enable_networking ? module.networking[0].vpc_id : null
# }
# 
# output "public_subnet_ids" {
#   description = "List of public subnet IDs"
#   value       = var.enable_networking ? module.networking[0].public_subnet_ids : []
# }
# 
# output "private_subnet_ids" {
#   description = "List of private subnet IDs"
#   value       = var.enable_networking ? module.networking[0].private_subnet_ids : []
# }
# 
# # Add other module outputs as needed
