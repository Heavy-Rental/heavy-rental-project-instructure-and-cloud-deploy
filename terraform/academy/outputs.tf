output "portal_alb_dns" {
  value       = aws_lb.portal.dns_name
  description = "Public portal ALB. Students use this. May 502 until branch 3 compose."
}

output "rest_alb_dns" {
  value       = aws_lb.rest.dns_name
  description = "Internal REST ALB. Lands in heavy-rental/portal REST_BASE_URL (branch 3)."
}

output "haystack_alb_dns" {
  value       = aws_lb.haystack.dns_name
  description = "Internal Haystack ALB. Lands in heavy-rental/rest HAYSTACK_URL (branch 3)."
}

output "rds_endpoint" {
  value       = aws_db_instance.heavy_rental.address
  description = "REST SoR RDS hostname (data subnet). Not public."
}

output "rds_port" {
  value       = aws_db_instance.heavy_rental.port
  description = "REST SoR RDS port (5432)."
}

output "rds_database" {
  value       = aws_db_instance.heavy_rental.db_name
  description = "REST SoR database heavy_rental."
}

output "rds_haystack_endpoint" {
  value       = aws_db_instance.haystack.address
  description = "Haystack RDS hostname (data subnet). Not public."
}

output "rds_haystack_port" {
  value       = aws_db_instance.haystack.port
  description = "Haystack RDS port (5432)."
}

output "rds_haystack_database" {
  value       = aws_db_instance.haystack.db_name
  description = "Haystack database name."
}

output "rds_username" {
  value       = aws_db_instance.heavy_rental.username
  description = "Master username on both RDS instances. Password is not an output."
}

output "neo4j_private_ip" {
  value       = aws_network_interface.neo4j.private_ip
  description = "Dedicated ENI IP for bolt://<ip>:7687."
}

output "neo4j_uri" {
  value       = "bolt://${aws_network_interface.neo4j.private_ip}:7687"
  description = "NEO4J_URI for heavy-rental/haystack (branch 3)."
}

output "secret_arns" {
  value       = { for k, s in aws_secretsmanager_secret.app : k => s.arn }
  description = "Empty secret shells. Values wait for sync-secrets."
}

output "asg_names" {
  value = {
    portal   = aws_autoscaling_group.portal.name
    rest     = aws_autoscaling_group.rest.name
    haystack = aws_autoscaling_group.haystack.name
    neo4j    = aws_autoscaling_group.neo4j.name
  }
}

output "nat_instance_id" {
  value       = aws_instance.nat.id
  description = "NAT instance (not a NAT Gateway)."
}

output "vpc_id" {
  value = aws_vpc.academy.id
}

output "lab" {
  value = "aws-academy-vocareum"
}

output "lab_instance_profile" {
  value       = data.aws_iam_instance_profile.lab.name
  description = "Instance profile on NAT + four ASGs. Must be LabInstanceProfile."
}

output "lab_role" {
  value       = data.aws_iam_role.lab.name
  description = "IAM role inside LabInstanceProfile. Must be LabRole."
}
